---
name: subagent-review
description: 구현 완료 후 서브에이전트를 병렬 실행하여 코드 리뷰. 코드 리뷰, 피드백 루프 실행, Phase 완료 리뷰 요청 시 사용.
---

# subagent-review

구현 완료 후 **서브에이전트를 병렬로 실행**하여 코드를 리뷰한다.

> **`Skill()` 제약 안내**: AI가 `Skill("subagent-review")`를 자율 호출하면 "Unknown skill" 오류가 발생할 수 있다.
> 이 파일은 `Read(".claude/skills/subagent-review.md")`로 읽은 뒤 **인라인 실행**하는 방식으로 동작한다.
> `/run-phase` Step 3, `/session-phase-workflow` Part D·E 모두 이 방식을 사용한다.

> **Claude Code 구현**: Claude Code의 `Agent` 도구를 사용한다.
> 각 서브에이전트는 `subagent_type: "general-purpose"` 로 병렬 실행한다.

## 실행 모드

| 모드 | 리뷰어 | 사용 시점 |
|---|---|---|
| `--full` (기본) | Security, Performance, Architecture, Spec Fidelity, Accessibility, Feature Behavior (6명) | Phase 경계 리뷰, 배포 전 최종 점검 |
| `--fast` | Security, Architecture (2명) | 세션 중간 빠른 점검, 3개 미만 파일 변경 |
| `--security` | Security (1명) | 보안 관련 코드만 변경 시 |
| `--spec` | Spec Fidelity (1명) | 문서↔코드 일치 확인만 필요할 때 |

---

## 트리거

- "코드 리뷰해줘"
- "피드백 루프 실행"
- "서브에이전트 리뷰"
- Phase 경계 도달 시 (`/run-phase` Step 3 또는 `/session-phase-workflow` Part B에서 호출)

---

## Step 1: 모드 결정 및 리뷰 범위 확인

### 1-1. 모드와 실행 리뷰어 목록 확정

사용자 요청에서 모드 힌트를 파악한다:

| 요청 패턴 | 선택 모드 | 실행 리뷰어 |
|---|---|---|
| "코드 리뷰", "Phase 리뷰", 기본 | `--full` | 6명 전원 |
| "빠른 리뷰", "중간 점검" | `--fast` | Security + Architecture |
| "보안만", "보안 확인" | `--security` | Security만 |
| "스펙 맞는지", "문서 확인" | `--spec` | Spec Fidelity만 |

변경 파일이 3개 이하이고 사용자가 모드를 명시하지 않았으면 `--fast`를 적용한다.
단, **T{N}-review 태스크에서 호출된 경우(Phase 경계 리뷰)는 파일 수에 관계없이 `--full`을 유지한다.**
T{N}-review 여부 판별:
```bash
CURRENT_TASK=$(python3 -c "
import json, sys
try:
    d = json.load(open('.claude/state.json'))
    print(d.get('current_task', ''))
except:
    print('')
" 2>/dev/null || echo "")
echo "$CURRENT_TASK" | grep -qE '^[Tt][0-9]+-review$' && IS_PHASE_BOUNDARY=true || IS_PHASE_BOUNDARY=false
```

### 1-2. 리뷰 대상 파일 확인

Phase 경계 커밋을 기준으로 변경 파일을 추출한다.

```bash
# 현재 Phase 번호를 state.json에서 읽는다
CURRENT_PHASE=$(python3 -c "
import json, sys
try:
    d = json.load(open('.claude/state.json'))
    print(int(d.get('phase', 1)))
except:
    print(1)
" 2>/dev/null || echo "1")
PREV_PHASE=$((CURRENT_PHASE - 1))

# Phase N-1 완료 커밋(현재 Phase의 시작점)을 찾는다
# NR==1은 가장 최근 커밋을 반환하므로, 이전 Phase 완료 패턴으로 명시적 검색
if [ "$PREV_PHASE" -ge 1 ]; then
  PHASE_START_COMMIT=$(git log --oneline | grep -E "Phase ${PREV_PHASE} 완료" | head -1 | awk '{print $1}')
else
  PHASE_START_COMMIT=""
fi

# 없으면 직전 커밋 기준으로 fallback
if [ -z "$PHASE_START_COMMIT" ]; then
  PHASE_START_COMMIT="HEAD~1"
fi

# 변경 파일 목록
git diff --name-only "${PHASE_START_COMMIT}" HEAD | sort
```

리뷰 대상: `.py`, `.ts`, `.tsx`, `.js`, `.jsx`, `.toml`, `.json`, `.yaml`
제외: `.md`, `tests/`, lock 파일, 자동 생성 파일

변경 파일 수가 0이면 "리뷰할 소스 코드 변경 없음"을 출력하고 종료한다.

`.review-suppress.yaml`이 있으면 읽어서 suppress 항목을 파싱한다.

**스프린트 컨트랙트 로드**: `.claude/review-contracts/phase-{N}.md`가 존재하면 읽는다.
컨트랙트 파일의 "이번 Phase에서 의도적으로 포함하지 않는 범위" 섹션을 각 서브에이전트 프롬프트에 추가하여 범위 밖 항목의 오탐을 방지한다.
파일이 없으면 컨트랙트 없이 진행한다 (하위 호환성 유지).

```bash
REVIEWER_COUNT=$([ "$MODE" = "--full" ] && echo 6 || echo 2)
./scripts/log-activity.sh REVIEW "Phase {N} 리뷰 시작" "${MODE:-full} 모드 / 리뷰어 ${REVIEWER_COUNT}명" || true
./scripts/notify-slack.sh "🔍 Phase {N} 리뷰 시작" "${MODE:-full} 모드 / 리뷰어 ${REVIEWER_COUNT}명 병렬 실행" || true
```

### 1-3. Typed Context Object 구성

**표준 파일 분류 규칙** (Step 4에서도 동일하게 재사용):

```
ReviewContext = {
  // 공통 (모든 리뷰어에게 전달)
  common: {
    changed_files: [정렬된 변경 파일 경로 목록],
    phase: {현재 Phase 번호},
    suppress_rules: {.review-suppress.yaml 내용 또는 "없음"}
  },

  // Security 전용
  security: {
    auth_files: [인증·인가 관련 파일],
    api_routes: [엔드포인트 파일],
    env_files: [.env.example 경로],
    security_policy: "refs/policies/security.md 경로"
  },

  // Performance 전용
  performance: {
    db_files: [ORM/쿼리 관련 파일],
    frontend_files: [렌더링·번들 관련 파일],
    api_files: [응답 크기·캐싱 관련 파일]
  },

  // Architecture 전용
  architecture: {
    layer_files: {
      api: [API 레이어 파일],
      service: [Service 레이어 파일],
      repository: [Repository 레이어 파일]
    },
    observability_files: [로그 설정·로거 모듈·헬스체크·미들웨어·트레이싱 관련 파일],
    arch_policy: "CLAUDE.md 아키텍처 원칙 (레이어 분리, SOLID, DRY)"
  },

  // Spec Fidelity 전용
  spec: {
    spec_file: "specs/{NNN}/spec.md",
    tasks_file: "tasks.md (해당 Phase 섹션)",
    test_files: [테스트 파일 목록]
  },

  // Accessibility 전용
  accessibility: {
    frontend_files: [HTML/JSX/TSX 파일],
    css_files: [스타일 파일]
  },

  // Feature Behavior 전용
  feature_behavior: {
    api_files: [라우터·컨트롤러·핸들러 파일],
    service_files: [Service·UseCase 레이어 파일],
    frontend_files: [컴포넌트·페이지·hook·API 호출 파일],
    spec_file: "specs/{NNN}/spec.md"
  }
}
```

