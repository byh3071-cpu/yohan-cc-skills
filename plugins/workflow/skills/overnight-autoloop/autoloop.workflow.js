export const meta = {
  name: 'overnight-autoloop',
  description: '무인 자율 결함루프: 감사발굴→수정→검증+적대리뷰→PR(머지X), 아침 보고. args로 파라미터화.',
  phases: [
    { title: 'Discover', detail: '레포별 병렬 감사 → 결함 후보' },
    { title: 'Resolve', detail: '결함당: 진단→수정→검증→적대리뷰→PR/로컬커밋' },
    { title: 'Report', detail: '아침 머지권고 + park 보고' },
  ],
}

// ── 파라미터(args) 검증 — SILENT FALLBACK 금지 (OS 원칙 1호) ─────────
// args = { scope:'audit'|'github'|'both', repos:[{name,path,kind:'python'|'next'}], capPRs:N }
//
// [재발방지] 2026-07-01 밤샘 오실행: Workflow args 하네스 직렬화 버그로 args 가
// 스크립트에 미도달 → 조용히 하드코딩 기본레포(yohan-mcp/control-tower)로 폴백 →
// 엉뚱한 레포에 PR 6개 오생성(8.5h 무감지). 스크립트는 "사용자가 기본값 원함" vs
// "하네스가 args 드롭"을 구분할 수 없으므로 추측 금지 — 불완전 args 면 즉사.
// 기본값 해소는 스킬 런치층(SKILL.md)에서 명시적으로 하고 완전한 args 를 전달할 것.
const VALID_SCOPE = ['audit', 'github', 'both']
const VALID_KIND = ['python', 'next']
function die(msg) {
  throw new Error(
    `[overnight-autoloop] 파라미터 검증 실패 — ${msg}\n` +
    `무인 고비용 작업(PR 생성)이므로 불완전/미수신 args 에 기본값 폴백 금지(silent fallback 금지, 7/1 오실행 재발방지).\n` +
    `호출측이 { scope:'audit|github|both', repos:[{name,path,kind:'python|next'}], capPRs:양의정수 } 를 명시 전달해야 함.\n` +
    `받은 args = ${JSON.stringify(args)}`,
  )
}
// [2026-07-04] Workflow 런타임이 객체 args 를 JSON 문자열로 주입함(프로브 실증: typeof args==='string').
// 7/1 "args 미도달"의 실제 정체 = 미도달이 아니라 문자열 도달. 문자열이면 parse(실패 시 die — silent fallback 아님).
let cfg = args
if (typeof cfg === 'string') { try { cfg = JSON.parse(cfg) } catch (e) { die(`args 문자열 JSON.parse 실패: ${e.message}`) } }
if (!cfg || typeof cfg !== 'object' || Array.isArray(cfg)) die('args 객체 미수신 (Workflow args 직렬화 버그 의심 — 하네스가 스크립트에 args 를 전달했는지 먼저 확인)')
if (!VALID_SCOPE.includes(cfg.scope)) die(`scope 누락/무효 (받음=${JSON.stringify(cfg.scope)}, 허용=${VALID_SCOPE.join('|')})`)
if (!Array.isArray(cfg.repos) || cfg.repos.length === 0) die('repos 누락/빈배열 (대상 레포를 최소 1개 명시)')
cfg.repos.forEach((r, i) => {
  if (!r || typeof r !== 'object') die(`repos[${i}] 객체 아님 (받음=${JSON.stringify(r)})`)
  if (!r.name || typeof r.name !== 'string') die(`repos[${i}].name 누락/무효`)
  if (!r.path || typeof r.path !== 'string') die(`repos[${i}].path 누락/무효`)
  if (!VALID_KIND.includes(r.kind)) die(`repos[${i}].kind 무효 (받음=${JSON.stringify(r.kind)}, 허용=${VALID_KIND.join('|')})`)
})
if (!Number.isInteger(cfg.capPRs) || cfg.capPRs < 1) die(`capPRs 누락/무효 (받음=${JSON.stringify(cfg.capPRs)}, 양의 정수 필요)`)

