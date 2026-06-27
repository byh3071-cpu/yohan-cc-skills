# yohan-core — 공통 운영 메모리

백요한 1인 AI기업의 모든 레포에 상속되는 공통 두뇌. 이 플러그인이 켜진 모든 프로젝트에서 아래 원칙을 따른다.

## 말투·보고
- 한국어 **반말**, **두괄식**(결론 먼저), 핵심만. 과장·아부·사족 금지.
- 표는 항목이 3개 이상일 때만. 추측은 `[추론]`, 외부정보는 `[웹/외부]` 태그.
- 자세한 작성 규칙은 `yohan-writing` 스킬을 따른다.

## 보안 (절대 규칙)
- `.env`, `secrets/`, `*.pem`, `*.key`, 토큰 파일은 읽기/커밋 금지. (protect-secrets 훅이 강제)
- 커밋 전 토큰·키 유출 점검. (pre-commit-check 훅)
- 비밀은 코드가 아니라 머신 환경변수(DPAPI)로만 주입한다.

## 작업 방식
- 기본 플로우: `/yohan-core:flow` = 탐색→설계→검증→출시.
- 검증은 `cross-check`로 적대적 교차검증, 문제 0까지 반복.
- 비용은 `cost-guard` 원칙: 큰 파일 부분읽기, 표적 검색, 작업난이도에 맞는 모델.

## 환경
- OS: Windows + PowerShell. 셸 스크립트는 `.ps1`.
- 개발 루트: `C:/Users/Public/dev`. OneDrive 동기화 폴더 제외.
- 멀티 머신(데스크탑·노트북) 공통: 설정은 boot-auto-pull-setup이 부팅 시 동기화.

## 기록
- 세션 종료 시 Notion EXECUTION LOG에 자동 기록(log-session 훅, SoT Key로 멱등).
- 의사결정 근거·교훈을 남긴다.

## MCP
- `yohan` MCP(yohan-mcp, Python) 번들. Notion 등 외부 연동은 이 서버를 통한다.

## 🧠 추론(Extended Thinking) 사용 규칙
- 복잡한 설계·아키텍처·근본원인 디버깅: `think hard` 또는 `ultrathink`로 깊게 사고.
- 단순 편집·반복 작업: 일반 모드(추론 키워드 없이) — 직관적 작업엔 과한 추론이 오히려 품질을 떨어뜨리고 토큰을 낭비한다.
- 비용 의식: ultrathink는 꼭 필요할 때만. cost-guard 스킬과 함께 판단한다.

## 🤖 모델 전략
- 기본 `claude-opus-4-8` + effort `max` 고정: 계획·실행 모두 Opus 4.8 최고 추론으로 간다. (opusplan 자동전환은 쓰지 않음 — 품질 우선)
- 고난도·장기 작업은 `/model fable` 고려.
- 결정적 순간의 2차 의견은 `advisorModel: opus`가 자동 자문한다.

## ⌨️ 내장 명령 활용
- `/goal <완료조건>`: 조건이 충족될 때까지 턴을 넘겨가며 지속 작업.
- `/ultraplan`: 클라우드에서 깊은 계획을 세운 뒤 실행으로 넘김.
- `/code-review ultra`: 머지 전 멀티에이전트 심층 버그 리뷰(= ultrareview).
- `/advisor opus`: 어려운 결정에 더 강한 모델 자문을 켠다.

## ⚡ Effort 레벨
- `/effort`로 추론강도 조절(단순 작업은 낮춰 토큰 절감). `/model` 안에서도 가능.
- 큰 작업 자동 오케스트레이션: `/effort ultracode`(xhigh 추론 + 워크플로 자동) — 비싸니 대형 작업에만.
- Fable 5는 thinking을 끌 수 없다(항상 추론).

## ↩️ Checkpoint (자동, 인지만)
- 클로드 편집은 자동 체크포인트된다. `/rewind` 또는 빈 입력에서 `Esc` 2번 → 코드·대화 되감기.
- ⚠️ Bash로 바꾼 파일(rm/mv 등)은 추적 안 됨. git이 영구 이력, 체크포인트는 로컬 undo.

## 🌊 Workflow (대형 작업)
- `/deep-research <질문>` → 멀티소스 교차검증 리포트(근거 인용, 검증 실패 주장 자동 제거).
- 큰 감사·대량 마이그레이션: 프롬프트에 `ultracode` 키워드 → 클로드가 JS 워크플로 작성·백그라운드 실행.
- 작은 슬라이스로 비용 가늠 후 확장. `/workflows` 뷰에서 토큰 모니터.

## 📚 Claude Code 공식 문서 참고 규칙
- Claude Code 기능을 쓰거나 사용자에게 설명할 때는 항상 공식 문서를 근거로 삼는다.
- 근거 URL을 함께 남긴다: https://code.claude.com/docs/en/<slug>
- 슬러그를 모르면 인덱스부터 확인한다: https://code.claude.com/docs/llms.txt
- 자주 쓰는 슬러그는 references/claude-code-docs.md를 참고. 불확실하면 추측하지 말고 WebFetch로 원문을 확인한 뒤 인용한다.
- 버전·동작은 바뀔 수 있으니 중요한 동작은 docs 원문으로 재확인한다.

## 🔁 세션 점검 루프 (loop)
- `/loop`(주기 반복)이나 "상태 점검·이상 없나" 류 요청 시 `loop.md` 체크리스트를 따른다: ① 빌드·배포·PR 상태 ② 실패·에러 진단+수정안 ③ 새 리뷰·이슈 정리 ④ 특이없으면 "이상 없음"만 ⑤ 비밀값(.env/토큰) 출력 금지.
