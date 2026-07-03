---
name: overnight-autoloop
description: "Use when 백요한 wants an unattended autonomous overnight run that finds, fixes, and PRs code defects on the yohan ecosystem repos. Triggers: '자는 동안 돌려', '자는 동안 goal', '오토파일럿 밤새', '무인 결함루프', '자율 수정 돌려', '밤새 고쳐놔', 'overnight loop', 'autonomous fix loop'."
---

# Overnight Autoloop

## Overview
백요한이 자는 동안 무인으로 코드 결함을 **감사발굴→진단→수정→검증+적대리뷰→PR(머지 X)** 한 바퀴 돌리고 아침에 머지권고만 보고. 엔진은 Workflow 스크립트(`autoloop.workflow.js`), 이 스킬은 파라미터 수집 + 런칭 + 아침 보고 담당.

**되돌리기 어려운 것 전면 금지**(머지·close·force-push·외부데이터 재적재·노션쓰기). LLM 은 수정·검증만, 머지 결정은 아침에 사람.

## When to Use
- 트리거 문구(위 description) 나오면 발동.
- 무인으로 결함을 고쳐 PR까지 만들어두고 싶을 때.
**When NOT:** 대형 기능 구현·설계판단 필요 작업(무인 부적합) · 단일 버그 즉시수정(그냥 고쳐라).

## Launch Steps
1. **파라미터 3개를 런치층에서 완전히 확정** (`AskUserQuestion`). 사용자가 "알아서"라 하면 아래 기본값을 **명시적으로 확정해 args 에 실어 전달**한다(스크립트에 기본값 없음 — 아래 ⚠️):
   - **scope**: `audit`(감사발굴, 기본) | `github`(열린 이슈) | `both`
   - **repos**: 기본 `[{name:'yohan-mcp',path:'C:/Users/Public/dev/yohan-ecosystem/yohan-mcp',kind:'python'}, {name:'control-tower',path:'C:/Users/Public/dev/yohan-ecosystem/yohan-control-tower',kind:'next'}]`. 다르면 `{name,path,kind}` 배열. **런칭 전 각 path 실재 확인**(`Test-Path`) — 없는 경로 있으면 런칭 중단하고 사용자에게 확인 (머신마다 레포 위치 다를 수 있음).
   - **capPRs**: 해결 시도 상한(기본 6, 양의 정수). 나머지는 발굴목록만.
2. **scriptPath 절대경로 해석 (필수 선행)**: 엔진은 이 스킬과 같은 폴더의 `autoloop.workflow.js` (논리 경로 `${CLAUDE_PLUGIN_ROOT}/skills/overnight-autoloop/autoloop.workflow.js`). ⚠️ **Workflow tool 은 `${CLAUDE_PLUGIN_ROOT}` 를 확장하지 않는다** — 리터럴로 넘기면 파일 못 찾고 죽는다. 반드시 절대경로로 풀어서 전달:
   - Glob `~/.claude/plugins/cache/yohan-cc-skills/workflow/*/skills/overnight-autoloop/autoloop.workflow.js` → 매칭 경로 사용 (복수면 최신 버전 디렉터리).
   - 매칭 0건이면 중단하고 사용자에게 `/plugin update` 요청 (구버전 플러그인).
3. **Workflow 런칭**: `Workflow({ scriptPath: "<2에서 해석한 절대경로>", args: { scope, repos, capPRs } })`. 백그라운드 완주 후 알림.
   - ⚠️ **args 미전달/불완전이면 스크립트가 즉사한다**(silent fallback 금지, 7/1 오실행 재발방지). 기본값 폴백은 이제 스크립트가 아니라 **이 런치층 책임** — "알아서"여도 반드시 완전한 `{scope,repos,capPRs}` 를 만들어 넘길 것.
   - ✅ **args 전달 확인**: 진행로그 첫 줄에 `[params ✓] scope=… · capPRs=… · repos=…` 가 떠야 정상. 이 줄이 없거나 workflow 가 `[overnight-autoloop] 파라미터 검증 실패` 로 죽으면 = Workflow args 하네스 버그 재현 → 하드코딩 args 로 재런칭(임시) + blockers 기록.
4. 사용자에게 "가동 + 자도 됨" 1줄 + 안전요약 보고.

## On Completion (알림 턴)
- 워크플로 반환 `report_md` 를 `<주레포>/docs/audits/overnight-<날짜>.md` 로 저장(날짜는 알림 시점 stamp).
- `summary`(PR수·로컬커밋·park) + **PR별 머지권고**(권고/보류+근거)를 두괄식으로 보고.
- **self-merge 주의**: 자동승인 분류기가 PR 생성/머지를 막을 수 있음(실측). 막힌 건 "로컬커밋(차단/대기)"로 표기되고 아침에 사람 탭 1회 필요.

## Quick Reference
| 항목 | 값 |
|---|---|
| 엔진 | `autoloop.workflow.js` (args 파라미터화) |
| 게이트 | 검증(pytest / typecheck+lint) + 적대리뷰 blocker 0 |
| 재시도 | 결함당 ≤3회, 초과 시 park |
| 밤 산출 | 브랜치 commit + (가능 시)push+PR. 머지 0 |
| 폴백 | push/PR 차단 시 로컬커밋까지 + 아침보고 |

## Common Mistakes
- scriptPath 에 `${CLAUDE_PLUGIN_ROOT}` 리터럴 그대로 전달 → Workflow tool 은 변수 확장 안 함. Glob 으로 절대경로 해석 후 전달 (Launch Steps 2).
- 파라미터 없이 바로 런칭 → scope/repos/cap 먼저 **런치층에서 완전 확정**해 args 로 전달(스크립트 기본값 폴백 없음, "알아서"여도 명시 확정).
- args 전달 확인 생략 → `[params ✓]` 로그 줄 확인 필수(안 뜨면 args 미도달 = 오실행 위험).
- 완료 보고를 chat 에만 → 반드시 `docs/audits/` 파일로도 떨굼(산출물 색인).
- 머지까지 자동 시도 → 금지. 권고만, 머지는 사람.

## 관련
범용 코어 독트린(되돌릴 수 없는 작업 4중 안전장치) = 글로벌 PAT-003. 메모리 `overnight-autoloop-spec` 와 동기화.
