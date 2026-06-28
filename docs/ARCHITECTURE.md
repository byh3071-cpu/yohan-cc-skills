# ARCHITECTURE — yohan-cc-skills

> 실제 디렉토리/모듈 구조·마켓플레이스 구조·MCP 연동을 파일 직접 확인 기준으로 기술한다. 미확정은 `TBD`.

## 1. 한눈에

git 레포 = **Claude Code 플러그인 마켓플레이스**. 루트 매니페스트(`marketplace.json`)가 `plugins/` 아래 3개 플러그인을 가리키고, 각 플러그인은 자체 매니페스트(`.claude-plugin/plugin.json`)와 구성요소(skills · agents · hooks · commands · MCP)를 갖는다. 규칙은 `RULES.md`(SoT)에서 `vhk sync`로 `AGENTS.md`·`.cursorrules`에 전파된다.

## 2. 디렉토리 구조 (실측)

```
yohan-cc-skills/
├─ .claude-plugin/
│  └─ marketplace.json              # 마켓플레이스 매니페스트 (플러그인 3종 등록)
├─ .agents/
│  └─ CORE-RULES.md
├─ .cursor/
│  ├─ mcp.json.example
│  └─ rules/ecosystem.mdc           # vhk inject-bootstrap (생태계 규칙)
├─ .vhk/                            # VHK CLI 상태(context.md, README.md)
├─ .cursorrules                     # RULES.md에서 자동 생성 (직접 수정 금지)
├─ AGENTS.md                        # RULES.md에서 자동 생성 (직접 수정 금지)
├─ RULES.md                         # 규칙 단일 소스(SoT)
├─ README.md
├─ CLAUDE-CODE-SETUP-HANDOFF.md
├─ dotfiles/claude/settings.json
├─ docs/
│  ├─ PRD.md                        # 본 PRD
│  ├─ ARCHITECTURE.md               # 본 문서
│  ├─ state/                        # next-task / blockers (append-only)
│  ├─ analysis/2026-06-18-work-patterns.md
│  └─ patterns/PAT-001-ps-statusline-encoding.md
└─ plugins/
   ├─ yohan-core/                   # 공통 코어 플러그인 (v0.3.0)
   ├─ statusline/                   # 상태줄 셋업 (v0.1.0)
   └─ workflow/                     # 워크플로 스킬 묶음 (v0.1.0)
```

## 3. 마켓플레이스 구조

`.claude-plugin/marketplace.json`:
- `name`: `yohan-cc-skills`, `owner`: 백요한, `metadata.version`: `0.1.0`.
- `plugins[]`: 각 항목이 `{ name, source(상대경로 ./plugins/<x>), description, version }`.
  - `yohan-core` → `./plugins/yohan-core` (v0.3.0)
  - `statusline` → `./plugins/statusline` (v0.1.0)
  - `workflow` → `./plugins/workflow` (v0.1.0)

각 플러그인 디렉토리는 `.claude-plugin/plugin.json`(name·description·version·author·homepage)을 자체 매니페스트로 갖는다. **불변식**: 플러그인 매니페스트 변경 시 `marketplace.json` 버전·메타 정합 유지(`RULES.md` 코딩 규칙). SessionEnd 훅 `sync-marketplace.ps1`이 관련 동기화를 담당한다(파일명 기반).

## 4. 플러그인 모듈 구조

### 4.1 yohan-core (공통 코어)
```
plugins/yohan-core/
├─ .claude-plugin/plugin.json
├─ .mcp.json                        # yohan MCP 서버 정의
├─ CLAUDE.md                        # 공통 운영 메모리(상속용)
├─ loop.md                          # 세션 점검 체크리스트
├─ agents/      explorer · planner · critic · shipper   (.md, frontmatter에 model/tools)
├─ commands/    flow.md             (/yohan-core:flow)
├─ hooks/       hooks.json + 7 ps1
├─ output-styles/ yohan-voice.md
├─ references/  claude-code-docs.md
└─ skills/      cc-docs · cost-guard · cross-check · cursor-docs · ship-it · yohan-writing
```

- **서브에이전트 파이프라인**: `/yohan-core:flow`가 explorer(탐색)→planner(설계)→critic(적대검증, 문제0까지 반복)→shipper(출시) 순으로 위임. (출처: `commands/flow.md`)
- **모델 배치**: explorer=haiku, planner/critic/shipper=sonnet. (출처: agent frontmatter)
- **skills**는 각 `SKILL.md`(frontmatter `name`/`description`, 일부 `allowed-tools`·`disable-model-invocation`)로 정의. `ship-it`은 `disable-model-invocation: true` + git 전용 allowed-tools.

### 4.2 statusline
```
plugins/statusline/
├─ .claude-plugin/plugin.json
└─ skills/setup-statusline/
   ├─ SKILL.md                      # 배포·병합·검증 절차 + 인코딩 불변식
   └─ assets/statusline.ps1         # 배포되는 실제 스크립트(검증본)
```

