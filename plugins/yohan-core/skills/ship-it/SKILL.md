---
name: ship-it
description: 변경을 안전하게 출시(commit·push·release)할 때. pre-commit 점검→교차검증 게이트→두괄식 커밋→푸시. 게이트 통과 시 .claude/.gate-pass 갱신. 출시·배포·머지 시 사용.
disable-model-invocation: true
allowed-tools: Bash(git add *), Bash(git commit *), Bash(git status *), Bash(git push *)
---

# ship-it — 안전 출시

자동 실행 금지(`disable-model-invocation`). 사용자가 `/`로 호출하거나 shipper가 위임받았을 때만.

## 절차
1. `git status` / `git diff --cached`로 변경 확인.
2. **pre-commit 점검**: 비밀·대용량·토큰 패턴(pre-commit-check 훅이 한 번 더 강제).
3. **게이트**: cross-check 통과했는지 확인. 통과면 `.claude/.gate-pass`를 갱신(touch).
4. **커밋**: 두괄식 한 줄 요약 + 본문(무엇을/왜).
5. **푸시**: `git push`. (critic-gate 훅이 게이트 미통과 시 확인 요청)

## 커밋 메시지 형식
타입: feat/fix/refactor/docs/chore/security

  <타입>: <두괄식 요약>

  - 무엇을 바꿨는지
  - 왜
