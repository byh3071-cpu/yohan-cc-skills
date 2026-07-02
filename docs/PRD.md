# PRD — yohan-cc-skills

> 이 문서는 레포 실제 내용(`README.md` · `RULES.md` · `.claude-plugin/marketplace.json` · `plugins/*`)을 근거로 작성됐다. 추측은 `[추론]`, 미확정은 `TBD`로 표기한다.

## 1. 제품 정의

백요한 개인용 **Claude Code 플러그인 마켓플레이스**. Claude Code 스킬·서브에이전트·훅·MCP 설정을 git 레포로 패키징해, 멀티 머신(데스크탑·노트북·새 PC)에 동일 환경을 `install` 한 줄로 배포·동기화하는 것이 핵심이다. (출처: `README.md`)

- 레포: https://github.com/byh3071-cpu/yohan-cc-skills (출처: `RULES.md`)
- 한 줄 설명: "Claude Code operations — handoff · parallel · release-gate (Claude-only)" + 공통 코어(yohan-core). (출처: `RULES.md`, `marketplace.json`)
- 소유자: 백요한 (byh3071@gmail.com). (출처: `marketplace.json` owner)

## 2. 해결하는 문제

Claude Code 스킬은 **로컬 파일**(`~/.claude/skills/`)이라 머신·제품 경계를 자동으로 넘지 않는다. (출처: `README.md`)

- 같은 머신의 CLI ↔ VSCode 확장: `~/.claude` 공유 → 자동 공통.
- 다른 머신 / claude.ai 앱: 자동 동기화 **안 됨**.

→ git 마켓플레이스로 패키징하면 각 머신에서 `claude plugin install ...` 한 줄로 동기화된다(`caveman`·`lazyweb`·`codex`와 동일 방식).

## 3. 목표

1. 멀티 머신 스킬/설정 동기화를 git 한 줄 설치로 달성. (출처: `README.md` "새 머신에 설치")
2. 모든 yohan 생태계 레포에 상속되는 공통 코어(`yohan-core`) 제공 — 말투·보안·작업방식·MCP를 일원화. (출처: `plugins/yohan-core/CLAUDE.md`, `marketplace.json`)
3. 반복 작업을 스킬로 표준화 — 작업 패턴 분석(history 618프롬프트/76세션)에서 도출한 워크플로를 재사용 가능한 스킬로. (출처: `docs/analysis/2026-06-18-work-patterns.md`, `README.md`)

## 4. 범위 (Scope)

### In scope
- Claude Code 플러그인 3종(`yohan-core`, `statusline`, `workflow`) 패키징·버전관리.
- 마켓플레이스 매니페스트(`marketplace.json`)와 플러그인 매니페스트 정합 유지.
- Windows + PowerShell 우선 환경의 훅·상태줄. (출처: `RULES.md` 기술 스택)
- `yohan` MCP(Python) 번들을 통한 Notion 등 외부 연동. (출처: `plugins/yohan-core/.mcp.json`, `CLAUDE.md`)

### Out of scope
- Claude-only 운영 스킬(handoff · release-gate · parallel)은 Cursor에서 중복 구현 금지. (출처: `RULES.md`, `.cursorrules`)
- 비밀값은 코드/훅에 평문 노출 금지 — 머신 환경변수(DPAPI)로만 주입. (출처: `CLAUDE.md` 보안)

## 5. 주요 구성요소

### 5.1 마켓플레이스
- `.claude-plugin/marketplace.json` — 매니페스트. 플러그인 3종 등록(`yohan-core` v0.3.0, `statusline` v0.1.0, `workflow` v0.1.0). (출처: 파일 직접 확인)

### 5.2 `yohan-core` 플러그인 (v0.3.1) — 공통 코어 "두뇌"
모든 레포에 상속되는 공통 운영 메모리. (출처: `plugins/yohan-core/CLAUDE.md`)

