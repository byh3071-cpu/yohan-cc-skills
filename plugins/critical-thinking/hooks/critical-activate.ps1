#requires -Version 5.1
# critical-activate.ps1 - SessionStart hook: inject critical-thinking lens if mode active.
# ASCII source only. Korean lens text is read from UTF-8 files; ConvertTo-Json escapes it to \uXXXX so stdout stays ASCII-safe.
$ErrorActionPreference = 'Continue'

$statePath = Join-Path $env:USERPROFILE '.claude\critical-thinking-state.json'
$level = 'off'
if (Test-Path $statePath) {
  try {
    $state = Get-Content -Raw -Encoding UTF8 $statePath | ConvertFrom-Json
    if ($state.level) { $level = [string]$state.level }
  } catch { $level = 'off' }
}
$level = $level.ToLower().Trim()

if ($level -eq 'off') { exit 0 }

$lensMap = @{ 'lite' = 'lens-lite.txt'; 'full' = 'lens-full.txt'; 'ultra' = 'lens-ultra.txt'; 'auto' = 'lens-auto-idle.txt' }
$file = $lensMap[$level]
if (-not $file) { exit 0 }
$lensPath = Join-Path $PSScriptRoot $file
if (-not (Test-Path $lensPath)) { exit 0 }
# "$(...)" forces a plain string, stripping Get-Content's ETS NoteProperties (PSDrive/PSProvider).
$lens = "$(Get-Content -Raw -Encoding UTF8 $lensPath)"

$banner = "CRITICAL THINKING MODE ACTIVE - level: $level"
$ctx = $banner + "`n" + $lens
$out = @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $ctx } } | ConvertTo-Json -Depth 5 -Compress
# PS 5.1 ConvertTo-Json keeps non-ASCII literal; force pure-ASCII \uXXXX so stdout is encoding-independent.
$out = [regex]::Replace($out, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]($m.Value[0]) })
Write-Output $out
exit 0
