#requires -Version 5.1
<#
.SYNOPSIS
  plan-audit 원문 추출기 — 현재 세션 트랜스크립트에서 "사람이 직접 친 발화"만 뽑는다.

.DESCRIPTION
  역추출 대조(blind extraction)의 기준선을 만든다.
  지휘자가 요약해서 넘기면 그 순간 정보가 손실되므로, 기계적으로 뽑아야 한다.

  수집 대상 3종 — 산출 파일이 둘로 갈린다:

  [requests-<sid>.txt]  블라인드 기준선. critic 에게 주는 것.
    (1) 직접 입력  — type=user AND isSidechain!=true AND promptSource='typed'
    (2) 반려 지시  — 사용자가 도구/계획을 반려하며 남긴 말.
                     tool_result 로 들어와 promptSource 가 null 이라 (1)로는 안 잡힌다.
                     plan-audit 의 핵심 입력이므로 반드시 함께 수집한다.

  [decisions-<sid>.txt] 지휘자 전용. ★ critic 에게 절대 주지 마라.
    (3) 선택지 응답 — AskUserQuestion 으로 사용자가 고른 답.
                     (1)(2) 어느 쪽에도 안 걸린다: promptSource 키가 없고 반려 마커도 없다.
                     이걸 안 뽑으면 원문엔 'ㅇㅇ'·'A' 같은 수락 신호만 남아,
                     감사가 "근거 없음"으로 오판한다(실측: 0.3.14 F4 거짓 고발).
                     ★ 선택 라벨에는 어시스턴트 제안의 요지가 들어 있다.
                       requests 에 섞으면 critic 이 앵커링돼 블라인드가 깨진다 — 그래서 파일을 가른다.

  제외: 그 외 tool_result · image 블록(base64) · 스킬/훅 주입 · 슬래시커맨드 입력

  ★ 이 파일은 한글 리터럴을 담으므로 반드시 UTF-8 BOM 으로 저장할 것.
    (PS5.1 은 BOM 없는 UTF-8 .ps1 을 CP949 로 파싱해 한글이 깨진다 — PAT-001 원인(1))
#>
[CmdletBinding()]
param(
  # 트랜스크립트 jsonl 경로. 생략하면 현재 디렉터리 슬러그에서 최신 파일 자동 선택.
  [string]$TranscriptPath,
  # 산출물 디렉터리. 기본 $env:TEMP\plan-audit
  [string]$OutDir = (Join-Path $env:TEMP 'plan-audit')
)

$ErrorActionPreference = 'Stop'

# 출력 인코딩 UTF-8 강제. -NoProfile PS5.1 기본은 CP949 라 한글이 모지바케로 나간다 (PAT-002 원인(A)).
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}

$projectsRoot = Join-Path $env:USERPROFILE '.claude\projects'

