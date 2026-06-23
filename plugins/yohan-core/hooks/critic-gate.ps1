#requires -Version 5.1
# critic-gate.ps1 — git push 직전 게이트: critic 통과 마커 확인
$ErrorActionPreference = 'Continue'
$gate = Join-Path (Get-Location).Path '.claude/.gate-pass'
$ok = $false
if (Test-Path $gate) {
  $age = (Get-Date) - (Get-Item $gate).LastWriteTime
  if ($age.TotalHours -lt 6) { $ok = $true }
}
if (-not $ok) {
  $reason = "critic-gate: 릴리즈 게이트 미통과. '/flow' 또는 '/release-gate'로 적대적 리뷰를 통과한 뒤 push 하세요. (통과 시 .claude/.gate-pass 갱신)"
  $out = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'ask'; permissionDecisionReason = $reason } } | ConvertTo-Json -Depth 5 -Compress
  Write-Output $out
}
exit 0
