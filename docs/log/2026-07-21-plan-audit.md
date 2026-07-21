# 2026-07-21 — plan-audit 스킬 (역추출 대조 감사)

> append-only. 과거 항목 수정·삭제 금지.

## 지금까지 한 것

| 단위 | 내용 |
|---|---|
| PR #48 → `6b437fc` | `plan-audit` 스킬 신설. yohan-core `0.3.9` → `0.3.10` |
| `plugins/yohan-core/skills/plan-audit/SKILL.md` | 감사 절차 + 고정 루브릭 7항목 + 회차 운영법 |
| `plugins/yohan-core/skills/plan-audit/scripts/Export-UserTurns.ps1` | 트랜스크립트에서 사람 발화만 기계 추출 |
| `docs/analysis/2026-07-21-plan-audit-auto-trigger.md` | C안(자동 트리거) 설계문서. 코드 0줄 |
| README · ARCHITECTURE | 스킬 목록 미러 갱신 + 기존 드리프트 교정(스킬 7→10, 에이전트 4→6, 훅 7→9) |
| 브랜치 정리 | `feat/research-loop-html-template` 로컬·원격 삭제(PR #46 머지 완료분) |
| git 신원 교정 | 이 레포만 local override로 실명이 박혀 있던 것 제거 → 전역 `byh3071-cpu` 상속 |

## 핵심 결정 (왜)

**1. 역추출 대조(blind extraction)를 택한 이유**
기존 `cross-check`·`critic`은 대상을 *받아서* 검증한다 → 계획을 먼저 읽는 순간 앵커링돼 "빠진 것"은 구조적으로 못 본다. 잡으려는 결함은 계획의 버그가 아니라 **요청→계획 번역에서 떨어진 정보**이므로, 감사자에게 계획을 주지 않고 대화 원문만 줘서 요구사항을 독립 추출한 뒤 대조한다.

**2. 계획 사본 파일을 만들지 않는다**
초안은 사본을 레포 안에 뒀다가 → 레포 밖으로 옮겼다가 → 결국 **아예 안 만드는 것**으로 갔다. 어느 서브에이전트도 계획을 읽지 않으면(critic=원문만, explorer=경로목록만) 사본이 필요 없고, 앵커링 차단이 "파일 숨기기"에서 **구조적 부재**로 바뀐다. 우회 경로가 0이 된다.

**3. 훅 자동 강제(C안)를 v1에서 뺀 이유**
훅은 PowerShell이라 "의도 정합"을 판정하지 못한다. 마커 확인밖에 못 하고 그 마커를 만드는 건 결국 B안이다. `deny`로 막아도 같은 세션 같은 모델이 자기 계획을 고쳐 자기확증이 남는다 → 마찰만 늘고 품질은 그대로. C안은 B안의 대안이 아니라 위에 얹는 레이어라 결론.

**4. `allowed-tools` 생략**
`cross-check`처럼 `Read, Grep, Glob, Bash`를 나열하면 목록에 Agent가 빠져 서브에이전트 위임이 막힌다. 레포 24개 스킬 중 21개가 생략하고 있다.

**5. 반려 지시 수집 (승인 플랜 대비 스코프 추가)**
승인된 계획의 추출기 사양은 `promptSource=typed` 하나였다. 구현 중 실행해보니 **계획을 반려하며 남긴 지시가 통째로 유실**됐다 — `tool_result`에 묻혀 `promptSource` 키 자체가 없다. 이 스킬의 핵심 입력이라 추가했다. 절차상 재승인을 안 받은 이탈이며 PR 본문에 명시했다.

**6. 인코딩 3중 규칙**
층마다 다른 지뢰다. 입력=`[IO.File]::ReadLines(path, UTF8)`(`switch -File`은 인코딩 파라미터가 없어 CP949 오독), 소스=UTF-8 BOM 저장, 출력=stdout UTF-8 강제. `PAT-001`은 "소스 순수 ASCII"를 처방하지만 이 레포는 한글 리터럴이 필요한 파일에 BOM 예외를 써왔다(`hooks/detect-routing-miss.ps1:6` 선례).

## 다음 할 일 (우선순위)

1. **[높음] 미검증 2건 확인** — 다음 세션에서 `/yohan-core:plan-audit`이 뜨는지 확인 후 ① 스킬 실행 중 Agent 위임 ② `$env:CLAUDE_PLUGIN_ROOT` Glob 폴백. 스킬 로드가 세션 시작 시점이라 구현 세션에서는 불가능했다
2. **[중간] Codex 벤더 교차검증** — 2026-07-25 12:30 이후 재시도. 사용량 한도 초과로 이번에 실패
3. **[중간] 커서 검증** — 요청받았으나 미이행. 커서 연동 가능 여부 조사조차 안 했다
4. **[낮음] studio-post 잔여물** — 로컬 `docs/studio-post-vhk-wiring`에 미반영 커밋 1건(`36841a3`, 유령 voice CLI 참조 진실화). 원격 브랜치는 이미 삭제됨. PR #29(열림)도 같은 계통이라 한 번에 처리
5. **[낮음] 다중 세션 경고 경로** — 자동탐색 경로 전용이라 재현 못 했다. 실제 세션 재개 시 자연 검증

## 산출물 포인터

**진입점: `plugins/yohan-core/skills/plan-audit/SKILL.md`** — 절차·루브릭·회차 운영이 전부 여기 있다.

| 경로 | 역할 |
|---|---|
| `plugins/yohan-core/skills/plan-audit/SKILL.md` | 감사 절차 SoT |
| `plugins/yohan-core/skills/plan-audit/scripts/Export-UserTurns.ps1:60` | 파싱 루프 — 직접입력/반려지시 2종 수집 분기 |
| `docs/analysis/2026-07-21-plan-audit-auto-trigger.md` | C안 설계 + 미검증 전제 2개 |
| `plugins/yohan-core/hooks/critic-gate.ps1:5-12` | 매처 불신 방어 패턴(스크립트가 직접 tool_name 확인) — C안이 재사용할 선례 |
| `plugins/yohan-core/hooks/detect-routing-miss.ps1:5` | fail-open 규율 선례 |
| `docs/ARCHITECTURE.md` §4.1 | `allowed-tools` 함정 경고 + plan-audit 설명 |

**산출물 위치(런타임):** `$env:TEMP\plan-audit\requests-<sessionId>.txt`. 레포를 오염시키지 않으며 7일 초과분은 스크립트가 자동 정리한다.

## 세션 회고 — 의도 대비 미달 4건

자기 감사 결과를 기록에 남긴다. 다음 세션이 같은 실수를 반복하지 않기 위해.

1. **커서 검증 미이행** — "원한다면 커서 검증 해"에 대해 "못 몬다"고 단정하고 Codex로 대체했으며 그마저 실패했다. 연동 가능 여부 조사조차 없었다
2. **의사결정 회피** — 보고 후 A/B/C만 던져 "그래서 어떻게 하라고"를 2연속 받았다. 빠른 결정 규칙 위반
3. **승인 없는 스코프 추가** — 반려 지시 수집(위 결정 5). 결과는 옳았으나 순서가 틀렸다
4. **보고 자체의 오류 2건** — "위임 3번 성공"(실제 2번), 쓰지도 않은 explorer를 쓴 것처럼 서술. 지적받고 자진 정정

## 감사 실적

이 계획 자체를 자기 절차에 3회차 걸어 **결함 16건(치명 7)** 을 잡고 반영했다. 구현 중 1건(반려 지시 누락) 추가 발견. 회차마다 새 결함이 **직전 회차의 수정문**에서 나왔다 — 멈추는 기준은 "결함 0"이 아니라 "새로 추가한 문장이 더 이상 새 결함을 안 낳을 때".
