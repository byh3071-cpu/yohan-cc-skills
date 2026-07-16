# next-task

> append-only — 새 항목은 맨 아래에 추가만 한다(기존 줄 수정·삭제 금지). active goal 1개만 작업한다. (출처: `AGENTS.md` Loop Protocol)

- [ ] 2026-07-02 멀티모델 오케스트레이션 도입 — **승인 대기**. 상세: `docs/log/2026-07-02-handoff.md` (팩트체크 완료, 승인 시 서브에이전트 tier 고정 + Codex 플러그인 통합)
- [x] 2026-07-03 멀티모델 배분 정렬 완료 — planner·critic→opus, 독트린 3곳 정렬(CLAUDE.md·cost-guard·핀)+ARCHITECTURE·PRD 미러 동반, 순정 스위치 추가, plugin 0.3.1. 상세: `docs/log/2026-07-02-handoff.md` §5 정정. (Codex·cross-check 통합은 별건 대기)
- [x] 2026-07-06 문서 드리프트 정합 — README·PRD·ARCHITECTURE를 실측 4플러그인(critical-thinking 추가)·yohan-core studio-post 스킬·workflow overnight-autoloop·plugin.json 버전으로 통일, SETUP-HANDOFF STEP0 경로 정정(automation→yohan-ecosystem), 2026-07-02 핸드오프 상태선 반영완료로 정정. (Codex 통합은 이미 라이브 활성 — settings.json codex@openai-codex + 마켓 등록; 잔여 cross-check/release-gate 병렬통합)
- [ ] 2026-07-16 `/handoff` 채팅 종료 검증(scan/close/full·재고축) — 브랜치 `feat/handoff-session-end-verify` 커밋 2개 로컬만. **다음: push→PR→머지→plugin 0.3.4 갱신**. 상세 `docs/log/2026-07-16-handoff-session-end-verify.md`