const REPOS = cfg.repos
const RESOLVE_CAP = cfg.capPRs
const SCOPE = cfg.scope
log(`[params ✓] scope=${SCOPE} · capPRs=${RESOLVE_CAP} · repos=${REPOS.map((r) => `${r.name}(${r.kind})`).join(',')}`)

function verifyCmd(r) {
  return r.kind === 'python'
    ? `cd ${r.path} && PYTHONPATH=${r.path} ${r.path}/.venv/Scripts/python.exe -m pytest -q`
    : `cd ${r.path} && npm run typecheck && npm run lint`
}
function repoOf(name) { return REPOS.find((x) => x.name === name) }

const ENV = `
[실행 환경]
대상 레포: ${REPOS.map((r) => `${r.name}(${r.kind})=${r.path}`).join(' · ')}
- 검증 커맨드: python=pytest(venv), next=typecheck+lint. 레포별: ${REPOS.map((r) => `[${r.name}] ${verifyCmd(r)}`).join(' | ')}
- 앱 도구 실행이 필요하면(예 get_context/status): scratchpad 에 .py 작성, load_dotenv 에 .env 절대경로 명시(없으면 의존백엔드 오폴백). 로컬 인프라: qdrant http://localhost:6333 · ollama http://localhost:11434(bge-m3).
`
const GITRULES = `
[GIT 규율 — 엄수]
- 시작: 해당 레포 cd, git checkout master(트리 더러우면 git checkout -- . 정리). 기본=master.
- 브랜치: git checkout -b <branchName>(있으면 checkout 후 이어서 amend).
- 커밋: git add -A && git commit, 메시지 한국어 + 마지막줄 "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>".
- 종료: 반드시 git checkout master(트리 clean).
[절대 금지] git merge · gh pr merge · git push --force · gh issue/pr close · 다른 브랜치 수정 · 외부 데이터스토어 재적재 · 노션 쓰기.
`

const DEFECTS_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    defects: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        properties: {
          repo: { type: 'string', description: 'REPOS 의 name 중 하나' },
          title: { type: 'string' },
          symptom: { type: 'string' },
          evidence: { type: 'string', description: '파일:라인 또는 실측 출력' },
          severity: { type: 'string', enum: ['high', 'med', 'low'] },
          fixable: { type: 'boolean', description: '경계 분명한 diff로 무인 수정+검증 가능' },
          rationale: { type: 'string', description: '왜 결함이며 기능/설계건이 아닌지' },
        },
        required: ['repo', 'title', 'symptom', 'evidence', 'severity', 'fixable', 'rationale'],
      },
    },
  },
  required: ['defects'],
}

// ── DISCOVER ────────────────────────────────────────────────────
const DISC = []
for (const r of REPOS) {
  DISC.push({ key: `${r.name}-correct`, prompt: `${ENV}\n[감사] ${r.name}(${r.kind}) 경로=${r.path} 핵심 로직 정확성 결함 사냥. 잘못된 계산/분기/None-safety/경계조건/계약위반을 실증거(파일:라인 + 실행출력)로. 기능/설계건·추측 제외.` })
  DISC.push({ key: `${r.name}-robust`, prompt: `${ENV}\n[감사] ${r.name} 견고성·데이터정합 결함. 조용한 에러삼킴(except: pass/빈폴백), 검증/스키마 누락, 설정정합(id·차원·키), 재시도/타임아웃 누락. 신규 건만, 실증거 필수.` })
}
if (REPOS.length > 1) {
  DISC.push({ key: 'cross', prompt: `${ENV}\n[감사] 레포 간 교차 정합 결함. 공유 스키마·벡터차원·임베딩모델·payload 키(쓰는쪽 vs 읽는쪽) 불일치 사냥. 실제 데이터와 코드 대조. 레포: ${REPOS.map((r) => r.name + ':' + r.path).join(', ')}` })
}
if (SCOPE === 'github' || SCOPE === 'both') {
  DISC.push({ key: 'github', prompt: `${ENV}\n[수집] 각 레포 'gh issue list --state open' 에서 무인 수정가능한 '버그/결함'만 추려라(대형기능·설계필요·중복 이슈 제외). 각 건을 fixable defect 로 변환. 레포: ${REPOS.map((r) => r.path).join(', ')}` })
}

