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
# PAT-002: 비-ASCII 를 \uXXXX 로 강제(모지바케·JSON 파싱실패 방지).
$out = [regex]::Replace($out, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]($m.Value[0]) })
Write-Output $out
exit 0
