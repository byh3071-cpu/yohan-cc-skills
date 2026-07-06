# 요한 CC 생태계 8축 감사보고서 (2026-07-06)

> 진입점: 이 문서 = 스킬·훅·플러그인·MCP·명령어·라우팅·문서·설정 전면 감사의 영구 기록. temp 출력(`w5g53mkgg.output`) 박제본.
> 관련 산출물: `plugins/yohan-core`(훅·스킬·MCP), `plugins/critical-thinking`, `plugins/workflow`, `plugins/statusline`, `docs/{ARCHITECTURE,PRD}.md`, `docs/log/2026-07-02-handoff.md`, `docs/state/next-task.md`, `~/.claude/settings.json`(live), `automation/boot-auto-pull-setup/*`.

## 메타
- **총계:** 생존 발견 46 · 기각 4 · 투입 에이전트 58
- **방법:** 8축 팬아웃(훅/플러그인·마켓/스킬/서브에이전트·라우팅/MCP/문서·git/명령어·output-style/개선기회) → 각 발견 적대 검증(CONFIRMED·PLAUSIBLE 생존, REJECTED 4건 기각)
- **verdict 분포:** CONFIRMED 42 · PLAUSIBLE 4(F21·F27·F28 + 위임규칙) · REJECTED 4
- **심각도 분포:** HIGH 5 · MEDIUM 21 · LOW 20

---

## §1 두괄식 요약

**핵심 결론: 개별 버그보다 3대 "구조결함"이 이 생태계의 무게중심이다.** 낱개 오탐·오타가 아니라, 자기 독트린(PAT-002·003·004·"MCP Connected 신뢰 금지")을 자기 인프라가 위반하는 계통적 균열이다.

1. **🔐 보안훅이 실효 없다.** `protect-secrets`의 `.env` 차단 정규식이 파이프·리다이렉트·따옴표 뒤에서 전부 뚫리고(`cat .env | clip` → ALLOWED, 실측), `.git-credentials`·`.aws/credentials`·`.npmrc`는 denylist에 아예 없다. `hooks.json`의 `if` 필드는 스키마상 잘못된 위치에 있어 무시되고, 토큰 스캐너 정규식은 정작 이 생태계가 상시 쓰는 `sk-ant-` 키를 못 잡는다. CLAUDE.md "절대 규칙"을 강제한다고 선언한 가드가 최빈 경로에서 무력.
2. **🖥️ 멀티머신 동기화가 라이브 설정을 파괴한다.** `Sync-ClaudeSettings.ps1`이 6월 23일 초판에 동결된 dotfiles를 라이브 `settings.json` 위로 **전체 덮어쓰기**(머지 아님)한다. 로그온 태스크가 등록된 머신(노트북/새 PC)에서 `MCP_TIMEOUT=30000`·`opus[1m]`·statusLine·plugins 9종·94줄 allow-list가 조용히 소실 → 유저 메모리에 박제된 콜드스타트 회귀가 그대로 재발.
3. **📝 Notion 자동적재가 사문화됐다.** 세션로그 훅과 MCP 어댑터가 **서로 다른 3개 env 이름**(`NOTION_EXECLOG_DB` / `NOTION_EXECLOG_DB_ID` / `NOTION_EXECUTION_LOG_DB_ID`)을 써서, 실제 존재하는 DB에 아무것도 안 붙는다. 매 세션 조용히 no-op. 공언한 "세션 종료 시 EXECUTION LOG 자동기록" 기능이 죽어 있음 — 규칙 ④(Connected 신뢰 금지) 위반 전형.

### HIGH 5건

| # | 테마 | 제목 | 근거 file:line | verdict |
|---|---|---|---|---|
| F1 | 🔐보안훅 | protect-secrets `.env` 차단이 Bash 파이프·리다이렉트·따옴표로 우회됨 + credentials 파일 denylist 누락 + fail-open | `plugins/yohan-core/hooks/protect-secrets.ps1:12` | CONFIRMED |
| F2 | 🔐보안훅 | `hooks.json`의 `if`가 matcher-그룹 레벨에 있어 무시 → pre-commit-check가 모든 Bash를 검사·오차단 | `plugins/yohan-core/hooks/hooks.json:20` | CONFIRMED |
| F9 | 🖥️멀티머신 | sync가 stale dotfiles를 라이브 settings.json 위로 전체 덮어써 라이브 설정 파괴(MCP_TIMEOUT 회귀) | `automation/boot-auto-pull-setup/Sync-ClaudeSettings.ps1:32-42` | CONFIRMED |
| F23 | 📝Notion | 세션로그→Notion EXECUTION LOG가 env 이름 불일치로 매 세션 조용히 no-op | `plugins/yohan-core/hooks/log-session.ps1:5-6` | CONFIRMED |
| F41 | 🖥️멀티머신 | dotfile SoT 첫 커밋에 동결 + 이 머신엔 sync 태스크 미등록 → 새 머신 복원 시 crippled config, git 백업 0 | `automation/boot-auto-pull-setup/Sync-ClaudeSettings.ps1:41` | CONFIRMED |

> F9·F41은 같은 파괴적 `Copy-Item -Force` 설계를 서로 다른 팬아웃 축(플러그인/개선기회)에서 독립 발견한 것 — 사실상 한 결함의 양면이다.

---

## §2 테마별 상세

