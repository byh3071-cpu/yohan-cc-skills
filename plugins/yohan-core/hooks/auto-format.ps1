#requires -Version 5.1
# auto-format.ps1 — PostToolUse(Write|Edit) 훅: 저장된 파일 자동 포맷(있을 때만)
$ErrorActionPreference = 'Continue'
try { $evt = ([Console]::In.ReadToEnd() | ConvertFrom-Json) } catch { exit 0 }
$f = $evt.tool_input.file_path
if (-not $f -or -not (Test-Path $f)) { exit 0 }
$ext = [IO.Path]::GetExtension($f).ToLower()
if ($ext -in @('.ts','.tsx','.js','.jsx','.json','.md','.css','.scss','.html')) {
  # 로컬 prettier 해석 가능여부를 값싸게 확인(파일 디렉터리부터 상위로 node_modules/.bin 탐색).
  # 없으면 npx 스폰(1~2s 헛스폰) 자체를 스킵 — prettier 미설치 레포에서 포맷 0인데 매 편집마다 spawn 하던 낭비 제거.
  $hasPrettier = $false
  $dir = Split-Path -Parent $f
  while ($dir) {
    if ((Test-Path (Join-Path $dir 'node_modules\.bin\prettier.cmd')) -or (Test-Path (Join-Path $dir 'node_modules\.bin\prettier'))) { $hasPrettier = $true; break }
    $parent = Split-Path -Parent $dir
    if (-not $parent -or $parent -eq $dir) { break }
    $dir = $parent
  }
  if ($hasPrettier -and (Get-Command npx -ErrorAction SilentlyContinue)) { npx --no-install prettier --write "$f" 2>$null | Out-Null }
} elseif ($ext -eq '.py') {
  if (Get-Command ruff -ErrorAction SilentlyContinue) { ruff format "$f" 2>$null | Out-Null }
} elseif ($ext -eq '.rs') {
  if (Get-Command rustfmt -ErrorAction SilentlyContinue) { rustfmt "$f" 2>$null | Out-Null }
}
exit 0
