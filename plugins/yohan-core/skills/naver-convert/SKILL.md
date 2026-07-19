---
name: naver-convert
description: yohanstudio.co 블로그 글(MDX)을 네이버 블로그용으로 변환·준비할 때. LLM 의미 변환→네이버 친화 HTML→CF_HTML UTF-8 클립보드→섹션 자동 캡처→발행 후 콘텐츠 허브 기록까지 반자동 파이프라인. 발행 버튼·최종 편집은 사람. "네이버 변환", "네이버 발행 준비", "네이버로 옮겨줘" 트리거.
---

# naver-convert — 네이버 발행 반자동 파이프라인

콘텐츠 OS 🟡 반자동 단계 도구: **변환은 도구, 승인·발행은 사람.**
근거: yohan-studio `docs/superpowers/specs/2026-07-13-content-os-retro-naver4.md` (수동 4회 완주 회고).

## 절차 (6단계)

### 1. 입력
- MDX slug (yohan-studio `src/content/blog/<slug>.mdx`). 라이브 발행(published:true + yohanstudio.co 200) 상태가 전제 — 네이버는 티저, 원문이 상세판이어야 함.
- **원문 밀도 게이트**: 원문이 네이버 초안과 밀도가 비슷하면 변환 중단하고 원문 보강을 먼저 제안 (특강 후기 사례: 보강 → 배포 → 발행 순서).

### 2. LLM 의미 변환 (정규식 아님 — 직접 다시 쓴다)
**저작 스펙 SoT = yohan-studio `skills/yohan-dual-blog/references/naver-structure.md`** (고정/유연/진솔 슬롯·문체 `-다`·이모지 팔레트·주제 변형) — 변환 전 필독. 특히 고정 슬롯(성공담 부정 1문장·고정멘트·존댓말 서명)과 **진솔 슬롯 `[여기 네 말: …]`을 비워서 남기는 것**(자동생성 금지)을 빼먹지 말 것.
`references/naver-channel-rules.md`(포인터 요약) 적용. 핵심:
- 문단 1~3문장 분절, 모바일 줄 읽기 우선. 첫 5줄 안에 결과·기간·문제 제시
- 기술 용어 첫 등장 시 한국어 풀이 괄호 병기
- 문단 사이 여백은 제로폭 공백(`​` U+200B) 단독 문단
- 이미지 자리는 `[이미지 삽입: 설명]` 마커 (형광펜 배경으로 눈에 띄게)
- 해시태그 5~8개, 원문 링크는 끝에 한 번
- 분량 ~1,500자 (원문 유입 동기 보존 — 네이버를 상세판으로 만들지 않는다)

**격식 SoT = 기존 발행 글 (2026-07-19 사고로 승격 — 밋밋한 텍스트 덤프 반려됨):**
변환 전에 최근 발행 글 1편(`m.blog.naver.com/yohan3071` — 예: 224316171488 npm 배포 후기)의 컴포넌트 구조를 대조한다. 실측 격식:
- 섹션(`##`)마다 **구분선**으로 분리 (hr → SE 구분선 컴포넌트 자동 매핑)
- 섹션 제목은 **19px 굵게** (h2 태그 아님 — `<span style="font-size:19px"><b>`)
- "한눈에 요약" 섹션이 도입 다음, 구분선 사이 독립 배치
- 해시태그는 **본문에 없음** — 발행창 태그 입력에 등록
- 마무리는 라벨(굵게)+URL 줄바꿈 블록 ("원문" / URL)
→ 이 격식은 `naver-to-html.mjs`(yohan-studio `skills/yohan-dual-blog/scripts/`)가 자동 생성한다. 수동으로 격식 없는 평문 덤프 금지.

### 3. 네이버 친화 HTML 생성
SmartEditor 새니타이저 생존 검증 완료(18/18, 2026-07-13) 태그만 사용:
`<h2> <h3> <p> <b> <strong> <em> <u> <s> <blockquote> <hr> <ul> <ol> <li> <a>` +
`<span style="color:...">`, `<span style="background-color:...">`(형광펜), `<span style="font-size:NNpx">`
- blockquote → 네이버 인용구 스타일, hr → 구분선으로 자동 매핑됨
- 마크다운·코드펜스·표 금지 (표는 리스트로)

### 4. 클립보드 적재
```powershell
& scripts/Set-ClipboardHtmlUtf8.ps1 -Path <slug>.fragment.html
```
⚠️ **PS 5.1 `Set-Clipboard -AsHtml` 직접 사용 금지** — CF_HTML을 ANSI로 넣어 한글 전멸 (PAT-004, yohan-studio `docs/patterns/`). 스크립트가 UTF-8 바이트 오프셋으로 CF_HTML을 직접 빌드한다.
⚠️ **반드시 `.fragment.html`(순수 본문)을 적재** — 전체 `.html`(미리보기)을 넣으면 안내 바·제목 박스·하단 각주까지 에디터에 붙여넣어진다 (2026-07-19 사고). 미리보기 `.html`은 사람이 브라우저로 열어 [본문 복사] 버튼을 쓸 때만.
- 사람: 네이버 에디터에서 Ctrl+V 한 번 → 서식 완성. 제목은 별도 입력(에디터가 SEO형으로 다듬는 것 권장)
- 자동 주입(playwright-extension) 시: 본문 클릭 → Ctrl+A → Ctrl+V (전체 교체). SE ONE은 프로그램 DOM 셀렉션을 무시하므로 부분 수정은 캐럿 기반 키 입력만 — 문단 단위 정밀 삭제가 필요하면 부분 수정 대신 fragment 재생성 후 전체 교체가 정답.

### 5. 이미지 준비 (선택)
라이브 블로그 섹션 캡처가 필요하면 playwright로:
- `h2/h3` 헤딩 bounding box → 다음 헤딩 직전까지 `page.screenshot({clip})`
- 우측 챗봇 위젯 잘리게 `x:60, width:800` 클립
- 에디터 자동 삽입까지 할 경우: 마커 문단 클릭 → `사진 추가` 클릭 → **filechooser 이벤트 인터셉트** → setFiles → 마커 문단 triple-click 삭제. 이미지 선택 오버레이가 클릭 가로채면 Escape + 중립 문단 클릭 후 진행
- SmartEditor는 합성 `ClipboardEvent('paste')`를 무시(isTrusted 체크) — 붙여넣기 자동화는 네이티브 키 입력만 가능

### 6. 발행 후 기록 (데이터 루프 — 잊으면 허브가 빈다)
사람이 발행하고 URL을 주면:
- 노션 **콘텐츠 허브** (data source `e4fa638f-fac6-478b-9452-df4d57626673`)에 1행: 제목(네이버 최종 제목)/채널=네이버/포맷=블로그/상태=발행/발행일/URL/메모
- 발행 이력 확인이 필요하면 `https://m.blog.naver.com/api/blogs/yohan3071/post-list?categoryNo=0&itemCount=30&page=1` (Referer 헤더 필요) — 기억·수기 의존 금지
- Dev Log 마일스톤 트리거 해당 시 기록

## 사람 게이트 (불변)
- 붙여넣기·최종 편집·제목 확정·**발행 버튼 = 사람**
- 네이버 글쓰기 API 자동 발행 금지 (콘텐츠 OS 🔴 단계 재론 안 함 — 외부 발송 사람 게이트 원칙)