**표준 파일 분류 기준** (경로 패턴 매칭):

```
- 경로에 auth, login, session, middleware 포함           → security.auth_files
- 경로에 model, repository, orm, query, db 포함          → performance.db_files + architecture.repository
- 경로에 route, controller, handler, api 포함            → security.api_routes + architecture.api + feature_behavior.api_files
- 경로에 service, usecase 포함                           → architecture.service + feature_behavior.service_files
- 경로에 .tsx, .jsx, .css, .scss, .html 포함             → accessibility.frontend_files
- 경로에 component, page, view, hook, store, context 포함
  또는 .tsx/.jsx 확장자                                   → feature_behavior.frontend_files
- 경로에 log, logger, logging, health, monitor, metric,
  trace, telemetry 포함                                   → architecture.observability_files
```

---

## Step 2: 통합 테스트 + 서브에이전트 병렬 실행

### 2-0. 통합 테스트 실행

정적 분석(Step 2-1)과 독립적인 동적 검증. 에이전트 실행 전에 미리 결과를 수집하여 Step 3에서 함께 취합한다.

```bash
# 백엔드: pytest integration 디렉터리 확인
ls tests/integration/ 2>/dev/null && echo "BE_EXISTS" || echo "BE_NONE"
jq -r '.scripts["test:integration"] // empty' package.json 2>/dev/null

# 프론트엔드: E2E 설정 파일 및 스크립트 확인
ls playwright.config.* cypress.config.* 2>/dev/null && echo "FE_E2E_EXISTS" || echo "FE_E2E_NONE"
jq -r '.scripts["test:e2e"] // .scripts["test:integration"] // empty' \
  frontend/package.json package.json 2>/dev/null | head -1

# 변경 파일 중 프론트엔드 파일 존재 여부 (FE 변경 판별)
echo "{context.common.changed_files}" | grep -E '\.(tsx|jsx|vue|svelte)$' \
  && echo "FE_CHANGED" || echo "FE_NOT_CHANGED"

# Phase 경계 여부 판별 (IS_PHASE_BOUNDARY: Step 1-1에서 이미 설정된 값 재사용)
# IS_PHASE_BOUNDARY=true 이면 T{N}-review 태스크에서 호출된 것
```

**판정 로직:**

| 상황 | 처리 |
|---|---|
| 백엔드 통합 테스트 없음 | `[WARN] 백엔드 통합 테스트 없음 — 추가 권장` 기록 후 2-1 진행 |
| 백엔드 통합 테스트 존재 | 아래 실행 후 결과를 TEST_RESULTS 변수에 저장 |
| **Phase 경계(`IS_PHASE_BOUNDARY=true`) + FE 파일 변경 + E2E 미설정** | **`[Blocker(즉시수정)] E2E 미설정` — Step 3에 Blocker로 전달, Phase 완료 차단** |
| 일반 리뷰(`IS_PHASE_BOUNDARY=false`) + FE 파일 변경 + E2E 미설정 | `[REQUIRED] E2E 미설정` — Step 3에 Required로 전달 (2-1은 계속 진행) |
| FE 파일 변경 있음 + E2E 존재 | 아래 실행 후 결과를 TEST_RESULTS 변수에 저장 |
| FE 파일 변경 없음 + E2E 없음 | `[WARN] E2E 미설정` 기록 후 2-1 진행 |
| FE 파일 변경 없음 + E2E 존재 | `[INFO] E2E 설정 있음, FE 변경 없어 스킵` 기록 후 2-1 진행 |
| 실행 불가 (서버 미기동 등) | `[WARN] 통합 테스트 환경 미구성` 기록 후 2-1 진행 |

**Phase 경계 + FE 변경 + E2E 미설정** 시 Step 3에 전달할 항목:
```
[Blocker(즉시수정) — E2E 미설정] — Phase 경계 리뷰: 프론트엔드 변경이 있으나 E2E 테스트 미구성
  기대 동작: playwright.config.ts 또는 cypress.config.* 존재 + package.json test:e2e 스크립트
  실제 상태: E2E 설정 파일 없음
  수정 방안: boilerplate-setup Stage 2-E 실행 또는 npx playwright init 후 tests/e2e/ 작성
  자동 수정 가능: no
```

**일반 리뷰 + FE 변경 + E2E 미설정** 시 Step 3에 전달할 항목:
```
[REQUIRED — E2E 미설정] — 프론트엔드 파일 변경이 있으나 E2E 테스트가 구성되지 않음
  기대 동작: playwright.config.ts 또는 cypress.config.* 존재 + package.json test:e2e 스크립트
  실제 상태: E2E 설정 파일 없음
  수정 방안: boilerplate-setup Stage 2-E 실행 또는 npx playwright init 후 tests/e2e/ 작성
  자동 수정 가능: no
```

존재하면 실행:
```bash
# 백엔드 (Python)
pytest tests/integration/ -v --tb=short 2>&1 | tail -60

# 백엔드 (Node.js)
npm run test:integration 2>&1 | tail -60

# 프론트엔드 E2E (설정 존재 확인 후)
npx playwright test --reporter=line 2>&1 | tail -60
```

**Phase 경계 E2E 커버리지 대조 (IS_PHASE_BOUNDARY=true일 때만 실행):**

현재 Phase의 프론트엔드 태스크 중 e2e spec이 없는 태스크를 감지한다.

