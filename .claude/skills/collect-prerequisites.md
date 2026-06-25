---
name: collect-prerequisites
description: prerequisites.md의 미해결 항목을 수집하고 연결 테스트까지 수행. 모든 항목이 ✅ 통과되면 integration-ready.md를 발급. "prerequisite 확보해줘", "연동 테스트해줘", "값 입력할게" 요청 시 사용.
---

# Prerequisite 수집·검증 워크플로

> **원칙**: Real-First. 실제 값 없이 다음 Phase로 진행하지 않는다.
> 미해결 항목에 대해 "나중에", "모름", "신청 중" 선택지를 제공하지 않는다.
> 값이 없으면 작업을 중단하고 구체적인 발급 방법만 안내한다.

> **⛔ Phase 0.5 우회 절대 금지 (Claude 행동 규칙)**
>
> Phase 0.5 진입 시 사용자에게 제시할 수 있는 선택지는 **"지금 수집"** 하나뿐이다.
> 아래 선택지는 어떤 상황에서도 제시하지 않는다:
> - "Phase 1 먼저 진행하고 나중에 값 입력"
> - "Mock 처리 후 실제 API 키 나중에 교체"
> - "Phase 0.5 건너뛰고 구현 먼저"
> - 이와 유사한 우회 방법 일체
>
> prerequisites.md의 미수집 항목이 1개라도 있으면 Phase 1 진입은 **물리적으로 차단**된다.
> (`integration-ready.md` 미발급 → `check_phase_gate` 실패 → Phase 1 시작 불가)
>
> 수집이 불가능한 경우(발급 처리 중, 담당자 부재 등)에도 Mock 우회가 아닌
> **블로커 등록 후 대기**가 올바른 처리이다:
> ```bash
> # 블로커 처리 예시 — 우회가 아닌 대기
> ./scripts/log-activity.sh BLOCKED "T051 API Key 미수신" "GW.Platform@nexon.com 발급 대기 중" || true
> ./scripts/notify-slack.sh "🔴 블로커: Phase 0.5" "API Key 수신 후 재개" || true
> ```

## 트리거

- "prerequisite 확보해줘" / "연동 테스트해줘" / "값 입력할게"
- "{항목명} 발급받았어" (부분 실행)
- Phase 0.5 태스크 T051 실행 시 자동 호출

---

## Step 0: 인증 유형 자동 판별 (해당 시)

`prerequisites.md`에 SSO/GNB 관련 항목이 있으면 판별 후 진행.

| 감지 키워드 | 시스템 | 읽을 파일 |
|---|---|---|
| NXAS, 사내 SSO, 관리자 인증 | NXAS SSO (사내) | `refs/policies/authentication-nxas.md` A-3 |
| INSIGN, GameScale SDK, 넥슨 로그인 | INSIGN (외부) | `refs/policies/authentication-external.md` A-2d |
| GNB, 넥슨 GNB | 넥슨 GNB | `refs/policies/authentication-external.md` A-10 |

hosts 설정이 필요한 경우:
```bash
# Mac/Linux — 설정 확인
ping -c 1 dev-{서비스}.nexon.com
# 127.0.0.1이 나오면 성공

# NXAS 연결 테스트
curl -sI https://nxas.nexon.com/ | head -1

# INSIGN 연결 테스트
curl -sI https://signin.nexon.com/sdk/inface.js | head -1

# GNB 리소스 도메인 테스트 (테스트 환경)
curl -sI https://rs-test.nxfs.nexon.com/common/js/gnb.min.js | head -1
```

---

## Step 1: 현황 로드

`prerequisites.md`를 읽고 상태를 집계한다.

```
## Prerequisites 현황

| 시스템 | 총 항목 | ✅ 완료 | 🔴 미완료 |
|---|---|---|---|
| {시스템명} | {N} | {N} | {N} |

미완료 항목: {N}개
```

미완료가 0개이면 → **Step 3으로 바로 이동** (연결 테스트 실행).

---

## Step 2: 미완료 항목 처리

미완료 항목을 **의존관계 순서대로** 하나씩 처리한다.

### 처리 방식 (선택지 없음)

각 미완료 항목에 대해 다음 형식으로 안내한다:

```
⛔ {항목명} — 값 필요

이 값이 없으면 {영향받는 기능} 구현이 불가능합니다.

발급 방법: {구체적 방법 — URL, 이메일, 담당팀}
필요한 값 형식: {예시}

값을 발급받아 입력해주세요.
```

항목별 처리 절차:

> **Claude Code 보안 정책**: `.env.local` 등 환경변수 파일은 Claude Code가 직접 읽거나 쓸 수 없다.
> 대신 `.env.example`에 키 템플릿을 작성하고, 사용자가 직접 복사·편집하도록 안내한다.

**2-A. `.env.example` 키 템플릿 추가:**

해당 항목의 환경변수명이 `.env.example`에 없으면 Write 도구로 추가한다.
이미 존재하면 건너뛴다. 필수 항목은 반드시 `# required` 주석을 달아야 `check-env.sh`가 감지한다.

`.env.example` 추가 형식:
```
# {시스템명 — 예: 넥슨 쪽지 API}
{VARIABLE_NAME}=  # required — {값 설명, 예: GW.Platform@nexon.com에서 발급}
{OPTIONAL_VAR}=기본값  # optional — {설명}
```

**2-B. 사용자 안내 (모든 항목 추가 완료 후 1회만 안내):**

모든 미완료 항목을 2-A에서 `.env.example`에 추가한 뒤, 아래 형식으로 1회 안내한다:

```
📝 환경변수 설정 방법

.env.example 파일에 필요한 키가 모두 준비되었습니다.
아래 순서로 실제 값을 입력해주세요:

① 터미널에서 아래 명령을 실행하세요:
   cp .env.example .env.local

② .env.local 파일을 열어 각 항목에 실제 값을 입력하세요:

{.env.example에 추가된 전체 변수 목록 출력 — 변수명·설명·발급처 포함}

예시:
  NOTE_API_KEY=sk-abc123...   ← 여기에_값_입력 부분을 실제 값으로 교체
  DATABASE_URL=postgresql://user:pass@localhost:5432/dbname

③ 저장 완료 후 "완료"를 입력해주세요.
```

자동 생성 가능한 값(CRON_SECRET 등)은 직접 생성해서 안내에 포함한다:
```bash
# CRON_SECRET 자동 생성 후 사용자에게 복붙 안내
openssl rand -base64 32
```

**2-C. 완료 확인 및 연결 테스트:**

사용자 "완료" 입력 후 `check-env.sh`로 검증:

```bash
bash scripts/check-env.sh
```

- `exit 0` (모든 required 변수 설정됨) → Step 2-T 실행 (연결 테스트)
- `exit 1` (미설정 변수 출력) → 출력된 변수 목록을 사용자에게 안내하고 재입력 요청:

```
⛔ 아직 설정되지 않은 변수가 있습니다:
  {check-env.sh 출력 그대로}

.env.local 파일에서 해당 항목을 입력하고 저장한 뒤 다시 "완료"를 입력해주세요.
```

통과 시 → `prerequisites.md` 해당 항목 ✅ 갱신 → 다음 항목으로.

### Step 2-T: 항목별 연결 테스트

> 단순 포트 연결이나 health 엔드포인트만으로 통과하지 않는다.
> 발급받은 인증 키·토큰을 사용한 **실제 API 호출**로 권한까지 검증한다.

| 시스템 유형 | 1차 연결 확인 | 2차 인증 검증 |
|---|---|---|
| HTTP API (공개) | `curl -sI {BASE_URL}/health \| head -1` | HTTP 2xx 응답 |
| HTTP API (Bearer) | `curl -sI {BASE_URL}/health \| head -1` | `curl -s -H "Authorization: Bearer {TOKEN}" {BASE_URL}/api/ping` → 401 아닌 응답 |
| HTTP API (API Key) | `curl -sI {BASE_URL}/health \| head -1` | `curl -s -H "x-api-key: {KEY}" {BASE_URL}/api/ping` → 401/403 아닌 응답 |
| NXAS SSO | `curl -sI https://nxas.nexon.com/ \| head -1` | `curl -s -H "Authorization: Bearer {ACCESS_TOKEN}" https://nxas.nexon.com/api/userinfo` → 200 |
| INSIGN / GameScale | `curl -sI https://signin.nexon.com/sdk/inface.js \| head -1` | `curl -s -H "x-ncl-app-key: {APP_KEY}" {GS_BASE_URL}/v1/ping` → 200 |
| DB (PostgreSQL) | `nc -zv {HOST} {PORT}` | `psql -h {HOST} -p {PORT} -U {USER} -c "SELECT 1"` → 정상 응답 |
| DB (MSSQL) | `nc -zv {HOST} {PORT}` | `sqlcmd -S {HOST},{PORT} -U {USER} -P {PW} -Q "SELECT 1"` → 정상 응답 |
| 네트워크 ACL | `nc -zv {HOST} {PORT}` | 포트 열림 확인으로 충분 |

