# D2A Boilerplate — Claude Code 프로젝트 지침

---

## 언어 설정

**모든 대화와 응답은 반드시 한국어로 한다.**
코드, 변수명, 주석, 파일 내 기술 용어는 영어를 유지하되, Claude의 모든 설명·질문·안내는 한국어로 작성한다.

---

## Claude Code 도구 활용 원칙

이 보일러플레이트는 **Claude Code (CLI / IDE 확장)** 를 유일한 개발 도구로 전제한다.

### 핵심 규칙

| 도구 | 제약 |
|---|---|
| `Agent` | `/subagent-review` 리뷰 전용 — 구현에 사용 금지 |
| `Skill` | `/skill-name` 입력 시 텍스트 설명 대신 반드시 도구 호출 |
| `TodoWrite` | 3단계 이상 작업·Phase 실행 시 사용. 세션 내 추적 전용 (`PROGRESS.md`는 세션 간 영구 기록) |

### 컨텍스트 압축 대응

- **블로커·Phase 경계마다** `PROGRESS.md`를 갱신한다 (세션 간 영구 기록)
- `tasks.md`의 ☑/☐ 상태가 항상 실제 완료 상태와 일치해야 한다

---

## 작업 흐름 설정

### 명령 자동 실행 (auto-run-commands)

자동 실행 범위는 `.claude/settings.json`의 `permissions.allow` 참조.
파괴적 명령(`rm -rf`, `git push --force`, DB drop 등)은 항상 사용자 확인 후 실행한다.

---

## 프로젝트 헌법 (변경 불가 원칙)

### 핵심 원칙

1. **문서가 코드보다 먼저**: spec.md → plan.md → tasks.md → 구현 순서를 지킨다.
2. **실제 데이터 기반**: 사내 정책이 수집되면 `refs/policies/`에 기록하고, `refs/collaboration-tracker.md`를 갱신한다.

### 기술 선택 원칙

아래 항목은 사용자 지정이 없을 경우 AI가 프로젝트 특성에 맞게 선택한다.
**선택 기준**: 프로젝트에 적합한 최신 안정 버전 (정식 릴리즈 후 3개월 이상 경과, RC/Beta 제외).

| 항목 | 결정 방식 |
|---|---|
| **D-1 기술 스택** | AI가 프로젝트 유형에 맞는 최신 안정 버전 선택. 사용자 확인 후 확정. |
| **B-4 서비스 스택** | AI가 프로젝트 규모·트래픽에 맞는 인프라 조합 선택. 사용자 확인 후 확정. |
| **A-1a 사내 인증** | NXAS SSO — `refs/company-policies/compliance/NEXON-OS/03_DEPENDENCIES/01_AUTH/NXAS/` 참조. |
| **A-1b 유저 인증** | `refs/gamescale-docs/public/docs/ko/service-integration/authentication/` 참조. |
| **B-1 클라우드** | AI가 서비스 특성(사내/외부, 규모, 리전)에 맞게 제안. 사용자 확인 후 확정. |
| **F-6 UI 프레임워크** | 사용자 지정이 없으면 AI가 프로젝트에 맞는 후보를 제시, 사용자가 선택. |
| **F-7 디자인 시스템** | PRD에 NX Basic 키워드(`NX Basic`/`nxbasic`)가 있으면 `DESIGN_SYSTEM=nxbasic`으로 디자인 리서치를 건너뛰고 UI 프로토타입 직행. 없으면 디자인 리서치 단계에서 NX Basic을 리서치 결과와 함께 선택지로 제시. 참조: `refs/design-systems/nxbasic-1.0v.md` (MCP 미등록, Storybook WebFetch 조회). |

### 아키텍처 원칙

아키텍처는 `spec.md`에 명시된다. 미명시 시 레이어드 아키텍처를 기본으로 한다: `API → Service → Repository → DB`
레이어 경계를 넘는 직접 호출은 금지한다 (예: router에서 repository 직접 호출).

### 로컬 개발 환경 표준 (모든 파생 프로젝트)

모든 파생 프로젝트는 라이브 환경과 동일한 HTTPS 흐름으로 로컬 검증한다:

| 단계 | 책임 | 산출물 |
|---|---|---|
| **Stage 1.6-A** *(boilerplate-setup)* | 인증 프로필 결정 (`AskUserQuestion`) | `state.json.auth_profile` (insign / nxas / insign-with-nxas / custom / none) |
| **Stage 1.6-B** *(boilerplate-setup)* | HTTPS + Caddy 셋업 (`setup-https.sh`) | mkcert 인증서 + `/etc/hosts` + Caddy 사이트 + `.env.example` |
| **Stage 2-E** *(boilerplate-setup)* | Playwright 셋업 (frontend 부재 시에도 선행) | `playwright.config.ts` + `auth-mock fixture` (CI/로컬 자동 분기) |
| **Step 2.7** *(create-spec)* | UI 프로토타입 + 실제 로그인 + storageState **1회 통합 검증** (`save-auth-state.sh`) | UI 승인 + `tests/e2e/.auth/user.json` storageState (만료 시 `save-auth-state.sh` 재실행) |

> **2026-05 변경**: 이전 **Stage 2-F** (로그인 1회 수동 검증) 는 폐지되어 `create-spec` Step 2.7
> 에 통합되었다. UI 프로토타입 확인과 실제 INSIGN/NXAS 로그인 + storageState 저장이 동일한
> Playwright 헤드풀 세션에서 한 번에 끝난다. 사용자 입력은 Step 2.7 의 단일 A/B/C 프롬프트로
> 수렴되며, 보일러플레이트 셋업 흐름은 Stage 2-E 직후 Stage 3~4 로 진행한다.

호스트명 정책:
- **insign / insign-with-nxas**: `local-{프로젝트}.nexon.com` (INSIGN `_ifwt` 강제)
- **nxas / custom**: `local-{프로젝트}.nxgd.io` (NXAS 개발 권장)
- **none**: `local-{프로젝트}.test` (RFC 6761)

Phase 게이트(`subagent-review` Step 2-0)가 매번 자동 검증하는 것:
- HTTPS 인증서 / hosts / Caddy 데몬 실행 (Stage 1.6-B 산출물)
- storageState 존재·만료 (쿠키 `expires` 기준, create-spec Step 2.7 산출물 — 만료 시 `save-auth-state.sh` 재실행)
- runtime-health 통과 (콘솔 에러·네트워크 4xx/5xx 0건)
- ROUTES 자동 갱신 (`extract-routes.sh` — spec.md/PRD 변경 반영)
- state.json ↔ .env.example 동기화 (`sync-state-to-env.sh` — state.json 이 source of truth)

인증 프로필 변경 시: `./scripts/change-auth-profile.sh <새 프로필>` (자동 정리 + 재셋업 안내)

---

## AI 행동 규칙 (항상 적용)

### 1. 결정 전 반드시 확인 (ask-before-decide)

정보가 부족하거나 선택지가 있는 상황에서 절대 추측하지 않는다.
반드시 사용자에게 질문한 뒤 답변을 받고 나서 진행한다.

**반드시 물어봐야 하는 상황:**

- **카테고리 A — 사내 정보**: `refs/policies/`에 명시되지 않은 인증 방식, 클라우드/인프라 설정, 도메인/SSL, 보안 정책, DB/캐시/큐 선택, CI/CD 도구, 모니터링/알림, 사내 패키지 URL
- **카테고리 B — 설계 선택**: `spec.md` 또는 `decisions.md`에 없는 라이브러리 선택, 데이터 모델 설계, API 설계, 상태 관리, 파일 저장, 에러 처리 전략
- **카테고리 C — 비즈니스 판단**: 기능 우선순위/범위 변경, UX 흐름, 에러 메시지 문구, 데이터 보관/삭제 정책, 권한/역할, 외부 서비스 연동 여부
- **카테고리 D — 구조 변경**: 아키텍처·디렉터리 구조 변경, 새 라이브러리 도입, 기존 패턴과 다른 패턴 적용, 데이터 흐름 변경, 설정/환경 구조 변경

**질문 형식:**
```
🔶 결정이 필요합니다: {주제}

**상황**: {왜 이 결정이 필요한지}
**선택지**:
  A) {선택지 1} — {장단점}
  B) {선택지 2} — {장단점}
  C) {기타 — 직접 지정}

**참고**: {관련 refs/policies/ 정보 또는 "정책 정보 없음"}
**영향**: {이 결정이 다른 부분에 미치는 영향}
```

---

### 2. 정책 레퍼런스 확인 (check-policy-refs)