표기: 심각도(H/M/L) · 분류 · verdict. evidence는 핵심 근거만, 권고는 최소 처방만 남긴다.

### 🔐 보안훅 실효성 (5건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F1 | **H** bug·CONF | `.env` 우회 · `protect-secrets.ps1:12` | deny `\.env($\|\.)`는 문자열 끝/뒤에 점일 때만 매칭. 실측: `cat .env \| clip`·`type .env > x`·`cp .env /tmp` 전부 ALLOWED. `.git-credentials`·`.aws/credentials`·`.npmrc` denylist 부재. catch 시 exit 0(fail-open) | Bash 정규식 `\.env\b`로 교체 + credentials 패턴 3종 추가 + 파싱실패는 stderr 경고(정상 미매칭과 구분) |
| F2 | **H** bug·CONF | `if` 미인식 오차단 · `hooks.json:20` | 공식 스키마상 `if`는 핸들러 레벨. 그룹 레벨(line 20·27)이라 무시 → matcher `Bash`만 남아 모든 Bash에서 pre-commit-check 발동. staged에 `prod.env`·`.env.example`(오탐) 있으면 이후 모든 Bash 차단 | `if`를 핸들러 객체 안으로 이전(선언적) + critic-gate式 스크립트 내부 stdin 자기검사를 1차 방어로(스키마 드리프트 생존) |
| F3 | M bug·CONF | 토큰 정규식 사각 · `pre-commit-check.ps1:13` | `sk-[A-Za-z0-9]{20,}`가 `sk-ant-`를 못 잡음(ant 뒤 하이픈에서 끊김). AWS `AKIA`·Slack `xoxb`·Google `AIza`·`sk-proj-`도 미탐. 상시 쓰는 Anthropic 키가 blind spot | `sk-ant-`·`AKIA`·`xox[baprs]-`·`AIza`·`sk-(proj\|svcacct)-` 추가. 장기적으로 gitleaks/trufflehog 위임 검토 |
| F4 | M bug·CONF | PAT-002 escape 미적용 · `pre-commit-check.ps1:17`(+ context-hint·protect-secrets·critic-gate) | 자매 훅 critical-activate·critical-tracker는 방출 직전 `[regex]::Replace`로 비-ASCII→`\uXXXX` 강제(PAT-002 준수). yohan-core 4개 훅은 한글 reason을 ConvertTo-Json 원문 방출 → Git Bash 파이프 캡처 시 모지바케(꼬리: 최악 JSON 파싱 실패) | 4개 훅 모두 방출 직전 PAT-002 처방 `[regex]::Replace(...\u{0:x4})` 삽입 + raw 바이트로 왕복 검증 |
| F43 | M workflow·CONF | 파괴작업 게이트 공백 · `hooks.json:18` | 파괴 게이트는 `git commit`·`git push` 2종뿐. force-push(critic-gate에 걸리나 gate-pass 6h 통과)·`reset --hard`·`clean -fd`·`publish`·`release`는 내용인지형 훅 게이트 부재. 자율/bypass 플로우(overnight·vhk-auto)에서 사람 개입 없이 실행 위험. PAT-003 독트린과 배치 | PreToolUse Bash에 `guard-destructive.ps1` 추가(force-push는 `--force-with-lease` 제외, publish/release는 `ask`). **범위는 §5 결정 필요** |

### 🖥️ 멀티머신 동기화 (5건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F9 | **H** bug·CONF | stale dotfiles가 라이브 파괴 · `Sync-ClaudeSettings.ps1:32-42` | `:41 Copy-Item -Force`=전체 덮어쓰기. dotfiles는 cc4ff5f(6/23) 이후 무수정(plugins 3개뿐). 라이브는 MCP_TIMEOUT=30000·opus[1m]·statusLine·hooks·plugins 9개·allow 94줄로 진화 → 로그온 첫 사이클에 소실 | 전체덮어쓰기 폐기 → 공유 baseline 키만 병합, 머신/옵트인은 settings.local.json으로 이관. 즉시 라이브→dotfiles write-back으로 SoT 현행화 |
| F41 | **H** workflow·CONF | dotfile 동결 + sync 태스크 미등록 · `Sync-ClaudeSettings.ps1:41` | dotfile 커밋 1건(6/23) 이후 갱신 0. 이 데스크탑엔 `Yohan-ClaudeSync` 태스크·log 부재 → **config git 백업 0**(머신 사망 시 전량 유실). Setup-Machine 도는 머신은 동결 dotfile로 crippled | ① 라이브를 민감치 정리 후 1회 스냅샷 커밋(백업 0 해소) ② sync를 키 단위 merge로 전환 ③ merge 전환 후에만 이 머신에 태스크 등록 |
| F11 | M improvement·CONF | 머신·옵트인 설정이 settings.json에 몰림 · `settings.json:106-181` | model·statusLine 절대경로·외부마켓·프로젝트경로 박힌 allow-list·effortLevel이 sync 타깃 settings.json에 뒤섞임 → 덮어쓰기 시 전부 휘발. settings.local.json은 sync가 안 건드림(분리 지점 이미 존재). 역설: dotfile의 비밀차단 `deny`가 라이브엔 없음 | 공유 baseline만 settings.json, 머신/옵트인 값은 settings.local.json으로 이관. **분리 전략 §5 결정 필요** |
| F34 | M bug·CONF | 새 머신 부트스트랩 경로 오류 · `CLAUDE-CODE-SETUP-HANDOFF.md:27` | STEP 0 Test-Path `dev\automation\yohan-cc-skills` → False(실제는 `dev\yohan-ecosystem\yohan-cc-skills`). 새 머신에서 상시 False로 Setup-HomePC 재실행 경로 오분기. (line 28/34 boot-auto-pull-setup 경로는 실존 — 정상) | line 27만 `yohan-ecosystem\yohan-cc-skills`로 정정. dev 루트 변수 앵커링 |
| F46 | L maintenance·CONF | permissions.allow mojibake 死엔트리 · `settings.json:21` | allow 93개 중 CP949 깨진 경로 3개(:21 SnapContext, :42 Yohan-Studio, :23 Read 글롭) + additionalDirectories :102(shotgrade). 폴더 개명 전 캡처된 stale 경로 → 어떤 명령과도 매치 불가한 dead weight. fewer-permission-prompts는 '추가'만 함 | 死엔트리 4개 1회 prune. prune를 fewer-permission-prompts에 역기능 추가 검토 |

