---
name: vhk-gate
description: VHK 검증 게이트 전체 — verify → receipt → review. 트리거: "검증", "게이트", "완료", goal done 전, 코드 변경 후.
---

# VHK Gate

코드·완료 주장 전 **반드시** 실행. red/BLOCK/skip이면 아래 분기 스킬로.

## 순서 (Windows)

```powershell
pnpm.cmd typecheck
pnpm.cmd test
pnpm.cmd lint
vhk verify
vhk receipt
vhk review
```

## 판정 분기

| 결과 | 다음 |
|---|---|
| verify red | `.vhk/reports/latest.json` → 수정 → 재실행 |
| receipt BLOCK | dirty/stale → commit 또는 `vhk receipt --mark-start` → **vhk-evolve-loop** |
| review skip (goal 0) | **vhk-goal-health** |
| review fail | **vhk-evolve-loop** + 앱 결함이면 수정 |

## L1 vs L2

- VHK CLI 버그/크래시 → **vhk-dogfood-issue**
- 프로젝트 반복 실수 → **vhk-evolve-loop**

## Pass criteria

verify exit 0 + receipt pass/caution + review pass (또는 skip 사유 goal-health 해결 후).

완료 선언 금지 until pass.
