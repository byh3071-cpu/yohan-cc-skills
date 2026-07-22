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
  [string]$OutDir = (Join-Path $env:TEMP 'plan-audit'),
  # 이 길이 이하의 발화를 "내용 없는 수락 신호"로 보고 직전 어시스턴트 제안을 함께 수집한다.
  # 12 = 'ㅇㅇ'·'A'·'머지해'·'그래 그렇게 해'를 덮는 실측 폭. 넓게 잡아 노이즈를 내는 쪽이
  # 좁게 잡아 근거를 잃는 쪽보다 낫다 — decisions 는 지휘자만 읽으므로 노이즈 비용이 싸다.
  [int]$AcceptSignalMaxLen = 12
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

  # ★ 현재 세션 ID 로 정확히 집는다. 하네스가 트랜스크립트 파일명과 같은 값을 넣어준다.
  #   수정시각 최신을 고르는 방식은 병렬 세션이 있으면 남의 세션을 감사하게 된다 —
  #   그 경우 "요구사항 전량 누락"이 나오고 원인을 찾기까지 한참 헤맨다.
  $envSid = $env:CLAUDE_CODE_SESSION_ID
  $picked = $null
  if ($envSid) { $picked = $candidates | Where-Object { $_.BaseName -eq $envSid } | Select-Object -First 1 }

  if ($picked) {
    $TranscriptPath = $picked.FullName
  } else {
    $TranscriptPath = $candidates[0].FullName
    if ($envSid) {
      Write-Warning "현재 세션 ID($envSid)에 해당하는 jsonl 이 없다. 수정시각 최신 파일로 폴백한다."
      Write-Warning "  -> 다른 세션의 발화를 감사할 수 있다. 결과가 이상하면 -TranscriptPath 로 직접 지정해라."
    } else {
      Write-Warning "CLAUDE_CODE_SESSION_ID 가 비어 있다. 수정시각 최신 파일로 고른다(병렬 세션이면 틀릴 수 있다)."
    }
  }

  # 세션 재개(resume)로 원문이 분할됐을 수 있다 -> 경고만, 자동 병합은 범위 밖.
  # ID 로 정확히 집었어도 이전 조각은 다른 파일에 있으므로 경고는 그대로 유효하다.
  $recent = @($candidates | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) })
  if ($recent.Count -ge 2) {
    Write-Warning "최근 24h 내 트랜스크립트가 $($recent.Count)개다. 세션이 재개돼 원문이 분할됐을 수 있다."
    $recent | ForEach-Object { Write-Warning ("  - {0}  ({1:yyyy-MM-dd HH:mm})" -f $_.Name, $_.LastWriteTime) }
    Write-Warning "  -> 이 감사의 기준선은 한 조각뿐이다. 앞 조각의 요구사항은 '누락'으로 보이니 그렇게 판정하지 마라."
  }
}
if (-not (Test-Path -LiteralPath $TranscriptPath)) { Write-Error "트랜스크립트가 없다: $TranscriptPath"; exit 1 }

# --- 2. 파싱 --------------------------------------------------------------
# 줄 단위 스트리밍 + 인코딩 명시.
# Get-Content -Raw 는 장기 세션에서 메모리가 무너지고, switch -File 은 인코딩 파라미터가 없어 CP949 로 오독한다.

# 트랜스크립트 timestamp(ISO8601 UTC)에서 밀리초만 떼어낸다. 정렬 가능성은 그대로 유지.
# 한 세션에 여러 작업이 섞이므로 지휘자가 "어디부터가 현재 계획인가"를 이걸로 가른다.
function Get-ShortTs {
  param([string]$Ts)
  if (-not $Ts) { return '????-??-??T??:??:??Z' }   # 방어: 스키마에서 사라져도 자리를 비우지 않는다
  $i = $Ts.IndexOf('.')
  if ($i -gt 0) { return $Ts.Substring(0, $i) + 'Z' }
  return $Ts
}

