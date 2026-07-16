# 작업 패턴 분석 보고서 (2026-06-18)

> 진입점: 이 문서 = `yohan-cc-skills` 마켓플레이스 스킬들의 도출 근거.
> 관련 산출물: `plugins/statusline`, `plugins/workflow`(release-gate·dogfood-crosscheck·visualize·handoff).

## 메타
- **데이터:** `~/.claude/history.jsonl` 618프롬프트 / 76세션 / 2026-03-18~06-17 (3개월)
- **방법:** 멀티에이전트 워크플로(7에이전트) — 5소스 병렬 수집(history·permissions·CLAUDE.md·project scaffolds·transcripts) → 종합 → history 원자료 대조 적대 검증
- **한 줄:** 비전공 1인 개발자, 자작도구 **VHK CLI**(vhk-cli 154=최다) 만들며 SnapContext·cafe-pos에서 독푸딩하는 "도구 제작자 겸 사용자". 작업이 4개 척추로 수렴.

## 반복 패턴

### 척추 (very-high · 스킬화 ◎)
| 패턴 | 빈도(실측) | 실제 프롬프트 예시 |
|---|---|---|
| ① 릴리즈 전 적대적 검증 루프 | 검증/확인 95·리뷰 31·/code-review 15 | "리뷰 결과도 자체 검증까지, 문제 하나라도 나오면 다시 반복 문제 해결될 때까지" / "머지 푸시 후 PR 생성 머지해도 문제없는지 적대적 검증 ㄱㄱ" / "사람 개입 필요한 문제는 스킵" |
| ② 멀티머신 핸드오프·복원 | 핸드오프/recap 49 | "멈추고 내용 work로 남겨 내일 이어서, vhk 이용" / "핸드오프 갱신해서 노트북 전달프롬프트 필요한거지?" |

### 빈출 (frequent · 스킬화 ◎/○)
| 패턴 | 빈도 | 예시 |
|---|---|---|
| ③ Notion Dev Log 마감 루틴 | devlog/노션 27 | "노션 Dev Log 적재… 세션로그·패턴·ADR 싹다 ㄱㄱ" / "CLAUDE.md 버전 갱신 + 노뚝이 최신맥락 알게 적재" |
| ④ VHK 독푸딩 교차검증+결함 역추적 | 독푸딩 15 | "VHK 리뷰 정확한지 독푸딩 가능?" / "앱버그인지 도구결함인지 역추적?" / "발견된거 VHK 이슈 등록?" |
| ⑤ 디자인 시안 N개 + HTML 시각화 보고 | HTML/시각화 43 | "5~6개로 퀄리티 높게, 10배 더 잘" / "비전공자라 디자인 용어 몰라 시각화로" / `! start docs\...html` |
| ⑥ VHK Goal 사이클 초장문 운영 프롬프트 | goal 42·vhk 73 | "너는 byh3071-cpu/vhk 코딩에이전트다. Plan 모드로… 한 PR=한 goal, 게이트 통과 전 done 금지, publish는 사람(2FA)" |

### 빈도 있으나 스킬 ✗ (기존 도구가 커버)
- 모델/effort 메타운영(63) → `claude-api`+`update-config`
- Plan모드 사지선다 협업(28) → Plan/brainstorming 기본
- 에러 자가치유 → systematic-debugging / 플러그인 설치검증 → update-config / 스캐폴딩 부트스트랩 → vibeinit CLI / 온톨로지 → 단일 프로젝트 특화

## 검증 보정 (적대 critic)
**과장:** "복원 자가평가(1~5)" 정형화(실제 1건) · "자가치유 ~14건"(직접지시 5건) · "검증 ~59"(실측 95, 카운팅 들쭉날쭉, 실제 라인 ~730)
**누락(중요):** ⭐ **PR→머지→main 최신화→태그/버전 사이클**(PR 91·버전 54) 독립 패턴 누락→①⑥에 흡수 / 짧은 승인토큰 운전(ㅇㅇ·ㄱㄱ·진행해 62) / SnapContext **OCR 도메인** 통째 누락(8) / "왜·설명" 이해요구(46) / 한국어 출력 강제 정정(8)

## 스킬화 결정 → 빌드 결과
| 패턴 | 스킬 | 상태 |
|---|---|---|
| ① + ⑥ + 누락 PR/태그 | `/release-gate` | ✅ 빌드 |
| ④ | `/dogfood-crosscheck` | ✅ 빌드 |
| ⑤ | `/visualize` | ✅ 빌드 |
| ② | `/handoff` | ✅ 빌드 |
| ②+ | 「채팅 종료 검증」루틴 (history 반복 문구) | ✅ `/handoff` — 2026-07-16 verify-only→**scan/close/full** + 재고축(문서·적재·갱신·핸드오프·Goal…) 로 정정 |
| ③ | (Notion Dev Log 마감) | ⏸ 보류 |
| 환경 | `/setup-statusline` | ✅ 빌드(시드) |

## 산출물 포인터
- repo: `byh3071-cpu/yohan-cc-skills` (public)
- 커밋: `b3991d7`(init+statusline) · `a20d8d5`(workflow 3) · `fe39a5b`(release-gate)
- 워크플로 비용: 7에이전트 / 469k 토큰 / 11분
