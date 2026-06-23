#requires -Version 5.1
# context-hint.ps1 — SessionStart 훅: 현재 레포 컨텍스트를 모델에 주입
$ErrorActionPreference = 'Continue'
$cwd = (Get-Location).Path
$repo = Split-Path $cwd -Leaf
$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
$lines = @()
$lines += "현재 레포: $repo (branch: $branch)"
if (Test-Path "$cwd/CLAUDE.md") { $lines += "프로젝트 CLAUDE.md 존재" }
if (Test-Path "$cwd/.claude/rules") { $lines += ".claude/rules 규칙 존재" }
$ctx = "[yohan-core] " + ($lines -join ' | ')
$out = @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $ctx } } | ConvertTo-Json -Depth 5 -Compress
Write-Output $out
exit 0
