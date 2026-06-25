#requires -Version 5.1
# pre-commit-check.ps1 — git commit 직전 정적 점검 (비밀/대용량/토큰)
$ErrorActionPreference = 'Continue'
$staged = (git diff --cached --name-only 2>$null)
if (-not $staged) { exit 0 }
$bad = @()
foreach ($f in $staged) {
  if ($f -match '\.env($|\.)|/secrets/|\.pem$|\.key$|id_rsa') { $bad += "비밀파일 의심: $f" }
  if (Test-Path $f) {
    if ((Get-Item $f).Length -gt 5MB) { $bad += "대용량(>5MB): $f" }
  }
}
$leak = git diff --cached -U0 2>$null | Select-String -Pattern 'ghp_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9]{20,}|secret_[A-Za-z0-9]{30,}|ntn_[A-Za-z0-9]{30,}'
if ($leak) { $bad += "토큰 패턴 감지" }
if ($bad.Count -gt 0) {
  $reason = "pre-commit-check 차단:`n - " + ($bad -join "`n - ")
  $out = @{ hookSpecificOutput = @{ hookEventName='PreToolUse'; permissionDecision='deny'; permissionDecisionReason=$reason } } | ConvertTo-Json -Depth 5 -Compress
  Write-Output $out
}
exit 0
