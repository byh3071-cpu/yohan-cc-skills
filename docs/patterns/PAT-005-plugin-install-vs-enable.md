---
id: PAT-005
패턴명: 플러그인 install vs enable — 같은 버전이면 marketplace update 후에도 cache 미갱신 (version bump 필수)
카테고리: env
증상: |
  로컬/마켓플레이스 플러그인의 파일(agent frontmatter·스킬·훅 등)을 고쳤는데, `/plugin marketplace update` + `/plugin install` 재설치를 해도 **옛 코드가 그대로 돈다**.
  settings.json에서 `"plugin": true`(enable)로 켜져 있어도 변경이 반영 안 됨. "분명 고쳤는데 왜 안 바뀌지"로 시간을 태운다. 특히 tier 핀(agent `model:`)만 바꾸고 버전 숫자를 안 건드린 경우 재현.
원인: |
  Claude Code는 설치된 플러그인을 **버전 키로 캐시**한다. plugin.json/marketplace.json의 `version`이 그대로면 파일 내용이 바뀌어도 CC는 "이미 그 버전 설치됨"으로 보고 캐시본을 재사용 → `marketplace update`/`install`이 사실상 no-op으로 끝난다.
  게다가 **install ≠ enable**을 혼동하기 쉽다: enable(settings.json의 `"plugin": true`)은 이미 설치된 버전을 **활성/비활성 토글**만 할 뿐 새 코드를 당겨오지 않는다. 껐다 켜도 캐시본은 그대로다.
해결: |
  - **버전을 반드시 bump**한다(patch라도). plugin manifest의 `version`을 올려야 CC가 새 버전으로 인식해 캐시를 갱신하고 새 파일을 당긴다. 파일만 수정하고 버전 동결은 배포 안 된 것과 같다.
  - 순서: **version bump → `/plugin marketplace update` → `/plugin install ...`(재설치)**. enable 토글은 코드 갱신 수단이 아님을 기억(활성 축과 배포 축은 별개).
  - 확인: 재설치 후 실제 바뀐 내용(예: agent frontmatter `model:` 값·스킬 본문)이 **라이브에 반영됐는지 직접 관찰**로 검증. "설치 완료"·enable 체크 표시만 믿지 말 것(MCP ✓Connected 신뢰 금지 규칙의 플러그인판).
적용조건: Claude Code 로컬/마켓플레이스 플러그인을 고친 뒤 재배포할 때. 특히 버전 숫자는 안 건드리고 파일만 바꾼 변경(tier 핀 조정·스킬/훅 수정·frontmatter 편집).
출처프로젝트: yohan-cc-skills
태그: [claude-code, plugin, marketplace, cache, version-bump, install, enable, distribution]
발견일: 2026-07-06
출처DevLog: "docs/log/2026-07-02-handoff.md §3·§5 (멀티모델 tier 도입 — 도입 비용 = plugin version bump 1회)"
---

# PAT-005 — 플러그인 install vs enable

## 핵심 한 줄
플러그인 파일만 고치고 **버전을 안 올리면** `marketplace update` + `install` 재설치를 해도 CC가 버전-키 캐시본을 재사용해 옛 코드가 돈다. **version bump 1회가 캐시 갱신 트리거**. enable(settings.json `true`)은 활성 토글일 뿐 코드 갱신이 아니다.

## 실사례 (멀티모델 tier 도입)
- yohan-core 서브에이전트의 model tier를 바꾸려 agent frontmatter만 수정 → 같은 버전이면 재설치해도 캐시 미갱신, 옛 tier가 계속 상속될 위험. 핸드오프(`docs/log/2026-07-02-handoff.md:35·40`)가 "tier 고정 관리 부담 ≈ 0, **도입 시 plugin version bump 1회만**"이라고 못박고, §3-2에 "⚠️ 같은 버전이면 cache 안 갱신"을 경고로 단 이유가 이것.
- 두 축을 분리해 기억: **install = 코드 배포(버전으로 캐시)**, **enable = 활성 토글(settings.json)**. enable을 껐다 켜는 것으로는 새 코드가 절대 안 들어온다.

## 교훈 (역전파)
- install(배포)과 enable(활성)은 서로 다른 축 — enable은 새 코드를 당기지 않는다.
- 캐시 키는 버전 → 같은 버전 = stale. "고쳤는데 안 바뀜"의 첫 용의자는 미-bump.
- 설치 완료 메시지 신뢰 금지, **라이브 반영 실측** — ✓Connected/설치완료 UI는 캐시 갱신을 보장하지 않는다.

## 비고
글로벌 규칙 "MCP ✓ Connected 신뢰 금지 → 테스트 호출로 확인"의 플러그인 배포판 일반화. 핸드오프의 dangling 위키링크 `[[plugin-install-vs-enable]]`(감사 F35)를 실체화한 문서 — 이후 그 링크는 `[[PAT-005]]`로 정정 대상(해당 파일 소유 에이전트 처리). core 독트린 승격 후보. 노뚝이가 Notion 패턴 사전 등록.