### 📝 Notion 사문화 (4건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F23 | **H** workflow·CONF | 세션로그 env 이름 불일치 no-op · `log-session.ps1:5-6` | `:5 $db=$env:NOTION_EXECLOG_DB`, `:6 if(-not $db){exit 0}`. 실측: NOTION_EXECLOG_DB=MISSING, 실제 설정된 이름은 NOTION_EXECUTION_LOG_DB_ID. $db 항상 빈값 → 매 Stop exit 0(무음). try/catch로 실패도 삼킴 | `:5`를 `NOTION_EXECUTION_LOG_DB_ID`로 교체(SoT 단일화) + 미설정 시 stderr 경고 1줄 + 실제 1건 적재로 검증 |
| F24 | M bug·CONF | 어댑터도 exec-log env 불일치 + DB id 미설정 · `notion_adapter.py:25-29,58` | 어댑터는 `NOTION_EXECLOG_DB_ID`(또 다른 이름)에서 읽음. RESOURCE/SUMMARY/TRIPLE/AIDICT_DB_ID는 env·.env 어디에도 없음 → db_id=None. 즉 훅·어댑터·머신 3자가 전부 다른 이름. 동작하는 건 TOKEN·DEVLOG·PATTERN뿐 | env 이름 SoT를 `.env.example`에 고정, 4곳 통일(NOTION_EXECUTION_LOG_DB_ID 수렴). 미사용 4종은 `_DB_ENV`에서 제거하거나 '미구현' 명시 |
| F42 | M improvement·CONF | log-session이 stub · `log-session.ps1:31` | `:31 결과=@{select=@{name='성공'}}`(실패해도 성공), `:33 작업내용`=고정문구뿐. 수정파일·커밋·교훈 0 캡처. 글로벌 규칙 "Dev Log 행=산출물 색인, 교훈 필수"와 배치. transcript는 이미 stdin에 들어오는데 미사용 | create-once를 upsert로 전환, transcript 파싱(statusline式)으로 마지막 요약·git diff --stat·커밋해시·교훈 적재, 실패마커 감지 시 결과 분기 |
| F44 | M improvement·CONF | Notion 경로 파편화 · `plugins/yohan-core/CLAUDE.md:30` | 독트린은 "Notion 연동은 yohan MCP 단일 창구"인데 log-session은 raw REST 직접 호출(MCP 우회). 런타임엔 claude_ai_Notion·notion-mcp·yohan 3~4계통 병존 → 관측성 저하. (주의: Stop 훅은 MCP 클라이언트 없어 raw REST 불가피) | CLAUDE.md에 "훅은 raw REST 예외" 1줄 명시 + env 이름 이원화 해소 + 커넥터 정본 SoT 문서화 |

