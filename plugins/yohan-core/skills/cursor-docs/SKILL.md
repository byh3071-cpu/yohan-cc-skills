---
name: cursor-docs
description: Cursor 공식 문서를 조회·인용한다. Cursor 기능을 설명하거나 쓰기 전 근거 확인용.
---

사용자가 Cursor 기능을 묻거나, 네가 Cursor 기능을 쓰거나 설명할 때 실행한다.

1. 주제 슬러그를 ${CLAUDE_PLUGIN_ROOT}/references/cursor-docs-index.md에서 찾는다. 없으면 https://cursor.com/llms.txt 를 WebFetch로 받아 슬러그를 찾는다.
2. 원문을 WebFetch로 받는다 — **`.md` 없는 bare URL**로 받는다.
   - 제품 문서: https://cursor.com/docs/<slug>  (예: rules · mcp · agent/overview · cli/overview)
   - 헬프센터: https://cursor.com/help/<slug>  (예: customization/context · customization/indexing)
   - ⚠️ llms.txt는 URL을 `.md`로 광고하지만 그 경로는 404다 — 반드시 `.md`를 떼고 받는다. (slug는 슬래시 포함 가능: `agent/overview`, `customization/context`)
3. 핵심을 요약하고, 설명에 출처 URL을 반드시 남긴다.
4. 동작·옵션이 불확실하면 추측하지 말고 원문 문장을 근거로 답한다.
