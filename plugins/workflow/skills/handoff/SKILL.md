---
name: handoff
description: Use when a session is ending/pausing, moving between machines, or the user asks for chat/session end verification — (0)채팅 종료 검증 →(full) dev log·next-task·전달 프롬프트·커밋(승인 후). Triggers - "채팅 종료 검증", "채팅 종료 섹션 검증", "세션 종료 검증", "핸드오프", "마무리하자", "오늘 끝", "내일 이어서", "노트북으로 전달", "정리하고 끝", "다른 기기에서 이어서", "컨텍스트 work로 남겨".
---

# handoff

세션 맥락을 디스크에 고정하고, 다른 기기 복원용 **전달 프롬프트**를 만든다.
history에 반복되는 **「채팅 종료 검증」** 을 **0단계**로 공식화.

## 모드

| 모드 | 언제 | 하는 일 |
|------|------|---------|
| **verify-only** | "채팅/세션 종료 검증"·"채팅 종료 섹션 검증"만 (핸드오프·마무리·내일·전달 없음) | **0단계만** 표 보고. 커밋·파일쓰기·삭제 **기본 금지** |
| **full** | 핸드오프/마무리/내일 이어서/전달/정리하고 끝 **또는** 종료검증+핸드오프가 **한 메시지에 같이** | **0 → 1~7** |

애매하면 verify-only 먼저 → "full 할까?" 한 줄.

## 원칙

- 핸드오프 **파일** = 1차 진실 (노션만으로 복원 약함).
- 산출물 **경로 포인터** 필수.
- **≠ `/release-gate`.** 머지/publish 게이트 아님. 세션 마감·이어가기만.
- 브랜치/worktree **삭제 강제 금지** (목록·승인 후).

## 0. 채팅 종료 검증

실측만 (`git status -sb` 등). 해당 없으면 그 항 **Pass(N/A)**.

| # | 항목 | Pass | Warn/Fail | 권고 |
|---|------|------|-----------|------|
| 1 | 작업 잔여 | clean 또는 의도된 dirty | 미커밋·미추적 | 커밋/stash 후보만 (승인 전 실행 X) |
| 2 | 다음 할 일 | next-task·HANDOFF·LIVE에 세션 기준 "다음" | 없음/stale | full이면 2단계에서 갱신 |
| 3 | 기록 누락 | log/ADR/TS/README 후보 없음 | 코드 변경인데 log 없음 등 | 경로 후보만 (VHK governance면 log 필수) |
| 4 | 이슈·블로커 | 새 막힘 없음/이미 기록 | 막힌 채 미기록 | 이슈 1줄·blockers 제안 |
| 5 | 브랜치·worktree | 정리 불필요 | 죽은 브랜치/worktree 의심 | **목록만** |
| 6 | 거짓완료 | 완료 주장 없거나 모순 없음 | 미완·게이트 실패인데 완료 톤 | `vhk review` 권고. done 금지 |

```text
## 채팅 종료 검증
| # | 항목 | 결과 | 근거 | 권고 |
요약: Pass N · Warn N · Fail N · N/A N
모드: verify-only | full
```

Fail 있어도 보고. full은 고칠 수 있는 항만 진행(커밋·삭제는 승인 후).

## full 절차 (todo)

0. 채팅 종료 검증
1. dev log append-only (`docs/log/...`) — 한 것·왜·다음·포인터
2. 상태: VHK=`next-task`+LIVE / 그 외=`HANDOFF.md`
3. 전달 프롬프트 (경로·브랜치·명령·기기차·yohan-cc-skills install)
4. 커밋 **승인 후** (push/머지도 승인 후)
5. 설정 드리프트 → install (파일복사 X)
6. (VHK) `vhk work handoff` 보조
7. (선택) 복원 자가평가 1~5

## 출력

- verify-only → 표 + 요약 (+ full 제안)
- full → 표 + 핸드오프 경로 + 전달 프롬프트 블록

## 중복 방지

| 이 스킬 | 다른 것 |
|---------|---------|
| 세션 마감 검증 | `/release-gate` = 릴리즈 직전 |
| 전달 프롬프트 | `vhk context` = 저장소 |
| 거짓완료 의심 | `vhk review` 권고만 (대체 실행 X) |
