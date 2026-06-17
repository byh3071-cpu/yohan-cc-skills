---
id: PAT-001
패턴명: PowerShell 상태줄/스크립트 인코딩 (소스 ASCII + 출력 UTF-8)
카테고리: env
증상: Windows에서 Claude Code 상태줄·PS 스크립트의 가운뎃점 `·`(U+00B7) 등 비-ASCII가 `쨌`(파스 단계) 또는 `��`(출력 단계)로 깨짐
원인: |
  두 단계의 서로 다른 인코딩 불일치.
  (1) 파스: PowerShell 5.1은 BOM 없는 UTF-8 .ps1을 시스템 ANSI 코드페이지(한국어=CP949)로 파싱 → 소스에 직접 박은 비-ASCII 리터럴/주석이 실행 전에 깨짐(C2 B7 → CP949 2글자).
  (2) 출력: Claude Code는 상태줄 stdout을 UTF-8로 디코드하는데 스크립트가 [Text.Encoding]::Default(=CP949) 바이트로 출력 → `·`가 A1 A4로 나가 UI에서 U+FFFD(��)로 깨짐.
해결: |
  - 소스는 순수 ASCII로: 비-ASCII는 코드포인트로 생성(`$sep = ' ' + [char]0x00B7 + ' '`), 주석도 영어.
  - 출력은 UTF-8 바이트로: `[Text.Encoding]::UTF8.GetBytes($out)` (GetBytes는 BOM 안 붙임). Default(CP949) 금지.
  - 검증은 실제 소비자(UTF-8) 기준 raw 바이트로: `C2 B7` 존재 & `A1 A4`/`EF BF BD` 부재. 부모 셸 OutputEncoding을 맞춰 자기참조로 통과시키지 말 것(거짓 통과 위험).
  - 파일 ASCII 확인: `([IO.File]::ReadAllBytes(path) | ?{$_-gt127}).Count -eq 0`.
적용조건: Windows PowerShell 5.1 + Claude Code 상태줄/훅 스크립트 + 비-ASCII 출력. (PS7 또는 BOM 저장 시 파스 문제는 완화되나 출력 UTF-8 규칙은 동일 유지 권장)
출처프로젝트: yohan-cc-skills
태그: [powershell, encoding, utf-8, cp949, statusline, windows]
발견일: 2026-06-18
출처DevLog: "[2026-06-18] 작업 패턴 분석 + yohan-cc-skills 마켓플레이스 구축"
---

# PAT-001 — PowerShell 상태줄/스크립트 인코딩

## 핵심 한 줄
PS5.1 `.ps1`은 **소스 ASCII-only**(비-ASCII는 `[char]0xNNNN`), **출력은 UTF-8 바이트**, **검증은 실제 소비자(UTF-8) 인코딩 기준**.

## 왜 두 번 깨졌나 (실사례)
1차: statusline.ps1 작성 직후 `·`가 `쨌`. → 출력 인코딩 의심했으나 범인은 **소스 파싱**(BOM 없는 UTF-8 → CP949). 구분자를 `[char]0x00B7`로 바꿔 해결.
2차: 그 다음 `·`가 `��`. → 이번엔 진짜 **출력 인코딩**. `Encoding.Default`(CP949) → `UTF8`로 변경해 해결. 첫 검증이 "통과"였던 건 부모 PowerShell의 OutputEncoding을 CP949로 맞춰 자식 출력을 디코드한 **자기참조 루프**였고, 실제 소비자(Claude Code=UTF-8)와 인코딩이 달랐기 때문.

## 교훈 (역전파)
증상이 "출력 깨짐"처럼 보여도 원인이 파싱 단계일 수 있다 → 단계별로 분리해 검증. 그리고 검증은 반드시 **실제 소비자가 쓰는 인코딩**으로 — 테스트 하니스를 산출물에 맞춰버리면 거짓 통과한다.

## 비고
범용 코어 가치가 커 `yohan-brain` 코어로 승격 가능(현재는 yohan-cc-skills 로컬 PAT-001). Notion 패턴 사전 DB 등록은 노뚝이 담당.