```bash
# tasks.md에서 현재 Phase의 FE 태스크 목록 추출 (write에 .tsx/.jsx/.vue/.svelte 포함)
# Phase 번호는 state.json의 phase 값 사용
python3 - <<'PYEOF'
import re, json, os, sys

# state.json에서 Phase 번호 읽기
try:
    with open('.claude/state.json') as f:
        phase = int(json.load(f).get('phase', 1))
except:
    phase = 1

# tasks.md 읽기 (파일 없으면 종료)
tasks_files = [f for f in ['tasks.md', 'specs/.template/tasks.md'] if os.path.exists(f)]
if not tasks_files:
    sys.exit(0)

with open(tasks_files[0]) as f:
    content = f.read()

# 현재 Phase 섹션 추출 (## Phase N: ~ ## Phase N+1:)
phase_pattern = rf'## Phase {phase}:.*?(?=## Phase {phase+1}:|$)'
phase_match = re.search(phase_pattern, content, re.DOTALL)
if not phase_match:
    sys.exit(0)
phase_section = phase_match.group(0)

# FE 태스크: write 필드에 .tsx/.jsx/.vue/.svelte 포함하는 태스크
fe_tasks = []
task_blocks = re.split(r'(?=### T)', phase_section)
for block in task_blocks:
    task_id_match = re.match(r'### (T\S+):', block)
    if not task_id_match:
        continue
    task_id = task_id_match.group(1)
    write_match = re.search(r'\*\*write\*\*:\s*(.+?)(?=\*\*|\Z)', block, re.DOTALL)
    if write_match and re.search(r'\.(tsx|jsx|vue|svelte)', write_match.group(1)):
        # e2e spec이 write에 포함되어 있는지 확인
        has_e2e = bool(re.search(r'tests/e2e/', write_match.group(1)))
        fe_tasks.append({'id': task_id, 'has_e2e_in_write': has_e2e})

# 실제 tests/e2e/ 디렉터리 파일 목록
e2e_specs = set()
if os.path.isdir('tests/e2e'):
    e2e_specs = {f for f in os.listdir('tests/e2e') if f.endswith('.spec.ts') or f.endswith('.spec.js') or f.endswith('.cy.ts')}

print(f"FE_TASKS_TOTAL={len(fe_tasks)}")
for t in fe_tasks:
    print(f"TASK_ID={t['id']} HAS_E2E_IN_WRITE={t['has_e2e_in_write']}")
print(f"E2E_SPECS_COUNT={len(e2e_specs)}")
print(f"E2E_SPECS={','.join(sorted(e2e_specs))}")

# 커버리지 누락 태스크 (write에 e2e spec 없는 FE 태스크)
missing = [t['id'] for t in fe_tasks if not t['has_e2e_in_write']]
if missing:
    print(f"E2E_COVERAGE_MISSING={','.join(missing)}")
else:
    print("E2E_COVERAGE_MISSING=")
PYEOF
```

판정 로직:
- `E2E_COVERAGE_MISSING`에 태스크 ID가 있으면 → 아래 항목을 Step 3에 추가
- `IS_PHASE_BOUNDARY=true` → **`[Blocker(즉시수정)]`**로 전달 (Phase 완료 차단)
- `IS_PHASE_BOUNDARY=false` → **`[REQUIRED]`**로 전달

```
[Blocker(즉시수정) — E2E 커버리지 누락] Phase {N} 프론트엔드 태스크 중 e2e spec 없는 태스크 존재
  누락 태스크: {E2E_COVERAGE_MISSING 목록}
  기대 동작: 각 FE 태스크의 write 필드에 tests/e2e/{feature}.spec.ts 포함,
             done 필드에 cmd: npx playwright test tests/e2e/{feature}.spec.ts 포함
  실제 상태: 해당 태스크에 e2e spec write/done 기준 없음
  수정 방안: tasks.md 해당 태스크에 tests/e2e/{feature}.spec.ts write 추가 후 spec 파일 작성
  자동 수정 가능: no
```

단, `smoke.spec.ts` 한 개만 존재하고 FE 태스크가 2개 이상인 경우도 커버리지 부족으로 동일하게 처리한다:
```bash
# smoke.spec.ts / runtime-health.spec.ts 만 존재 + FE 태스크 2개 이상 = 커버리지 불충분 경고
# (runtime-health 는 항상 존재하는 게이트 spec 이므로 기능 커버리지 카운트에서 제외)
if [ "$(echo "$E2E_SPECS" | tr ',' '\n' | grep -cvE 'smoke|runtime-health')" -eq 0 ] && [ "$FE_TASKS_TOTAL" -ge 2 ]; then
  echo "E2E_SMOKE_ONLY_WARNING=true"
fi
```

**HTTPS 인증서 사전 체크 (`IS_PHASE_BOUNDARY=true` + FE 변경 시):**

런타임 헬스체크는 HTTPS 표준(`https://${LOCAL_DEV_HOST}`)에서 동작하므로,
[boilerplate-setup.md](../skills/boilerplate-setup.md) Stage 1.6 의 인증서·Caddy 셋업이 완료되어 있어야 한다.