기술 결정이 필요한 코드 변경 시, 아래 순서로 정책을 확인한다:

1. `refs/INDEX.md`의 "빠른 결정 가이드" 표를 확인한다
2. 부족하면 `refs/policies/` 해당 파일을 읽는다
3. GameScale 관련 항목은 `refs/gamescale-docs-index.md`에서 키워드로 경로를 찾아
   `refs/gamescale-docs/public/docs/ko/{경로}` 문서를 직접 읽는다
   → **한 태스크에서 gamescale-docs 파일은 최대 3개만 읽는다. 더 필요하면 사용자에게 보고 후 대기.**
4. 위 경로에서 찾지 못하면 `/internal-doc-survey` 스킬의 래더(Step 2)를 따른다
5. 모든 경로에서 정보를 찾지 못하면 업계 표준을 적용하고 🤖(AI 제안)으로 표시한다

**인증 파일 판별 (두 파일을 동시에 읽지 않는다):**
- `EMPNO`, `DEPTCode`, `nxas.nexon.com` → `refs/policies/authentication-nxas.md`
- `_ifwt`, `signin.nexon.com`, `MemberSN`, GameScale SDK → `refs/policies/authentication-external.md`
- 판별 불명확 → `refs/policies/authentication.md` (라우터 파일, 2KB) 읽고 판별 후 해당 파일만 읽기

정책과 충돌하는 구현을 발견하면 코드를 수정하지 않고 사용자에게 보고한다.

---

### 3. 소스 변경 시 빌드 검사 및 커밋 (commit-on-source-change)

소스 파일을 수정·추가·삭제한 뒤 같은 턴에서:

1. **진행 추적**: 수정 범위가 3파일 이상이면 `TodoWrite`로 단계를 먼저 정의한다.

2. **빌드 검사**
   - 백엔드: 프로젝트 스택에 맞는 테스트 명령 실행 (`backend/CLAUDE.md` 참조). 실패 시 수정 후 재검사.
   - 프론트엔드: `npm run build` 실행. 실패 시 수정 후 재검사.
   - specs·문서만 변경 시 빌드 생략 가능.

3. **리뷰 게이트** (Phase 경계 외 추가 개발 시 적용)

   `run-phase` Step 3 또는 `T{N}-review` 태스크에서 이미 리뷰가 실행된 경우 생략한다.
   그 외 모든 소스 변경(기능 추가·버그 수정·리팩터링)에서 아래 기준으로 모드를 결정한다:

   | 조건 | 리뷰 모드 |
   |---|---|
   | 1–2파일 변경, Critical Path 파일 아님 | 생략 |
   | 3–9파일 변경 또는 `spec.md`·`decisions.md` 변경 | `--fast` (Security + Architecture) |
   | 10+ 파일 변경 또는 Critical Path 파일 포함 | `--full` (6명 전원) |

   **Critical Path 파일**: `contracts/`, `data-model.md`, `api-spec.yaml`, auth/login/session/middleware 경로 포함 파일

   리뷰 실행: `.claude/skills/subagent-review.md` Read 후 인라인 실행 (Step 1–5, Step 3.5 포함).

4. **스테이징**: `git add {변경 파일}`

5. **커밋**: `git commit -m "{type}: {요약}"` (Conventional Commits 형식)

---

### 4. 태스크 자율 실행 (enforce-task-completion)

tasks.md가 있는 프로젝트에서 구현 작업 시:

- Phase 0(UI 프로토타입)은 `/create-spec` Step 2.7에서 완료된다.
- Phase 0.5: `/collect-prerequisites`로 외부 연동 검증 → `integration-ready.md` 발급
- Phase 1 이후: `/run-phase N`으로 자율 실행. **사용자 확인 없이 태스크·Phase를 연속 진행한다.**
- **Phase 실행 절차:**
  1. `Skill("run-phase", "N")` 호출을 먼저 시도한다
  2. "Unknown skill" 오류 발생 시 (Claude Code 환경 제약):
     - `.claude/skills/run-phase.md`를 Read로 읽는다
     - 각 Step을 메인 에이전트가 순차적으로 직접 실행한다
     - **Step 3(서브에이전트 리뷰)는 반드시 실행한다 — 스킵 금지**
     - `Skill("subagent-review")` 호출도 실패하는 경우: `.claude/skills/subagent-review.md`를 Read로 읽고 인라인 실행