### 4.3 workflow
```
plugins/workflow/
├─ .claude-plugin/plugin.json
└─ skills/
   ├─ release-gate/        SKILL.md  # 게이트(tsc→eslint→build)+테스트+적대리뷰 문제0, PR→머지→태그
   ├─ dogfood-crosscheck/  SKILL.md  # VHK 독푸딩 교차검증 · 결함 역추적
   ├─ visualize/           SKILL.md  # 디자인 시안/HTML 시각화 보고
   ├─ handoff/             SKILL.md  # 세션 핸드오프 · 멀티머신 복원
   ├─ new-repo/            SKILL.md  # 새 GitHub 레포 생성·그룹분류·repos.json
   └─ parallel/            SKILL.md  # git worktree 자동 격리(병렬 작업)
```

## 5. 훅(hook) 생명주기

`plugins/yohan-core/hooks/hooks.json`이 Claude Code 이벤트에 PowerShell 스크립트를 연결한다(모두 `powershell -NoProfile -ExecutionPolicy Bypass -File`, `${CLAUDE_PLUGIN_ROOT}` 기준 경로):

| 이벤트 | matcher / 조건 | 스크립트 | 용도(파일명·CLAUDE.md 근거) |
|---|---|---|---|
| SessionStart | `startup\|resume` | context-hint.ps1 | 세션 시작 컨텍스트 힌트 |
| PreToolUse | `Bash\|Write\|Edit\|Read` | protect-secrets.ps1 | 비밀 파일 읽기/노출 차단 |
| PreToolUse | `Bash` + `git commit *` | pre-commit-check.ps1 | 커밋 전 토큰·키 유출 점검 |
| PreToolUse | `Bash` + `git push *` | critic-gate.ps1 | push 전 게이트(critic) |
| PostToolUse | `Write\|Edit` | auto-format.ps1 | 편집 후 자동 포맷 |
| Stop | (전체) | log-session.ps1 | 세션 로그 기록(CLAUDE.md: Notion EXECUTION LOG, SoT Key 멱등) |
| SessionEnd | (전체) | sync-marketplace.ps1 | 마켓플레이스 동기화 |

> 보안 불변식: `.env`·`secrets/`·`*.pem`·`*.key`·토큰 파일은 읽기/커밋 금지(protect-secrets·pre-commit-check 훅이 강제). (출처: `CLAUDE.md` 보안 섹션)

## 6. MCP 연동

`plugins/yohan-core/.mcp.json`:
```json
{ "mcpServers": { "yohan": { "command": "python",
  "args": ["C:/Users/Public/dev/yohan-ecosystem/yohan-mcp/server.py"] } } }
```
- `yohan` MCP = 별도 레포(`yohan-mcp`)의 Python 서버. Notion 등 외부 연동은 이 서버를 통한다. (출처: `CLAUDE.md` MCP 섹션)
- 현재 base 브랜치 기준 경로는 절대경로 하드코딩 → 머신별 개발 루트가 다르면 이식성 제약(TBD: 환경변수 기반 경로화).
- Cursor용 예시는 `.cursor/mcp.json.example` 제공.

## 7. 규칙 전파 체인 (운영 아키텍처)

```
RULES.md  (단일 소스 SoT)
   │  vhk sync
   ├─▶ AGENTS.md      (에이전트 작동 규약 — 손수 편집 금지)
   └─▶ .cursorrules   (Cursor 규칙 — 손수 편집 금지)
```
- 생태계(cross-repo) 계약 SoT: yohan-brain `memory/core/ecosystem-contract.yaml`, tier 레지스트리 `inheritance-registry.yaml`. (출처: `AGENTS.md` Ecosystem)
- Cursor 생태계 규칙은 `.cursor/rules/ecosystem.mdc`(vhk inject-bootstrap).
- Loop Protocol: `context → goal next → 작업 → goal check → goal done`, `.vhk/HARD_STOP` 존재 시 자동화 즉시 중단, active goal만 작업, `docs/state`(next-task/blockers)는 append-only. (출처: `AGENTS.md`)

## 8. 배포 흐름 (요약)
1. 레포를 GitHub에 push.
2. 머신에서 `claude plugin marketplace add byh3071-cpu/yohan-cc-skills`.
3. `claude plugin install <plugin>@yohan-cc-skills` 또는 `settings.json`에 직접 등록.
4. statusline은 `/setup-statusline`으로 `~/.claude`에 배포·병합. (출처: `README.md`)

## 9. TBD
- 빌드/테스트 게이트(`tsc`/`test:run`/`build`) 실제 정의·CI: 레포 루트에 해당 스크립트 없음 → TBD.
- MCP 경로 이식성(절대경로 → 환경변수) → TBD.
- 루트 `CLAUDE.md` 부재 vs `.cursorrules`/`RULES.md` 참조 정합 → TBD.