```bash
# .env.example 에서 LOCAL_DEV_HOST 추출 — awk 로 첫 매칭 라인의 값만 정확히 추출
# (cut/tr 조합은 값에 = 또는 따옴표가 포함될 때 부정확)
extract_env_value() {
  local key="$1"; shift
  for f in "$@"; do
    [ -f "$f" ] || continue
    local v
    v=$(awk -F= -v k="$key" '
      $0 ~ "^"k"=" {
        sub(/^[^=]*=/, "")
        gsub(/^[ \t]*["'\'']|["'\''][ \t]*$/, "")
        print
        exit
      }
    ' "$f")
    if [ -n "$v" ]; then echo "$v"; return; fi
  done
}

LOCAL_DEV_HOST=$(extract_env_value LOCAL_DEV_HOST frontend/.env.example .env.example 2>/dev/null)

# 화이트리스트 검증 — 추출된 값이 셸 메타문자·공백 등을 포함할 경우 즉시 차단
if [ -n "$LOCAL_DEV_HOST" ] && ! [[ "$LOCAL_DEV_HOST" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
  echo "HTTPS_HOST_INVALID=$LOCAL_DEV_HOST"
  LOCAL_DEV_HOST=""
fi

if [ "$IS_PHASE_BOUNDARY" = "true" ] && [ -n "$LOCAL_DEV_HOST" ]; then
  # 인증서 파일 존재 확인 (frontend/ 또는 root)
  CERT_FOUND=""
  for d in frontend .; do
    if [ -f "$d/$LOCAL_DEV_HOST.pem" ] && [ -f "$d/$LOCAL_DEV_HOST-key.pem" ]; then
      CERT_FOUND="$d"
      break
    fi
  done

  if [ -z "$CERT_FOUND" ]; then
    echo "HTTPS_CERT_MISSING=true"
  fi

  # /etc/hosts 등록 확인
  if ! grep -qE "[[:space:]]$LOCAL_DEV_HOST($|[[:space:]])" /etc/hosts; then
    echo "HTTPS_HOSTS_MISSING=true"
  fi

  # Caddy 데몬 실행 확인 (macOS 한정)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! sudo brew services list 2>/dev/null | grep -qE '^caddy[[:space:]]+started'; then
      echo "HTTPS_CADDY_NOT_RUNNING=true"
    fi
  fi
fi

# 인증 storageState 가드 (create-spec Step 2.7 통합 검증 산출물)
# 인증 프로젝트 판별: tests/e2e/fixtures/auth-mock.ts 파일 존재 여부
# (Stage 2-E 가 AUTH_MODE != 'none' 일 때만 fixture 를 생성하므로 신뢰 가능한 시그널)
AUTH_FIXTURE="tests/e2e/fixtures/auth-mock.ts"
STORAGE_FILE="tests/e2e/.auth/user.json"

if [ "$IS_PHASE_BOUNDARY" = "true" ] \
   && [ -f "$AUTH_FIXTURE" ] \
   && [ "$HAS_FE_CHANGED" -gt 0 ]; then
  if [ ! -f "$STORAGE_FILE" ]; then
    echo "AUTH_STORAGE_MISSING=true"
  else
    # 정책(authentication-external.md A-4b): 세션 만료는 INSIGN/GNB 서버 측 관리.
    # 따라서 파일 mtime 이 아니라 storageState 안의 인증 쿠키 `expires` 가 단일 신뢰원이다.
    # mtime 30일은 보조 안전망으로만 사용한다.
    # node 인라인 보간 위험 회피 — 환경변수로 파일 경로 전달.
    AUTH_STATUS=$(STORAGE_FILE="$STORAGE_FILE" node -e '
      const fs = require("fs");
      try {
        const state = JSON.parse(fs.readFileSync(process.env.STORAGE_FILE, "utf8"));
        const cookies = state.cookies || [];
        const authNames = ["_ifwt", "NXAS_TOKEN", "access_token", "authToken", "next-auth.session-token"];
        const auth = cookies.filter(c => c.name && authNames.some(n => c.name.toLowerCase().includes(n.toLowerCase())));
        if (auth.length === 0) { console.log("NO_AUTH_COOKIE"); process.exit(0); }

        // Playwright 는 세션 쿠키를 expires 없음/-1/0 으로 직렬화한다 → 브라우저 종료 시 만료 = stale
        const persistent = auth.filter(c => typeof c.expires === "number" && c.expires > 0);
        if (persistent.length === 0) { console.log("SESSION_ONLY"); process.exit(0); }

        const now = Math.floor(Date.now() / 1000);
        const maxExp = Math.max(...persistent.map(c => c.expires));
        if (maxExp < now) { console.log("EXPIRED:" + Math.floor((now - maxExp) / 86400)); process.exit(0); }

        // 안전망 — 서버 측 만료를 캡처하지 못할 가능성이 있으므로 파일 자체가 너무 오래되면 갱신
        const ageDays = Math.floor((Date.now() - fs.statSync(process.env.STORAGE_FILE).mtimeMs) / 86_400_000);
        if (ageDays > 30) { console.log("STALE_FILE:" + ageDays); process.exit(0); }

        const remainingDays = Math.floor((maxExp - now) / 86400);
        console.log("VALID:" + remainingDays);
      } catch (e) { console.log("INVALID"); }
    ' 2>/dev/null || echo "INVALID")

    case "$AUTH_STATUS" in
      VALID:*)         ;;  # 정상
      NO_AUTH_COOKIE)  echo "AUTH_STORAGE_STALE=no_auth_cookie" ;;
      SESSION_ONLY)    echo "AUTH_STORAGE_STALE=session_only" ;;
      EXPIRED:*)       echo "AUTH_STORAGE_STALE=expired_${AUTH_STATUS#EXPIRED:}d" ;;
      STALE_FILE:*)    echo "AUTH_STORAGE_STALE=file_age_${AUTH_STATUS#STALE_FILE:}d" ;;
      INVALID|*)       echo "AUTH_STORAGE_STALE=invalid" ;;
    esac
  fi
fi
```

판정 로직 (어느 하나라도 set 이면 **`[Blocker(즉시수정)]`** Phase 경계 차단):

```
[Blocker(즉시수정) — HTTPS 인증서 누락] ${LOCAL_DEV_HOST} 의 mkcert 인증서가 없음
  원인: Stage 1.6 의 setup-https.sh 가 실행되지 않았음
  사용자 조치 (sudo 1회):
    ./scripts/setup-https.sh ${LOCAL_DEV_HOST} frontend
  자동 수정 가능: no
```

```
[Blocker(즉시수정) — /etc/hosts 미등록] ${LOCAL_DEV_HOST} → 127.0.0.1 매핑 없음
  사용자 조치 (sudo 1회):
    sudo sh -c 'echo "127.0.0.1  ${LOCAL_DEV_HOST}" >> /etc/hosts'
    sudo dscacheutil -flushcache
  또는 setup-https.sh 재실행 (자동 추가)
  자동 수정 가능: no
```

```
[Blocker(즉시수정) — Caddy 데몬 미실행] 443 게이트키퍼 가 동작하지 않음
  사용자 조치 (sudo 1회):
    sudo brew services start caddy
  자동 수정 가능: no
```

```
[Blocker(즉시수정) — 인증 storageState 누락]
  원인: tests/e2e/.auth/user.json 이 없습니다.
        create-spec Step 2.7 의 통합 검증 (save-auth-state.sh) 이 실행되지 않았거나 파일이 삭제되었습니다.
  설명: INSIGN/NXAS/custom 프로젝트는 로컬 로그인 연동을 매 Phase 마다 검증합니다.
  
  ─── 복구 절차 (3단계) ───
  ① 별도 터미널 1 — 프론트 dev 서버:
       cd frontend && npm run dev -- --port ${LOCAL_DEV_PORT}
  ② 별도 터미널 2 — (백엔드 콜백 처리가 필요한 경우):
       cd backend && {백엔드 dev 명령}
  ③ 메인 터미널 — Playwright 헤드풀 브라우저로 UI 확인 + 실제 로그인 + storageState 저장 (1회 통합):
       ./scripts/save-auth-state.sh https://${LOCAL_DEV_HOST}
       → 브라우저에서 INSIGN/NXAS 로그인 후 창을 닫으면 자동 저장됩니다.
  
  완료 후 같은 Phase 를 다시 진입하면 자동 검증이 재개됩니다.
  자동 수정 가능: no (사용자 자격증명 필요)
```

```
[Blocker(즉시수정) — 인증 storageState 만료]
  원인(${AUTH_STORAGE_STALE} 사유):
    no_auth_cookie  : 파일에 _ifwt/NXAS_TOKEN 등 인증 쿠키가 없음 (로그인 미완료)
    session_only    : 인증 쿠키가 모두 브라우저 세션 쿠키 (expires 없음/-1)
                      → 정책(authentication-external.md A-4b): INSIGN/GNB 서버 만료 관리.
                      → 세션 쿠키는 브라우저 종료 시 만료되므로 다음 실행에서 무효.
    expired_Nd      : 인증 쿠키 expires 가 이미 지났음 (N일 경과)
    file_age_Nd     : 파일 자체가 30일 한도 초과 (보조 안전망)
    invalid         : 파일 파싱 실패
  
  ─── 갱신 절차 (위 누락 절차와 동일) ───
  ① cd frontend && npm run dev               (별도 터미널)
  ② ./scripts/save-auth-state.sh https://${LOCAL_DEV_HOST}
     → 기존 파일을 자동 덮어씁니다 (rm 불필요).
  
  자동 수정 가능: no (사용자 재로그인 필요)
```

**런타임 헬스체크 가드 (HTTPS 사전 체크 통과 후 실행):**

