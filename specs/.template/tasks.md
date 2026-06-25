# 태스크 목록

> plan.md 기반으로 분해된 구현 태스크입니다.
> 각 태스크는 `/run-phase`가 독립 컨텍스트로 실행할 수 있는 자기완결 스펙을 포함합니다.
> **status**: ☐ (미완료) / ☑ (완료)
> **parallel**: 동일 Phase 내 deps 공유 없이 독립 실행 가능한 태스크 ID (생략 시 순차 실행)

---

## Phase 0: React + Mock UI 구현 ☑ (스펙 단계 완료)

> Phase 0은 create-spec Step 2.7(React 프로젝트 + Mock 서비스 레이어 구현 + 사용자 승인)에서 완료됨.

### T001: React 프로젝트 초기화 + 디자인 시스템 셋업
**status**: ☑

### T002: 공통 레이아웃 + GNB/INSIGN 연동
**status**: ☑

### T003: 전체 페이지 UI 구현 (spec.md 기반 Mock 서비스)
**status**: ☑

<!-- ─────────────────────────────────────────────────────────────────────────
     T020-step27-verify는 auth_profile ∈ {insign, insign-with-nxas, nxas} 시
     반드시 포함한다. auth_profile=none 프로젝트는 이 태스크를 삭제한다.
     create-spec Step 2.7 산출물(GNB·INSIGN·storageState·사용자 승인)을
     코드로 강제 검증한다. 누락 시 Phase 1 진입 게이트에서 자동 차단된다.
     케이스 배경: docs/case-studies/step27-validation-gap.md
     ───────────────────────────────────────────────────────────────────── -->

### T020-step27-verify: Step 2.7 산출물 검증 (auth_profile ≠ none 전용)
**read**: -
**write**: -
**done**:
  - contains: frontend/index.html :: ngb_head.js
  - contains: frontend/index.html :: gnb.min.js
  - contains: frontend/index.html :: ngb_bodyend.js
  - file: frontend/src/lib/insign.ts
  - file: frontend/src/context/InsignContext.tsx
  - file: frontend/src/lib/apiClient.ts
  - contains: frontend/src/context/InsignContext.tsx :: useInsign
  - regex: frontend/src/lib/apiClient.ts :: buildAuthHeaders
  - file: tests/e2e/.auth/user.json
  - json: .claude/state.json :: .auth_storage_ready=true
  - json: .claude/state.json :: .step27_user_approved=true
**deps**: T003
**status**: ☐

---

<!-- Phase 0.5는 외부 연동(🔴)이 1개 이상인 프로젝트에만 포함한다.
     모든 기능이 🟢 자체 개발이면 이 Phase를 삭제한다. -->

## Phase 0.5: 외부 연동 검증

> 모든 ☑ 완료 후 integration-ready.md가 발급되어야 Phase 1 진입 가능.
> `/collect-prerequisites` 스킬이 이 Phase를 담당한다.

### T050: 환경변수 키 목록 확정
**read**: specs/{NNN}/prerequisites.md, .env.example
**write**: .env.example
**done**:
  - file: .env.example
  - contains: .env.example :: # required
**deps**: -
**status**: ☐

### T051: 전체 외부 연동 Smoke Test + 환경변수 검증 + integration-ready.md 발급
**read**: specs/{NNN}/prerequisites.md
**write**: integration-ready.md
**done**:
  - file: integration-ready.md
  - contains: integration-ready.md :: ✅ AUTONOMOUS ZONE 진입 가능
  - cmd: bash scripts/check-env.sh
**skill**: /collect-prerequisites
**deps**: T050
**status**: ☐

---

<!-- Phase 0.6/0.7은 방안 A에서 create-spec Step 2.7(React + Mock 구현)로 통합되었다.
     GNB 렌더링 + INSIGN 로그인 플로우를 Step 2.7 HTTPS 세션에서 한 번에 확인한다.
     Phase 0.5 완료 후 Phase 1으로 직행한다. 이 섹션은 삭제해도 된다. -->

---

## Phase 1: {이름}

