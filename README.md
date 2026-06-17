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

## 수록 플러그인
| 플러그인 | 스킬 | 내용 |
|---|---|---|
| `statusline` | `/setup-statusline` | Windows PowerShell 상태줄 배포 + settings.json 병합. ctx 1M 자동감지, tok=실작업량(cache_read 제외), caveman 태그 머지, UTF-8 출력 |

## 구조
```
.claude-plugin/marketplace.json        # 마켓플레이스 매니페스트
plugins/statusline/
  .claude-plugin/plugin.json
  skills/setup-statusline/
    SKILL.md                           # 배포·병합·검증 절차 + 인코딩 불변식
    assets/statusline.ps1              # 배포되는 실제 스크립트(검증본)
```

## 향후 추가 후보
작업 패턴 분석(history 618프롬프트/76세션 기준)에서 나온 반복 작업을 스킬로 추가 예정. (별도 분석 결과 참조)