빌드 통과 ≠ 런타임 통과의 갭을 차단하기 위해 `runtime-health.spec.ts` 존재와 통과를 검증한다.
이 spec 은 [boilerplate-setup.md](../skills/boilerplate-setup.md) Stage 2-E 가 자동 생성한다.

**ROUTES 자동 갱신 + state.json/.env.example 동기화 (런타임 헬스체크 실행 전):**

Phase 경계마다 다음 두 스크립트를 호출하여 셋업 상태를 최신으로 유지:

1. `scripts/extract-routes.sh` — spec.md/PRD 변경 → `runtime-health.spec.ts` 의 ROUTES 갱신
2. `scripts/sync-state-to-env.sh` — `state.json` 값을 `.env.example` 에 반영
   (사용자가 `.env.example` 을 수동 변경했어도 state.json 이 source of truth)

```bash
# pipefail 활성화 — 파이프 중간 실패가 silent 통과되는 것을 차단
set -o pipefail

# ROUTES 자동 갱신 (실패 시 Advisory 로 Step 3 에 보고)
if [ -x scripts/extract-routes.sh ] && [ -f tests/e2e/runtime-health.spec.ts ]; then
  if ! ./scripts/extract-routes.sh 2>&1 | tail -3; then
    echo "ROUTES_UPDATE_FAILED=true"
  fi
fi

# state.json / .env.example 일치성 우선 검사 → 불일치 시 사용자 알림 후 동기화
if [ -x scripts/sync-state-to-env.sh ]; then
  if ! ./scripts/sync-state-to-env.sh --check 2>&1 | tail -3; then
    # 불일치 발견 — Advisory 로 Step 3 에 전달하고 자동 동기화 진행
    echo "ENV_SYNC_MISMATCH_DETECTED=true"
    ./scripts/sync-state-to-env.sh 2>&1 | tail -3 || echo "ENV_SYNC_FAILED=true"
  fi
fi

set +o pipefail
```

판정 (Step 3 에 Advisory 로 추가):

```
[Advisory — ROUTES 자동 갱신 실패] scripts/extract-routes.sh 가 비정상 종료
  영향: runtime-health 가 stale 한 ROUTES 로 실행 → 새 라우트 회귀 미감지
  조치: ./scripts/extract-routes.sh --dry-run 으로 출력 확인 후 수동 수정
```

```
[Advisory — .env.example 자동 갱신] 사용자가 .env.example 의 LOCAL_DEV_HOST/PORT 등을 수동 변경했으나
  state.json 값으로 회귀되었습니다 (state.json 이 source of truth — 의도된 동작).
  사용자 의도가 다르면 ./scripts/change-auth-profile.sh 로 정식 변경 후 boilerplate-setup 재실행.
```

```bash
# 런타임 헬스체크 가드 — Phase 경계 + FE 변경 + E2E 설정이 모두 충족된 경우에만 실행
HAS_FE_E2E_CONFIG=$(ls frontend/playwright.config.* playwright.config.* frontend/cypress.config.* cypress.config.* 2>/dev/null | head -1)
HAS_FE_CHANGED=$(echo "{context.common.changed_files}" | grep -cE '\.(tsx|jsx|vue|svelte)$' || true)

# 런타임 헬스체크 spec 위치 — 프로젝트 루트의 tests/e2e/ 가 표준
RUNTIME_HEALTH_SPEC=""
if [ -f tests/e2e/runtime-health.spec.ts ]; then
  RUNTIME_HEALTH_SPEC="tests/e2e/runtime-health.spec.ts"
elif [ -f tests/e2e/runtime-health.cy.ts ]; then
  RUNTIME_HEALTH_SPEC="tests/e2e/runtime-health.cy.ts"
fi

if [ "$IS_PHASE_BOUNDARY" = "true" ] && [ "$HAS_FE_CHANGED" -gt 0 ] && [ -n "$HAS_FE_E2E_CONFIG" ]; then
  if [ -z "$RUNTIME_HEALTH_SPEC" ]; then
    echo "RUNTIME_HEALTH_MISSING=true"
  else
    # config 위치(frontend/ 또는 root)에 따라 실행 디렉터리·spec 경로를 분기
    # — Stage 2-E 표준: config는 frontend/, spec은 root tests/e2e/
    # — 단일 root 구조: config·spec 모두 root
    HEALTH_DIR=$(dirname "$HAS_FE_E2E_CONFIG")
    if [ "$HEALTH_DIR" = "frontend" ]; then
      HEALTH_SPEC_REL="../$RUNTIME_HEALTH_SPEC"
    else
      HEALTH_SPEC_REL="$RUNTIME_HEALTH_SPEC"
    fi

    (cd "$HEALTH_DIR" && npx playwright test "$HEALTH_SPEC_REL" --reporter=line) 2>&1 | tee /tmp/runtime-health.log | tail -30
    HEALTH_EXIT=${PIPESTATUS[0]}
    if [ "$HEALTH_EXIT" -ne 0 ]; then
      echo "RUNTIME_HEALTH_FAILED=true"
    fi
  fi
fi
```

판정 로직:
- `RUNTIME_HEALTH_MISSING=true` → **`[Blocker(즉시수정)]`** Phase 경계 차단
- `RUNTIME_HEALTH_FAILED=true` → **`[Blocker(즉시수정)]`** Phase 경계 차단

```
[Blocker(즉시수정) — 런타임 헬스체크 누락] tests/e2e/runtime-health.spec.ts 없음
  기대 동작: dev 서버 기동 후 핵심 라우트 방문 시 콘솔 에러·네트워크 4xx/5xx 0건
  실제 상태: runtime-health.spec.ts 파일이 존재하지 않음
  수정 방안: boilerplate-setup Stage 2-E 재실행하여 자동 생성하거나,
            tests/e2e/runtime-health.spec.ts 를 직접 작성한다
            (Stage 2-E 의 표준 템플릿 참조)
  자동 수정 가능: no
```

```
[Blocker(즉시수정) — 런타임 헬스체크 실패] tests/e2e/runtime-health.spec.ts 통과 실패
  기대 동작: 콘솔 에러 0건, 네트워크 4xx/5xx 0건
  실제 상태: {/tmp/runtime-health.log 의 실패 메시지 요약}
  수정 방안: 실패 로그의 콘솔/네트워크 에러를 코드에서 직접 수정.
            대표 패턴: SSR/CSR 하이드레이션 불일치, 환경변수 누락,
                      옵셔널 체이닝 누락, dynamic import 경로 오타
  자동 수정 가능: yes (메인 에이전트가 Step 4 에서 수정)
```

> **로그인이 필요한 프로젝트 주의**: `runtime-health.spec.ts` 는 인증이 필요 없는 공개 라우트만 대상으로 한다.
> 보호 라우트의 런타임 검증은 별도 spec 에서 `tests/e2e/fixtures/auth-mock.ts` 의 `authenticatedPage` fixture 를 사용한다.
> 이 fixture 는 INSIGN(`_ifwt`) / NXAS(Bearer) / 자체 인증(JWT·세션·NextAuth 등) 3가지 모드를 모두 지원하며,
> boilerplate-setup Stage 2-E 에서 프로젝트의 인증 시그널을 자동 감지해 기본 모드를 설정한다.
> 실제 토큰/쿠키 발급 흐름의 검증은 `pre-launch-check` 의 auth-smoke 단계에서 수행한다.