$turns = New-Object System.Collections.ArrayList
$decisions = New-Object System.Collections.ArrayList
$sawPromptSource = $false
$sawAskUserQuestion = $false
$skippedSlash = 0
$rejectCount = 0
$sawRejectMarker = 0    # 마커를 본 레코드 수 — 수집 수와 벌어지면 파서가 새는 것이다
$rejectLooseCount = 0   # 후행 래퍼를 못 찾아 끝까지 캡처한 수 — 오염 가능
$jsonFailUser = 0       # 수집 후보인데 JSON 파싱이 깨진 줄 — 그 발화는 통째로 사라진다
$jsonFailAssistant = 0  # 어시스턴트 줄 파싱 실패 — 평문 수락의 대상 복원만 영향
$sawDecisionMarker = 0  # tool_result 안에서 선택지 마커를 본 수 (파싱 후라 라인 기반보다 정확)
$decisionKept = 0       # 형식 검사를 통과해 수집된 수
$decisionRejected = 0   # 마커는 있으나 응답 형식이 아니라 버린 수 (인용·로그 오염)
$sessionId = [IO.Path]::GetFileNameWithoutExtension($TranscriptPath)

# 반려 지시 래퍼에서 사용자 원문만 도려내는 패턴.
# 실제 형태: "... To tell you how to proceed, the user said:\n<원문>\n\nNote: The user's next message ..."
$rejectMarker = 'To tell you how to proceed, the user said:'
# 후행 래퍼까지 정확히 잘라내는 패턴. 이게 매치되면 오염이 없다.
$rejectRegexStrict = [regex]::new(
  'To tell you how to proceed, the user said:\s*\r?\n(.*?)\r?\n\r?\nNote: The user''s next message',
  [Text.RegularExpressions.RegexOptions]::Singleline)
# 폴백. 후행 래퍼 문구가 바뀌면 strict 가 실패하는데, 여기서 끝까지 캡처하면
# 바뀐 래퍼 문구까지 사용자 발화로 섞인다 -> 반드시 세서 경고한다(조용히 오염되면 안 된다).
$rejectRegexLoose = [regex]::new(
  'To tell you how to proceed, the user said:\s*\r?\n(.*)$',
  [Text.RegularExpressions.RegexOptions]::Singleline)

# AskUserQuestion 응답 래퍼.
# 실제 형태: "Your questions have been answered: \"질문\"=\"고른라벨\", \"질문2\"=\"라벨2\". You can now continue..."
# ⚠ 하네스 내부 문자열이라 예고 없이 바뀔 수 있다 -> 아래 fail-loud 로 방어한다.
$decisionMarker = 'Your questions have been answered:'

$lastAssistantText = ''   # 직전 어시스턴트 평문 발화 — 수락 신호의 대상을 복원하는 유일한 단서
$plainAcceptCount = 0
$orphanAcceptCount = 0