# --- 1. 트랜스크립트 찾기 -------------------------------------------------
if (-not $TranscriptPath) {
  # CC 슬러그 규칙: 경로의 ':' 와 '\' '/' 를 '-' 로 치환. (예: C:\Users\Public\dev\x -> C--Users-Public-dev-x)
  $slug = ((Get-Location).Path -replace '[\\/:]', '-')
  $sessionDir = Join-Path $projectsRoot $slug

  if (-not (Test-Path -LiteralPath $sessionDir)) {
    Write-Error "세션 디렉터리를 못 찾았다: $sessionDir`n-TranscriptPath 로 jsonl 경로를 직접 지정하거나, 아래에서 골라라:`n$((Get-ChildItem $projectsRoot -Directory -EA SilentlyContinue | Select-Object -Expand Name) -join "`n")"
    exit 1
  }

  $candidates = @(Get-ChildItem -LiteralPath $sessionDir -Filter '*.jsonl' -File | Sort-Object LastWriteTime -Descending)
  if ($candidates.Count -eq 0) { Write-Error "jsonl 이 없다: $sessionDir"; exit 1 }

  $TranscriptPath = $candidates[0].FullName

  # 세션 재개(resume)로 원문이 분할됐을 수 있다 -> 경고만, 자동 병합은 v1 범위 밖.
  $recent = @($candidates | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) })
  if ($recent.Count -ge 2) {
    Write-Warning "최근 24h 내 트랜스크립트가 $($recent.Count)개다. 세션이 재개돼 원문이 분할됐을 수 있다."
    $recent | ForEach-Object { Write-Warning ("  - {0}  ({1:yyyy-MM-dd HH:mm})" -f $_.Name, $_.LastWriteTime) }
    Write-Warning "다른 파일을 쓰려면 -TranscriptPath 로 지정해라."
  }
}
if (-not (Test-Path -LiteralPath $TranscriptPath)) { Write-Error "트랜스크립트가 없다: $TranscriptPath"; exit 1 }

# --- 2. 파싱 --------------------------------------------------------------
# 줄 단위 스트리밍 + 인코딩 명시.
# Get-Content -Raw 는 장기 세션에서 메모리가 무너지고, switch -File 은 인코딩 파라미터가 없어 CP949 로 오독한다.
$turns = New-Object System.Collections.ArrayList
$decisions = New-Object System.Collections.ArrayList
$sawPromptSource = $false
$sawAskUserQuestion = $false
$skippedSlash = 0
$rejectCount = 0
$sessionId = [IO.Path]::GetFileNameWithoutExtension($TranscriptPath)

# 반려 지시 래퍼에서 사용자 원문만 도려내는 패턴.
# 실제 형태: "... To tell you how to proceed, the user said:\n<원문>\n\nNote: The user's next message ..."
$rejectMarker = 'To tell you how to proceed, the user said:'
$rejectRegex = [regex]::new(
  'To tell you how to proceed, the user said:\s*\r?\n(.*?)(?:\r?\n\r?\nNote: The user''s next message|\s*$)',
  [Text.RegularExpressions.RegexOptions]::Singleline)

# AskUserQuestion 응답 래퍼.
# 실제 형태: "Your questions have been answered: \"질문\"=\"고른라벨\", \"질문2\"=\"라벨2\". You can now continue..."
# ⚠ 하네스 내부 문자열이라 예고 없이 바뀔 수 있다 -> 아래 fail-loud 로 방어한다.
$decisionMarker = 'Your questions have been answered:'

foreach ($line in [IO.File]::ReadLines($TranscriptPath, [Text.Encoding]::UTF8)) {
  # 값싼 선필터: 거대한 tool_result 라인을 파싱조차 하지 않는다.
  # ★ 반려 지시 라인에는 promptSource 키가 아예 없다 — 그래서 두 조건을 OR 로 본다.
  #   (이 프리필터를 promptSource 단독으로 두면 반려 지시가 통째로 유실된다)
  if ($line -like '*"promptSource"*') { $sawPromptSource = $true }
  # fail-loud 용 관측: 마커가 바뀌어도 "레코드는 있었다"는 사실은 남는다.
  if ($line -like '*AskUserQuestion*') { $sawAskUserQuestion = $true }

  $isTyped = ($line -like '*"promptSource"*') -and ($line -like '*"typed"*')
  $isReject = $line -like "*$rejectMarker*"
  $isDecision = $line -like "*$decisionMarker*"
  if (-not ($isTyped -or $isReject -or $isDecision)) { continue }

  try { $o = $line | ConvertFrom-Json } catch { continue }
  if ($o.type -ne 'user') { continue }
  if ($o.isSidechain) { continue }

  $c = $o.message.content
  $text = ''

  if ($o.promptSource -eq 'typed') {
    # (1) 직접 입력
    if ($c -is [string]) {
      $text = $c
    } elseif ($c) {
      # 배열이면 text 블록만. image(base64) 는 버린다.
      foreach ($b in $c) { if ($b.type -eq 'text') { $text += $b.text } }
    }
    $text = $text.Trim()
    if (-not $text) { continue }
    # 슬래시커맨드 입력도 promptSource=typed 로 잡힌다. 요구사항이 아니므로 기준선에서 뺀다.
    if ($text -match '^/') { $skippedSlash++; continue }

  } elseif ($isReject) {
    # (2) 반려 지시 — tool_result 안에 래퍼로 묻혀 있다.
    if (-not $c -or ($c -is [string])) { continue }
    foreach ($b in $c) {
      if ($b.type -ne 'tool_result') { continue }
      $raw = if ($b.content -is [string]) { $b.content } else { ($b.content | Out-String) }
      if ($raw -notlike "*$rejectMarker*") { continue }
      $m = $rejectRegex.Match($raw)
      if ($m.Success) { $text = $m.Groups[1].Value.Trim() }
    }
    if (-not $text) { continue }
    $rejectCount++

  } else {
    # (3) 선택지 응답 — AskUserQuestion. decisions 로만 빠지고 turns 에는 절대 안 들어간다.
    #     구조 파싱을 시도하지 않고 마커 이후를 통째로 보존한다.
    #     질문·라벨에 escape 된 따옴표가 섞여 정규식이 깨지기 쉬운데,
    #     쪼개다 실패하는 것보다 원문을 잃지 않는 게 낫다(파싱 실패 > 데이터 유실).
    if (-not $c -or ($c -is [string])) { continue }
    foreach ($b in $c) {
      if ($b.type -ne 'tool_result') { continue }
      $raw = if ($b.content -is [string]) { $b.content } else { ($b.content | Out-String) }
      $idx = $raw.IndexOf($decisionMarker)
      if ($idx -lt 0) { continue }
      $d = $raw.Substring($idx + $decisionMarker.Length).Trim()
      if ($d) { [void]$decisions.Add($d) }
    }
    continue
  }

  [void]$turns.Add($text)
}

# 미확인 가정 방어: promptSource 필드가 사라진 CC 버전이면 필터가 무력화된다.
# 조용히 노이즈를 흘리느니 실패한다.
if (-not $sawPromptSource) {
  Write-Error "promptSource 필드를 한 줄도 못 찾았다. Claude Code 트랜스크립트 스키마가 바뀐 것 같다. 필터를 갱신하기 전엔 결과를 신뢰하지 마라."
  exit 1
}
if ($turns.Count -eq 0) { Write-Error "사람이 친 발화를 하나도 못 뽑았다: $TranscriptPath"; exit 1 }

# fail-loud: 레코드는 있는데 수집이 0건이면 마커가 바뀐 것이다.
# 조용히 0건이 되면 감사가 "근거 없음"으로 오판한다 — 그게 0.3.14 F4 거짓 고발의 기전이었다.
# 여기서 죽이지는 않는다(원문 추출 자체는 유효하다). 대신 반드시 눈에 띄게 만든다.
if ($sawAskUserQuestion -and $decisions.Count -eq 0) {
  Write-Warning "AskUserQuestion 레코드는 감지됐는데 수집이 0건이다. 마커('$decisionMarker')가 바뀌었을 수 있다."
  Write-Warning "  -> 이 상태에서 '발화에 근거 없음' 판정을 내리지 마라. 선택지 응답이 통째로 안 보이는 중이다."
}

# --- 3. 출력 --------------------------------------------------------------
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# 7일 초과 산출물 정리 (세션마다 쌓인다).
foreach ($pat in @('requests-*.txt', 'decisions-*.txt')) {
  Get-ChildItem -LiteralPath $OutDir -Filter $pat -File -EA SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item -Force -EA SilentlyContinue
}

$outFile = Join-Path $OutDir "requests-$sessionId.txt"
$sb = New-Object System.Text.StringBuilder
for ($i = 0; $i -lt $turns.Count; $i++) {
  [void]$sb.AppendLine("--- TURN $($i + 1) ---")
  [void]$sb.AppendLine($turns[$i])
  [void]$sb.AppendLine()
}
[IO.File]::WriteAllText($outFile, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))

# 선택지 응답은 별도 파일. ★ critic 프롬프트에 섞이면 블라인드가 깨진다 — 파일이 갈려 있어야 실수로도 안 섞인다.
$decFile = $null
if ($decisions.Count -gt 0) {
  $decFile = Join-Path $OutDir "decisions-$sessionId.txt"
  $db = New-Object System.Text.StringBuilder
  [void]$db.AppendLine('# 지휘자 전용 — critic 에게 주지 마라 (선택 라벨에 어시스턴트 제안 요지가 들어 있다)')
  [void]$db.AppendLine()
  for ($i = 0; $i -lt $decisions.Count; $i++) {
    [void]$db.AppendLine("--- DECISION $($i + 1) ---")
    [void]$db.AppendLine($decisions[$i])
    [void]$db.AppendLine()
  }
  [IO.File]::WriteAllText($decFile, $db.ToString(), (New-Object System.Text.UTF8Encoding $false))
}

$size = (Get-Item -LiteralPath $outFile).Length
Write-Output "추출 완료"
Write-Output "  트랜스크립트 : $TranscriptPath"
Write-Output "  사람 발화    : $($turns.Count) 턴 (직접입력 $($turns.Count - $rejectCount) · 반려지시 $rejectCount)"
Write-Output "  슬래시 제외  : $skippedSlash 건"
Write-Output "  기준선       : $outFile ($size bytes)  <- critic 에 주는 것"
if ($decFile) {
  $dsize = (Get-Item -LiteralPath $decFile).Length
  Write-Output "  선택지 결정  : $($decisions.Count) 건 -> $decFile ($dsize bytes)  <- 지휘자 전용"
} else {
  Write-Output "  선택지 결정  : 0 건"
}
exit 0
