#requires -Version 5.1
# context-hint.ps1 — SessionStart 훅: 현재 레포 컨텍스트를 모델에 주입
$ErrorActionPreference = 'Continue'
try { $evt = ([Console]::In.ReadToEnd() | ConvertFrom-Json) } catch { $evt = $null }
$cwd = (Get-Location).Path
$repo = Split-Path $cwd -Leaf
$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
$lines = @()
$lines += "현재 레포: $repo (branch: $branch)"
if (Test-Path "$cwd/CLAUDE.md") { $lines += "프로젝트 CLAUDE.md 존재" }
if (Test-Path "$cwd/.claude/rules") { $lines += ".claude/rules 규칙 존재" }
$ctx = "[yohan-core] " + ($lines -join ' | ')

# 상시 지휘자(v0.4.0) 라우팅 카드 주입 — brain SoT의 카드 본문을 매 세션 컨텍스트에 부착.
# brain 미클론 머신 대비 하드코딩 3줄 폴백.
$brainRoot = $env:YOHAN_BRAIN_ROOT
if (-not $brainRoot) { $brainRoot = 'C:\Users\Public\dev\yohan-ecosystem\yohan-brain' }
$cardPath = Join-Path $brainRoot 'memory\core\templates\roster-routing-card.md'
if (Test-Path -LiteralPath $cardPath) {
  $card = Get-Content -LiteralPath $cardPath -Raw -Encoding UTF8
  $ctx = $ctx + "`n`n" + $card
} else {
  $ctx = $ctx + "`n`n[상시 지휘자] 모든 태스크: 크기 S/M/L 판정 → '라우팅: S|M|L — 계획' 선언 후 진행. S=지휘자 단독 · M=서브에이전트 티어링(haiku→sonnet→opus) · L=/goal orca 풀파이프라인. SoT: agent-roster.yaml conductor_always_on."
}

$out = @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $ctx } } | ConvertTo-Json -Depth 5 -Compress
# PAT-002: 비-ASCII 를 \uXXXX 로 강제(모지바케·JSON 파싱실패 방지).
$out = [regex]::Replace($out, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]($m.Value[0]) })
Write-Output $out

# routing miss 감지용 세션 시작 baseline sha 기록 (SessionEnd detect-routing-miss.ps1 이 대비 측정).
try {
  if ($evt -and $evt.session_id) {
    $cacheDir = Join-Path $env:USERPROFILE '.claude\.cache'
    if (-not (Test-Path -LiteralPath $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    $sha = (git -C "$cwd" rev-parse HEAD 2>$null)
    if ($sha) { Set-Content -LiteralPath (Join-Path $cacheDir "routing-$($evt.session_id).start") -Value "$sha".Trim() -Encoding ASCII }
  }
} catch {}
exit 0