<!-- 태스크 스펙 작성 규칙:
  - read: 이 태스크에 필요한 파일만 (광범위 파일 전체는 no-read로 금지)
  - write: 이 태스크가 생성/수정할 파일
  - done: 타입 명시 형식으로 기술 (아래 6가지 타입)
      file: {경로}                    — 파일 존재 확인
      cmd: {셸 명령}                  — exit 0 = 통과 (pytest, npm run build 등)
      contains: {경로} :: {문자열}    — 파일 내 문자열 포함 확인
      regex: {경로} :: {정규식}       — 파일 내 정규식 매칭 확인
      json: {경로} :: .{dot-path}     — JSON 경로 존재 확인 (.key=value로 값 비교)
      coverage: {경로} :: {임계값}    — 라인 커버리지 임계값 확인 (cmd:로 리포트 먼저 생성 필요)
  - e2e 관례: tests/e2e/{feature-name}.spec.ts — 구현 태스크와 함께 작성, cmd: npx playwright test 로 검증
              설정 없으면 boilerplate-setup Stage 2-E 먼저 실행. 미설정 시 subagent-review에서 REQUIRED 경고.
  - no-read: 읽지 말아야 할 파일 (선택)
  - deps: 선행 완료 필요 태스크 ID (없으면 -)
  - parallel: 이 태스크와 동시에 실행 가능한 태스크 ID (선택, 생략 시 순차)
              조건: 동일 write 파일 없음, deps 공유 없음, 동일 Phase 내에서만 병렬 가능
  ─────────────────────────────────────────────────────────────────────
  [Phase 1 주요 변경점 — create-spec Step 2.7 이후]
  - 프론트엔드 초기화 / GNB+INSIGN 연동 / Mock 서비스 레이어 / 페이지 UI 구현은
    create-spec Step 2.7에서 이미 완료되었다. Phase 1에서 중복 구현하지 않는다.
  - Phase 1의 프론트엔드 작업은 오직 "Mock → 실제 API 교체 + Mock 코드 제거"만 포함한다.
  - prototype/index.html은 존재하지 않으므로 read 필드에 포함하지 않는다.
-->

### T101: {태스크 제목 — 백엔드 API 구현}
**read**: specs/{NNN}/spec.md#{섹션}, specs/{NNN}/contracts/api-spec.yaml, {정책 파일}
**write**: {출력 파일 1}, {출력 파일 2}
**done**:
  - file: {출력 파일 1}
  - cmd: npm run build
  - regex: {출력 파일 1} :: export (default )?function {함수명}
**deps**: T051
**status**: ☐

<!-- Mock → 실제 API 교체 태스크 — Phase 1 프론트엔드 작업의 유일한 태스크
     create-spec Step 2.7에서 이미 Mock 서비스 레이어와 페이지 UI가 구현되어 있다.
     이 태스크는 서비스 레이어에서 USE_MOCK 분기를 제거하고 실제 apiFetch로 단일화한다.
     check-mock-cleanup.sh 통과가 Phase 2 진입의 필수 조건이다. -->

### T{N}: Mock → 실제 백엔드 API 교체 + Mock 코드 제거
**read**: specs/{NNN}/contracts/api-spec.yaml,
          frontend/src/services/{entity}Service.ts,
          frontend/src/mocks/{entity}Mock.ts
**write**: frontend/src/services/{entity}Service.ts,
           frontend/src/mocks/{entity}Mock.ts (삭제),
           frontend/src/mocks/index.ts (삭제)
**done**:
  - contains: frontend/src/services/{entity}Service.ts :: apiFetch
  - cmd: test ! -d frontend/src/mocks && echo "mocks 폴더 제거됨"
  - cmd: cd frontend && npm run build
  - cmd: npx playwright test tests/e2e/{feature}.spec.ts --reporter=line
  - cmd: bash scripts/check-mock-cleanup.sh
**deps**: T{N-1}
**status**: ☐

<!-- Mock 제거 절차:
  1. {entity}Service.ts에서 USE_MOCK 분기 제거 → apiFetch 직접 호출로 단일화
  2. frontend/src/mocks/ 폴더 전체 삭제
  3. .env.example에서 VITE_USE_MOCK 항목 제거
  4. frontend/src/types/ 의 rough type placeholder([key: string]: unknown) 제거
  5. 빌드 + E2E 테스트 + check-mock-cleanup.sh 통과 확인

  check-mock-cleanup.sh 검증 항목:
    [1] frontend/src/mocks/ 디렉터리 없음
    [2] services/ 내 USE_MOCK/VITE_USE_MOCK 참조 없음
    [3] 프로덕션 env에 VITE_USE_MOCK=true 없음
    [4] types/ 내 [key: string]: unknown/any 없음 (rough type 제거 확인)
-->

### T102: {태스크 제목}
**read**: {입력 파일}
**write**: {출력 파일}
**done**:
  - file: {출력 파일}
  - contains: {출력 파일} :: {핵심 문자열}
  - json: package.json :: .scripts.build
**deps**: T101
**parallel**: T103
**status**: ☐

### T103: {태스크 제목}
**read**: {입력 파일}
**write**: {출력 파일}
**done**:
  - file: {출력 파일}
  - cmd: pytest tests/{테스트 파일} -v
**deps**: T101
**parallel**: T102
**status**: ☐

