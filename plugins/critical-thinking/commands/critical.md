---
name: critical
description: 비판적 사고 모드 토글. /critical lite|full|ultra|auto|off (인자 없으면 full).
argument-hint: "[lite|full|ultra|auto|off]"
---

# /critical — 비판적 사고 모드 토글

요청 레벨: **$ARGUMENTS** (비어 있으면 `full`)

## 할 일
1. 레벨을 검증한다: `lite|full|ultra|auto|off` 중 하나만 허용. 인자가 없거나 목록에 없으면 `full`로 간주.
2. 아래 PowerShell 블록을 **PowerShell에서 직접** 실행해 상태 파일에 레벨을 기록한다 (설치 경로 무관, 유저 전역 상태). `powershell -Command "..."` 로 다시 감싸지 마라 — 바깥 셸이 `$p`를 먼저 비워 깨진다. 툴이 PS면 아래 줄을 그대로 실행:
   ```powershell
   $p = Join-Path $env:USERPROFILE '.claude\critical-thinking-state.json'
   $d = Split-Path $p -Parent
   if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
   @{ level = '<레벨>' } | ConvertTo-Json -Compress | Set-Content -Encoding UTF8 $p
   ```
   `<레벨>`을 1번에서 정한 값으로 치환해 실행.
3. 기록 후 현재 레벨과 의미를 **한 줄**로 알린다(두괄식 반말).
4. 다음 세션/턴부터 훅이 렌즈를 주입한다. **이번 응답부터도** 해당 레벨의 사고 규칙을 즉시 적용해라.

## 레벨 의미
- **off**: 해제(기본). 훅 렌즈 주입 없음.
- **lite**: 반사동의·아첨 금지 + 미검증 주장 [추론] 태깅.
- **full**: lite + 소크라테스 프로빙 + steelman-then-attack + 확신도 표기.
- **ultra**: full + CoVe 자가검증 + 고위험 주장/결정 시 `skeptic` 서브에이전트 소환.
- **auto**: 평소 조용, 아첨유도·결정어 감지된 턴만 자동으로 full 렌즈 발동.

## 해제
`/critical off`, 또는 프롬프트에 "stop critical" / "critical off" 포함 시 자동 off(트래커 훅이 단어 단위로 감지 — "offset"·"officer" 같은 부분매치는 무시). 한국어로 끄려면 `/critical off`.