- **각 태스크는 `**read**` 필드에 명시된 파일만 로드한다.** 스펙 외 파일 읽기는 블로커로 처리.
- **구현은 메인 에이전트가 순차적으로 직접 수행한다.** `Agent` 도구는 `/subagent-review` 리뷰 전용이며, 리뷰 결과를 메인 에이전트가 취합하여 직접 수정한다.
- **decisions.md ⬜ 발견 시**: 먼저 refs/INDEX.md 기반 자동 선택을 시도하고, 정책 근거 없는 항목만 사용자에게 질문한다.
- **멈추는 경우**: 블로커 발생 (연속 2회 빌드 실패, read 스펙 누락), 자동 선택 불가 decisions.md ⬜ 항목 잔존

**⛔ 구현 착수 전 필수 확인 (Phase 1 이상, 소스 코드 변경 수반 시) — 어느 단계도 생략 불가:**

| 순서 | 확인 항목 | 위반 시 |
|---|---|---|
| 1 | `PROGRESS.md` Read → `review_status` 필드 확인 | 구현 시작 금지 |
| 2 | `review_status` 가 `⏳ pending` 이거나 필드 없으면 subagent-review **먼저 실행** | run-phase 재진입 전 반드시 완료 |
| 3 | `Skill("run-phase", "N")` 호출 시도 → 실패 시 `run-phase.md` Read | 이 과정 없이 직접 Write/Edit 시작 불가 |
| 4 | 구현은 오직 run-phase.md Step 2 태스크 루프 안에서만 수행 | 루프 밖 직접 구현은 규칙 위반 |

자율 실행·블로커 처리·복귀 절차의 상세는 `/session-phase-workflow` 및 `/run-phase` 스킬을 따른다.

**MCP 하네스 강제 호출 (Phase 1 이상):**

아래 각 시점에 MCP 도구를 직접 호출한다. 텍스트 판단으로 우회하는 것은 규칙 위반이다.

| 시점 | MCP 호출 | 내부 처리 |
|---|---|---|
| Phase 시작 전 | `update_state({ phase: N, status: "running", current_task: null, blockers: [] })` | state 초기화 |
| Phase 게이트 확인 | `check_phase_gate(phase=N)` | integration-ready·블로커·decisions 검증 |
| **태스크 시작** | `get_next_task(phase=N)` | deps 확인·checkpoint 생성·state 갱신을 MCP가 직접 처리 |
| **태스크 완료 제출** | `submit_task(task_id=TXxx, attempt=1 또는 2)` | validate·token 생성·rollback 결정을 MCP가 직접 처리 |

`get_next_task` / `submit_task` 사용 시 `create_checkpoint`, `validate_task_done`, `update_state`는
**별도 호출하지 않는다** — MCP가 내부에서 처리한다.

MCP 실패 시에만 `/run-phase` 스킬에 명시된 폴백을 사용한다.

**done 기준 타입 (tasks.md 작성 시 반드시 타입 명시 형식 사용):**

| 타입 | 형식 | 용도 |
|---|---|---|
| `file:` | `file: {경로}` | 파일 존재 확인 |
| `cmd:` | `cmd: {셸 명령}` | exit 0 = 통과 (build, test 등) |
| `contains:` | `contains: {경로} :: {문자열}` | 파일 내 문자열 포함 |
| `regex:` | `regex: {경로} :: {정규식}` | 파일 내 정규식 매칭 (플래그 미지원) |
| `json:` | `json: {경로} :: .{dot-path}[={값}]` | JSON 경로 존재/값 확인 (배열 인덱스 미지원) |
| `coverage:` | `coverage: {경로} :: {임계값}` | 라인 커버리지 임계값 확인 (% 선택) |
| `ut:` | `ut: {report 경로} :: S4=0,S3<=2` | AI 사용성 테스트 결과 Severity 임계값 (v1.6.0+) |

> `json:` 타입 예: `json: package.json :: .scripts.build` (존재 확인)
> `json: package.json :: .name=my-app` (값 일치 확인)

> `coverage:` 타입 주의: 리포트 파일이 먼저 생성되어 있어야 한다.
> `cmd:` 기준으로 테스트를 실행하고 커버리지 리포트를 생성한 뒤 `coverage:` 기준으로 검증한다.
>
> 지원 리포트: `coverage/coverage-summary.json` (Vitest/Jest), `coverage.json` (pytest-cov)
>
> ```yaml
> done:
>   - cmd: pytest --cov=backend/app --cov-report=json -q   # 리포트 생성
>   - coverage: backend/app :: 80                           # 임계값 검증
> ```

