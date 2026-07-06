#requires -Version 5.1
# pre-commit-check.ps1 — git commit 직전 정적 점검 (비밀/대용량/토큰)
$ErrorActionPreference = 'Continue'
try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}

# stdin 자기검사(critic-gate 방식): tool_input.command 이 git commit 이 아니면 즉시 통과.
# hooks.json 의 if 매처가 무시되는 스키마 드리프트 대비 — 매 Bash 마다 헛돌지 않게 스크립트가 직접 방어.
$cmd = ''
if ([Console]::IsInputRedirected) {
  try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $cmd = "$(($raw | ConvertFrom-Json).tool_input.command)" }
  } catch { $cmd = '' }
}
if ($cmd -notmatch '(?i)\bgit\b(\s+-\S+(\s+\S+)?)*\s+commit\b') { exit 0 }

$staged = (git diff --cached --name-only 2>$null)
if (-not $staged) { exit 0 }
$bad = @()
foreach ($f in $staged) {
  if ($f -match '\.env($|\.)|/secrets/|\.pem$|\.key$|id_rsa') { $bad += "비밀파일 의심: $f" }
  if (Test-Path $f) {
    if ((Get-Item $f).Length -gt 5MB) { $bad += "대용량(>5MB): $f" }
  }
}
# 토큰 패턴: Anthropic(sk-ant-/sk-proj-/sk-svcacct-)·AWS(AKIA)·Slack(xox)·Google(AIza) 추가.
$tokenPattern = 'ghp_[A-Za-z0-9]{30,}' +
  '|sk-ant-[A-Za-z0-9_\-]{20,}' +
  '|sk-proj-[A-Za-z0-9_\-]{20,}' +
  '|sk-svcacct-[A-Za-z0-9_\-]{20,}' +
  '|sk-[A-Za-z0-9]{20,}' +
  '|AKIA[0-9A-Z]{16}' +
  '|xox[baprs]-[A-Za-z0-9\-]{10,}' +
  '|AIza[0-9A-Za-z_\-]{35}' +
  '|secret_[A-Za-z0-9]{30,}' +
  '|ntn_[A-Za-z0-9]{30,}'
$leak = git diff --cached -U0 2>$null | Select-String -Pattern $tokenPattern
if ($leak) { $bad += "토큰 패턴 감지" }
if ($bad.Count -gt 0) {
  $reason = "pre-commit-check 차단:`n - " + ($bad -join "`n - ")
  $out = @{ hookSpecificOutput = @{ hookEventName='PreToolUse'; permissionDecision='deny'; permissionDecisionReason=$reason } } | ConvertTo-Json -Depth 5 -Compress
  # PAT-002: 비-ASCII 를 \uXXXX 로 강제(모지바케·JSON 파싱실패 방지).
  $out = [regex]::Replace($out, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]($m.Value[0]) })
  Write-Output $out
}
exit 0