foreach ($line in [IO.File]::ReadLines($TranscriptPath, [Text.Encoding]::UTF8)) {
  # 어시스턴트 평문 발화를 따라다닌다. 사용자가 'ㅇㅇ'로 승낙하면 그 내용은 여기에만 있다.
  # AskUserQuestion 이 아닌 평문 제안은 decisions 채널로 안 잡혀서 0.3.15 가 절반만 고친 상태였다.
  if ($line -like '*"assistant"*') {
    # 60KB 초과는 tool_use 덩어리다. 평문 답변은 그보다 훨씬 작아서 잘라도 잃는 게 없고,
    # 안 자르면 긴 세션에서 파싱 비용이 선형으로 붙는다.
    if ($line.Length -lt 60000) {
      $a = $null
      try { $a = $line | ConvertFrom-Json } catch { $a = $null; $jsonFailAssistant++ }
      if ($a -and $a.type -eq 'assistant' -and $a.message.content -and -not $a.isSidechain) {
        $at = ''
        foreach ($ab in $a.message.content) { if ($ab.type -eq 'text') { $at += $ab.text } }
        $at = $at.Trim()
        if ($at) { $lastAssistantText = $at }
      }
    }
    continue
  }

  # 값싼 선필터: 거대한 tool_result 라인을 파싱조차 하지 않는다.
  # ★ 반려 지시 라인에는 promptSource 키가 아예 없다 — 그래서 두 조건을 OR 로 본다.
  #   (이 프리필터를 promptSource 단독으로 두면 반려 지시가 통째로 유실된다)
  # fail-loud 용 관측: 마커가 바뀌어도 "레코드는 있었다"는 사실은 남는다.
  if ($line -like '*AskUserQuestion*') { $sawAskUserQuestion = $true }

  $isTyped = ($line -like '*"promptSource"*') -and ($line -like '*"typed"*')
  $isReject = $line -like "*$rejectMarker*"
  $isDecision = $line -like "*$decisionMarker*"
  if (-not ($isTyped -or $isReject -or $isDecision)) { continue }

  # ★ 여기서 실패하면 수집 후보 발화가 통째로 사라진다. 조용히 넘기면 그 유실을 아무도 모른다.
  try { $o = $line | ConvertFrom-Json } catch { $jsonFailUser++; continue }
  if ($o.type -ne 'user') { continue }
  if ($o.isSidechain) { continue }

  # 스키마 관측은 반드시 파싱 후에. 라인 문자열로 보면 사용자가 "promptSource" 를 발화에
  # 인용하거나 어시스턴트가 코드를 출력한 것만으로 켜져서, 필드가 실제로 사라져도
  # fail-loud 가 안 터진다. 실측(C4)에서 반려 마커가 같은 방식으로 33 대 4 오탐을 냈다.
  if ($null -ne $o.promptSource) { $sawPromptSource = $true }

  $c = $o.message.content
  $text = ''

  if ($o.promptSource -eq 'typed') {
    # (1) 직접 입력
    if ($c -is [string]) {
      $text = $c
    } elseif ($c) {
      # 배열이면 text 블록만. image(base64) 는 버린다.
      # 블록 사이는 개행으로 잇는다 — 그냥 이으면 앞 블록 끝 단어와 뒤 블록 첫 단어가
      # 붙어서 없던 낱말이 생긴다. verbatim 을 표방하면서 원문을 바꾸는 셈이었다.
      $parts = @()
      foreach ($b in $c) { if ($b.type -eq 'text' -and $b.text) { $parts += $b.text } }
      $text = ($parts -join "`n")
    }
    $text = $text.Trim()
    if (-not $text) { continue }
    # 슬래시커맨드 입력도 promptSource=typed 로 잡힌다. 요구사항이 아니므로 기준선에서 뺀다.
    if ($text -match '^/') { $skippedSlash++; continue }

    # 내용 없는 수락 신호 — 무엇을 승낙한 건지는 직전 어시스턴트 발화에만 있다.
    # requests 에는 신호 그대로 남기고(발화니까), 대상 복원용 사본만 decisions 로 뺀다.
    if ($text.Length -le $AcceptSignalMaxLen) {
      if ($lastAssistantText) {
        # 지휘자 컨텍스트를 지키려고 자른다. 제안의 요지는 앞쪽에 있다(두괄식 규율).
        # 실측: 이 세션 16건 × 2000자 = 33KB 로 불어 지휘자가 매번 읽기 부담이었다. 1000 으로 낮춘다.
        $ctx = if ($lastAssistantText.Length -gt 1000) { $lastAssistantText.Substring(0, 1000) + "`n…(이하 생략 — 전문은 트랜스크립트)" } else { $lastAssistantText }
        [void]$decisions.Add([pscustomobject]@{
          Kind = '평문 수락'
          Text = "사용자 응답: $text`n`n[직전 어시스턴트 제안]`n$ctx"
          Ts   = (Get-ShortTs $o.timestamp)
        })
        $plainAcceptCount++
      } else {
        # 직전 발화가 없다 = 세션 첫 발화이거나 파싱을 놓쳤다. 조용히 넘기지 않고 센다.
        $orphanAcceptCount++
      }
    }

  } elseif ($isReject) {
    # (2) 반려 지시 — tool_result 안에 래퍼로 묻혀 있다.
    #     ★ 한 레코드에 tool_result 가 여럿일 수 있고, 한 raw 안에 래퍼가 여럿일 수도 있다.
    #       예전엔 $text 를 덮어쓰고 레코드당 한 번만 담아서 나머지가 조용히 사라졌다.
    #       여기서 바로 담고 분기를 끝낸다.
    if (-not $c -or ($c -is [string])) { continue }
    $ts = Get-ShortTs $o.timestamp
    foreach ($b in $c) {
      if ($b.type -ne 'tool_result') { continue }
      $raw = if ($b.content -is [string]) { $b.content } else { ($b.content | Out-String) }
      if ($raw -notlike "*$rejectMarker*") { continue }
      # ★ 여기서 센다. 프리필터(파싱 전)에서 세면 어시스턴트가 마커 문자열을 인용한 라인까지
      #   걸려서 거짓 경보가 난다 — 실측으로 이 세션에서 33 대 4 로 오탐이 났다.
      $sawRejectMarker += [regex]::Matches($raw, [regex]::Escape($rejectMarker)).Count

      $ms = $rejectRegexStrict.Matches($raw)
      if ($ms.Count -gt 0) {
        foreach ($mm in $ms) {
          $t = $mm.Groups[1].Value.Trim()
          if ($t) { [void]$turns.Add([pscustomobject]@{ Text = $t; Ts = $ts }); $rejectCount++ }
        }
      } else {
        $m2 = $rejectRegexLoose.Match($raw)
        if ($m2.Success) {
          $t = $m2.Groups[1].Value.Trim()
          if ($t) { [void]$turns.Add([pscustomobject]@{ Text = $t; Ts = $ts }); $rejectCount++; $rejectLooseCount++ }
        }
      }
    }
    continue

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
      $sawDecisionMarker++
      $d = $raw.Substring($idx + $decisionMarker.Length).Trim()
      if (-not $d) { continue }
      # 정상 응답은 반드시 "질문"="고른라벨" 형태로 시작한다.
      # 이 검사가 없으면 마커 문자열이 로그·코드·문서에 인용된 것까지 통째로 캡처된다 —
      # 실측: 0.3.15 개발 중 찍은 경고문(마커가 변수로 전개됨)이 '사용자 결정'으로 수집됐다.
      # 지휘자가 그걸 근거로 읽으면 없는 결정을 있다고 판단한다.
      if (-not $d.StartsWith('"')) { $decisionRejected++; continue }
      [void]$decisions.Add([pscustomobject]@{ Kind = '선택지'; Text = $d; Ts = (Get-ShortTs $o.timestamp) })
      $decisionKept++
    }
    continue
  }

  # ★ 시각을 함께 들고 간다 — 이게 없으면 지휘자가 이전 작업 발화와 현재 계획 발화를 못 가른다.
  [void]$turns.Add([pscustomobject]@{ Text = $text; Ts = (Get-ShortTs $o.timestamp) })
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
# 마커 자체가 통째로 바뀐 경우 — tool_result 안에서도 못 찾으므로 도구명으로 감지한다(독립 신호).
if ($sawAskUserQuestion -and $sawDecisionMarker -eq 0) {
  Write-Warning "AskUserQuestion 레코드는 감지됐는데 마커를 한 건도 못 찾았다. 마커('$decisionMarker')가 바뀌었을 수 있다."
  Write-Warning "  -> 이 상태에서 '발화에 근거 없음' 판정을 내리지 마라. 선택지 응답이 통째로 안 보이는 중이다."
}
# 부분 유실 — 마커는 찾았는데 형식 검사에서도 안 걸리고 수집도 안 된 잔차.
# 이전엔 Count -eq 0(전량 유실)만 봐서, 한 건만 살아남으면 나머지가 사라져도 조용했다.
$decisionLost = $sawDecisionMarker - $decisionKept - $decisionRejected
if ($decisionLost -gt 0) {
  Write-Warning "선택지 마커 $sawDecisionMarker 건 중 $decisionLost 건이 수집도 배제도 안 된 채 사라졌다."
  Write-Warning "  -> 파서가 새는 중이다. decisions 파일을 근거로 '결정 없음'을 단정하지 마라."
}
if ($decisionRejected -gt 0) {
  Write-Warning "선택지 마커 $decisionRejected 건은 응답 형식이 아니라 배제했다(로그·문서에 인용된 마커로 보인다)."
}

