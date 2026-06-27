# yohan-cc-skills — 프로젝트 규칙 단일 소스 (Single Source of Truth)

> ⚡ 규칙 변경은 **여기서만** — `vhk sync` 로 AGENTS.md · .cursorrules 전파.

## 서문

- 한 줄 설명: Claude Code operations — handoff · parallel · release-gate (Claude-only)
- 레포: https://github.com/byh3071-cpu/yohan-cc-skills
- tier: S (inheritance-registry)

## 기술 스택

- Markdown skills · Claude Code plugins
- PowerShell hooks (Windows primary)

## 코딩 규칙

- skills = SKILL.md + references; secrets in hooks 금지
- Claude-only ops: handoff · release-gate · parallel — Cursor duplicate 금지
- plugin manifest 변경 시 marketplace.json 정합

## 기록 규칙

- loop protocol → `plugins/yohan-core/loop.md`
- 패턴 문서 → `docs/patterns/`
