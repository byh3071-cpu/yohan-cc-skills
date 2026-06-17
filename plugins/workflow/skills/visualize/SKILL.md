---
name: visualize
description: Use when the user (a non-developer) wants to SEE something - generate 5~6 distinct UI design 시안 as one switchable HTML, OR turn verification results / version diffs / final reports into a browser-openable 두괄식 HTML. Triggers - "디자인 시안 N개 보여줘", "트렌디하게/감각적으로", "HTML로 시각화/결과 보고서", "비개발자용 두괄식", "버전 비교 보여줘".
---

# visualize

비전공 사용자가 **눈으로 확인**할 수 있게 만든다. 두 모드.

## 공통 원칙
- **두괄식 + 비개발자용.** 결론·핵심 먼저, 전문용어 최소(쓰면 1줄 풀이). 사용자는 디자인/개발 용어를 모른다고 명시함.
- **단일 파일 HTML.** 빌드 없이 바로 열림. 끝에 `! start <file>.html`(Windows)로 사용자가 직접 열게.
- **단일파일 아티팩트 제약 (PAT-005·006):** Tailwind 코어 유틸만(임의값 금지), import 화이트리스트, cdnjs, localStorage 금지. ★자체호스팅 Next.js/Vite 프로젝트엔 적용 금지(오적용 주의)★.

## Mode A — 디자인 시안 N개
1. 방향 먼저: `frontend-design` 스킬 필독 + `lazyweb` 레퍼런스 검색(토스·Linear·Raycast·Hermes 등 사용자가 지목한 레퍼런스 반영).
2. **5~6개**만(10개+ 금지 — 사용자가 "품질 떨어진다"고 명시). 각 시안 `#1`~`#6` 라벨, 한 HTML 안에서 전환(탭/스크롤).
3. 사용자가 번호 킵 → 그 시안만 변주 반복.

## Mode B — 결과 HTML 보고서
검증결과·버전 diff(예: `0.2.0 vs 0.1.3`)·최종 보고서를 브라우저용 단일 HTML로.
1. 맨 위 **한 문장 결론** + 핵심 3줄.
2. 표·배지·아이콘 중심(이미지 X), 비개발자가 읽는 언어.
3. `! start docs\<name>.html`로 열기.

## 출력
HTML 파일 경로 + 여는 명령. 코드 설명이 아니라 "열어서 보는 것"이 산출물.