### 📄 문서 드리프트 (7건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F20 | M maintenance·CONF | 4번째 플러그인 critical-thinking 누락 · `ARCHITECTURE.md:8` | marketplace엔 critical-thinking(v0.1.0, skeptic 서브에이전트) 등록됐으나 ARCHITECTURE·PRD 둘 다 "플러그인 3종". 커밋 4192eb0가 미러 미갱신. "실측 기준" 자처 문서가 설치된 플러그인+서브에이전트 통째 누락 | ARCHITECTURE §1·§2·§4 + PRD §5에 critical-thinking(skeptic model:sonnet, 코드용 critic과 분리 계통) 추가, '3종'→'4종' |
| F31 | M workflow·CONF | next-task active goal이 실제와 불일치 · `next-task.md:5` | `:5`는 여전히 "멀티모델 도입 — 승인 대기", `:6`은 "Codex 통합 별건 대기". 그러나 라이브 settings.json에 `codex@openai-codex:true` + 마켓플레이스 등록 → 이미 통합·활성. 진짜 잔여는 cross-check/release-gate 병렬통합뿐. active-goal 단일 앵커라 자율 세션 오도 위험 | append-only로 "Codex 통합 완료" 줄 추가, 잔여를 handoff §3 항목5로 좁힘, 상위 goal done 처리 |
| F32 | M maintenance·CONF | README 플러그인 표 누락 · `README.md:30` | 표(30~39)·구조(41~49)에 statusline·workflow만. 핵심 yohan-core("공통 두뇌", 스킬 6종+서브에이전트 4종+훅+MCP)와 critical-thinking 통째 부재. README 마지막 커밋 6/23=도입 이전 스냅샷 | 표·구조에 yohan-core·critical-thinking 4개 전부 반영. (권고 원문의 'studio-post'는 이 브랜치엔 없음 — 실제 6종) |
| F33 | M maintenance·CONF | PRD·ARCHITECTURE '3종' 고정 + 버전 불일치 · `PRD.md:31` | "플러그인 3종"(실제 4종). PRD `:43 v0.3.0` vs `:45 v0.3.1` 동일 문서 내 모순(SoT=0.3.1). ARCHITECTURE도 트리에 critical-thinking·PAT-002~004 없음. 두 문서 다 "레포 실제 근거" 자처라 더 오도적 | main 기준(4플러그인·버전 SoT)으로 재정렬. 미러에 "열거·버전은 marketplace.json SoT" PAT-004 주석 부착 |
| F19 | L maintenance·CONF | 0.3.1 버전 미러 미반영 · `ARCHITECTURE.md:36` | SoT plugin.json/marketplace=0.3.1. ARCHITECTURE line34·44 stale 0.3.0, PRD `:43` 0.3.0 vs `:45` 0.3.1 모순. c38cfc0가 tier 문구는 고쳤으나 버전 숫자 놓침. (앵커는 :36 아닌 line34) | 미러 숫자를 참조로 대체하거나 sync-marketplace가 버전 미러까지 동기화 |
| F22 | L workflow·CONF | 핸드오프 상태선 stale · `2026-07-02-handoff.md:2` | 헤더 "승인 대기/코드 변경 없음"인데 §5·commit c38cfc0·next-task는 이미 반영 완료(planner·critic→opus). 진입점 상태선이 거짓 | 원문보존(append-only) 지키며 최상단에 현재상태 배너 1줄 얹기 |
| F35 | L improvement·CONF | dangling 위키링크 · `2026-07-02-handoff.md:40` | `[[plugin-install-vs-enable]]`이 명명 패턴처럼 참조되나 레포 전체에 이 파일 1곳뿐(정의 없음). 트랩은 패턴화 3기준 충족 | PAT-005로 신설 후 `[[PAT-005]]`로 링크하거나, 브래킷 제거 |

### 🌊 flow 오케스트레이션 (4건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F36 | M bug·CONF | /flow critic가 '계획'만 검증, 구현 diff 미검증 · `flow.md:24-32` | 3)검증=critic이 planner의 "계획"만 봄, 4)출시=shipper가 그 뒤 코드 생성·적용. diff는 critic을 한 번도 안 거침. 그런데 계획-only 통과가 `.gate-pass`를 찍어 push 게이트 개방. 글로벌 풀개발 독트린(구현→critic)과 순서 역전 | flow에 명시적 '구현' 단계를 설계·검증 사이 삽입, critic이 diff를 검증하도록 재배치, gate-pass는 diff 통과 후에만. **재설계 §5 결정** |
| F37 | M workflow·CONF | /flow에 planner 후 승인 게이트 없음 · `flow.md:19-27` | 2)설계 직후 3)검증 직행, 승인 체크포인트 없음. 글로벌 "🚀 풀개발"은 "승인받고 시작(승인 전 코드 금지)" 명시 → 이중 SoT 드리프트. critic-gate도 gate-pass 갱신 때문에 승인 누락 못 잡음 | shipper 앞(코드/커밋/push 직전)에 승인 게이트. 근본: flow.md를 풀개발 SoT로 단일화 |
| F15 | M workflow·CONF | ship-it `.gate-pass`가 6시간 시간창 · `ship-it/SKILL.md:16`(실제 :15) | critic-gate는 파일 존재+mtime<6h면 무조건 통과. 10시 변경A가 touch→12시 미검증 변경B push해도 age<6h로 자동 통과. SHA/브랜치 미바인딩이라 defeatable | `.gate-pass`에 통과 HEAD SHA 기록, push 시점 HEAD와 대조. 무인 push 경로 우선 |
| F21 | L workflow·PLAUS | 위임 규칙 vs /flow 상충 · `CLAUDE.md:41` | `:41` "판단·핵심설계는 지휘자 직접"인데 /flow는 설계→planner, 판단→critic 위임. carve-out 없음. (강도는 과장 — command가 ad-hoc 기본을 override, line39 "판단"과 어휘 충돌이 더 날카로움) | CLAUDE.md:41에 /flow carve-out 1줄 + line39/41의 "판단" 어휘 구분(서브=분석노동, 지휘자=최종판단) |

