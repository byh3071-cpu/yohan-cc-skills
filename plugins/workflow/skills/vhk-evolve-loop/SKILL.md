---
name: vhk-evolve-loop
description: VHK L2 자기개선 — learn/win → pattern → evolve. 트리거: gate FAIL, critic/security finding, receipt BLOCK, 반복 실수.
---

# VHK Evolve Loop (L2 프로젝트)

**SoT:** `.vhk/memory.json` → `vhk evolve` → `RULES.md` (프로젝트만). VHK CLI 버그는 **vhk-dogfood-issue** (L1).

## 1. 기록

```powershell
vhk learn "한 줄 교훈 — why 포함"
vhk win "한 줄 성공 — reinforce"
```

팀 공유 필요 시 `docs/context/recurring-defects.md` 또는 ADR.

## 2. 패턴

```powershell
vhk pattern detect
vhk pattern list
vhk evolve suggest
vhk evolve list
```

## 3. 반영

- TTY + 사람 확인: `vhk evolve apply <id>` → `vhk sync`
- Headless/agent: `vhk evolve digest` → RULES 초안 제안만 (자동 apply 금지)

## 4. L3 후보

동일 교훈이 **2+ VHK 프로젝트**면 yohan-cc-skills 스킬/RULES 템플릿 PR 검토.

## 금지

- L1 CLI 결함을 learn만으로 끝내기 — vhk 레포 이슈 병행
- memory.json만 믿고 RULES 미갱신 (로컬 전용, gitignore)
