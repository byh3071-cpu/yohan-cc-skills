#requires -Version 5.1
# protect-secrets.ps1 — PreToolUse 가드: 민감 파일 접근/유출 차단
$ErrorActionPreference = 'Stop'
try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}

# stdin은 반드시 리다이렉트됐을 때만 읽는다(비대화형 hang 방지).
$raw = ''
if ([Console]::IsInputRedirected) {
  try { $raw = [Console]::In.ReadToEnd() } catch { $raw = '' }
}
if (-not $raw) { exit 0 }
try {
  $evt = $raw | ConvertFrom-Json
} catch {
  # 파싱 실패는 stderr 경고만 남기고 fail-open(작업 자체는 차단하지 않음 — 정상 미매칭과 구분).
  [Console]::Error.WriteLine("[protect-secrets] stdin JSON 파싱 실패 — 가드 미적용(fail-open): $($_.Exception.Message)")
  exit 0
}

$tool = $evt.tool_name
$ti = $evt.tool_input
# 단어경계(\b) 기반: `.env` 뒤에 파이프/리다이렉트/따옴표/공백이 붙어도 매칭(.envrc 는 word-char 로 제외).
# 안전 템플릿(.env.example/.sample/.template/.dist)은 negative-lookahead 로 오탐 제외(.env.local·.env.production 등 실비밀은 계속 차단).
# credentials 계열(git-credentials·aws/credentials·npmrc·경로한정 credentials) 추가. `-credentials`(예: test-credentials-service) 오탐 방지 위해 앞경계는 [\/.] 만.
$deny = @(
  '\.env(?!\.(example|sample|template|dist))\b',
  '/secrets/',
  '\\secrets\\',
  '\.pem$',
  '\.key$',
  'id_rsa',
  '\.pfx$',
  '\.p12$',
  'notion\.token',
  '\.secrets[/\\]',
  '\.git-credentials\b',
  '\.aws[/\\]credentials\b',
  '\.npmrc\b',
  '[\\/.]credentials\b'
)

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
    # PAT-002: 비-ASCII 를 \uXXXX 로 강제(PS5.1 이 non-ASCII 리터럴을 그대로 방출 → Git Bash 캡처 시 모지바케 방지).
    $out = [regex]::Replace($out, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]($m.Value[0]) })
    Write-Output $out
    exit 0
  }
}
exit 0