**2차 인증 검증이 불가한 경우** (테스트 환경 미제공 등):
- 사용자에게 사유를 설명하고 1차 연결 확인만으로 임시 통과 처리
- integration-ready.md에 `⚠️ 인증 검증 미완료 — {사유}` 표시
- tasks.md 해당 태스크에 `# TODO: 인증 검증 필요` 주석 추가

테스트 실패 시 — 오류 원인(URL/포트·인증·IP ACL·네트워크)을 안내하고 재시도 대기. "다음에 할게요" 선택지는 제공하지 않는다.

---

## Step 3: 전체 Smoke Test

모든 항목이 ✅ 상태가 된 후 전체 연결을 재검증한다.

```bash
# 시스템별 Smoke Test 일괄 실행
{각 시스템 연결 명령}
```

| 시스템 | 테스트 명령 | 결과 |
|---|---|---|
| {시스템 1} | `{명령}` | ✅ / ❌ |
| {시스템 2} | `{명령}` | ✅ / ❌ |

**전부 ✅** → Step 4 (integration-ready.md 발급)
**❌ 있음** → 해당 항목 재처리 (Step 2로 복귀)

---

## Step 3.5: 환경변수 파일 설정 검증

Smoke Test 후 `.env.local`에 실제 값이 모두 입력되어 있는지 `check-env.sh`로 확인한다.
(`.env.local`은 Claude Code가 직접 읽을 수 없으므로 스크립트로만 검증한다.)

```bash
bash scripts/check-env.sh
```

| 결과 | 처리 |
|---|---|
| exit 0 — 모든 required 변수 설정됨 | Step 3.6으로 진행 |
| exit 1 — 미설정 변수 목록 출력 | 아래 안내 후 재실행 |

**미설정 변수 발견 시 안내 형식:**

```
⛔ 다음 변수가 .env.local에 설정되지 않았습니다:

  ✗ {VARIABLE_NAME}  →  {.env.example 원문}

설정 방법:
1. .env.local 파일이 없다면: cp .env.example .env.local
2. .env.local 파일을 열어 위 변수에 실제 값을 입력하세요.
3. 발급 방법은 prerequisites.md를 참조하세요.
4. 설정 완료 후 "확인해줘"를 입력하면 재검사합니다.
```

사용자가 "확인해줘" / "설정했어" / "했어" 입력 시 → `bash scripts/check-env.sh`를 재실행한다.
exit 0이 되어야 Step 3.6으로 진행한다. "나중에"·"건너뛰기" 선택지는 제공하지 않는다.

---

## Step 3.6: 로컬 개발 필수 변수 추가 검증 (INSIGN 프로젝트)

> **방안 A 범위**: GNB 실제 렌더링과 INSIGN 로그인 플로우는 **React 앱 구현 단계(create-spec Step 2.7)**
> 에서 HTTPS 서버로 브라우저 검증한다. Phase 0.5는 서버사이드 연결(curl)과 환경변수만 확인한다.
> Phase 0.5 완료 후 바로 `integration-ready.md`를 발급하고 Phase 1로 진입한다.

> **적용 조건**: `.env.example`에 `VITE_INFACE_WEB_AUTH`, `VITE_INFACE_ENV`, `VITE_GID`, `BACKEND_URL` 중
> 하나라도 존재하는 경우. INSIGN(넥슨 GNB) 프로젝트는 로컬 개발 시 추가 변수가 없으면 401/400 에러가 반복 발생한다.

> **INSIGN API key (x-inface-api-key) 로컬 처리 원칙 (InfaceTest 패턴)**:
> - `INFACE_API_KEY`는 로컬에서 **optional**이다. 없으면 백엔드 `authMiddleware`가 API Key 검증을 생략한다.
> - 스테이지·라이브 배포 전까지 준비하면 되며, 없어도 로컬 개발이 가능하다.
> - `.env.example`에 `# optional-local` 주석으로 명시한다.
> - 로컬 인증 흐름: 프론트엔드가 게이트웨이 역할을 시뮬레이션 (`x-inface-api-key` + `Authorization: Web {token}` + `x-inface-user-uid` 직접 주입)

`.env.example` 파일을 확인하여 아래 검증을 실행한다:

```bash
# INSIGN 프로젝트 감지 — 로컬 개발 필수 변수 확인
IS_INSIGN=false
grep -qE "VITE_INFACE_WEB_AUTH|VITE_INFACE_ENV|VITE_GID|x-inface-user-uid" .env.example 2>/dev/null && IS_INSIGN=true

if [ "$IS_INSIGN" = "true" ]; then
  echo "=== INSIGN 프로젝트: 로컬 개발 필수 변수 검증 ==="

  # 1. INFACE_API_KEY — 로컬 optional, 스테이지/라이브 필수
  if grep -q "^INFACE_API_KEY=" .env.example 2>/dev/null; then
    if grep -q "optional-local" .env.example 2>/dev/null; then
      echo "✅ .env.example: INFACE_API_KEY 항목 존재 (optional-local 명시됨)"
    else
      echo "⚠️  .env.example: INFACE_API_KEY에 # optional-local 주석 추가 권장"
    fi
  else
    echo "⚠️  .env.example: INFACE_API_KEY 누락 — 추가 필요 (optional-local)"
    # .env.example에 INFACE_API_KEY 항목 추가
  fi

  # 2. VITE_INFACE_API_KEY — 프론트엔드 로컬 optional
  if grep -q "^VITE_INFACE_API_KEY=" .env.example 2>/dev/null; then
    echo "✅ .env.example: VITE_INFACE_API_KEY 항목 존재"
  else
    echo "⚠️  .env.example: VITE_INFACE_API_KEY 누락 — 추가 필요 (optional-local)"
  fi

  # 3. VITE_INFACE_WEB_AUTH — 로컬 도메인 필수
  if grep -q "^VITE_INFACE_WEB_AUTH=" .env.example 2>/dev/null; then
    echo "✅ .env.example: VITE_INFACE_WEB_AUTH 항목 존재"
  else
    echo "⚠️  .env.example: VITE_INFACE_WEB_AUTH 누락 — 추가 필요"
  fi

  # 4. BACKEND_URL self-proxy 위험 경고
  BACKEND_URL_VAL=$(grep "^BACKEND_URL=" .env.example 2>/dev/null | cut -d'=' -f2 | tr -d '"'"'" )
  if echo "$BACKEND_URL_VAL" | grep -qE "localhost:3000|127\.0\.0\.1:3000"; then
    echo "⚠️  .env.example: BACKEND_URL=${BACKEND_URL_VAL}"
    echo "    Next.js 기본 포트(3000)와 동일 → self-referencing proxy 위험"
    echo "    vite.config.ts proxy /api → 백엔드 포트(4000)로 설정 필요"
  fi
fi
```

누락 항목이 있으면 `.env.example`에 추가하고 사용자에게 안내한다:

```
📝 로컬 개발 환경변수 안내 (INSIGN 프로젝트 — InfaceTest 패턴)

.env.local에 아래 변수를 설정하세요:

  # ── INSIGN SDK (프론트엔드) ──────────────────────────────────
  VITE_INFACE_WEB_AUTH=local-{GNB_DOMAIN}  # required — 로컬 도메인 (mkcert 인증서 도메인과 일치)
  VITE_INFACE_ENV=test                      # required — test | pre | live
  VITE_INFACE_PLATFORM=krpc                 # required — krpc | jppc | arena_*
  VITE_INFACE_SDK_URL=https://signin.nexon.com/sdk/inface.js  # required
  VITE_INFACE_API_KEY=                      # optional-local — 없어도 로컬 동작 (스테이지 전 필수)
  VITE_APP_ENV=local                        # required
  VITE_API_BASE_URL=/api                    # required — vite proxy 경유

  # ── 백엔드 ───────────────────────────────────────────────────
  APP_ENV=local                             # required
  INFACE_API_KEY=                           # optional-local — 없으면 API Key 검증 생략됨
  PORT=4000                                 # required

로컬에서 INFACE_API_KEY 없이도 동작하는 이유:
  authMiddleware(APP_ENV=local)는 INFACE_API_KEY 환경변수가 설정된 경우에만 검증을 실행한다.
  미설정 시 x-inface-user-uid 헤더만 확인한다 (InfaceTest auth.ts 패턴).
```

---

## Step 3.7: prerequisites.md 정책 근거 검증 (할루시네이션 차단)

> **케이스 배경**: `docs/case-studies/step27-validation-gap.md` 4.7 장치 1.
> 메인 에이전트가 정책 문서를 읽지 않고 OAuth 표준 패턴(client_secret·redirect_uri 등)을
> INSIGN 프로젝트의 prerequisites.md에 ⬜로 추가하는 할루시네이션이 발견되었다.
> Step 4 발급 직전에 MCP 게이트로 근거 부재를 자동 차단한다.

