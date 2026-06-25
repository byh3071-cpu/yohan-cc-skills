#requires -Version 5.1
# auto-format.ps1 — PostToolUse(Write|Edit) 훅: 저장된 파일 자동 포맷(있을 때만)
$ErrorActionPreference = 'Continue'
try { $evt = ([Console]::In.ReadToEnd() | ConvertFrom-Json) } catch { exit 0 }
$f = $evt.tool_input.file_path
if (-not $f -or -not (Test-Path $f)) { exit 0 }
$ext = [IO.Path]::GetExtension($f).ToLower()
if ($ext -in @('.ts','.tsx','.js','.jsx','.json','.md','.css','.scss','.html')) {
  if (Get-Command npx -ErrorAction SilentlyContinue) { npx --no-install prettier --write "$f" 2>$null | Out-Null }
} elseif ($ext -eq '.py') {
  if (Get-Command ruff -ErrorAction SilentlyContinue) { ruff format "$f" 2>$null | Out-Null }
} elseif ($ext -eq '.rs') {
  if (Get-Command rustfmt -ErrorAction SilentlyContinue) { rustfmt "$f" 2>$null | Out-Null }
}
exit 0
