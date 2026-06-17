---
name: release-gate
description: Use before any hard-to-undo action — merge to main, npm publish, release, tag/version bump. Runs gate(tsc→eslint→build) + tests + adversarial code review in a loop until zero problems, then PR→merge→main 최신화→tag, skipping only human-only steps (2FA publish). Triggers - "머지/퍼블리시해도 되는지", "적대적 검증 ㄱㄱ", "릴리즈 전 확인", "문제 0까지 반복", "PR 만들고 머지", "안전한지 다시 확인".
---

# release-gate

되돌리기 어려운 작업(머지·publish·릴리즈·태그) 직전, "문제 하나도 안 나올 때까지" 검증 루프를 돌리는 오케스트레이터.

## 핵심 원칙
- **되돌릴 수 없는 작업은 LLM 결정경로에서 제외 (PAT-003, 4중 안전장치).** npm publish(2FA OTP)·외부 발송·강제푸시는 사람. LLM은 검증·보고·초안까지.
- **문제 0까지 루프.** 한 단계라도 실패하면 수정 후 **처음부터 재실행**. "거의 됨"으로 통과 금지.
- **새 도구 만들지 말고 오케스트레이션.** 아래는 기존 `/code-review`·`/verify`·`vhk-auto`·git/gh를 *순서대로 호출*하는 얇은 절차.

## 시퀀스 (todo로, 실패 시 해당 지점부터 되감기)
1. **게이트:** `tsc` → `eslint` → `build`. 각 단계 exit-code 확인(0 아니면 멈춤·수정·1번부터 재시작). 프로젝트 명령은 package.json/CLAUDE.md 따름.
2. **테스트:** vitest / playwright / node E2E 중 그 레포가 쓰는 것. 실패 → 수정 → 1번부터.
3. **적대적 코드리뷰:** `/code-review`(높은 effort) 또는 codex 리뷰 → 나온 지적을 **자가검증**(거짓양성 걸러내고 진짜만) → 수정 → **1번부터 재실행**. 지적 0까지 반복.
4. **통합:** PR 생성 → 머지 → `main` 최신화(pull) → 필요 시 **태그/버전** 확인·생성. 버전 올릴 때 직전 발행본과 대조("2.3.1 발행됐는데 2.3.2 맞는지" 류 확인).
5. **사람몫 핸드오프:** `npm publish`(2FA)·릴리즈 공개·외부 발송은 **하지 말고** 정확한 실행 명령 + 체크리스트만 출력. 사람이 실행.

## 출력
단계별 PASS/FAIL 표 + 루프 횟수 + 남은 사람몫(2FA publish 등) 명령. 모든 게이트 green일 때만 "머지/발행 안전" 선언(증거 없이 단언 금지).

## 중복 방지
`vhk-auto` = goal 1개 자율 1바퀴(앵커→개발→검증→리뷰→commit). `release-gate` = **이미 만든 변경을 내보내기 전 최종 안전 게이트**. 둘은 사이클의 다른 지점 — 개발 자체가 아니라 *릴리즈 직전*에 건다.
