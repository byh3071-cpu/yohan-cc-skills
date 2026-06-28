---
id: cursor-docs-index
description: cursor-docs 스킬용 slug→URL 인덱스. 없는 주제는 cursor.com/llms.txt 폴백.
updated: 2026-06-28
---

# Cursor 공식문서 인덱스

> cursor-docs 스킬이 주제 slug를 여기서 찾는다. 없으면 https://cursor.com/llms.txt 로 폴백.
> ⚠️ **bare URL만 쓴다.** llms.txt가 광고하는 `.md` 접미사 경로는 404다 (2026-06-28 실측).
> 제품문서 = `cursor.com/docs/…`, 헬프센터 = `cursor.com/help/…`.

## P0 — 매일 쓰는 것 (brain ingest: `yohan-brain/memory/ingest/cursor-official/`)

| slug | URL | ingest 파일 |
|------|-----|-------------|
| rules | https://cursor.com/docs/rules | p0-rules.md |
| mcp | https://cursor.com/docs/mcp | p0-mcp.md |
| agent | https://cursor.com/docs/agent/overview | p0-agent.md |
| context | https://cursor.com/help/customization/context | p0-context.md |
| indexing | https://cursor.com/help/customization/indexing | p0-context.md |
| skills | https://cursor.com/docs/skills | p0-skills.md |
| cli | https://cursor.com/docs/cli/overview | p0-cli.md |

## P0.5 — 자주 (ingest 미완 → fetch 폴백)

| slug | URL |
|------|-----|
| hooks | https://cursor.com/docs/hooks |
| subagents | https://cursor.com/docs/subagents |
| plugins | https://cursor.com/docs/plugins |
| plan-mode | https://cursor.com/docs/agent/plan-mode |
| cli-reference | https://cursor.com/docs/cli/reference/parameters |

## 그 외

전체 목록은 https://cursor.com/llms.txt — 제품문서·헬프·CLI·통합·SDK가 카테고리별로 링크돼 있다. 여기 없는 주제는 llms.txt에서 slug를 찾아 bare URL로 fetch한다.