- **skills** (6): `cc-docs`, `cost-guard`, `cross-check`, `cursor-docs`, `ship-it`, `yohan-writing`.
- **agents** (4): `explorer`(haiku, 탐색) · `planner`(opus, 설계) · `critic`(opus, 적대검증) · `shipper`(sonnet, 출시). (SoT: `agents/*.md` frontmatter — 값은 거기서 확인)
- **commands** (1): `/yohan-core:flow` — explorer→planner→critic→shipper 4단계 오케스트레이션. (출처: `commands/flow.md`)
- **hooks** (`hooks/hooks.json` + PowerShell 7종): SessionStart `context-hint`, PreToolUse `protect-secrets`/`pre-commit-check`(git commit)/`critic-gate`(git push), PostToolUse `auto-format`, Stop `log-session`, SessionEnd `sync-marketplace`. (출처: `hooks/hooks.json`)
- **output-styles**: `yohan-voice` (한국어 반말·두괄식).
- **references**: `claude-code-docs.md`.
- **loop.md**: 세션 점검 체크리스트.
- **.mcp.json**: `yohan` MCP 서버 번들.

### 5.3 `statusline` 플러그인 (v0.1.0)
- skill `setup-statusline` — Windows PowerShell 상태줄을 `~/.claude`에 배포하고 `settings.json` 병합. ctx 1M 자동감지, tok은 cache_read 제외, UTF-8 출력. (출처: `plugins/statusline/.claude-plugin/plugin.json`, `SKILL.md`)
- assets: `statusline.ps1`(배포 실체).

### 5.4 `workflow` 플러그인 (v0.1.0)
반복 작업 워크플로 스킬 묶음 (6): `release-gate`, `dogfood-crosscheck`, `visualize`, `handoff`, `new-repo`, `parallel`. (출처: `plugins/workflow/skills/*`)

> 참고: `workflow/.claude-plugin/plugin.json`의 description은 일부 스킬만 예시로 열거하나(`new-repo`·`parallel` 미언급), 실제 `skills/` 디렉토리에는 6개가 모두 있다. README 표는 6개 중 6개를 수록. (사실 관찰)

### 5.5 MCP 연동
- `plugins/yohan-core/.mcp.json` — `yohan` 서버를 `python <root>/yohan-mcp/server.py`로 기동. 현재 base 브랜치에서는 경로가 절대경로 하드코딩(`C:/Users/Public/dev/yohan-ecosystem/yohan-mcp/server.py`). Notion 등 외부 연동은 이 서버를 통한다. (출처: 파일 직접 확인, `CLAUDE.md` MCP 섹션)

## 6. 사용자 / 이해관계자
- 1인: 백요한(개발자 겸 사용자). 비전공 1인 개발자, 자작 도구 VHK CLI를 만들며 독푸딩. (출처: `docs/analysis/2026-06-18-work-patterns.md`)

## 7. 설치·사용 (요약)
```
claude plugin marketplace add byh3071-cpu/yohan-cc-skills
claude plugin install statusline@yohan-cc-skills
```
또는 `~/.claude/settings.json`의 `extraKnownMarketplaces`/`enabledPlugins`에 직접 등록. (출처: `README.md`)

## 8. 규칙 전파 (운영 불변식)
- 규칙 단일 소스: `RULES.md` → `vhk sync`로 `AGENTS.md` · `.cursorrules` 전파. AGENTS.md/.cursorrules 손수 편집 금지. (출처: `RULES.md`, `AGENTS.md`)
- 플러그인 매니페스트 변경 시 `marketplace.json` 정합 유지. (출처: 코딩 규칙)

## 9. 미확정 / TBD
- **게이트 명령**: AGENTS.md는 `tsc / test:run / build` 통과를 `vhk goal done` 조건으로 명시하나, 이 레포는 Markdown·PowerShell 위주로 해당 빌드/테스트 스크립트가 레포 루트에 없다. 실제 게이트 정의·CI 구성: **TBD**.
- **MCP 경로 이식성**: `.mcp.json` 절대경로 하드코딩 → 머신별 루트가 다르면 이식성 제약. 환경변수 기반 경로화 여부: **TBD**.
- **루트 CLAUDE.md**: `.cursorrules`·`RULES.md`가 `CLAUDE.md` 참조를 명시하나 레포 루트에 `CLAUDE.md`는 없고 공통 운영 메모리는 `plugins/yohan-core/CLAUDE.md`에 있다(상속용). 루트 참조 정합: **TBD**.
- **향후 스킬 후보**: 작업 패턴 분석에서 도출 예정(별도 분석 결과 참조). (출처: `README.md` "향후 추가 후보")
