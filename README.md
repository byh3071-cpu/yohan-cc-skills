# yohan-cc-skills

백요한 개인 Claude Code 플러그인 마켓플레이스. 멀티 머신(데스크탑·노트북·새 PC)에 동일한 스킬을 한 줄로 배포하기 위한 git 기반 레포.

## 왜 레포인가
Claude Code 스킬은 **로컬 파일**(`~/.claude/skills/`)이라 머신·제품 경계를 자동으로 넘지 않는다:
- 같은 머신 CLI ↔ VSCode 확장: `~/.claude` 공유 → 자동 공통
- 다른 머신 / claude.ai 앱: 자동 동기화 **안 됨**

→ git 마켓플레이스로 패키징하면 각 머신에서 `install` 한 줄로 동기화된다. (`caveman`·`lazyweb`·`codex` 와 동일한 방식)

## 새 머신에 설치
GitHub 에 push 된 뒤:
```
claude plugin marketplace add byh3071-cpu/yohan-cc-skills
claude plugin install statusline@yohan-cc-skills
```
또는 `~/.claude/settings.json` 에 직접:
```json
"extraKnownMarketplaces": {
  "yohan-cc-skills": { "source": { "source": "github", "repo": "byh3071-cpu/yohan-cc-skills" } }
},
"enabledPlugins": { "statusline@yohan-cc-skills": true }
```
설치 후 상태줄 세팅:
```
/setup-statusline
```

## 수록 플러그인 (4종)

> 열거·버전 SoT는 `.claude-plugin/marketplace.json` + 각 `plugin.json`. 아래 표는 그 미러다(하드코딩 버전 금지).

| 플러그인 | 구성 | 내용 |
|---|---|---|
| `yohan-core` | 스킬 10 · 서브에이전트 6 · 훅 9 · MCP | 모든 레포에 상속되는 공통 두뇌. 스킬(cc-docs·cost-guard·cross-check·cursor-docs·naver-convert·**plan-audit**·ship-it·studio-post·yohan-writing·youtube-summary) + 서브에이전트(explorer·planner·critic·shipper·prd-generator·prd-validator) + 보안/포맷/세션로그·라우팅미스감지 훅 + yohan-voice 출력스타일 + yohan MCP(Notion) |
| `statusline` | `/setup-statusline` | Windows PowerShell 상태줄 배포 + settings.json 병합. ctx 1M 자동감지, tok=실작업량(cache_read 제외), caveman 태그 머지, UTF-8 출력 |
| `workflow` | 스킬 7 | 반복 작업 워크플로 묶음 (아래 표) |
| `critical-thinking` | `/critical` · skeptic | 비판적 사고 모드 — 소크라테스식 질문·CoVe 자가검증·steelman-attack으로 아첨·할루시네이션 억제. `/critical lite\|full\|ultra\|auto\|off` 토글 + critical-thinking 스킬 + skeptic 서브에이전트. 대화·추론 시점 담당(코드용 critic과 분리). 기본 OFF 옵트인 |

### `workflow` 스킬 (7)
| 스킬 | 내용 |
|---|---|
| `/release-gate` | 머지·publish 전 게이트(tsc→eslint→build)+테스트+적대적 리뷰를 문제 0까지, PR→머지→태그. 사람몫(2FA)만 스킵 |
| `/dogfood-crosscheck` | VHK 독푸딩 → CC 독립분석 교차대조 → 도구결함 vs 앱버그 분류 → 이슈 초안 |
| `/visualize` | 디자인 시안 5~6개(단일 HTML) / 결과·버전비교 HTML 보고서(두괄식·비개발자용) |
| `/handoff` | **채팅 종료 검증** scan/close(기본)/full — 재고(문서·적재·갱신·핸드오프·Goal·git·브랜치) + 안전 조치 + 전달프롬프트 |
| `/new-repo` | 새 GitHub 레포 생성 + 그룹 자동분류 + repos.json 등록·push → 멀티PC 같은 폴더 자동 정리 |
| `/parallel` | 병렬·동시 작업 시 worktree 자동 격리(생성·작업·정리) → 충돌 0. worktree 몰라도 됨 |
| `/overnight-autoloop` | 무인 야간 결함 발굴→수정→검증→PR 루프(머지 금지). run 간 이월 + 같은 파일 배칭 |

## 구조
```
.claude-plugin/marketplace.json        # 마켓플레이스 매니페스트 (플러그인 4종)
plugins/
  yohan-core/                          # 공통 코어 "두뇌"
    .claude-plugin/plugin.json
    CLAUDE.md · .mcp.json · loop.md
    agents/ · commands/ · hooks/ · output-styles/ · references/ · skills/
  statusline/
    .claude-plugin/plugin.json
    skills/setup-statusline/
      SKILL.md                         # 배포·병합·검증 절차 + 인코딩 불변식
      assets/statusline.ps1            # 배포되는 실제 스크립트(검증본)
  workflow/                            # 워크플로 스킬 7종
    .claude-plugin/plugin.json
    skills/{release-gate,dogfood-crosscheck,visualize,handoff,new-repo,parallel,overnight-autoloop}/
  critical-thinking/                   # 비판적 사고 모드 (기본 OFF 옵트인)
    .claude-plugin/plugin.json
    agents/skeptic.md · commands/critical.md · skills/critical-thinking/
```

## 향후 추가 후보
작업 패턴 분석(history 618프롬프트/76세션 기준)에서 나온 반복 작업을 스킬로 추가 예정. (별도 분석 결과 참조)