### 3.7-1: 모든 🔴 차단 항목에 근거 필드 강제

prerequisites.md를 작성·갱신할 때 각 ⬜ 차단 항목 행은 다음 중 하나의 근거를 반드시 포함한다:

| 근거 패턴 | 예시 | 검증 방식 |
|---|---|---|
| 정책 문서 인용 | `근거: refs/policies/authentication-external.md` | 파일 존재 + 항목 키워드 grep 매치 |
| 사용자 입력 | `근거: 사용자 입력` | 추가 검증 없이 통과 |
| 운영 정책 / 사내 결정 | `근거: 운영 정책` | 추가 검증 없이 통과 |

**작성 절차 (모든 ⬜ 항목 강제):**

1. **키워드 검색 먼저**: 항목 추가 전에 `grep -niE "{항목 키워드}" refs/policies/authentication-*.md` 실행.
2. **검색 결과 0건**:
   - 항목이 실제로 필요한지 사용자에게 재확인.
   - 정책 문서 부재라면 `근거: 사용자 입력` 또는 `근거: 운영 정책`으로 명시.
   - **임의로 ⬜를 추가하지 않는다** — 검증 단계에서 자동 차단된다.
3. **검색 결과 ≥1건**: `근거: refs/policies/{file}.md` 필수 작성.

### 3.7-2: MCP `check_prerequisites_grounded` 자동 호출

Step 4(integration-ready.md 발급) 진입 전 다음을 실행한다:

```javascript
const result = await mcp__d2a-harness__check_prerequisites_grounded();
if (!result.ok) {
  // result.ungrounded 배열의 각 항목을 사용자에게 표시
  // ungrounded 항목이 1개라도 있으면 Step 4 진입 차단
  // 사용자에게 정책 근거를 보강하거나 사용자 입력으로 명시하도록 안내
}
```

ungrounded 항목 보고 형식:
```
🔴 정책 근거가 부족한 prerequisites 항목 발견:

specs/{NNN}/prerequisites.md:{line} — {text}
  └ {reason}

이 항목들은 다음 중 하나로 보강해주세요:
  A) 정책 문서에 근거가 있다면 `근거: refs/policies/{file}.md` 추가
  B) 사용자 정보라면 `근거: 사용자 입력` 추가
  C) 정책에 없는 추측이라면 항목 자체를 삭제

(이전 사례: docs/case-studies/step27-validation-gap.md 4.5)
```

### 3.7-3: auth_profile 키워드 블랙리스트 자동 검증

`state.json.auth_profile ∈ {insign, insign-with-nxas}`이면 `check_phase_gate(phase=0.5)`가
prerequisites.md / spec.md / decisions.md에서 다음 키워드 등장 시 차단한다:

- `redirect_uri`, `callback_url`, `Callback URL`, `client_secret`, `client_id`,
  `authorization_code`, `PKCE`

INSIGN은 `_ifwt` 쿠키 기반이라 OAuth 표준 용어는 거의 100% 추측. 등장 시 메인 에이전트는
`refs/policies/authentication-external.md`를 재확인하고 추측 항목을 제거해야 한다.

### 3.7-4: subagent-review 정책 컴플라이언스 자동 트리거 (선택)

`prerequisites.md` 항목이 10개 이상이거나 INSIGN/NXAS 혼용 프로젝트면 종료 직전
`Skill("subagent-review")` 로 정책 컴플라이언스 리뷰를 추가 실행한다.

```
.claude/skills/subagent-review.md Read 후 인라인 실행
리뷰 모드: --fast (Security + Architecture)
초점: prerequisites.md 항목별 정책 인용 정합성 + auth_profile 일관성
```

---

## Step 4: integration-ready.md 발급

모든 Smoke Test + 환경변수 검증 통과 후 `integration-ready.md`를 프로젝트 루트에 생성한다.

```markdown
# Integration Readiness Certificate

**발급일**: {YYYY-MM-DD HH:MM}
**프로젝트**: {프로젝트명}

## Smoke Test 결과

| 시스템 | 테스트 명령 | 결과 | 확인 일시 |
|---|---|---|---|
| {시스템} | `{명령}` | ✅ | {HH:MM} |

## 환경변수 상태

> `bash scripts/check-env.sh` 실행 결과 기반 (Step 3.5 통과 후 자동 생성)

| 변수 | 파일 | 상태 |
|---|---|---|
| {변수명} | .env.local | ✅ 설정됨 |

## 판정: ✅ AUTONOMOUS ZONE 진입 가능

> **GNB / INSIGN 사용 프로젝트 추가 안내**
> Phase 0.5(서버 연결) 이후 Phase 0.6(GNB 렌더링), Phase 0.7(INSIGN 로그인 플로우)을
> 순서대로 완료해야 Phase 1 구현을 시작할 수 있다.
> 각 Phase 태스크는 `tasks.md`의 Phase 0.6/0.7 섹션을 참조한다.
```

