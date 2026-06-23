#requires -Version 5.1
# protect-secrets.ps1 — PreToolUse 가드: 민감 파일 접근/유출 차단
$ErrorActionPreference = 'Stop'
try {
  $raw = [Console]::In.ReadToEnd()
  if (-not $raw) { exit 0 }
  $evt = $raw | ConvertFrom-Json
} catch { exit 0 }

$tool = $evt.tool_name
$ti = $evt.tool_input
$deny = @('\.env($|\.)','/secrets/','\\secrets\\','\.pem$','\.key$','id_rsa','\.pfx$','\.p12$','notion\.token','\.secrets[/\\]')

$target = ''
switch ($tool) {
  'Read'  { $target = "$($ti.file_path)" }
  'Write' { $target = "$($ti.file_path)" }
  'Edit'  { $target = "$($ti.file_path)" }
  'Bash'  { $target = "$($ti.command)" }
  default { exit 0 }
}

foreach ($p in $deny) {
  if ($target -match $p) {
    $reason = "yohan-core 보안 가드: 민감 리소스 접근 차단 (패턴 $p). 의도된 작업이면 사용자가 직접 수행하세요."
    $out = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } | ConvertTo-Json -Depth 5 -Compress
    Write-Output $out
    exit 0
  }
}
exit 0
