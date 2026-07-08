---
name: vhk-bootstrap-cursor
description: VHK Cursor 독푸딩 — 설치+배선 한 번에. 트리거: "VHK 도입", "독푸딩", "vhk bootstrap", Claude→Cursor 전환.
---

# VHK Bootstrap Cursor (설치 + 배선)

**목표:** `vhk doctor` green + **goal/receipt/review/learn 루프 연결** + gate 1회 PASS.

## Phase 0 — CLI

```powershell
vhk doctor
vhk context
vhk brief
vhk sync
vhk mcp-init
```

## Phase 1 — Goal (필수)

```powershell
vhk goal list
```

- silent skip 있으면 → **vhk-goal-health**
- 없으면 `goals/_meta.md` + active goal 1개

## Phase 2 — Cursor 산출물

| 산출물 | 최소 |
|---|---|
| `.cursor/rules/` | context, windows-shell |
| `.cursor/skills/` | vhk-gate, vhk-evolve-loop, vhk-dogfood-issue, vhk-bootstrap-cursor, recap |
| `.cursor/hooks.json` | session-start, stop-recap |
| `docs/state/` | next-task, blockers |
| `docs/context/agent-compact.md` | 1페이지 |

프로젝트 skill은 **vhk-gate 위임** (로직 중복 금지).

## Phase 3 — 배선 검증

```powershell
vhk pattern detect
pnpm.cmd typecheck; pnpm.cmd test; pnpm.cmd lint
vhk verify
vhk receipt
vhk review
```

review skip → goal-health 재실행.

## Phase 4 — L1 갭

bootstrap 중 CLI 결함 → **vhk-dogfood-issue** (inject-bootstrap 누락, doctor goal 미검 등).

## 완료 기준

- `vhk goal list` ≥ 1 active
- vhk-gate skill 존재
- verify PASS; receipt not BLOCK (또는 사유 해소)