# JSON 파싱 실패. 잘린 마지막 줄·손상 레코드·PS5.1 이 못 먹는 형태에서 난다.
# 프리필터를 통과한 줄만 파싱하므로 여기서 깨진 건 전부 "수집 후보였던 발화"다.
if ($jsonFailUser -gt 0) {
  Write-Warning "수집 후보 $jsonFailUser 줄이 JSON 파싱에 실패해 통째로 빠졌다."
  Write-Warning "  -> 기준선에 구멍이 있다. '요구사항 없음'·'근거 없음' 판정을 내리지 마라."
}
if ($jsonFailAssistant -gt 0) {
  Write-Warning "어시스턴트 $jsonFailAssistant 줄이 파싱에 실패했다. 그 구간의 평문 수락은 대상 복원이 안 된다."
}

# 반려 지시에도 같은 방어를 건다. 여긴 fail-loud 가 없어서 AskUserQuestion 쪽과 비대칭이었다.
# 반려 지시는 이 스킬의 핵심 입력이라(계획을 왜 되돌렸는지가 여기 있다) 유실이 더 비싸다.
#
# ⚠ 부분 비교(감지 N > 수집 M)는 쓰지 않는다. 마커는 평범한 영문 문장이라 대화 본문에
#   인용되면 그대로 걸린다 — 이 스킬 자체를 다루는 세션에서 실측 9 대 4 로 거짓 경보가 났다.
#   인용된 마커는 뒤에 개행이 없어 strict·loose 둘 다 실패하고 수집에서 알아서 빠지므로,
#   동작은 정확하고 카운터만 부풀 뿐이다. 그래서 전량 유실만 잡는다(AskUserQuestion 과 같은 기준).
if ($sawRejectMarker -gt 0 -and $rejectCount -eq 0) {
  Write-Warning "반려 지시 마커를 $sawRejectMarker 건 봤는데 하나도 못 뽑았다. 래퍼 형식이 바뀌었을 수 있다."
  Write-Warning "  -> 계획을 되돌린 이유가 통째로 안 보이는 중이다. '요구사항 없음' 판정을 내리지 마라."
}
if ($rejectLooseCount -gt 0) {
  Write-Warning "반려 지시 $rejectLooseCount 건에서 후행 래퍼를 못 찾아 끝까지 캡처했다. 하네스 문구가 사용자 발화로 섞였을 수 있다."
  Write-Warning "  -> 해당 TURN 의 꼬리에 영문 안내문이 붙어 있는지 눈으로 확인해라."
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
[void]$sb.AppendLine('# 시각은 UTC. 한 세션에 여러 작업이 섞일 수 있다 — 전부 현재 계획의 요구사항은 아니다.')
[void]$sb.AppendLine()
for ($i = 0; $i -lt $turns.Count; $i++) {
  [void]$sb.AppendLine("--- TURN $($i + 1) [$($turns[$i].Ts)] ---")
  [void]$sb.AppendLine($turns[$i].Text)
  [void]$sb.AppendLine()
}
[IO.File]::WriteAllText($outFile, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))