실패 케이스는 CRITICAL 항목으로 Step 3에 전달:
```
[CRITICAL — 통합 테스트] {파일}::{테스트명} — 실패
  에러: {출력 요약}
  수정 방안: {원인에 따른 방법}
  자동 수정 가능: no
```

```bash
# 실패가 있는 경우에만 슬랙 알림
./scripts/log-activity.sh BUILD "통합 테스트 실행" "통과: N건 / 실패: M건" || true
./scripts/notify-slack.sh "🔴 통합 테스트 실패" "실패: M건\n{실패 케이스 요약}" || true
```

### 2-1. 서브에이전트 병렬 실행

Step 1에서 확정된 실행 리뷰어의 프롬프트 템플릿을 Read한 뒤 Agent 도구로 병렬 실행한다.
각 서브에이전트는 코드 수정 없이 분석만 수행한다.

**프롬프트 템플릿 위치**: `.claude/subagent-templates/{role}.md`

| # | 역할 | 템플릿 | 모드 |
|---|---|---|---|
| 1 | Security Reviewer | `.claude/subagent-templates/security.md` | --full / --fast / --security |
| 2 | Performance Reviewer | `.claude/subagent-templates/performance.md` | --full |
| 3 | Architecture Reviewer | `.claude/subagent-templates/architecture.md` | --full / --fast |
| 4 | Spec Fidelity Reviewer | `.claude/subagent-templates/spec-fidelity.md` | --full / --spec |
| 5 | Accessibility Reviewer | `.claude/subagent-templates/accessibility.md` | --full |
| 6 | Feature Behavior Reviewer | `.claude/subagent-templates/feature-behavior.md` | --full |

**실행 방법:**
```
1. 실행 리뷰어의 템플릿 파일 존재 여부를 먼저 확인한다:
   Glob(".claude/subagent-templates/*.md") 로 목록 조회
   필요한 템플릿 파일이 없으면 → 블로커 보고 후 멈춤
2. 템플릿 파일 Read
3. 템플릿의 {context.*} 플레이스홀더를 Step 1-3의 ReviewContext 값으로 치환
4. Agent 도구로 해당 모드의 리뷰어를 동시에 실행 — description 형식 필수:
   Agent(
     description="{역할} Review",         # ← "Review" 단어 필수 (post-agent-hook 분류 키)
     subagent_type="general-purpose",     # ← 6명 모두 동일 — 영역 이름 사용 금지
     prompt="{치환된 템플릿 내용}"
   )

   ⚠️ 호출 표준 — 위반 시 hook이 SKILL 카테고리로 잘못 분류 (활동 로그 추적성 저하):
     ❌ description="Security"                    → REVIEW 분류 실패
     ❌ subagent_type="fidelity" / "behavior"     → general-purpose 우회
     ✅ description="Security Review"             → REVIEW 분류 통과
     ✅ description="Phase 1 Accessibility Review" → REVIEW + Phase 정보

   6명 호출은 한 메시지에 6개 Agent 도구 블록 동시 발사 — 순차 호출 금지.
```

**에이전트 실패 처리:**
일부 에이전트 결과를 받지 못한 경우 → 해당 역할을 `[AGENT_FAIL] {역할} — 결과 없음`으로 Step 3 결과에 기록하고 계속 진행한다. 전체 재실행하지 않는다.

---

## Step 2-2: 구조적 결함 체크리스트 (메인 에이전트 직접 실행)

서브에이전트 실행과 병렬로, 메인 에이전트가 아래 체크리스트를 직접 코드에서 확인한다.
발견된 항목은 Step 3의 결과 취합 시 Blocker(즉시수정) 또는 Required로 포함한다.

### 동시성·레이스 컨디션 체크

변경 파일 중 DB 쓰기(create/update/delete)가 포함된 파일을 대상으로 확인:

```
☐ 읽기 후 쓰기 패턴(TOCTOU): count/findFirst → create 사이에 트랜잭션 없음
   → 정원/한도/중복 체크 후 쓰기 시 Serializable 트랜잭션 필수
☐ DB 레벨 제약 없이 애플리케이션 레벨에서만 중복 방지
   → unique 제약 또는 트랜잭션 내 재확인 필요
☐ 복합 쓰기 작업(create A → create B)에 트랜잭션 없음
   → 원자적 처리 필수 (orphan 레코드 방지)
☐ 멱등성 없는 cron/batch 작업 (lastSentAt 등 발송 여부 추적 없음)
   → 중복 발송 위험
```

### 보안 신뢰 경계 체크

변경 파일 중 API Route/Controller가 포함된 파일을 대상으로 확인:

```
☐ 사용자 신원(uid, memberSn, nexonId)을 request.body에서 직접 읽음
   → 반드시 서버 헬퍼 함수(getUid, getMemberSn 등) 또는 Gateway 헤더 경유
☐ NEXT_PUBLIC_ prefix 인증 변수가 AuthContext 또는 클라이언트 코드에 사용됨
   → 클라이언트 번들에 포함되어 프로덕션 배포 시 노출 위험
☐ middleware에서 페이지 라우트 인증 판별
   → INFACE Gateway 헤더는 API 요청에만 주입 — 페이지 보호에 사용 불가
```

### 타임존 체크

변경 파일 중 날짜 계산이 포함된 파일을 대상으로 확인:

```
☐ new Date() + setHours(0,0,0,0) 패턴: 서버 TZ=UTC 배포 시 KST와 9시간 오차
   → getKSTToday() 유틸리티 사용 또는 서버 환경변수 TZ=Asia/Seoul 설정
☐ toLocaleString() / new Date() 서버 컴포넌트 직접 사용
   → useClientDate() 훅 또는 suppressHydrationWarning 필요
```

### 집계 정확도 체크

```
☐ take/limit 값으로 가져온 배열의 length를 totalCount로 사용
   → _count 또는 별도 count 쿼리 필요
```

---

## Step 3: 결과 취합 (메인 에이전트)

**메인 에이전트**가 Step 2-0의 통합 테스트 결과, Step 2-1의 서브에이전트 반환값, Step 2-2의 체크리스트 결과를 통합하여 심각도별로 정리한다.

**Blocker 분류 기준:**
- `Blocker(구현차단)`: 현재 태스크 구현 자체를 막는 설계 오류 — Phase 완료 전 수정 필수
- `Blocker(즉시수정)`: 구현은 됐으나 프로덕션에서 반드시 문제를 일으키는 결함 — Phase 완료 전 수정 필수
  - 해당하는 경우: 보안 취약점(신뢰 경계 위반), 레이스 컨디션(DB 레벨 제약 없음), 인증 아키텍처 오류

