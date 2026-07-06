#requires -Version 5.1
# destructive-guard.ps1 — PreToolUse(Bash) 가드: 되돌릴 수 없는 파괴적 명령에 확인 프롬프트.
# PAT-003 집행(commit/push 외 사각지대 보완). hard-deny 아니라 permissionDecision=ask 로 사용자 확인만 강제.
$ErrorActionPreference = 'Continue'
try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
if (-not [Console]::IsInputRedirected) { exit 0 }
$raw = ''
try { $raw = [Console]::In.ReadToEnd() } catch { $raw = '' }
if (-not $raw) { exit 0 }
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }
if ($evt.tool_name -ne 'Bash') { exit 0 }
$cmd = "$($evt.tool_input.command)"
if (-not $cmd) { exit 0 }

# 되돌릴 수 없는 작업 패턴(정규식은 대소문자 무시·부분매칭). 발견 시 ask.
$patterns = @(
  @{ rx = 'git\s+push\b[^\n]*(--force|(\s|=)-f(\s|$))'; label = 'git force-push (원격 이력 덮어씀)' },
  @{ rx = 'git\s+push\b[^\n]*--delete';                 label = 'git push --delete (원격 브랜치/태그 삭제)' },
  @{ rx = 'git\s+reset\s+--hard';                       label = 'git reset --hard (미커밋 변경 소멸)' },
  @{ rx = 'git\s+clean\s+-[a-zA-Z]*f';                  label = 'git clean -f (untracked 파일 삭제)' },
  @{ rx = 'git\s+branch\s+-D\b';                        label = 'git branch -D (미머지 브랜치 강제삭제)' },
  @{ rx = 'git\s+tag\s+-d\b';                           label = 'git tag -d (태그 삭제)' },
  @{ rx = '\b(npm|pnpm|yarn)\s+publish\b';              label = '패키지 publish (되돌리기 어려운 배포)' }
)
foreach ($p in $patterns) {
  if ($cmd -match $p.rx) {
    $reason = "되돌릴 수 없는 작업 감지: $($p.label). PAT-003 안전장치 — 정말 실행할지 확인하세요."
    $out = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'ask'; permissionDecisionReason = $reason } } | ConvertTo-Json -Depth 5 -Compress
    # PAT-002: 비-ASCII 를 \uXXXX 로 강제(PS5.1 CP949 방출 모지바케 방지).
    $out = [regex]::Replace($out, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]($m.Value[0]) })
    Write-Output $out
    exit 0
  }
}
exit 0
