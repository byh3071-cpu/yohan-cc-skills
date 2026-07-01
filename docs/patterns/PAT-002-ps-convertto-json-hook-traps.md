---
id: PAT-002
패턴명: PS5.1 ConvertTo-Json 훅 JSON 출력 2대 함정 (비-ASCII 미escape + Get-Content ETS 직렬화)
카테고리: env
증상: |
  PowerShell 5.1로 Claude Code 훅의 `hookSpecificOutput.additionalContext` JSON을 만들 때 두 가지로 깨짐.
  (A) 한글 렌즈가 모델에 U+FFFD(모지바케)로 주입됨. `-NoProfile` 훅이라 대화형 셸의 UTF-8 설정이 안 먹음.
  (B) additionalContext가 문자열이 아니라 `{"value":"...","Root":"D:\\",...,"ReadCount":1}` 같은 거대 객체가 되어 훅 stdout이 384KB로 폭증(PSDrive 덤프가 통째로 새어나감).
원인: |
  (A) 통념과 달리 PS5.1 `ConvertTo-Json`은 비-ASCII를 `\uXXXX`로 escape하지 **않고** 원문 유지(PS7과 다름). 게다가 `powershell -NoProfile -File`로 실행되는 훅은 `[Console]::OutputEncoding` 기본값(한국어 Windows=CP949)으로 stdout을 내보내 → UTF-8로 읽는 Claude Code가 깨뜨림. 콘솔 인코딩에 암묵 의존.
  (B) `Get-Content -Raw`가 돌려주는 값은 순수 [string]이 아니라 ETS NoteProperty(PSPath·PSDrive·PSProvider·ReadCount 등)가 붙은 PSObject. 이걸 해시테이블 값으로 바로 넣고 `ConvertTo-Json`하면 그 NoteProperty들까지 직렬화 → PSDrive("D:\") 전체 구조가 JSON에 딸려 들어감. 문자열 **연결**(`$a + $b`)은 ETS를 벗겨 우연히 멀쩡, **직접 대입**은 노출 — 그래서 한 훅은 되고 다른 훅은 터지는 함정.
해결: |
  - (A) 방출 직전 비-ASCII를 손수 `\uXXXX`로 escape해 stdout을 **순수 ASCII**로 만든다 → 어떤 다운스트림 인코딩에서도 동일(UTF-8 바이트 출력보다 강함, JSON escape는 인코딩 독립):
    `$out = [regex]::Replace($out, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]($m.Value[0]) })`
  - (B) Get-Content 결과를 값으로 쓰기 전 **plain string 강제**: `$s = "$(Get-Content -Raw -Encoding UTF8 $p)"` (또는 `[string]`/`-join ''`). 그래야 ETS가 벗겨져 문자열만 직렬화됨.
  - 검증은 **raw 바이트**로: 자식 프로세스 stdout을 latin1(28591)로 1:1 캡처하거나 `cmd /c "... > out.bin"`로 받아, ①전부 <128(ASCII) ②UTF-8 유효 ③크기 정상(수 KB) ④`ConvertFrom-Json` 왕복 후 한글 무손상. in-process 문자열 캡처는 stdout 바이트 인코딩·객체화 버그를 **못 잡는다**(리뷰어도 놓침, 바이트검증이 잡음).
적용조건: Windows PowerShell 5.1 + Claude Code 훅(SessionStart/UserPromptSubmit 등)에서 ConvertTo-Json으로 additionalContext JSON 방출. Get-Content|ConvertTo-Json 조합은 훅이 아니어도 (B) 재현.
출처프로젝트: yohan-cc-skills
태그: [powershell, encoding, convertto-json, get-content, ets, hook, json, windows, cp949]
발견일: 2026-07-01
출처DevLog: "[2026-07-01] critical-thinking 비판적 사고 모드 플러그인 + release-gate 검증"
---

# PAT-002 — PS5.1 ConvertTo-Json 훅 JSON 출력 2대 함정

## 핵심 한 줄
PS5.1 훅에서 JSON 낼 때: **(A) 비-ASCII는 손수 `\u` escape**(ConvertTo-Json이 안 해줌 + 콘솔 CP949 의존 제거), **(B) Get-Content 결과는 `"$(...)"`로 문자열 강제**(ETS NoteProperty가 PSDrive 덤프로 새는 것 차단). 검증은 raw 바이트로.

## 실사례 (critical-thinking 플러그인)
- activate 훅은 `$banner + $lens` **연결**이라 우연히 멀쩡(1.5KB). tracker 훅은 `additionalContext = $lens` **직접 대입**이라 384KB(D:\ 드라이브 구조 통째)로 폭증 → 렌즈 대신 쓰레기 주입 직전.
- 최초 기능테스트는 `($out|ConvertFrom-Json).additionalContext -match 'FULL'`로 통과했는데, 이건 객체도 문자열화해 매칭돼 **거짓 통과**였다. 바이트 크기를 재고서야 발각.
- 적대적 리뷰어 2명은 (A)를 "cp949로 깨진다"고 지적(이 머신 리다이렉트 시엔 미재현)했고 (B)는 **둘 다 놓침** → 자체 바이트검증이 실질 방어선.

## 교훈 (역전파)
- ConvertTo-Json은 버전마다 escape 정책이 다르다 — ASCII 안전성을 스스로 확보하라(수동 escape).
- PowerShell "문자열"은 ETS가 붙은 객체일 수 있다 — 직렬화 경계에선 plain string으로 강제.
- 검증 하니스를 산출물에 맞추면 거짓 통과([[PAT-001]]과 동일 교훈) — 실제 소비자(CC=UTF-8) 기준 **raw 바이트**로 확인.

## 비고
[[PAT-001]](소스 ASCII+출력 UTF-8 바이트, statusline)의 자매 — 그건 콘솔 텍스트 출력·소스 파싱, 이건 **ConvertTo-Json 직렬화** 특정. core `PAT-009`(ps-script-encoding) 계열. 노뚝이가 Notion 패턴 사전 등록.