```
## Phase {N} 코드 리뷰 결과

### Blocker(구현차단) ({N}건) — 현재 Phase 완료 차단, 즉시 수정
1. [{리뷰어/체크리스트}] {파일:줄} — {카테고리}: {내용}
   근거: {1줄}
   수정 방안: {방법}
   자동 수정 가능: yes/no

### Blocker(즉시수정) ({N}건) — 프로덕션 결함, Phase 완료 전 수정 필수
> 동시성·보안·인증 아키텍처 결함. 로컬 단일 사용자 테스트에서 재현 안 될 수 있으나
> 프로덕션에서 반드시 문제를 일으킴.
1. [{리뷰어/체크리스트}] {파일:줄} — {카테고리}: {내용}
   근거: {1줄}
   수정 방안: {방법}
   자동 수정 가능: yes/no

### Required ({N}건) — 다음 Phase 시작 전 수정 필수
...

### Advisory ({N}건) — 프로덕션 전 수정 권장 (기술 부채로 추적)
...

### Info ({N}건) — 참고
...

### 교차 분석 — 동일 파일에 2개 이상 리뷰어 Blocker
> Blocker가 0건이거나 모든 Blocker가 서로 다른 파일이면 이 섹션을 생략한다.
{파일경로}: [{리뷰어A} — {이슈요약}] + [{리뷰어B} — {이슈요약}]
→ 수정 시 두 이슈가 서로 영향을 줄 수 있으므로 함께 검토 필요

Blocker(구현차단): {N}건 / Blocker(즉시수정): {N}건 / Required: {N}건
→ {모든 Blocker=0이면 "Step 4 생략, Required 추적 후 Step 5로 진행" / Blocker>0이면 "Step 4로 진행"}
```

---

## Step 4: Blocker 수정 (메인 에이전트 직접 수행)

**메인 에이전트가 직접 수정한다.** 수정을 서브에이전트에 위임하지 않는다.

> **`Blocker(즉시수정)` 항목도 반드시 Step 4에서 수정한다.**
> "나중에", "다음 Phase에서" 처리는 허용하지 않는다. 미수정 시 Phase 완료 차단.

### 4-1. Blocker 수정

```
각 Blocker 항목에 대해 (구현차단 + 즉시수정 모두):

1. Read로 해당 파일·줄 확인
2. 수정 방안대로 Edit/Write로 직접 수정
3. 수정 범위가 3파일 이상이면 TodoWrite로 수정 항목 추적
4. 관련 빌드/테스트 실행하여 수정 검증 (pytest 또는 npm run build)
5. 수정한 파일 경로를 MODIFIED_FILES 목록에 기록
```

### 4-2. 재실행 대상 결정

Blocker 출처 리뷰어에 수정 파일의 도메인 리뷰어를 합산한다.

```
RERUN_REVIEWERS = {Blocker 출처 리뷰어 집합}

MODIFIED_FILES 각 파일에 대해 Step 1-3의 표준 파일 분류 기준을 동일하게 적용하여
해당 도메인의 리뷰어를 RERUN_REVIEWERS에 추가한다 (중복 제거).
```

확장 결과 출력:
```
재실행 대상: {리뷰어 목록}
  - [원래] {Blocker 출처 리뷰어}
  - [확장] {수정 파일 도메인으로 추가된 리뷰어}
```

### 4-3. 재실행 및 결과 판정

RERUN_REVIEWERS를 병렬 실행한다. 재실행 전에 이번 Blocker 항목의 `{파일:줄}` 목록을 PREV_BLOCKERS로 저장해 둔다.

| 결과 | 조건 | 처리 |
|---|---|---|
| 통과 | Blocker 0건 | Step 5로 진행 |
| 동일 Blocker 반복 | PREV_BLOCKERS와 동일 파일:줄 1건 이상 | 즉시 블로커 처리 |
| 신규 Blocker 발생 | 수정 side-effect로 새 위치 발생 | 4-1→4-2→4-3 1회 더 실행 |
| 2회 연속 신규 Blocker | 재실행 후에도 Blocker 잔존 | 즉시 블로커 처리 |

> **동일 Blocker 판별**: 파일 경로 + 줄 번호 일치. 줄 번호가 이동한 경우 취약점 유형 + 설명으로 보완 판별.

**블로커 처리:**

```bash
./scripts/log-activity.sh BLOCKED "리뷰 Blocker 해소 불가" "{이유}" || true
./scripts/notify-slack.sh "🔴 블로커: 리뷰 Blocker 해소 불가" "{상세}\n해결 후 '해결됨, 계속해줘'" || true
```

blockers.md 기록:
```
## {날짜} 리뷰 블로커 — Phase {N}
- 원인: {동일 Blocker 반복 / 2회 연속 신규 Blocker}
- Blocker 항목: {파일:줄 목록}
- 조치 필요: 설계 수준 검토 후 수동 수정
```

PROGRESS.md 🔴 갱신 → **멈춤**.

---

## Step 5: 완료 처리

```bash
./scripts/log-activity.sh REVIEW "Phase {N} 리뷰 완료 (${MODE:-full})" \
  "Blocker: {B}건 / Required: {R}건 / Advisory: {A}건 / Info: {I}건 — 리뷰어 ${REVIEWER_COUNT}명" || true
./scripts/notify-slack.sh "✅ Phase {N} 리뷰 완료" \
  "Blocker: {B}건 / Required: {R}건 / Advisory: {A}건 / Info: {I}건\n다음 Phase 진행 가능" || true
```

**Required 항목 추적**

Required 항목이 1건 이상이면 `docs/technical-debt.md`에 기록한다 (없으면 생성).

```
## Phase {N} Required — {YYYY-MM-DD}
> 다음 Phase 시작 전 수정 필수

| 리뷰어 | 파일:줄 | 내용 | 수정 방안 |
|---|---|---|---|
| {리뷰어} | {파일:줄} | {내용} | {방법} |
```

Required 항목이 0건이면 이 단계를 생략한다.

**Blocker(즉시수정) 잔존 시 Phase 완료 차단**

Step 4 수정 후에도 `Blocker(즉시수정)` 항목이 남아있으면 Phase 완료를 차단한다:

```bash
# Blocker(즉시수정) 잔존 시
./scripts/log-activity.sh BLOCKED "Phase {N} Blocker(즉시수정) 미수정" "{항목 목록}" || true
./scripts/notify-slack.sh "🔴 블로커: Phase {N} 즉시수정 미완료" "{항목}\n해결 후 계속해줘" || true
```

blockers.md 기록 → PROGRESS.md 🔴 갱신 → **멈춤**.

> `Blocker(즉시수정)`은 "advisory" 처리·다음 Phase로 이월·Technical Debt으로 등록할 수 없다.
> 이 단계를 우회하면 STRUCT-01~07 같은 결함이 QA에서 재발견된다.

**PROGRESS.md review_status 갱신 (세션 복귀 시 탐지 기준)**

PROGRESS.md의 `review_status` 행을 완료 날짜로 갱신한다:

