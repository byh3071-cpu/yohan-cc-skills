---
name: flow
description: 한 작업을 explorer→planner→critic→shipper 순으로 끝까지 진행하는 오케스트레이션. 인자로 작업 설명을 받는다.
argument-hint: [작업 설명]
disable-model-invocation: true
---

# /yohan-core:flow — 4단계 선순환 플로우

작업: **$ARGUMENTS**

아래 순서를 그대로 따른다. 각 단계는 해당 서브에이전트에 위임한다.

## 1) 탐색 (explorer)
`explorer` 서브에이전트로 위임해 작업과 관련된 코드/문서/설정을 정찰한다.
- 추측 금지. 파일 경로·라인 근거만 수집.
- 산출물: 관련 파일 목록 + 현재 동작 요약 + 제약/리스크.

## 2) 설계 (planner)
`planner` 서브에이전트로 위임해 검증 가능한 단계로 분해한다.
- 작은 단위, 각 단계의 완료 기준 명시.
- 산출물: 단계별 체크리스트 + 영향 범위.

## 3) 검증 (critic)
`critic` 서브에이전트로 위임해 계획을 적대적으로 교차검증한다(cross-check 스킬).
- 반례·엣지케이스·보안·회귀를 역추적.
- 통과 못하면 2)로 돌아가 수정. **문제 0이 될 때까지 반복.**

## 4) 출시 (shipper)
`critic`가 통과시키면 `shipper` 서브에이전트로 위임해 변경을 적용한다(ship-it 스킬).
- pre-commit 점검 → 두괄식 커밋 메시지 → push.
- 게이트 통과 시 `.claude/.gate-pass` 갱신.

## 보고
끝나면 한국어 반말·두괄식으로 결과를 요약한다(yohan-writing 스킬). 무엇을 바꿨고, 검증에서 무엇을 잡았고, 다음 할 일.
