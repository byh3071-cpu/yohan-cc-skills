# 채널 규칙 — 포인터 (SoT는 yohan-dual-blog)

> ⚠️ 이 파일은 요약 포인터다. **저작 규칙의 SoT는 yohan-studio 레포의
> `skills/yohan-dual-blog/references/` 4종**이며, 충돌 시 그쪽이 이긴다.
> (2026-07-20 정리 — 이 파일의 구버전 `.txt` 규칙이 현행 `.md` 파이프라인과 모순돼
> 이중 작업 사고를 유발했던 것을 계기로 이원화 제거.)

| 무엇 | SoT (yohan-studio 레포) |
|---|---|
| 네이버 구조 스펙 — 고정/유연/진솔 슬롯·문체 `-다`·이모지 팔레트·주제 변형 | `skills/yohan-dual-blog/references/naver-structure.md` |
| 채널 공통 — 문단 길이·이미지 3질문·해시태그·발행 체크리스트 | `skills/yohan-dual-blog/references/channel-rules.md` |
| 12항목 글 뼈대 | `skills/yohan-dual-blog/references/content-model.md` |
| 벤치마킹 윤리(복제 금지) | `skills/yohan-dual-blog/references/reference-patterns.md` |

## 파이프라인 산출물 위치 (현행 — `.txt` 아님)

1. `pnpm blog:naver -- <slug>` → `docs/content/naver/<slug>.md` (라이트 마크다운 초안)
2. **naver-structure.md 규칙대로 `.md` 편집** — 고정 슬롯(성공담 부정·고정멘트·서명), 진솔 슬롯 `[여기 네 말: …]`은 반드시 비워서 남긴다(자동생성 금지), 문체 `-다`, 이모지 팔레트 0~1/섹션
3. `pnpm blog:naver:html -- <slug>` → `<slug>.html`(사람 미리보기) + `<slug>.fragment.html`(클립보드/자동 주입용)

## 발행 전 최소 체크 (상세는 channel-rules.md)

- [ ] 고정 슬롯 전부 존재: 결과선행 제목 / 첫 5줄 내 결과 / 성공담 부정 / 고정멘트 / 존댓말 서명 / 원문 백링크 1회 / 해시태그 5~8
- [ ] 진솔 슬롯이 최소 1개 있고, 사람이 채웠다 (플레이스홀더 채로 발행 금지)
- [ ] 웹 MDX와 수치·링크 일치