phase('Discover')
const discovered = await parallel(
  DISC.map((d) => () => agent(d.prompt, { label: `audit:${d.key}`, phase: 'Discover', schema: DEFECTS_SCHEMA, effort: 'high' })),
)
let all = []
for (const r of discovered) if (r && Array.isArray(r.defects)) all = all.concat(r.defects)
const SEV = { high: 0, med: 1, low: 2 }
const seen = new Set()
const fixable = []
for (const d of all) {
  if (!d || !d.fixable || !repoOf(d.repo)) continue
  const k = (d.repo + '|' + (d.title || '').toLowerCase().trim()).slice(0, 120)
  if (seen.has(k)) continue
  seen.add(k)
  fixable.push(d)
}
fixable.sort((a, b) => (SEV[a.severity] ?? 3) - (SEV[b.severity] ?? 3))
const toResolve = fixable.slice(0, RESOLVE_CAP)
const deferred = fixable.slice(RESOLVE_CAP)
log(`발굴 ${all.length} · 수정가능 ${fixable.length} · 해결시도 ${toResolve.length} · 보류 ${deferred.length}`)

function branchFor(d, i) {
  const s = (d.title || 'fix').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '').slice(0, 28) || 'fix'
  return `auto-fix/${(repoOf(d.repo).name || 'repo').slice(0, 4)}-${i + 1}-${s}`
}

const FIX_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    status: { type: 'string', enum: ['fixed', 'cannot'] },
    branch: { type: 'string' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    diffSummary: { type: 'string' },
    selfChecks: { type: 'string', description: '검증 실제 실행 결과 요약(통과/실패+핵심출력)' },
    committed: { type: 'boolean' },
    notes: { type: 'string' },
  },
  required: ['status', 'branch', 'committed', 'selfChecks', 'notes'],
}
const REVIEW_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    blocker: { type: 'boolean' },
    issues: { type: 'array', items: { type: 'object', additionalProperties: false, properties: { severity: { type: 'string' }, desc: { type: 'string' } }, required: ['severity', 'desc'] } },
    verdict: { type: 'string' },
  },
  required: ['blocker', 'issues', 'verdict'],
}
const FINAL_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { pushed: { type: 'boolean' }, prUrl: { type: 'string' }, blockedReason: { type: 'string' } },
  required: ['pushed', 'prUrl', 'blockedReason'],
}

