#requires -Version 5.1
# log-session.ps1 — Stop 훅: 세션 결과를 Notion EXECUTION LOG에 기록(SoT Key로 멱등)
$ErrorActionPreference = 'Continue'
$token = $env:NOTION_TOKEN
$db = $env:NOTION_EXECLOG_DB
if (-not $token -or -not $db) { exit 0 }

try { $evt = ([Console]::In.ReadToEnd() | ConvertFrom-Json) } catch { $evt = $null }
$sid = if ($evt -and $evt.session_id) { "$($evt.session_id)" } else { [guid]::NewGuid().ToString() }
$cwd = (Get-Location).Path
$sotKey = $sid

$headers = @{ 'Authorization' = "Bearer $token"; 'Notion-Version' = '2022-06-28'; 'Content-Type' = 'application/json; charset=utf-8' }

function Invoke-Notion($uri, $obj) {
  $json = ($obj | ConvertTo-Json -Depth 20)
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  return Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $bytes
}

try {
  $q = @{ filter = @{ property = 'SoT Key'; rich_text = @{ equals = $sotKey } }; page_size = 1 }
  $existing = Invoke-Notion "https://api.notion.com/v1/databases/$db/query" $q
  if ($existing.results.Count -gt 0) { exit 0 }
} catch { }

$title = "[CC] $(Split-Path $cwd -Leaf) — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$props = @{
  '이름'      = @{ title = @(@{ text = @{ content = $title } }) }
  '실행일'    = @{ date = @{ start = (Get-Date -Format 'yyyy-MM-dd') } }
  '결과'      = @{ select = @{ name = '성공' } }
  '작업 유형' = @{ select = @{ name = '프로토콜 실행' } }
  '작업 내용' = @{ rich_text = @(@{ text = @{ content = "Claude Code 세션 종료 (cwd: $cwd)" } }) }
  'SoT Key'   = @{ rich_text = @(@{ text = @{ content = $sotKey } }) }
}
$page = @{ parent = @{ database_id = $db }; properties = $props }
try { Invoke-Notion 'https://api.notion.com/v1/pages' $page | Out-Null } catch { }
exit 0
