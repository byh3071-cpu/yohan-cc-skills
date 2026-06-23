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