// ── RESOLVE (결함당 순차) ────────────────────────────────────────
phase('Resolve')
const results = []
for (let i = 0; i < toResolve.length; i++) {
  const d = toResolve[i]
  const r = repoOf(d.repo)
  const branch = branchFor(d, i)
  log(`[해결 ${i + 1}/${toResolve.length}] ${d.repo}: ${d.title}`)
  let attempt = 0, resolved = false, pushed = false, prUrl = '', parkReason = '', lastReview = '', lastSelf = '', prev = ''
  while (attempt < 3 && !resolved) {
    attempt++
    const fix = await agent(
      `${ENV}\n${GITRULES}\n[수정 ${attempt}/3] 레포=${d.repo} 경로=${r.path} 브랜치명=${branch} 검증=${verifyCmd(r)}\n결함: ${JSON.stringify(d)}\n${prev ? '직전 적대리뷰 피드백(반영): ' + prev : ''}\n근본원인 진단(증상패치 금지)→최소 diff 수정→검증 실제 실행→통과 시 로컬 커밋. 실패면 status=cannot+사유. push/PR 은 금지(다음 단계).`,
      { label: `fix:${d.repo}#${i + 1}.${attempt}`, phase: 'Resolve', schema: FIX_SCHEMA, effort: 'high' },
    )
    if (!fix || fix.status !== 'fixed' || !fix.committed) {
      parkReason = fix ? `수정/검증 실패: ${fix.notes} | ${fix.selfChecks}` : 'fix agent 무응답'
      lastSelf = fix ? fix.selfChecks : ''
      continue
    }
    lastSelf = fix.selfChecks
    const rev = await agent(
      `${ENV}\n[적대 리뷰] 레포=${d.repo} 경로=${r.path} 브랜치=${branch}. git -C ${r.path} diff master...${branch} 를 적대적으로 검토. 결함 실제 해결·회귀·범위이탈·검증누락 점검. 머지 막을 문제면 blocker=true. 읽기만(파일수정 금지).`,
      { label: `review:${d.repo}#${i + 1}.${attempt}`, phase: 'Resolve', schema: REVIEW_SCHEMA, effort: 'high' },
    )
    lastReview = rev ? rev.verdict : '리뷰 무응답'
    if (rev && !rev.blocker) {
      const fin = await agent(
        `${ENV}\n${GITRULES}\n[확정 push+PR] 레포=${d.repo} 경로=${r.path} 브랜치=${branch}. git push -u origin ${branch} 후 gh pr create --base master --head ${branch}(제목·본문 한국어, 본문에 결함요약·수정·검증결과·"머지 금지: 사람 검토 대기" + 끝에 "🤖 Generated with Claude Code"). 머지 절대 금지. push/gh 가 막히면 pushed=false·blockedReason 기록, 로컬커밋은 유지. 끝에 git checkout master.`,
        { label: `finalize:${d.repo}#${i + 1}`, phase: 'Resolve', schema: FINAL_SCHEMA, effort: 'medium' },
      )
      pushed = fin ? fin.pushed : false
      prUrl = fin ? fin.prUrl : ''
      if (fin && !fin.pushed) parkReason = `수정완료·로컬커밋, push/PR 차단: ${fin.blockedReason}`
      resolved = true
    } else {
      prev = rev ? JSON.stringify(rev.issues) : 'review blocker(미상)'
    }
  }
  results.push({
    repo: d.repo, title: d.title, severity: d.severity, branch,
    outcome: resolved ? (pushed ? 'PR생성' : '로컬커밋(차단/대기)') : 'park(3회실패)',
    attempts: attempt, pushed, prUrl, parkReason, lastReview, lastSelf,
  })
}

// ── REPORT ──────────────────────────────────────────────────────
phase('Report')
const REPORT_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    headline: { type: 'string' },
    morning_report_md: { type: 'string', description: '아침 보고 두괄식 한국어 md: PR별 머지권고(권고/보류+근거)·park목록+사유·미시도 발굴목록·후속권고.' },
  },
  required: ['headline', 'morning_report_md'],
}
const report = await agent(
  `무인 자율 결함루프 결과를 아침 보고서(두괄식 한국어 md)로 합성. 머지 결정은 사람이 아침에 한다(밤=머지 0). PR별 머지권고·근거, park 사유, 미시도 발굴목록 포함. 과장 금지.\n\n해결:\n${JSON.stringify(results)}\n\n미시도(보류):\n${JSON.stringify(deferred)}\n\n전체 발굴=${all.length}`,
  { label: 'report', phase: 'Report', schema: REPORT_SCHEMA, effort: 'high' },
)

return {
  headline: report ? report.headline : '보고 합성 실패(report agent 무응답) — summary·results·deferred 원본으로 보고할 것',
  report_md: report ? report.morning_report_md : `# 아침 보고 합성 실패\n\nreport agent 가 결과를 반환하지 못함. 아래 원본 데이터로 수기 보고 필요.\n\n## results\n${JSON.stringify(results, null, 2)}\n\n## deferred\n${JSON.stringify(deferred, null, 2)}`,
  summary: {
    discovered: all.length, fixable: fixable.length, attempted: toResolve.length,
    prs: results.filter((x) => x.pushed).length,
    localOnly: results.filter((x) => x.outcome === '로컬커밋(차단/대기)').length,
    parked: results.filter((x) => x.outcome.startsWith('park')).length,
  },
  results, deferred,
}
