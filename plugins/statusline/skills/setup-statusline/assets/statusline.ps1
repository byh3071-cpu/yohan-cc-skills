$ErrorActionPreference = 'SilentlyContinue'

# --- Read status data from stdin (robust: open the redirected handle directly) ---
$raw = ''
try {
    $stdin  = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stdin, [System.Text.Encoding]::UTF8)
    $raw    = $reader.ReadToEnd()
    $reader.Close()
} catch { }
if (-not $raw) { try { $raw = [Console]::In.ReadToEnd() } catch { } }
$data = if ($raw) { $raw | ConvertFrom-Json } else { $null }

$model = $data.model.display_name
$style = $data.output_style.name
$cwd   = $data.workspace.current_dir
$tpath = $data.transcript_path
$over200k = [bool]$data.exceeds_200k_tokens

# --- Current directory (collapse home to ~) ---
$userHome = $env:USERPROFILE
$dir = $cwd
if ($userHome -and $dir -and $dir.StartsWith($userHome)) {
    $dir = '~' + $dir.Substring($userHome.Length)
}
$dir = $dir -replace '\\', '/'

# --- Git branch ---
$branch = $null
if ($cwd -and (Test-Path -LiteralPath $cwd)) {
    Push-Location -LiteralPath $cwd
    $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
    Pop-Location
}

# --- Parse transcript via regex (robust on Windows PowerShell 5.1) ---
$ctxUsed     = 0
$totalTokens = 0
if ($tpath -and (Test-Path -LiteralPath $tpath)) {
    foreach ($line in [System.IO.File]::ReadLines($tpath)) {
        if ($line -notlike '*"usage"*') { continue }
        $it = if ($line -match '"input_tokens":(\d+)')                 { [int]$Matches[1] } else { 0 }
        $cr = if ($line -match '"cache_read_input_tokens":(\d+)')      { [int]$Matches[1] } else { 0 }
        $cc = if ($line -match '"cache_creation_input_tokens":(\d+)')  { [int]$Matches[1] } else { 0 }
        $ot = if ($line -match '"output_tokens":(\d+)')                { [int]$Matches[1] } else { 0 }
        $turn = $it + $cr + $cc + $ot
        if ($turn -gt 0) {
            # ctx = current context-window fill: last turn's full input (cache incl.) + output.
            $ctxUsed = $turn
            # tok = real work done: EXCLUDES cache_read. Summing the same cached context
            # re-read every turn inflates throughput ~12x; count fresh input + cache_creation + output only.
            $totalTokens += ($it + $cc + $ot)
        }
    }
}

# --- Context window: detect the 1M-context model variant from its name/id
#     (e.g. "Opus 4.8 (1M context)" / "claude-opus-4-8[1m]"); otherwise 200k,
#     still flipping to 1M if the flag or usage says we crossed 200k. ---
$modelId = "$($data.model.display_name) $($data.model.id)"
$is1M = ($modelId -match '(?i)1m\s*context') -or ($modelId -match '(?i)\[1m\]')
$ctxWindow = if ($is1M -or $over200k -or $ctxUsed -gt 200000) { 1000000 } else { 200000 }

function Fmt-K($n) {
    if ($n -ge 1000000)  { return ('{0:0.0}M' -f ($n / 1000000)) }
    elseif ($n -ge 1000) { return ('{0:0}k'   -f ($n / 1000)) }
    else                 { return "$n" }
}

$ctxLeft = $ctxWindow - $ctxUsed
if ($ctxLeft -lt 0) { $ctxLeft = 0 }
$pct = if ($ctxWindow -gt 0) { [math]::Round(($ctxUsed / $ctxWindow) * 100) } else { 0 }

# --- Assemble segments ---
$segments = @()
if ($model) { $segments += $model }
if ($style) { $segments += $style }
$loc = $dir
if ($branch) { $loc += " ($branch)" }
if ($loc) { $segments += $loc }
$segments += ("ctx {0}/{1} ({2} left, {3}%)" -f (Fmt-K $ctxUsed), (Fmt-K $ctxWindow), (Fmt-K $ctxLeft), $pct)
$segments += ((Fmt-K $totalTokens) + " tok")

# Build separator from its code point so this script stays pure ASCII on disk.
# PowerShell 5.1 parses a BOM-less .ps1 as the system ANSI codepage (CP949 here),
# which would corrupt a literal U+00B7. The CP949 byte write below still emits
# the middle dot correctly for the terminal.
$sep = ' ' + [char]0x00B7 + ' '
$out = $segments -join $sep

# --- Caveman tag prefix (merge): show [CAVEMAN] / [CAVEMAN:MODE] when the
#     caveman flag is active, mirroring hooks/caveman-statusline.ps1. ASCII +
#     ANSI only (no emoji) so it survives the CP949 byte write below. The
#     caveman *mode* itself runs via the SessionStart/UserPromptSubmit hooks
#     regardless of which status line is configured. ---
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$Flag = Join-Path $ClaudeDir ".caveman-active"
$cavemanTag = ''
if (Test-Path -LiteralPath $Flag) {
    try {
        $Item = Get-Item -LiteralPath $Flag -Force -ErrorAction Stop
        if (-not ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -and $Item.Length -le 64) {
            $Mode = ''
            $Rawm = Get-Content -LiteralPath $Flag -TotalCount 1 -ErrorAction Stop
            if ($null -ne $Rawm) { $Mode = ([string]$Rawm).Trim().ToLowerInvariant() }
            $Mode = ($Mode -replace '[^a-z0-9-]', '')
            $Valid = @('off','lite','full','ultra','wenyan-lite','wenyan','wenyan-full','wenyan-ultra','commit','review','compress')
            if ($Valid -contains $Mode) {
                $Esc = [char]27
                if ([string]::IsNullOrEmpty($Mode) -or $Mode -eq 'full') {
                    $cavemanTag = "${Esc}[38;5;172m[CAVEMAN]${Esc}[0m "
                } else {
                    $cavemanTag = "${Esc}[38;5;172m[CAVEMAN:$($Mode.ToUpperInvariant())]${Esc}[0m "
                }
            }
        }
    } catch { }
}
$out = $cavemanTag + $out

# --- Write UTF-8 bytes: Claude Code decodes the status line's stdout as UTF-8,
#     NOT the system ANSI codepage. Emitting CP949 bytes here makes U+00B7 show
#     up as U+FFFD replacement chars in the UI. GetBytes adds no BOM. ---
$bytes  = [System.Text.Encoding]::UTF8.GetBytes($out)
$stdout = [Console]::OpenStandardOutput()
$stdout.Write($bytes, 0, $bytes.Length)
$stdout.Flush()