# 선택지 응답은 별도 파일. ★ critic 프롬프트에 섞이면 블라인드가 깨진다 — 파일이 갈려 있어야 실수로도 안 섞인다.
$decFile = $null
$staleDecRemoved = $false
if ($decisions.Count -eq 0) {
  # 이번 실행에서 0건인데 같은 세션의 옛 파일이 남아 있으면, 지휘자가 지난 실행의 결정을
  # 이번 근거로 읽는다. 파서가 퇴행했을 때 특히 위험하다 — 유실을 옛 데이터가 가려버린다.
  $oldDec = Join-Path $OutDir "decisions-$sessionId.txt"
  if (Test-Path -LiteralPath $oldDec) {
    Remove-Item -LiteralPath $oldDec -Force -EA SilentlyContinue
    $staleDecRemoved = $true
  }
}
if ($decisions.Count -gt 0) {
  $decFile = Join-Path $OutDir "decisions-$sessionId.txt"
  $db = New-Object System.Text.StringBuilder
  [void]$db.AppendLine('# 지휘자 전용 — critic 에게 주지 마라 (선택 라벨에 어시스턴트 제안 요지가 들어 있다)')
  [void]$db.AppendLine()
  for ($i = 0; $i -lt $decisions.Count; $i++) {
    [void]$db.AppendLine("--- DECISION $($i + 1) [$($decisions[$i].Ts)] ($($decisions[$i].Kind)) ---")
    [void]$db.AppendLine($decisions[$i].Text)
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
  Write-Output "  사용자 결정  : $($decisions.Count) 건 (선택지 $($decisions.Count - $plainAcceptCount) · 평문수락 $plainAcceptCount) -> $decFile ($dsize bytes)  <- 지휘자 전용"
} else {
  Write-Output "  사용자 결정  : 0 건"
  if ($staleDecRemoved) {
    Write-Warning "이번 실행 결정이 0건이라 이전 실행의 decisions 파일을 지웠다(옛 근거 오독 방지)."
    Write-Warning "  -> 직전 실행에서는 결정이 잡혔다면 파서가 퇴행한 것이다. 위 경고들을 먼저 봐라."
  }
}
if ($orphanAcceptCount -gt 0) {
  Write-Warning "수락 신호 $orphanAcceptCount 건에 직전 어시스턴트 발화가 없다. 무엇을 승낙한 건지 복원 불가 — '근거 없음' 판정 전에 트랜스크립트를 직접 봐라."
}
exit 0