```bash
TODAY=$(date +%Y-%m-%d)
# PROGRESS.md의 review_status 행을 찾아 갱신
# Edit 도구 사용: "Phase {N}: ⏳ pending" → "Phase {N}: ✅ {TODAY}"
# (해당 Phase 행이 없으면 현재 상태 행에 추가)
```

갱신 형식: `Phase {N}: ✅ {YYYY-MM-DD}` (예: `Phase 1: ✅ 2026-04-22`)

기존에 여러 Phase가 있으면 해당 Phase 값만 교체한다:
```
| **review_status** | Phase 1: ✅ 2026-04-22 / Phase 2: ⏳ pending |
```

**리뷰 토큰 생성 (pre-bash-hook Gate 3 및 T{N}-review done 기준용)**

state.json에서 현재 Phase 번호를 읽어 토큰 파일을 생성한다.
토큰 파일이 있어야 "Phase N 완료" 커밋이 허용된다.

```bash
python3 -c "
import json, os, datetime, subprocess, sys, hmac, hashlib, secrets

def get_or_create_secret():
    secret_path = '.claude/review-token-secret'
    if os.path.exists(secret_path):
        with open(secret_path) as f:
            return f.read().strip()
    # 최초 실행 시 프로젝트별 시크릿 생성
    secret = secrets.token_hex(32)
    os.makedirs('.claude', exist_ok=True)
    with open(secret_path, 'w') as f:
        f.write(secret)
    # .gitignore에 .claude/ 가 이미 포함되어 있으므로 별도 추가 불필요
    return secret

try:
    with open('.claude/state.json') as f:
        d = json.load(f)
    phase = int(d.get('phase', 0))
    if phase < 1:
        print('Phase 번호 0 이하 — 토큰 생성 생략', file=sys.stderr)
        sys.exit(0)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    # ── 리뷰 증거 결합 (proof-of-work) ────────────────────────────────────────
    # post-agent-hook 이 Agent(리뷰) dispatch 마다 기록한 phase-N.evidence 를
    # 토큰에 결합한다. 현재 commit 에 결합된 dispatch 증거가 1건도 없으면
    # 리뷰가 실제로 fan-out 되지 않은 것 → 토큰 발급을 거부한다.
    # 정당한 inline 폴백(Agent 도구 미사용)일 때만 D2A_ALLOW_INLINE_REVIEW=1 로
    # 명시 우회하여 레거시(증거 미결합) 토큰을 발급한다. (기존 게이트 우회 패턴과 동일)
    secret = get_or_create_secret()
    ev_path = f'.claude/review-tokens/phase-{phase}.evidence'
    ev_count = 0
    ev_digest = ''
    if os.path.exists(ev_path):
        with open(ev_path, 'rb') as ef:
            raw = ef.read()
        ev_digest = hashlib.sha256(raw).hexdigest()
        ev_count = sum(1 for ln in raw.decode('utf-8', 'replace').splitlines()
                       if len(ln.split('\t')) >= 2 and ln.split('\t')[1].strip() == commit)

    inline_ok = os.environ.get('D2A_ALLOW_INLINE_REVIEW', '0') == '1'
    os.makedirs('.claude/review-tokens', exist_ok=True)
    token_path = f'.claude/review-tokens/phase-{phase}.token'

    if ev_count >= 1:
        # 강한 토큰: 증거 digest + 결합 건수를 서명 대상에 포함
        payload = f'{phase}:{commit}:{timestamp}:{ev_count}:{ev_digest}'
        sig = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
        with open(token_path, 'w') as tf:
            tf.write(f'phase={phase}\n')
            tf.write(f'timestamp={timestamp}\n')
            tf.write(f'commit={commit}\n')
            tf.write(f'evidence_count={ev_count}\n')
            tf.write(f'evidence_digest={ev_digest}\n')
            tf.write(f'sig={sig}\n')
        print(f'리뷰 토큰 생성: {token_path} (commit={commit[:7]}, evidence={ev_count}건, sig={sig[:8]}...)')
    elif inline_ok:
        # inline 폴백: 증거 미결합 레거시 토큰 (3-field). 명시 우회 + 마커 기록.
        payload = f'{phase}:{commit}:{timestamp}'
        sig = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
        with open(token_path, 'w') as tf:
            tf.write(f'phase={phase}\n')
            tf.write(f'timestamp={timestamp}\n')
            tf.write(f'commit={commit}\n')
            tf.write(f'review_mode=inline\n')
            tf.write(f'sig={sig}\n')
        print(f'⚠️  inline 리뷰 토큰 생성(증거 미결합): {token_path} — Agent fan-out 리뷰 권장', file=sys.stderr)
    else:
        print(f'[ERROR] 리뷰 증거 없음: commit {commit[:7]} 에 결합된 Agent 리뷰 dispatch 가 0건입니다.', file=sys.stderr)
        print('        subagent-review 리뷰어를 Agent 도구로 실제 실행했는지 확인하세요.', file=sys.stderr)
        print('        Agent 미사용 inline 리뷰를 실제 수행했다면: export D2A_ALLOW_INLINE_REVIEW=1', file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f'[ERROR] 토큰 생성 실패: {e}', file=sys.stderr)
    sys.exit(1)
"
```

> 토큰 생성 실패 시 `sys.exit(1)`로 종료 — 조용히 넘어가지 않는다.
> `.claude/review-token-secret`은 최초 실행 시 자동 생성되는 프로젝트별 시크릿이다.
> **proof-of-work 결합**: 토큰은 `post-agent-hook` 이 기록한 리뷰 dispatch 증거
> (`phase-N.evidence`, 하네스가 Agent 도구 실제 호출 시에만 발화)에 결합된다.
> 현재 commit 에 결합된 증거가 없으면 mint 가 거부되어 "리뷰 스킵 + 토큰만 발급" 을
> 막는다. Agent 미사용 inline 리뷰는 `D2A_ALLOW_INLINE_REVIEW=1` 로 명시 우회한다
> (레거시 형식 토큰 + `review_mode=inline` 마커, Gate 3 는 통과시키되 경고).
> Gate 3는 파일 존재 + HMAC 서명 + 증거 digest·commit 결합을 함께 검증하여
> 수동 복사/위조 및 리뷰 스킵을 방지한다.

**suppress.yaml 갱신**

리뷰에서 "사용자가 수용 불가" 또는 "레거시 부채로 기각"한 항목은 `.review-suppress.yaml`에 추가한다.
파일이 없으면 새로 생성한다.

suppress.yaml 형식:
```yaml
# .review-suppress.yaml
# 각 섹션은 해당 리뷰어가 반복 발견하지 않도록 명시적으로 제외하는 항목
security:
  - file: src/legacy/auth.py
    issue: "하드코딩된 테스트 토큰 — 레거시 모듈, Phase 3에서 리팩터링 예정"
architecture:
  - file: src/models/user.py
    issue: "God Object — 기술 부채, 다음 Phase에서 분리 예정"
accessibility: []
performance: []
spec: []
feature_behavior: []
```
