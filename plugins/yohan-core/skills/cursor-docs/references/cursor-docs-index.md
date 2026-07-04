---
id: cursor-docs-index
description: cursor-docs 스킬용 slug→URL 인덱스. 없는 주제는 cursor.com/llms.txt 폴백.
updated: 2026-07-04
---

# Cursor 공식문서 인덱스

> cursor-docs 스킬이 주제 slug를 여기서 찾는다. 없으면 https://cursor.com/llms.txt 로 폴백.
> ⚠️ **bare URL만 쓴다** — 모든 페이지에서 예외 없이 통하는 형식이 bare뿐이라서(아래 참조).
> 제품문서 = `cursor.com/docs/…`, 헬프센터 = `cursor.com/help/…`.
>
> **2026-07-04 재실측 addendum:** 위 "`.md` 접미사는 404다 (2026-06-28 실측)"라는 원 서술이 전면 규칙으로 재현되지 않는다 — P0 6종 URL 전부 + 아래 P1 신규 5종 중 4종(`cloud-agent`·`git`·`bugbot`·`github-integration`)은 `.md`도 200(curl 재확인, redirect 없이 직접). `tab`(`docs/tab/overview.md`)만 404 재현. 즉 ".md는 항상 404"는 페이지별 사실이었지 전면 규칙이 아니었다 — **bare URL을 계속 쓰는 이유는 "예외 없이 통하는 유일한 형식"이기 때문**이지 ".md가 무조건 실패해서"가 아니다. 상세: `yohan-brain/memory/ingest/cursor-official/p1-*.md`의 "소스 출처" 섹션과 `yohan-brain` PR(feat/cdocs-04-05) 설명 참조.

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

## P1 — 주 1회 이상 (brain ingest: `yohan-brain/memory/ingest/cursor-official/`, CDOCS-04 2026-07-04)

| slug | URL | ingest 파일 |
|------|-----|-------------|
| tab | https://cursor.com/docs/tab/overview | p1-tab.md |
| cloud-agent | https://cursor.com/docs/cloud-agent | p1-background-agent.md |
| background-agent | https://cursor.com/help/ai-features/background-agents | p1-background-agent.md (구 명칭 — 정본은 "Cloud Agent") |
| git | https://cursor.com/help/integrations/git | p1-git.md |
| bugbot | https://cursor.com/docs/bugbot | p1-git.md |
| github-integration | https://cursor.com/docs/integrations/github | p1-git.md |

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