### 🔌 MCP (5건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F25 | M bug·CONF | .mcp.json bare python · `plugins/yohan-core/.mcp.json:4` | 플러그인은 `command:python`(전역), 프로젝트-로컬은 `.venv\Scripts\python.exe`. 현재 데스크탑은 전역에 deps 있어 우연 동작. Store python 셔임이 PATH 앞이거나 타 머신 전역에 50 deps 없으면 서버 조용히 사망. deps SoT=venv인데 플러그인만 우회 | command를 `${YOHAN_ECOSYSTEM_ROOT:-...}/yohan-mcp/.venv/Scripts/python.exe`로. 셋업 문서에 venv 부트스트랩 명문화 |
| F26 | M maintenance·CONF | Notion 3계통 중복 npx 콜드스타트 · `.claude.json notion-mcp` | notion-mcp(npx)·claude_ai_Notion 커넥터·yohan-mcp 병존. allow엔 커넥터 4개만, notion-mcp·yohan Notion 툴은 0 → 실사용은 커넥터인데 notion-mcp가 매 세션 npx 콜드스타트 세금만 문다. (실은 4계통 — log-session raw REST 포함) | notion-mcp 제거(소비처 0, 안전) + 4개 터치포인트 SoT 문서화. 메모리 콜드스타트 교훈과 상충 |
| F29 | L maintenance·CONF | 스테일 project-scoped MCP · `.claude.json (Yohan OS)` | 구 Desktop 경로 프로젝트에만 caveman-shrink(npx) 잔존. 현 개발루트로 이관 전 잔해. 동일 프로젝트가 슬래시/백슬래시 두 키로 중복 | 구 경로 항목 mcpServers.caveman-shrink 블록 제거(死설정, 무해). (projects는 40 아닌 27개) |
| F27 | L improvement·PLAUS | MCP_TIMEOUT 전역 단일값 · `settings.json:2-4` | 30000은 warm 캐시 기준 적정이나 serena(`uvx --from git`)는 최초 git clone+빌드라 30s 초과 소지. 전역 단일값이라 서버별 편차 미반영. ('반드시 초과'는 미실측 예측) | 30000 유지 + serena/npx 서버 첫 세션 전 1회 예열을 신규 머신 체크리스트에 |
| F28 | L improvement·PLAUS | config단 인증 검증 부재 · `.claude.json / notion_adapter.py:66` | notion-mcp가 `Bearer ${NOTION_TOKEN}`을 치환만, 미검증 → 토큰 미동기 머신에서 ✓Connected인데 전건 401 가능. (원문 근거 notion_adapter.py:66은 감사 트리에 없어 환각 — config 갭 자체는 실재) | boot-auto-pull-setup에 부팅 시 auth 스모크(get-self) 1회 추가 |

