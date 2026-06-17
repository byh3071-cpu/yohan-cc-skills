---
name: handoff
description: Use when ending/pausing a session or moving between machines (집컴↔노트북) — write/update a handoff doc, generate a copy-paste 전달 프롬프트 for the other machine, and sync config drift. Triggers - "핸드오프 남겨/갱신", "내일 이어서", "노트북으로 전달", "전달프롬프트 만들어줘", "다른 기기에서 이어서", "컨텍스트 work로 남겨".
---

# handoff

세션 맥락을 디스크에 고정하고, 다른 기기에서 한 번에 복원할 **전달 프롬프트**를 만든다. 멀티머신 1인 개발의 핵심 통증점.

## 핵심 원칙 (CLAUDE.md SoT)
- **핸드오프md = 무게중심.** 노션 단독 복원은 약함(출처: cafe-pos-vhk VHK-6). 디스크 핸드오프 문서가 1차 진실.
- **행 = 산출물 색인.** 본문에 산출물 포인터 필수 — 특히 **진입점 1줄 + 관련 파일 경로**.

## 절차 (todo로)
1. **핸드오프 문서 작성/갱신.** 위치는 그 레포 관례 따름: `docs/log/<date>-handoff.md` / `HANDOFF.md` / `.vhk/handoff-*.md`. 내용 4블록:
   - **지금까지 한 것** (커밋/PR/파일 단위로 구체)
   - **핵심 결정** (왜 그렇게 했는지)
   - **다음 할 일** (우선순위 순)
   - **산출물 포인터** — 진입점 파일:라인 1줄 + 관련 경로 목록
2. **전달 프롬프트 생성.** 다른 기기에 그대로 붙여넣을 복사블록:
   - 핸드오프 문서 경로 + "이거 읽고 이어가자"
   - 진입점·복원 단계(어떤 브랜치, 어떤 명령으로 시작)
   - 기기차 주의(경로·사용자명 다르면 자동 보정 지시)
   - (오늘 statusline 동기화처럼) 환경 차이 있으면 그 항목도
3. **설정 드리프트 동기화.** statusline/settings/스킬이 기기 간 다르면 정렬. 단 **스킬은 파일 복사 말고 마켓플레이스 install**(`yohan-cc-skills`)로 — 파일 복사는 드리프트 원천.
4. (VHK 있으면) `vhk context`/`vhk work`와 연동 — 디스크 핸드오프가 무게중심, vhk는 보조.
5. (선택) 복원 정확도 자가평가 1~5 — 사용자가 요청할 때만(상시 산출물 아님).

## 출력
핸드오프 문서 경로 + **전달 프롬프트 복사블록**. (자가평가는 요청 시)

## 중복 방지
`vhk context`는 저장/복원 저장소 역할. 이 스킬의 고유값 = **기기 간 전달 프롬프트 + 설정 동기화**. 단일 기기 내 복원만이면 vhk context로 충분.