<!-- coverage: 타입 예시 — 테스트 + 커버리지 임계값을 같이 검증할 때 사용.
     cmd:으로 리포트를 생성한 뒤 coverage:로 임계값을 확인한다. -->
### T103-cov-example: 백엔드 API 커버리지 80% 이상 확인 (예시 — 실제 태스크로 사용 시 이 주석 삭제)
**read**: {구현 파일}
**write**: {출력 파일}
**done**:
  - cmd: pytest --cov=backend/app --cov-report=json -q
  - coverage: backend/app :: 80
**deps**: T101
**status**: ☐
<!-- /coverage 예시 끝 -->

<!-- e2e: 패턴 예시 — 프론트엔드 기능 구현 태스크에서 핵심 시나리오를 done 기준으로 연결.
     tests/e2e/{feature}.spec.ts를 구현 파일과 함께 작성한다.
     done: cmd: npx playwright test 통과 = MCP submit_task 승인 → AI가 직접 회귀를 감지한다.

     사용 규칙:
     - e2e 설정이 없으면 boilerplate-setup Stage 2-E에서 먼저 Playwright를 설정한다.
     - spec.ts는 Happy path 1개 + Error path 1개를 최소 단위로 작성한다.
     - CI 없는 환경에서는 dev 서버가 기동된 상태에서만 통과하므로
       webServer 설정(playwright.config.ts)이 완료되어 있어야 한다.
     - 콘솔 에러·네트워크 4xx/5xx 자동 검증은 Phase 경계에서 subagent-review Step 2-0이
       tests/e2e/runtime-health.spec.ts 를 자동 실행하여 1차 차단한다 (개별 spec에서 중복 검증 불필요).

     로그인이 필요한 프로젝트 (보호 라우트 e2e 작성 시):
     - boilerplate-setup Stage 2-E가 인증 시그널을 자동 감지해
       tests/e2e/fixtures/auth-mock.ts 를 생성한다 (insign / nxas / custom 3가지 모드 통합).
       감지 시그널:
         insign  → NEXT_PUBLIC_GID, inface.js, signin.nexon.com, _ifwt 등
         nxas    → nxas.nexon.com, EMPNO, NXAS_CLIENT_ID 등
         custom  → JWT_SECRET/SESSION_SECRET 등 환경변수, jsonwebtoken/next-auth/passport 등 의존성,
                   src/auth 디렉터리 존재 등
     - 보호 라우트 spec은 fixture 의 authenticatedPage 를 사용한다:
         import { test, expect } from '../fixtures/auth-mock';
         test('보호 라우트', async ({ authenticatedPage: page }) => { ... });
     - 모드 오버라이드: test.use({ authMode: 'custom' });
     - 실제 토큰/쿠키 발급 흐름 검증은 pre-launch-check 의 auth-smoke 단계에서 수행한다.
-->
### T{N}-e2e-example: {기능명} E2E 통과 (예시 — 실제 태스크로 사용 시 이 주석 삭제)
**read**: specs/{NNN}/spec.md#{기능섹션}
**write**: frontend/{구현파일}, tests/e2e/{feature}.spec.ts
**done**:
  - cmd: cd frontend && npm run build
  - cmd: npx playwright test tests/e2e/{feature}.spec.ts --reporter=line
**deps**: T{N-1}
**status**: ☐
<!-- /e2e 예시 끝 -->

### T1-review: 서브에이전트 코드 리뷰
**read**: -
**write**: .claude/review-tokens/phase-1.token
**skill**: subagent-review
**done**:
  - file: .claude/review-tokens/phase-1.token
**deps**: T103
**status**: ☐

---

## Phase 2: {이름}

### T201: {태스크 제목}
**read**: {입력 파일}
**write**: {출력 파일}
**done**: {검증 명령}
**deps**: T103
**status**: ☐

### T202: {태스크 제목}
**read**: {입력 파일}
**write**: {출력 파일}
**done**: {검증 명령}
**deps**: T201
**status**: ☐

### T2-review: 서브에이전트 코드 리뷰
**read**: -
**write**: .claude/review-tokens/phase-2.token
**skill**: subagent-review
**done**:
  - file: .claude/review-tokens/phase-2.token
**deps**: T202
**status**: ☐

---

## Phase 3: {이름}

### T301: {태스크 제목}
**read**: {입력 파일}
**write**: {출력 파일}
**done**: {검증 명령}
**deps**: T202
**status**: ☐

### T3-review: 서브에이전트 코드 리뷰
**read**: -
**write**: .claude/review-tokens/phase-3.token
**skill**: subagent-review
**done**:
  - file: .claude/review-tokens/phase-3.token
**deps**: T301
**status**: ☐