**Task ID 규칙:**
- 형식: `T{phase}-{seq}` (예: `T1-001`) 또는 `T{seq}` (예: `T001`) — 한 프로젝트 내 혼용 금지
- **예약 접미사** `T{N}-review`: 각 Phase 말미 서브에이전트 리뷰 태스크 전용 ID. 형식 혼용으로 감지되지 않는 예외 패턴이다.
  - 형식 `T{N}-review`에서 N은 Phase 번호. 예: `T1-review`, `T2-review`
  - 이 ID는 `skill: subagent-review` 필드와 반드시 함께 사용한다.
  - `T{seq}` 형식 프로젝트에서는 숫자 3자리 대신 `T{N}-review`를 그대로 사용한다 (예외 허용).
- deps 비교는 대소문자·공백 정규화 후 매칭 (소문자 `t1-001`도 `T1-001`로 인식)
- 혼용 감지 시 MCP가 stderr 경고 출력 (단, `T{N}-review` 패턴은 경고 대상에서 제외)

**`.claude/state.json`: MCP 관리, 수동 편집 금지. `.gitignore` 대상.**

---

### 5. 활동 로그 및 슬랙 알림 (log-boilerplate-activity)

보일러플레이트 활동을 `logs/boilerplate-activity.md`에 기록한다.

```bash
./scripts/log-activity.sh <카테고리> <제목> [상세내용] || true
# 슬랙 알림이 필요한 이벤트:
./scripts/notify-slack.sh "<제목>" "<본문>" || true
```

**카테고리 및 슬랙 알림 여부:**

| 활동 | 카테고리 | 기록 방식 | 슬랙 |
|---|---|---|:---:|
| 프로젝트 세팅/의존성/환경변수 변경 | SETUP | AI 직접 호출 | — |
| Phase 시작/완료 | PHASE | update_state hook 자동 | ✅ |
| MCP submit_task 완료 | TASK | submit_task hook 자동 | (granularity 의존) |
| 서브에이전트 리뷰 시작/완료 | REVIEW | Agent hook 자동 + AI 완료 기록 | ✅ |
| decisions.md 항목 결정 | DECISION | **AI 직접 호출 필수** | — |
| 정책 문서 참조/갱신 | POLICY | **AI 직접 호출 필수** | — |
| collaboration-tracker 갱신 | COLLAB | **AI 직접 호출 필수** | — |
| git commit 직후 | COMMIT | Bash hook 자동 | — |
| 빌드/테스트 성공·실패 | BUILD | Bash hook 자동 | ✅ (FAIL만) |
| 차단 항목 발생/해제 | BLOCKED | rollback hook 자동 + **AI 직접 호출 필수** | ✅ |
| 스킬 실행 | SKILL | Skill hook 자동 | — |
| 소스 파일 수정 | SOURCE | Write/Edit hook 자동 | — |
| MCP 도구 호출 (update_state, check_phase_gate, get_next_task, rollback) | MCP | post-mcp-hook 자동 | — |

**슬랙 알림 단위 조정 (`SLACK_TASK_GRANULARITY`)** — 기본 `phase`:

| 값 | TASK 슬랙 발송 시점 |
|---|---|
| `task` | 모든 태스크 완료 시 (Phase 1에서 T101~T108 = 8건 — 노이즈 많음) |
| `phase` ⭐ | 재시도(attempt>1) / 실패 시에만 — 일반 성공은 Phase 시작/완료로 갈음 |
| `blocker` | 실패 시점만 (조용한 모드) |

`.env.local` 또는 셸 export 로 변경. PHASE / BLOCKED 슬랙은 granularity 와 무관하게 항상 발송.

**AI 직접 호출 필수 카테고리** — hook으로 자동화 불가, 반드시 같은 턴에서 호출한다:

```bash
# DECISION: decisions.md 항목을 결정한 직후
./scripts/log-activity.sh DECISION "[{항목}]: {결정값}" "🤖 refs 자동선택" || true
# 또는
./scripts/log-activity.sh DECISION "[{항목}]: {결정값}" "👤 사용자 확인" || true

# POLICY: refs/policies/ 파일을 읽거나 갱신한 직후
./scripts/log-activity.sh POLICY "{정책 파일명}: {참조/갱신 내용 요약}" "" || true

# COLLAB: refs/collaboration-tracker.md를 갱신한 직후
./scripts/log-activity.sh COLLAB "{항목}: {상태 변경 내용}" "" || true

# BLOCKED: 블로커 발생 시 (rollback 없이 직접 차단된 경우)
./scripts/log-activity.sh BLOCKED "{task_id} {원인 요약}" "{상세 원인}" || true
./scripts/notify-slack.sh "🔴 BLOCKED: {요약}" "{상세}" || true

# ⚠️ BLOCKED 의무 트리거 — 아래 5가지 상황은 rollback 없이도 반드시 BLOCKED 기록:
#   1. 보일러플레이트 스크립트(scripts/*.sh)를 *수동 patch* 후 재실행 (예: save-auth-state.sh 직접 수정)
#   2. 같은 파일을 5분 내 3회 이상 연속 Edit + COMMIT 없음 (반복 fix 신호)
#   3. BUILD/TEST 가 FAIL 로 기록됐는데 같은 명령을 즉시 재실행 (재시도 = 사일런트 실패 회피)
#   4. 외부 서비스 응답 대기로 진행 멈춤 (예: INFACE API Key 발급, GW 회신)
#   5. 사용자 입력 없이 진행 불가 (decisions.md ⬜ 결정 필요, 사용자 확인 대기)
#
# BLOCKED 미기록 시: 다음 세션이 friction 원인 추적 불가 → 동일 결함 반복 발생.

# REVIEW 완료: 리뷰 결과를 취합한 직후
./scripts/log-activity.sh REVIEW "Phase {N} 리뷰 완료 ({mode})" \
  "Blocker: {B}건 / Required: {R}건 / Advisory: {A}건 / Info: {I}건 — 리뷰어 {N}명" || true
```

**카테고리별 필수 형식:**

| 카테고리 | 제목 형식 | 상세내용 형식 |
|---|---|---|
| TASK | `{task_id}: {태스크 제목}` | `Phase {N} — 통과/재시도 (attempt {N})` |
| PHASE | `Phase {N} 시작` 또는 `Phase {N} 완료` | `current_task={ID}` 또는 생략 |
| REVIEW | `Phase {N} 리뷰 완료 ({mode})` | `Blocker: {B}건 / Required: {R}건 / Advisory: {A}건 / Info: {I}건 — 리뷰어 {N}명` |
| DECISION | `[{항목}]: {결정값}` | `🤖 refs 자동선택` 또는 `👤 사용자 확인` |
| POLICY | `{정책 파일}: {참조/갱신 요약}` | 생략 가능 |
| COLLAB | `{tracker 항목}: {상태}` | 생략 가능 |
| BLOCKED | `{task_id} {원인 요약}` | 상세 원인 |
| MCP | `{도구명}` | `phase={N} status={S} ...` |
| BUILD | `{명령어}` | `SUCCESS/FAIL | {N} passed, {M} failed | {T}s` |
| COMMIT | `git commit: {메시지}` | `{hash} | {N} files changed, ...` |
| SOURCE | `[{도구}] {변경유형}: {파일명}` | 파일 절대/상대 경로 |

> **TASK 카테고리 남용 금지**: TASK는 MCP `submit_task` hook에서만 기록한다. T-ID 없이 일반 작업을 TASK로 기록하지 않는다. 그런 활동은 SKILL 또는 SETUP을 사용한다.

슬랙 발송은 best-effort — 실패해도 작업을 중단하지 않는다 (`|| true`).

---

### 6. 범위 보호 (scope-guard)

**파급 효과 보고 형식:**
```
⚠️ 파급 효과 감지

변경 파일: {수정한 파일}
영향받는 파일: {영향받는 파일 목록}
내용: {어떤 영향인지 간단 설명}
조치 필요: {사용자가 해야 할 것}
```

---

### 7. 진행 상황 추적 (track-progress)

| 계층 | 도구 | 역할 |
|---|---|---|
| 세션 내 | `TodoWrite` | Phase 태스크 등록 + 완료 즉시 마킹. 세션 종료 시 초기화. |
| 머신 상태 | `.claude/state.json` | MCP(`update_state`)가 읽고 씀. 수동 편집 금지. `.gitignore` 대상. |
| 세션 간 | `PROGRESS.md` | Phase 전환·블로커·중단 시 갱신. 세션 복귀 기준 문서. |

