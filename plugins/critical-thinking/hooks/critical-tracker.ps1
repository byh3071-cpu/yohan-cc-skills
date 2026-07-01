#requires -Version 5.1
# critical-tracker.ps1 - UserPromptSubmit hook: re-inject lens each turn; auto-mode keyword detection; ASCII stop-phrase deactivation.
# ASCII source only. Korean lens/trigger text comes from UTF-8 files. stdin read as UTF-8.
$ErrorActionPreference = 'Continue'
try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}

$statePath = Join-Path $env:USERPROFILE '.claude\critical-thinking-state.json'

function Get-Level {
  $lvl = 'off'
  if (Test-Path $statePath) {
    try {
      $s = Get-Content -Raw -Encoding UTF8 $statePath | ConvertFrom-Json
      if ($s.level) { $lvl = [string]$s.level }
    } catch {}
  }
  return $lvl.ToLower().Trim()
}

# read prompt from stdin JSON (guard against hang when stdin is not redirected)
$raw = ''
if ([Console]::IsInputRedirected) { try { $raw = [Console]::In.ReadToEnd() } catch {} }
$prompt = ''
if ($raw) {
  try { $j = $raw | ConvertFrom-Json; $prompt = [string]$j.prompt } catch { $prompt = '' }
}

$level = Get-Level
if ($level -eq 'off') { exit 0 }

# ASCII stop-phrase deactivation. Word-anchored to avoid substrings ("offset"/"officer"). Korean off via /critical off.
if ($prompt -imatch '\bstop critical\b|\bcritical off\b') {
  try { @{ level = 'off' } | ConvertTo-Json -Compress | Set-Content -Encoding UTF8 $statePath } catch {}
  exit 0
}

$lensFile = $null
switch ($level) {
  'lite'  { $lensFile = 'lens-lite.txt' }
  'full'  { $lensFile = 'lens-full.txt' }
  'ultra' { $lensFile = 'lens-ultra.txt' }
  'auto'  {
    $triggersPath = Join-Path $PSScriptRoot 'auto-triggers.txt'
    $fired = $false
    if (Test-Path $triggersPath) {
      try {
        $pat = ((Get-Content -Encoding UTF8 $triggersPath | Where-Object { $_ -and -not $_.TrimStart().StartsWith('#') }) -join '|')
        if ($pat -and ($prompt -match $pat)) { $fired = $true }
      } catch {}
    }
    if ($fired) { $lensFile = 'lens-full.txt' } else { $lensFile = 'lens-auto-idle.txt' }
  }
}
if (-not $lensFile) { exit 0 }
$lensPath = Join-Path $PSScriptRoot $lensFile
if (-not (Test-Path $lensPath)) { exit 0 }
# "$(...)" forces a plain string, stripping Get-Content's ETS NoteProperties (PSDrive/PSProvider) that would otherwise serialize into additionalContext.
$lens = "$(Get-Content -Raw -Encoding UTF8 $lensPath)"

$out = @{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $lens } } | ConvertTo-Json -Depth 5 -Compress
# force pure-ASCII \uXXXX so stdout is encoding-independent (PS 5.1 keeps non-ASCII literal).
$out = [regex]::Replace($out, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]($m.Value[0]) })
Write-Output $out
exit 0
