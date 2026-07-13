---
name: studio-post
description: yohan.studio 블로그 글을 저작·검증·발행할 때. MDX 템플릿, 저작 규율(용어 정의·표 금지), BOM·이미지 함정 회피, 발행 절차(published 게이트→라이브 검증→8채널 변환)까지 전 과정. "블로그 글 써줘", "studio에 발행", "글 초안" 트리거.
---

# studio-post — yohan.studio 글 저작·발행

## 정본 참조 (이 스킬은 얇은 진입점 — 상세는 brain이 SoT)

| 무엇 | 어디 (yohan-brain) |
|---|---|
| 발행 전·중·후 체크리스트 | `memory/rules/publish-checklist.md` (사고 이력 포함 — 반드시 대조) |
| 8채널 변환 스펙 | `memory/rules/content-platform-specs/*.md` |
| 환경 함정 (BOM·vitest·MDX) | `memory/wiki/concepts/windows-agent-pitfalls.md` |
| 스타일 | yohan-writing 스킬 + 기존 발행 글 (studio `src/content/blog/`) |
| 웹+네이버 저작·변환 | `yohan-dual-blog` 스킬 (studio repo `skills/`) — web-post·naver-post 템플릿, `mdx-to-naver.mjs`, 채널 규칙. 웹/네이버 실작성은 이 스킬과 정합 유지 |

## MDX 템플릿

```mdx
---
title: "구체 결과가 들어간 제목: 부제"
description: "검색 스니펫용 1~2문장 — 훅과 실측 수치 포함."
date: "YYYY-MM-DD"
tags:
  - 태그3~5개
category: "AI/바이브코딩"
published: false        # 초안은 반드시 false — 발행은 사람 게이트
---

> **한눈에 요약**
> 3문장 이내 — 결론·수치·핵심 규칙.

(도입 1~2문단: 1인칭 일기체 훅 — "나는 바리스타 출신 비전공자다" 계열의 구체 상황)

(전문용어 첫 등장 시 한 줄 정의 — PR·머지 등)

{/* [이미지 1: 설명] */}   ← 이미지 자리 주석 마커

## 섹션 제목 (질문형 or 행동형)
...
```

## 저작 규율 (2026-07 두 편 검토 + 벤치마킹 1회전 반영 — 위반 시 반려됨)

1. **수치는 실측만** — 원장(audits·git·gh) 대조 가능한 숫자만. 추정치 금지.
2. **실패 포함 + 도입부 예고** — 성공담 금지. 실패·헛돈은 **도입부에서 예고**하고 결말에서 교훈으로 재포장 (벤치 실측 최대 호응 구조 — 브런치 라이킷 1,151 사례). 중반에 숨기지 않는다.
3. **마크다운 표 금지** — MDX 렌더 미지원. 목록으로.
4. **3-3-3 대칭 리스트 남발 금지** — AI 티의 최대 마커. 문단 흐름 위주.
5. 메타 발화 금지("과장 없이 쓰면") · "실측" 같은 엔지니어 용어 지양.
6. 용어 첫 등장 정의 — 비개발자 독자 기준.
7. 분량 — 마스터(studio 원본)는 상한 없음: 소재 깊이만큼 길게 쓴다(실측: 발행글 다수 3,000자+). 1,500~2,000자는 파생 채널(티스토리 등) 목표치이지 마스터 목표가 아니다. 직전 글 내부링크로 마무리.
8. thumbnail은 실파일 있을 때만 frontmatter에 (없는 경로 = 깨진 히어로 / 생략 시 OG 텍스트 카드 자동 폴백 — studio #35).
9. **제목 = 결과 숫자 선행** — 궁금증 유발형보다 결과 스포일러형이 한·해외 공통 우세 [가설, 벤치 B2×B3]. 이모지·리스티클("~5가지") 금지 (한국 상위 10/10 이모지 0).
10. **실물 스크린샷/재현 출력 ≥ 1장** — 다이어그램만으로 채우지 않기 ("진짜 돌아간 증거"가 신뢰 장치, 해외 6:1 우세).
11. **정보 구간에도 자기 서사 껍질** — 도입·결말의 개인 서사가 AI 정보글과의 구분 기제 (벤치 B2). 8채널 변환물에도 유지.

## 커버·배포 규약 (벤치 1회전)

- **커버 시리즈 톤 고정**: 다크+오렌지 소프트 브루탈리즘 일러스트(텍스트 없음), gpt-image 생성. 프롬프트 베이스: "Editorial illustration, soft brutalism, deep charcoal + vivid orange accent, flat vector shapes, grainy texture, no text anywhere." — 발행 6편이 4가지 톤으로 흩어졌던 갭 해소(B4). 과거 커버 소급은 유저 승인 후.
- **배포 우선순위**: 블로그=아카이브, **트래픽 엔진=커뮤니티**(Reddit·디스콰이엇) — 동일 소재 Medium 클랩 2 vs IH 138업보트 실측(B3). 커뮤니티용 제목은 결과선행형으로 변환.
- 벤치 원장·재판정 조건: brain `docs/audits/content-benchmark-2026-07-05.md` (계측 4주 후 재판정).

## 파일 함정 (전부 실사고 이력)

- **BOM 금지**: PowerShell `Set-Content -Encoding UTF8` 절대 금지 — BOM이 frontmatter 파싱을 깨서 라이브 404 (studio #30 사고). Write 도구 또는 `UTF8Encoding($false)`.
- **BlogImage는 문자열 attr**: `width="1280"` (JSX 표현식 `{1280}`은 next-mdx-remote가 드롭 → 크롭 사고).
- **다이어그램 = SVG 파일** (`public/images/blog/<slug>/*.svg` + BlogImage) — 텍스트 선명·수정 1줄·비용 0. 사진풍·커버는 GPT 이미지(OPENAI_API_KEY 필요).
- 검증은 로컬 dev가 아니라 **프로덕션 빌드**: published:true 임시 토글 → `npm run build` + `npx next start` → 대조군(기존 글) 포함 확인 → false 원복.

## 발행 절차 (요약 — 상세는 publish-checklist)

1. 초안 PR (published:false) → 사람 검토 (아티팩트 렌더 제공).
2. 승인 시: published:true + 발행일 갱신 → 머지 → Vercel 배포 대기.
3. 라이브 검증: `yohanstudio.co`(도메인 정본 = `src/lib/siteUrl.ts`)에서 200 + 내용. sitemap·신규 자산 삼각측량.
4. **8채널 변환**: voice CLI로 export 생성 → `voice check` 기계 검증(8채널 전부 지원) → `docs/content/exports/<slug>/` PR. 각 채널 실발행은 사람.

## 금지

- 밤·무인 세션에서 published:true 전환 금지 (라이브 발행 = 사람 게이트).
- 같은 글의 캐러셀·카드뉴스 동시 발행 금지 (스펙 참조).