"어디까지 했지?", "이어서 해줘", "계속해줘" → 반드시 아래 절차로 진입:

1. `Skill("session-phase-workflow")` 호출 시도 → 실패 시 `.claude/skills/session-phase-workflow.md` Read → Part E 직접 실행
2. **Part E-1의 `review_status` 확인(step 5) 완료 전까지 어떠한 구현도 시작하지 않는다**
3. PROGRESS.md만 읽고 직접 구현 재개하는 것은 **절대 금지**
4. 모든 복귀 경로는 `Skill("run-phase", "N")` 또는 run-phase.md 인라인 실행으로 끝난다

---

### 8. 협업 트래커 갱신 (update-collaboration-tracker)

다음 상황에서 `refs/collaboration-tracker.md`를 갱신한다:
- **가상 데이터 참조 시**: "4. 개발 과정에서 발견된 항목" 섹션에 기록
- **새로운 외부 의존성 발견 시**: 필요 부서와 확인 내용 기록
- **가상 → 실제 전환 시**: `refs/policies/` 갱신 + 상태를 🔵 → 🟢로 변경
- **Phase 완료 시**: "1. 전체 진행 현황" 수치 갱신

---

### 9. 스펙·문서 동기화 (spec-doc-sync)

**적용 대상**: `spec.md`, `plan.md`, `tasks.md`, `api-spec.yaml`, `data-model.md`, `integration-registry.md`, `decisions.md`

코드 변경이 프로젝트 문서에 영향을 주면 같은 턴에서 문서를 함께 갱신한다:

| 변경 유형 | 갱신 대상 |
|---|---|
| API 엔드포인트·응답 필드 | `contracts/api-spec.yaml`, `spec.md` |
| DB 필드·상태 전이·관계 | `data-model.md`, `spec.md` |
| 환경변수·의존성·실행 방법 | `.env.example`, `backend/README.md` |
| Phase·태스크 완료 | `tasks.md`, `plan.md` |
| 외부 연동 변경 | `integration-registry.md`, `.env.example` |
| 설계 판단 | `decisions.md` |

---

## 주요 경로 참조

| 경로 | 설명 |
|---|---|
| `refs/INDEX.md` | 빠른 결정 가이드 — 기술 결정 시 먼저 확인 |
| `refs/policies/` | 인증·보안·인프라·데이터·배포 정책 |
| `refs/collaboration-tracker.md` | 협업 필요 항목 추적 |
| `.claude/skills/` | 슬래시커맨드 스킬 파일 (18개) |
| `.claude/settings.json` | 권한 및 hooks 설정 |
| `d2a-mcp-server/` | D2A 하네스 MCP 서버 (TypeScript) |
| `specs/.template/` | spec.md, plan.md, tasks.md 템플릿 |
| `specs/.template/VERSION` | 템플릿 버전 및 변경 이력 |
| `work-analysis/` | 3층 구조 근거층 — 디폴트 개선의 단일 근거. `DESIGN-FLOW-COMPARISON.md` + `baseline-defaults/` 동결 스냅샷 (v1.6.0+) |
| `scripts/log-activity.sh` | 활동 로그 기록 |
| `scripts/notify-slack.sh` | 슬랙 알림 발송 |
| `scripts/setup-https.sh` | 로컬 HTTPS + Caddy 게이트키퍼 1회 셋업 (Stage 1.6) |
| `scripts/save-auth-state.sh` | INSIGN/NXAS 1회 수동 로그인 → storageState 저장 (create-spec Step 2.7 통합) |
| `scripts/change-auth-profile.sh` | 인증 프로필 변경 자동화 (6단계 정리) |
| `scripts/extract-routes.sh` | spec.md/PRD → runtime-health ROUTES 자동 갱신 |
| `scripts/sync-state-to-env.sh` | state.json → .env.example 자동 동기화 |
| `logs/boilerplate-activity.md` | 활동 로그 |

---

## 사용 가능한 스킬 (슬래시 커맨드)

스킬 파일: `.claude/skills/{name}.md` | 호출: `Skill("name")` 도구 사용

### 스킬 호출 규약 (필수)