파일 생성 후 **HMAC 서명을 파일 끝에 추가한다** (위조 방지):

```bash
# HMAC 서명 — review-token-secret으로 서명하여 파일 위조를 탐지한다
# check_phase_gate가 서명을 검증하므로 이 단계를 생략하면 안 된다
if [ -f ".claude/review-token-secret" ]; then
  SECRET=$(cat .claude/review-token-secret)
  PROJECT_NAME=$(grep '^\*\*프로젝트\*\*:' integration-ready.md | head -1 | sed 's/\*\*프로젝트\*\*:[[:space:]]*//')
  ISSUED_DATE=$(grep '^\*\*발급일\*\*:' integration-ready.md | head -1 | sed 's/\*\*발급일\*\*:[[:space:]]*//')
  SIG=$(printf '%s:%s' "$PROJECT_NAME" "$ISSUED_DATE" | \
    openssl dgst -sha256 -hmac "$SECRET" -hex 2>/dev/null | awk '{print $NF}')
  if [ -n "$SIG" ]; then
    echo "" >> integration-ready.md
    echo "<!-- d2a-hmac: $SIG -->" >> integration-ready.md
    echo "✅ HMAC 서명 추가 완료 (위조 방지)"
  else
    echo "⚠️  HMAC 서명 생성 실패 — openssl 확인 필요. 서명 없이 계속 진행합니다."
  fi
else
  echo "ℹ️  .claude/review-token-secret 없음 — HMAC 서명 생략 (CI 환경 허용)"
fi
```

> **주의**: `review-token-secret`는 `.gitignore` 대상이므로 커밋되지 않는다.
> CI 환경에서 이 파일이 없으면 HMAC 서명이 생략되고 `check_phase_gate`도 검증을 건너뛴다(하위 호환).
> 로컬 개발에서는 항상 서명이 추가되어야 한다.

---

## Step 5: 완료 보고 및 문서 갱신

```
✅ 모든 외부 연동 준비 완료

integration-ready.md가 발급되었습니다.
```

state.json의 `integration_ready` 필드를 동기화한다 (MCP 필수):

```
mcp__d2a-harness__update_state({
  patch: { integration_ready: true }
})
```

이후 Phase 1로 진입한다:

```
Skill("run-phase", "1")
# 방안 A: GNB/INSIGN 브라우저 검증은 React 앱 구현 단계(create-spec Step 2.7)에서 완료됨.
# Phase 0.5 완료 후 항상 Phase 1으로 직행한다.
# Phase 0.6/0.7 섹션이 tasks.md에 존재하더라도 건너뛴다 (이미 Step 2.7에서 통합 검증 완료).
```

**갱신 대상:**
- `prerequisites.md`: 모든 항목 ✅ 상태 확인
- `refs/collaboration-tracker.md`: 수집 결과 기록
- `PROGRESS.md`: ✅ 외부 연동 준비 완료로 갱신
- `tasks.md`: Phase 0.5의 collect-prerequisites 태스크 ☑ 마킹
  - run-phase에서 `get_next_task`가 반환한 태스크 ID를 사용한다
  - 직접 호출 시에는 tasks.md에서 Phase 0.5의 첫 번째 태스크 ID를 파싱하여 사용:
    ```bash
    PREREQ_TASK_ID=$(python3 -c "
    import re
    content = open('tasks.md').read()
    lines = content.split('\n')
    in_phase = False
    for line in lines:
        ph = re.match(r'^##\s+Phase\s+([\d.]+)', line)
        if ph:
            in_phase = (float(ph.group(1)) == 0.5)
        if in_phase:
            m = re.match(r'^###\s+(T\S+)\s*:', line)
            if m:
                print(m.group(1))
                break
    " 2>/dev/null || echo "T051")
    ```

```bash
./scripts/log-activity.sh SETUP "외부 연동 검증 완료" "모든 항목 ✅" || true
./scripts/notify-slack.sh "✅ 외부 연동 준비 완료" "integration-ready.md 발급\nPhase 1 시작 가능" || true
```
