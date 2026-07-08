---
name: vhk-dogfood-issue
description: VHK L1 — CLI/하네스 결함 재현·분류·vhk 레포 이슈 등록. 트리거: vhk exit≠0, doctor/review/receipt 버그, "VHK 버그", "vhk 이슈".
---

# VHK Dogfood Issue (L1 제품)

**SoT:** https://github.com/byh3071-cpu/vhk/issues

## 분류 (먼저)

| 유형 | 등록 | 예 |
|---|---|---|
| **도구 결함** | vhk 레po | goal silent skip, recap headless |
| **앱 버그** | **현재 프로젝트** 이슈/수정 | aroo 결제 로직 |
| **배선 갭** | 프로젝트 skill/RULES + (공통이면) vhk enhancement | verify만 하고 receipt 생략 |

교차검증 필요 시 **dogfood-crosscheck** 선행.

## 절차

1. **재현** — 최소 명령·exit code·`vhk --version`
2. **중복 검색**
   ```powershell
   gh issue list -R byh3071-cpu/vhk --search "키워드" --state all
   ```
3. **body 작성** — `.vhk/issue-<slug>.md` (재현/기대/실제/환경)
4. **등록** — 사용자가 "등록해" / "ㅇㅋ 이슈" 명시 후:
   ```powershell
   gh issue create -R byh3071-cpu/vhk --title "..." --label "bug,dogfooding" --body-file .vhk/issue-<slug>.md
   ```
5. **로컬 흔적** — `vhk learn "dogfood: ..."` (태그 dogfood)

## 금지

- 사용자 승인 없이 `gh issue create`
- 앱 버그를 vhk 레po에 등록
