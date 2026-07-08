---
name: vhk-goal-health
description: goals/*.md 스키마修復 — type:goal 누락 silent skip 해소. 트리거: vhk review skip, vhk goal list ignored files, "정의된 goal 없음".
---

# VHK Goal Health

## 진단

```powershell
vhk goal list
vhk review
```

`스키마 불일치로 무시` / `goal 없음` → frontmatter修復.

##修復

각 `goals/*.md` frontmatter:

```yaml
---
type: goal
id: 4          # 숫자
title: ...
status: IN_PROGRESS   # NOT_STARTED | IN_PROGRESS | DONE (대문자 enum)
---
```

Legacy 매핑: `active`→`IN_PROGRESS`, `done`→`DONE`, `pending`→`NOT_STARTED`

- legacy `id`만 있으면 `type: goal` 추가
- `goals/_meta.md` 없으면 `vhk goal init` 참고 생성

## 검증

```powershell
vhk goal list    # 4 files recognized
vhk goal peek    # IN_PROGRESS 1개
vhk review       # skip 아님
```

## L1

doctor/goal list가 legacy status를 경고 없이 무시 → **vhk-dogfood-issue** (#465, #467 follow-up).
