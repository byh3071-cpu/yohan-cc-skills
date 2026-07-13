---
name: youtube-summary
description: 유튜브 영상을 요한 브레인에 지식화(요약·온톨로지·트리플·wiki 카드)할 때. yt-dlp로 자막 확보 → 원문→요약 프로토콜 Step 0~6 실행. 노동은 자동, 판단 지점(학습 의도·승격·최종 검토)만 요한이 개입(B 방식). "영상 브레인에 넣어줘", "유튜브 지식화", "이 영상 정리해줘 <url>", "영상 넣어줘 <url>" 트리거.
---

# youtube-summary — 유튜브 → 요한 브레인 지식화

> 얇은 진입점. 상세 규칙은 **brain이 SoT** — 아래 정본을 반드시 대조하며 실행한다.
> 역할 분담: **노동(자막·요약초안·트리플·적재)은 자동, 판단(학습의도·승격·검토)은 요한.** 판단 지점은 `[요한 개입]`으로 표시했고 **건너뛰지 않는다.**

## 진입 전제 (먼저 확인)

- **brain 경로 파악(포커스피드 등 어디서 발동해도 OK):** cwd가 `yohan-brain`이면 그대로. 아니면 요한에게 brain 절대경로를 확인하거나 흔한 위치(`…/yohan-ecosystem/yohan-brain`)를 탐색해 **절대경로로 적재**한다(cd 불필요 — 파일 read/write는 절대경로면 됨). 못 찾으면 요한에게 확인.
- `python -m yt_dlp --version` 확인. 없으면 `pip install -U yt-dlp` 안내(요한 실행).
- **재개 체크:** 대상 영상의 id로 부분 산출물 스캔(`ingest/url/`엔 있는데 `insights/`엔 없음 / insight는 있는데 `triple-map.md` 행 없음 등) → 있으면 **미완료 단계부터** 이어서(프로토콜 "원샷 완료").

## 정본 참조 (brain SoT)

| 무엇 | 어디 (yohan-brain) |
|---|---|
| 파이프라인 전체 Step 0~6·체크포인트 | `memory/rules/source-to-summary-protocol.md` (**#5 YouTube 특칙 필독**) |
| 요약 9섹션 구조 | 프로토콜 Step 2 "표준 요약 구조" |
| 트리플 관계 21종·도메인·신뢰도 | `memory/knowledge-hub/triple-map.md` 상단 팔레트 |
| 승격 기준(2소스+·재사용) | 프로토콜 Step 4.5-B |
| wiki 카드 포맷(Source Lock·Verified/Inferred) | 기존 카드 `memory/wiki/{entities,concepts}/*.md` |
| 키워드 DB(프롬프트 영향 전용) | `memory/knowledge-hub/keywords.md` |

## 실행 절차 (B = 판단 지점 개입)

0. **[요한 개입] 학습 의도** — "왜 이 영상 봐? (한 줄)" 물어본다. 답 없으면 기존 트리플·wiki 맥락으로 추론하고 SUMMARY에 `[학습 의도] (추론)` 표기.
1. **자막 확보 (yt-dlp 인라인 — 번들 경로 의존 제거)** — 아래를 Bash로 실행(`<URL>` 치환):
   ```bash
   TMP=$(mktemp -d)
   python -m yt_dlp --skip-download --write-auto-subs --write-subs \
     --sub-langs "ko,ko-orig,en" --sub-format "vtt/best" -o "$TMP/cap" "<URL>" 2>&1 | tail -3
   for L in ko-orig ko en; do f="$TMP/cap.$L.vtt"; [ -f "$f" ] && \
     grep -vE "^(WEBVTT|Kind:|Language:|[0-9]{2}:[0-9]{2}:)" "$f" \
     | sed 's/<[^>]*>//g; s/&amp;/\&/g; s/&gt;/>/g; s/&lt;/</g; s/&nbsp;/ /g' \
     | grep -vE "^[[:space:]]*$" | awk '!seen[$0]++' > "$TMP/transcript.txt" && break; done
   wc -m "$TMP/transcript.txt" && head -3 "$TMP/transcript.txt"
   ```
   `$TMP/transcript.txt`가 원문. 실패(자막 없음) 시 요한에게 텍스트 요청 or 요약 보류(프로토콜 #5).
2. **Step 0-Pre·1** — 읽기 등급(A/B/C) 보고 → `ingest/url/url-{sha256-16}.md`에 raw 저장(YouTube=전문 보존). **고유명사 오인식 교정**(영상 설명 등 clean 소스 대조, 화자 이름 충돌 시 `[확인 필요]` — 추측 금지).
3. **Step 2 요약** — `insights/{kebab-id}.md` 9섹션. `related`에 원본 필수. 긴 영상은 타임라인 구조. 인물 감지 시 후보 보고.
4. **Step 4.5 교차검증** — 같은 domain·기존 트리플과 수렴/충돌 대조 보고.
5. **[요한 개입] 체크포인트 1·2** — 역전파(4.6)·승격(위키/인물) 진행/스킵을 **A/B/C로 요한에게 판단 요청**(단일소스면 스킵/보류 추천 명시). 침묵 금지.
6. **Step 4.7 온톨로지** — 트리플 3~7 추출 → 기존 대조 → **SUMMARY 본문 `## 트리플 맵` + `triple-map.md` 둘 다 등록**. 키워드 스캔 **한 줄 보고**(등록 N / 스킵+이유).
7. **위키 카드** — 5번에서 승격 결정된 것만 생성(정의·`## Verified` [source: id]·Inferred TTL 30일) → `index.md` 통계·`log.md` append.
8. **[요한 개입] 최종 검토** — 요약을 요한이 읽고 프레이밍·수정. 트리플 관계 오용·과장·부풀리기 자가 점검.
9. **Step 5·6** — 인박스 아카이브(있으면) → **`logs/sessions/`에 세션 로그(실패·부분성공도 생략 금지)**.

## 금지

- 자막 오인식 교정 **생략 금지**(고유명사가 트리플·엔티티를 채움).
- 트리플 **한쪽만 등록 금지**(SUMMARY 본문 + `triple-map.md` 둘 다).
- **단일소스 자동 승격 금지** — 위키/인물 카드는 요한 확인 후(propose-and-confirm).
- 채용/홍보 등 저밀도 소스를 **부풀리기 금지** — 본문은 발화 충실 매핑, 벤치마크 해석은 내생각/OS적용에.
- **세션 로그 생략 금지.** 커밋은 요한 확인 후.

## 요구 도구

- `python -m yt_dlp` (없으면 `pip install -U yt-dlp`). 2026-07-13 실측: npm 자막 4경로(youtube-transcript·youtubei.js·caption url·ANDROID) 실패, yt-dlp만 성공. 자막 명령은 절차 1번에 인라인(번들 스크립트·경로 변수 의존 없음).
