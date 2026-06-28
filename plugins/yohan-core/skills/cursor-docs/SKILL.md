---
name: cursor-docs
description: Cursor 공식문서를 조회·인용한다. Cursor 기능을 설명하거나 쓰기 전 근거 확인용.
---

사용자가 Cursor 기능을 묻거나, 네가 Cursor 기능을 쓰거나 설명할 때 실행한다.

1. 주제의 슬러그를 ${CLAUDE_PLUGIN_ROOT}/references/cursor-docs-index.md에서 찾는다. 없으면 https://cursor.com/llms.txt 를 WebFetch로 받아 슬러그를 찾는다.
2. https://cursor.com/docs/<slug>.md (또는 help 경로 .md) 를 WebFetch로 받아 원문을 읽는다.
3. 핵심을 요약하고, 설명에 출처 URL을 반드시 남긴다.
4. 동작·옵션이 불확실하면 추측하지 말고 원문 문장을 근거로 답한다.