### 🧹 스킬·명령어·output-style 위생 (11건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F13 | M bug·CONF | cursor-docs dead ref · `cursor-docs/SKILL.md:8` | `${CLAUDE_PLUGIN_ROOT}/references/cursor-docs-index.md` 가리키나 그 파일 없음(실제는 skills/cursor-docs/references/에 존재). 대조군 cc-docs는 정상 → 진짜 경로-파일 불일치. 매 호출 llms.txt WebFetch 폴백 + 문서화된 404 트랩 노출 | 경로를 `${CLAUDE_PLUGIN_ROOT}/skills/cursor-docs/references/...`로 수정하거나 인덱스를 plugin-level로 이동(cc-docs 대칭) |
| F14 | M bug·CONF | new-repo 그룹 목록이 ValidateSet과 불일치 · `new-repo/SKILL.md:41` | "(add-repo.ps1 허용값)"이라 단언한 7개 목록이 실제 ValidateSet 9개 중 `_hackathon`·`_assets` 누락. 거짓 parity → 해당 성격 레포 오라우팅 | `_hackathon`·`_assets` 추가 + 판단표에 행 보강. 장기적으로 ValidateSet을 SoT로 위임 |
| F10 | M maintenance·CONF | critical-thinking 게시됐으나 휴면 · `marketplace.json:30-35` | v0.1.0 게시(#11)됐으나 dotfiles·라이브 enabledPlugins 둘 다 없음 → /critical·skeptic 사용 불가. 세션 스킬 목록에도 부재로 실측. "기본 OFF 옵트인"은 토글 기본값이지 enable 여부 아님. sync 덮어쓰기상 dotfiles에 없으면 옵트인 지속 불가 | 실사용이면 라이브+dotfiles 둘 다 enable, 미가동이면 handoff에 '대기중' 명시(유령 게시물 방지). **§5 결정** |
| F8 | L workflow·CONF | PAT-002 구현한 critical-thinking 미활성 + caveman 잠재 경합 · `settings.json:138` | escape를 제대로 구현한 훅(critical-tracker.ps1:62)은 잠자고, escape 미적용 yohan-core 훅만 라이브. 재활성 시 두 UPS 훅이 상반된 문체 지시(caveman 단문 vs critical 렌즈) 동시 주입 위험(현재 무충돌) | critical-tracker의 escape 로직을 라이브 context-hint.ps1로 이식(F4 연계). 재활성 시 문체 조건부 게이팅 |
| F16 | L workflow·CONF | cross-check/critical-thinking 트리거 충돌 · `cross-check/SKILL.md:3` | 둘 다 description에 '의사결정 검증' 광고. 본문 경계(코드=cross-check, 순수 추론=critical-thinking)는 있으나 자동발동은 프론트매터가 좌우 → 순수 의사결정 질의 경합 | cross-check description에서 '의사결정' 제거, 산출물 쪽으로 한정 |
| F17 | L maintenance·CONF | workflow description 스킬 누락 · `workflow/plugin.json:3` | 실제 6스킬 중 plugin.json은 3개만, marketplace는 4개만 열거 — new-repo·parallel 양쪽 누락 → 발견성 저평가 | 두 메타데이터를 6스킬 전부로 동기화. 릴리즈 체크리스트에 '스킬 vs description 대조' |
| F18 | L workflow·CONF | ship-it/release-gate 경계 없음 · `ship-it/SKILL.md:8` | 둘 다 '내보내기' 길목 커버, 상호 경계 명시 0. ship-it은 disable-model-invocation이라 실충돌 낮음. ship-it `:3` "머지"는 실제 절차에 없음(release-gate 소관) | 1줄 경계 노트 상호 추가. ship-it의 "머지" 문구 정정 |
| F38 | L maintenance·CONF | loop.md orphan + 이중 SoT · `loop.md:1-8` | plugin 루트·frontmatter 없어 로더 미등록. 동일 5항목이 CLAUDE.md:74에 인라인(이중 SoT). built-in /loop과 이름 충돌 | loop.md 삭제 + CLAUDE.md:74 "loop.md 따른다" 문구 제거(인라인 단일 SoT) |
| F39 | L maintenance·CONF | yohan-voice 태그 [웹] 불일치 · `yohan-voice.md:19` | 생태계 표준 [웹/외부](CLAUDE.md:7·yohan-writing:13·skeptic:17)와 달리 yohan-voice만 [웹]. always-on output-style이 다른 태그 강제 | 라벨만 [웹/외부]로 교체(서술부는 이미 '웹/외부') |
| F40 | L improvement·CONF | yohan-voice force-for-plugin:true lock-in · `yohan-voice.md:5` | 공식 docs상 "플러그인 enable 시 사용자 outputStyle을 override". yohan-core는 공통 두뇌라 어느 레포서도 Learning/Explanatory 선택 불가(항상 yohan-voice). 의도된 lock-in 가능성 높음 | 의도면 README에 1줄 명문화, 유연성 원하면 필드 제거하고 두괄식은 CLAUDE.md/yohan-writing으로 커버. **§5 결정** |
| F12 | L maintenance·CONF | [양호] 버전 정합 0 드리프트 · `marketplace.json:11-36` | 4개 plugin.json↔marketplace 버전 전부 일치, source 경로 실존, semver 유효. 경미: statusline/workflow에 homepage 없음(선택 필드, 영향 0) | 조치 불필요. 굳이 하면 homepage 형식 통일(우선순위 최하) |

### ⚡ 성능·비용 (4건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F5 | M workflow·CONF | log-session 매 Stop Notion 왕복 · `log-session.ps1:22` | Stop=매 응답 종료마다. 매번 databases/query로 SoT Key 중복조회(timeout 60s). 장세션 수십~수백 회 API. 의도('세션 종료 시')와 배선(Stop) 불일치, SessionEnd 슬롯 이미 존재 | scratch에 session_id flag 두고 기록됐으면 네트워크 스킵. timeout 60→10s. ('레이트리밋'은 부차, 주 근거는 매 턴 블로킹) |
| F7 | L improvement·CONF | auto-format 매 편집 npx 스폰 + staleness · `auto-format.ps1:9` | 9개 웹 확장자 편집마다 `npx prettier`(1~2s). 이 레포는 prettier 미설치라 헛스폰만(포맷 0). 타 레포선 저장 후 재기록→old_string 매칭 실패 가능 | 로컬 .bin/prettier 존재 확인 후 없으면 스폰 스킵. 근본은 편집마다→커밋 직전으로. 변경 시 재읽기 신호 |
| F6 | L workflow·CONF | sync-marketplace SessionEnd git fetch · `sync-marketplace.ps1:9` | 매 세션 종료 `git fetch`(timeout 30s). 오프라인/느린 원격이면 지연. `$PSScriptRoot ..\..\..`로 레포루트 가정 → 마켓 설치 구조선 비-git일 수 있음(fetch 무의미) | `.git` 가드 추가 + 하루 1회 쓰로틀(또는 ls-remote) + timeout 30→10s |
| F45 | L improvement·CONF | 전역 effortLevel=xhigh + opus[1m] 고정 · `settings.json:176` | 오타·1줄 편집도 기본 xhigh+opus. cost-guard는 opt-in(model-invoked). 자동 다운시프트 훅 없음(관측O 제어X). (단 독트린은 '지휘=max effort 유지, 절약은 서브에이전트 tier') | 기본값 낮추면 독트린 충돌 → UPS 훅으로 저난도 감지→다운시프트/위임 넛지. **정책 §5 결정** |

### 🌿 git 위생 (1건)

| # | 등급 | 제목 · 근거 | evidence(압축) | 권고 핵심 |
|---|---|---|---|---|
| F30 | M workflow·CONF | 머지·폐기된 stale 브랜치에 미커밋 변경 얹힘 · `handoff.md:1`(브랜치 handoff/2026-07-02-multimodel) | PR#13 MERGED(squash f6906bf). `git diff main HEAD`는 삭제만=HEAD 고유 0, main이 9커밋 앞. 브랜치 3커밋 내용은 squash로 main 반영. 그 위에 미커밋 `M statusline.ps1`(reasoning-effort 세그먼트+BOM 제거, PAT-001). 여기서 커밋하면 죽은 브랜치 연장 | stash→switch main&pull→신규 브랜치→pop→구 브랜치 `-D`+origin 삭제. WIP는 별도 PR(PAT-001 관할) |

---

## §3 수정 우선순위 로드맵 — 무충돌 병렬 웨이브

**같은 파일을 건드리는 발견은 한 묶음(직렬), 다른 파일은 병렬 가능.** 아래 그룹은 서로 파일이 겹치지 않아 동시에 손대도 충돌 0.

### Wave 0 — 선행(다른 모든 편집의 전제)
| 그룹 | 대상 | 관련 발견 | 의존성 |
|---|---|---|---|
| G0 git 상태 정리 | 작업 트리(브랜치) | **F30** | **최우선.** 현재 stale 브랜치 위에서 편집하면 죽은 브랜치를 연장. WIP stash → main 최신화 → 신규 브랜치에서 이후 웨이브 진행. 아래 모든 그룹의 선행조건 |

### Wave 1 — 훅 파일군(파일별 독립, 병렬 가능하나 F4가 4파일 교차)
| 그룹 | 대상 파일 | 관련 발견 | 의존성 |
|---|---|---|---|
| G1a | `hooks/protect-secrets.ps1` | F1 + F4(escape) | F4는 아래 4파일 공통 → escape 한 번에 |
| G1b | `hooks/pre-commit-check.ps1` | F2 자기검사 일부·F3·F4(escape) | — |
| G1c | `hooks/hooks.json` | F2(if 위치)·F43(guard-destructive 배선) | F43 범위는 §5 결정 후 |
| G1d | `hooks/critic-gate.ps1` | F4(escape)·F15(SHA 바인딩) | F15는 flow와 연계(G3) |
| G1e | `hooks/context-hint.ps1` | F4(escape)·F8(escape 이식) | — |
| G1f | `hooks/log-session.ps1` | **F23**(env 이름)·F5(Stop 스킵)·F42(stub 개선)·F44(raw REST 예외) | **한 파일에 4건 집중 → 반드시 한 묶음.** F23이 최우선(no-op 해소) |
| G1g | `hooks/sync-marketplace.ps1` | F6 | — |
| G1h | `hooks/auto-format.ps1` | F7 | — |

### Wave 2 — 스킬·output-style(전부 독립 파일, 완전 병렬)
| 그룹 | 대상 파일 | 관련 발견 |
|---|---|---|
| G2a | `skills/cursor-docs/SKILL.md` | F13 |
| G2b | `workflow/skills/new-repo/SKILL.md` | F14 |
| G2c | `skills/ship-it/SKILL.md` | F15(문서면)·F18 |
| G2d | `skills/cross-check/SKILL.md` | F16 |
| G2e | `workflow/.claude-plugin/plugin.json` | F17 |
| G2f | `output-styles/yohan-voice.md` | F39·F40(F40 §5 결정) |
| G2g | `plugins/yohan-core/loop.md` + `CLAUDE.md:74` | F38(삭제) |

### Wave 3 — flow 재설계(연계 묶음)
| 그룹 | 대상 파일 | 관련 발견 | 의존성 |
|---|---|---|---|
| G3 | `commands/flow.md` + `plugins/yohan-core/CLAUDE.md:41` (+ critic-gate G1d, shipper.md) | F36·F37·F21·F15 | **워크플로 근본 재설계 → §5 결정 선행.** critic-gate SHA 바인딩(F15)과 gate-pass 타이밍이 함께 움직임 |

### Wave 4 — 문서 미러(파일별 독립, 단 공유 파일 주의)
| 그룹 | 대상 파일 | 관련 발견 | 의존성 |
|---|---|---|---|
| G4a | `docs/ARCHITECTURE.md` | F19·F20·F33 | 세 발견이 같은 파일 → 한 묶음. **main 기준**으로 갱신(브랜치 혼동 주의) |
| G4b | `docs/PRD.md` | F19·F20·F33 | 동상. G4a와 동시 가능(다른 파일) |
| G4c | `README.md` | F32 | 독립 |
| G4d | `docs/state/next-task.md` | F31 | append-only |
| G4e | `docs/log/2026-07-02-handoff.md` | F22·F35 | 같은 파일 → 한 묶음. append-only |
| G4f | `docs/patterns/PAT-005-*.md`(신설) | F35 | G4e의 `[[PAT-005]]` 링크와 짝 |

### Wave 5 — MCP·라이브 설정(외부 레포/글로벌, 파일별 독립)
| 그룹 | 대상 파일 | 관련 발견 | 의존성 |
|---|---|---|---|
| G5a | `plugins/yohan-core/.mcp.json` | F25 | venv 부트스트랩 문서화 동반 |
| G5b | `yohan-mcp/adapters/notion_adapter.py` + `.env.example` | F24·F44 | **F23·F24가 env 이름 SoT를 공유 → G1f와 이름 통일 조율 필수** |
| G5c | `~/.claude.json` | F26(notion-mcp 제거)·F29(caveman-shrink 제거)·F28(auth 스모크) | 독립 |
| G5d | `~/.claude/settings.json` | F11·F46·F45·F27·F10(enable) | F11 분리전략 §5 결정. F46/F45는 즉시 가능 |
| G5e | `automation/boot-auto-pull-setup/Sync-ClaudeSettings.ps1` + `Setup-Machine.ps1` | **F9·F41** | **F11(settings.local 분리)에 의존** — 분리 안 하고 sync만 고치면 반쪽 |
| G5f | `CLAUDE-CODE-SETUP-HANDOFF.md` | F34 | 독립(line 27만) |

**핵심 의존 체인:** F11(분리전략 결정) → F9·F41(sync merge 전환) 은 직렬. env 이름 통일(F23·F24·F44)은 훅·어댑터·머신 env·control-tower `sources.ts` 4곳을 **하나의 이름**(`NOTION_EXECUTION_LOG_DB_ID` 권장)으로 동시에 맞춰야 함 — 부분 수정 시 split-brain 잔존.

---

## §4 기각 4건 (오탐 사유)

| 원제 | 기각 사유(압축) |
|---|---|
| critic-gate `.gate-pass`가 git 추적됨 → checkout으로 게이트 우회 | 전제가 거짓. `.gate-pass`는 **untracked**(`git ls-files`·`git log` 전부 빈 출력, `?? .claude/.gate-pass`). clone 시 mtime 리셋되는 tracked 파일 아님. 신규 clone엔 마커 없어 오히려 정상 차단(ask). git 추적상태 오독 |
| dotfiles가 명목상 SoT지만 역기록 없어 '무엇이 진실인가' 미해결 | 바이트 사실은 맞으나 논증 고리가 날조. "dotfiles=명목상 SoT"는 근거 없음(어떤 훅도 소비 안 함, 실제론 부트스트랩 시드). `Yohan-ClaudeSync` 태스크·`claude-sync.log`는 설계 어디에도 없는 **날조 아티팩트**. 권고(write-back 강제)는 시드를 미러로 오인 → 머신고유 permission·mojibake를 공유 시드에 역주입하는 해악 |
| server.py `load_dotenv()` 경로 미지정 → 외부 cwd 기동 시 미로딩 | 전제 반증. python-dotenv `find_dotenv(usecwd=False)`는 cwd 아닌 **호출 파일(server.py) 디렉터리** 기준 상위 탐색. 동일 시나리오 프로브 재현 결과 `.env` 정상 로드(load_dotenv=True, QDRANT_URL 등 PRESENT). '실측 MISSING'은 서버가 아닌 감사관 셸의 부모 env를 잰 측정 오류 |
| 플러그인 yohan(bare) vs 프로젝트-로컬 yohan-mcp(venv) 이중 등록 → 17툴 이중 기동 | 원자료는 참이나 결론이 라이브 설정으로 이미 차단. `yohan-mcp/.claude/settings.local.json:18-20`에 `"disabledMcpjsonServers":["yohan-mcp"]` → 프로젝트-로컬 서버 명시 비활성. 이중 노출 발생 안 함. 잔여는 그 disable이 gitignore된 파일에 있다는 별개의 미미한 이식성 문제뿐 |

---

## §5 결정 필요 항목 (자동수정 불가 — 사람 판단)

아래는 정답이 정책·의도에 달려 있어 그냥 고칠 수 없다. 방향을 정해야 실행 웨이브가 풀린다.

| # | 항목 | 관련 발견 | 결정해야 할 것 |
|---|---|---|---|
| D1 | **settings 분리 전략** | F11·F9·F41 | 공유 baseline과 머신/옵트인을 어떻게 가를지. sync를 키 단위 merge로 바꾸고 model·statusLine·MCP_TIMEOUT·hooks·allow-list를 settings.local.json으로 이관할지 — G5e(sync 수정)의 선행 |
| D2 | **/flow 재설계** | F36·F37·F15·F21 | 구현 단계를 설계-검증 사이에 넣고 critic이 diff를 검증하게 할지, 승인 게이트를 어디(shipper 앞)에 둘지, flow.md를 풀개발 단일 SoT로 승격할지. 워크플로 근본 변경이라 승인 필요 |
| D3 | **PAT-003 파괴작업 게이트 범위** | F43 | `guard-destructive` 훅이 어디까지 막을지 — force-push(–force-with-lease 예외)·reset --hard·clean -fd·publish·release. 자율 루프서 `ask`가 사람 개입을 유발하므로 무인 자동화와의 트레이드오프 판단 |
| D4 | **yohan-voice force-for-plugin** | F40 | 전 레포 output-style lock-in을 의도로 유지할지(→README 명문화), 아니면 필드 제거하고 두괄식·반말을 CLAUDE.md/yohan-writing으로 커버할지 |
| D5 | **effortLevel 정책** | F45 | 전역 xhigh+opus 기본을 유지할지. 독트린('지휘=max, 절약=서브에이전트 tier')과 충돌하므로 기본값을 낮추는 대신 저난도 감지→다운시프트/위임 넛지 훅을 넣을지 |
| D6 | **critical-thinking 활성화 여부** | F10·F8 | 실제로 쓸지 결정. 쓸 거면 라이브+dotfiles 둘 다 enable(+ escape 이식), 안 쓸 거면 marketplace 게시 상태 정리(유령 게시물 제거) |
| D7 | **Notion 정본 창구** | F26·F44 | claude_ai_Notion 커넥터·notion-mcp·yohan-mcp·log-session raw REST 중 무엇을 SoT로 고정할지. notion-mcp 제거는 안전(소비처 0)하나, 4계통 역할 분담은 문서 결정 필요 |
| D8 | **MCP_TIMEOUT 정책** | F27 | 전역 30000 유지 + serena/npx 예열로 갈지, 값을 올려 실패 감지 지연을 감수할지 |

---

*박제 완료. 원본: `tasks/w5g53mkgg.output`(1774줄, result.findings 46 + 기각 4). per-agent 원본: `subagents/workflows/wf_c473ebf0-fb4/journal.jsonl`.*
