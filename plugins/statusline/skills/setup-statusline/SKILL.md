---
name: setup-statusline
description: Use when setting up or repairing 백요한's Windows PowerShell Claude Code status line on a machine (desktop, laptop, new PC). Deploys the bundled statusline.ps1 to ~/.claude and merges settings.json (statusLine command + model). Windows + Windows PowerShell 5.1 only.
---

# setup-statusline

백요한의 Claude Code 상태줄을 현재 머신에 배포한다. 출력 예:

```
[CAVEMAN] Opus 4.8 (1M context) · default · ~/dir (branch) · ctx 156k/1.0M (844k left, 16%) · 645k tok
```

세그먼트: 모델 · output style · 현재 디렉터리(+git branch) · 컨텍스트 사용량/창크기(1M 자동감지)/잔여/% · 누적 토큰. caveman 플러그인 설치 시 앞에 `[CAVEMAN]` 태그(없으면 자동 생략).

## 적용 대상
- **Windows + Windows PowerShell 5.1 전용** (스크립트가 PS임). macOS/Linux면 적용하지 말고 그 사실을 알릴 것.

## 절차 (todo로 만들어 하나씩)

1. **번들 스크립트 복사.** `${CLAUDE_PLUGIN_ROOT}/skills/setup-statusline/assets/statusline.ps1` 를 `~/.claude/statusline.ps1` 로 복사.
   ```powershell
   Copy-Item "$env:CLAUDE_PLUGIN_ROOT\skills\setup-statusline\assets\statusline.ps1" "$env:USERPROFILE\.claude\statusline.ps1" -Force
   ```
   `$env:CLAUDE_PLUGIN_ROOT` 가 비면 이 SKILL.md 의 실제 경로 기준 상대로 찾을 것.

2. **settings.json 백업 후 병합 (덮어쓰기 금지).** `~/.claude/settings.json` 을 읽어 아래 키만 추가/수정하고 나머지(permissions·hooks·plugins·effortLevel·ultracode·language 등)는 그대로 보존:
   - `statusLine` = `{ "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<절대경로>\\statusline.ps1\"" }` (경로는 그 머신의 실제 `$env:USERPROFILE\.claude\statusline.ps1`)
   - `model` = `"opus"` (이미 있으면 건드리지 말 것)
   백업: `Copy-Item settings.json settings.json.bak-statusline-<timestamp>`.
   - 그 머신이 이미 caveman 상태줄(`hooks\caveman-statusline.ps1`)을 쓰면 교체 전 사용자에게 확인. 이 스크립트는 caveman 태그를 자체 머지하므로 교체해도 `[CAVEMAN]` 유지됨.

3. **검증 (실제 소비자 = UTF-8 기준).** raw 바이트로 확인 — `·`(U+00B7)가 UTF-8 `C2 B7` 로 나가고 CP949 `A1 A4` / U+FFFD `EF BF BD` 가 없어야 함. settings.json 은 `ConvertFrom-Json` 통과해야 함.
   ```powershell
   $j = @{ model=@{display_name="Opus 4.8 (1M context)";id="claude-opus-4-8[1m]"}; output_style=@{name="default"}; workspace=@{current_dir=$env:USERPROFILE}; transcript_path="" } | ConvertTo-Json -Compress
   $psi=New-Object Diagnostics.ProcessStartInfo; $psi.FileName="powershell"; $psi.Arguments="-NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\.claude\statusline.ps1`""; $psi.RedirectStandardInput=$true; $psi.RedirectStandardOutput=$true; $psi.UseShellExecute=$false
   $p=[Diagnostics.Process]::Start($psi); $p.StandardInput.Write($j); $p.StandardInput.Close(); $ms=New-Object IO.MemoryStream; $p.StandardOutput.BaseStream.CopyTo($ms); $p.WaitForExit()
   $hex=($ms.ToArray()|%{$_.ToString('X2')}) -join ' '; "C2B7=$([bool]($hex-match'C2 B7')) A1A4=$([bool]($hex-match'A1 A4')) FFFD=$([bool]($hex-match'EF BF BD'))"
   ```
   기대: `C2B7=True A1A4=False FFFD=False`.

4. **안내.** 상태줄이 안 바뀌면 Claude Code/VSCode 재시작 1회. 스크립트 *내용* 수정은 재시작 불필요(매 렌더 재실행), settings.json 의 statusLine *경로* 변경은 설정 리로드 필요.

## 불변식 (스크립트 수정 시 깨면 안 됨)
- **소스는 순수 ASCII.** PS 5.1 은 BOM 없는 UTF-8 `.ps1` 을 시스템 ANSI 코드페이지(한국어=CP949)로 파싱 → 소스의 비-ASCII 리터럴/주석이 파스 시점에 깨짐. 비-ASCII 문자는 `[char]0x00B7` 식 코드포인트로 생성.
- **출력은 UTF-8 바이트.** Claude Code 는 상태줄 stdout 을 UTF-8 로 디코드. `[Text.Encoding]::UTF8.GetBytes($out)` 사용 (`::Default`(=CP949) 쓰면 `·` 가 `��` 로 깨짐). GetBytes 는 BOM 안 붙임.
- **ctx** = 마지막 턴 input(캐시 포함)+output = 현재 컨텍스트 점유. **tok** = `input + cache_creation + output` 누적 (cache_read 제외 — 포함하면 같은 캐시 반복합산으로 처리량 ~12배 부풀려짐).
- **컨텍스트 창** = 모델명/ID 에 `1M context` 또는 `[1m]` 있으면 1,000,000, 아니면 200,000 (사용량이 200k 넘으면 자동 전환).
- 검증은 항상 **실제 소비자 인코딩(UTF-8) 기준** — 부모 셸 OutputEncoding 을 맞춰 자기참조로 통과시키지 말 것.
