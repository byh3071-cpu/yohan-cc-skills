---
name: ship-plan-to-pr
description: >
  Use when 요한 wants an approved plan/goal executed through commit+push+PR only
  (no merge). Triggers: '이 플랜 PR까지', '승인 플랜 실행', 'plan to pr',
  '머지 말고 PR만', 'GOAL 11', 'ship plan to pr'.
---

# ship-plan-to-pr

승인된 플랜/goal을 **구현 → 검증 → commit → push → gh pr create** 까지만.
**머지·force-push·시크릿 커밋·Orca overnight-runbook 금지.**

## Preconditions (없으면 중단)

1. 사용자가 플랜/goal을 승인함 (`approved_at` on `goals/*.md` 또는 명시 "승인됨")
2. 대상 레포·브랜치가 프롬프트/goal에 있음
3. Orca FLEET 야간 무인 경로로 우회하지 말 것

## Steps

1. Read goal/plan DoD. Worktree from default branch if needed.
2. Implement small units; no scope creep.
3. Run project checks relevant to changes.
4. `git status` / `git diff` / `git log` then commit (user rules).
5. `git push -u` + `gh pr create` (base=default). **Do not merge.**
6. Report PR URLs + morning merge recommendation. Stop.

## Diff vs overnight-autoloop

| | ship-plan-to-pr | overnight-autoloop |
|--|-----------------|-------------------|
| 입력 | 승인 플랜/goal | 결함 발굴 |
| 산출 | 명세 구현 PR | 감사→수정 PR |
| 머지 | 사람 | 사람 |