사용자가 아래 표에 있는 스킬 이름을 언급하면 (슬래시 유무, 한국어 자연어 표현 무관) 다음 순서를 반드시 따른다:

1. **즉시 `Skill("<이름>", "<args>")` 호출 시도** — 텍스트로 요약하거나 "이 스킬은 ~를 합니다" 같은 설명으로 대체 금지.
2. **"Unknown skill" 또는 호출 실패 시** `Read(".claude/skills/<이름>.md")` 폴백 — 파일 내용을 읽어 Step을 순차 실행.
3. **폴백 실행 시** 파일에 명시된 모든 Step을 빠짐없이 수행. Step 3(서브에이전트 리뷰)은 절대 스킵 금지.
4. **스킬명 추정 금지** — 표에 없는 이름은 사용자에게 확인 후 진행.
5. **응답 본문에 다음 스킬을 안내할 때는 자연어 표기를 사용한다** — `/<이름>` 형식은 응답 안에서 자동 실행되지 않으므로, 사용자가 그 텍스트를 다시 입력해야 한다. 따라서 사용자에게 다음 동작을 권할 때는 `` `<이름> 실행해줘` `` 같은 자연어 형식으로 출력한다. 단, 본 표·매칭 예시·내부 식별자 참조(`` `/스킬명` `` 형태의 백틱 식별)는 그대로 유지한다.

매칭 예시:
- "run-phase 1 해줘" / "/run-phase 1" / "Phase 1 실행해줘" → `Skill("run-phase", "1")`
- "spec 만들어줘" / "create-spec" / "스펙 작성해줘" → `Skill("create-spec")`
- "리뷰 돌려줘" / "subagent-review" → `Skill("subagent-review")`

이 규약은 [CLAUDE.md](CLAUDE.md)의 다른 모든 행동 규칙보다 **우선 적용**된다. 자체 해석으로 작업을 시작하는 것은 규칙 위반이다.

| 스킬 | 용도 |
|---|---|
| `/boilerplate-setup` | 프로젝트 초기 설정 마법사 (디자인·기술스택·인프라 결정) |
| `/create-spec` | spec.md → plan.md → tasks.md 문서 생성 |
| `/collect-prerequisites` | 외부 연동 자격증명 수집 + Smoke Test + integration-ready.md 발급 |
| `/run-phase` | tasks.md Phase 자율 실행 (read/done 스펙 기반) |
| `/add-feature` | Phase 완료 후 추가 개발 표준 진입점 (스코프 정의 → 구현 → 규모 기반 리뷰 → 커밋) |
| `/session-phase-workflow` | Phase 실행·자율 실행·블로커 처리·복귀 절차 |
| `/check-decision-gates` | 구현 전 미결정 항목 일괄 검증 |
| `/analyze-integrations` | 외부 연동 시스템 분석 |
| `/run-spike` | 기술 검증 PoC 실행 |
| `/design-research` | 디자인 시스템 리서치 워크플로 |
| `/ui-design-workflow` | PRD→0단계 게이트→3안 발산→확정 락→상태설계→자가점검→0-드리프트 전사→AI UT 게이트 (v1.6.0+) |
| `/ai-usability-test` | Playwright + 3 페르소나 + Nielsen 휴리스틱. D2A storageState 자동 통합, MCP `ut:` done 기준 |
| `/generate-context-docs` | 디렉토리별 CONTEXT.md 자동 생성 |
| `/internal-doc-survey` | 사내 정책 문서 수집 |
| `/update-policy-refs` | 정책 갱신 및 코드 영향 분석 |
| `/integrate-external-system` | 외부 시스템 연동 처리 |
| `/pre-launch-check` | 배포 전 검증 체크리스트 |
| `/subagent-review` | 병렬 코드 리뷰 (결과 취합·수정은 메인 에이전트) |
| `/refine-prd` | PRD 정제 워크플로 |
| `/d2a-installer` | D2A 보일러플레이트 설치 |

---

## 계층형 CLAUDE.md 분리

`/boilerplate-setup` Stage 2에서 `frontend/CLAUDE.md`와 `backend/CLAUDE.md`를 자동 생성한다.
각 서브디렉토리 작업 시 해당 CLAUDE.md가 자동 로드되어 루트 CLAUDE.md와 합산 적용된다.

> 스킬 로딩 문제 등 운영 이슈는 `SETUP.md`의 트러블슈팅 섹션을 참조한다.
