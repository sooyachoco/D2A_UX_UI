import { describe, it, expect, afterEach } from "vitest";
import { writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { checkPhaseGate } from "../tools/phase-gate.js";
import { DEFAULT_STATE, STATE_SCHEMA_VERSION } from "../shared/state-schema.js";
import { createTempGitRepo, mockCwd } from "./helpers.js";

describe("checkPhaseGate", () => {
  let dir: string;
  let cleanup: () => void;
  let cwdSpy: ReturnType<typeof import("vitest").vi.spyOn>;

  afterEach(() => {
    cwdSpy?.mockRestore();
    cleanup?.();
  });

  function setup(opts: {
    tasksContent?: string;
    integrationReady?: boolean;
    integrationReadyContent?: string;
    decisionsContent?: string;
    stateBlockers?: Array<{ task: string; reason: string; since: string }>;
  } = {}) {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });

    if (opts.tasksContent !== undefined) {
      writeFileSync(join(dir, "tasks.md"), opts.tasksContent, "utf-8");
    }

    if (opts.integrationReady !== false && opts.integrationReadyContent !== undefined) {
      writeFileSync(join(dir, "integration-ready.md"), opts.integrationReadyContent, "utf-8");
    }

    if (opts.decisionsContent !== undefined) {
      writeFileSync(join(dir, "decisions.md"), opts.decisionsContent, "utf-8");
    }

    const state = {
      ...DEFAULT_STATE,
      schema_version: STATE_SCHEMA_VERSION,
      blockers: opts.stateBlockers ?? [],
    };
    writeFileSync(join(dir, ".claude/state.json"), JSON.stringify(state), "utf-8");
  }

  // ── integration-ready.md ─────────────────────────────────────────────────

  it("Phase 0.5 태스크 없으면 integration-ready.md 불필요", async () => {
    setup({
      tasksContent: `## Phase 1\n### T1-001: 태스크\n**status**: ☐\n**read**: -\n**write**: a.ts\n**done**: file: a.ts\n**deps**: -\n`,
    });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.ok).toBe(true);
    expect(result.blockers).toHaveLength(0);
  });

  it("Phase 0.5 태스크 있고 integration-ready.md 없으면 차단", async () => {
    setup({
      tasksContent: `## Phase 0.5\n### T0-001: 연동\n**status**: ☑\n**read**: -\n**write**: integration-ready.md\n**done**: file: integration-ready.md\n**deps**: -\n\n## Phase 1\n### T1-001: 구현\n**status**: ☐\n**read**: -\n**write**: a.ts\n**done**: file: a.ts\n**deps**: T0-001\n`,
    });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.ok).toBe(false);
    expect(result.blockers.some((b) => b.includes("integration-ready.md"))).toBe(true);
  });

  it("integration-ready.md 있지만 AUTONOMOUS ZONE 문구 없으면 차단", async () => {
    setup({
      tasksContent: `## Phase 0.5\n### T0-001: 연동\n**status**: ☑\n**read**: -\n**write**: integration-ready.md\n**done**: file: integration-ready.md\n**deps**: -\n\n## Phase 1\n### T1-001: 구현\n**status**: ☐\n**read**: -\n**write**: a.ts\n**done**: file: a.ts\n**deps**: T0-001\n`,
      integrationReadyContent: "일부 항목 미완료",
    });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.ok).toBe(false);
    expect(result.blockers.some((b) => b.includes("AUTONOMOUS ZONE"))).toBe(true);
  });

  it("integration-ready.md 정상 → 차단 없음", async () => {
    setup({
      tasksContent: `## Phase 0.5\n### T0-001: 연동\n**status**: ☑\n**read**: -\n**write**: integration-ready.md\n**done**: file: integration-ready.md\n**deps**: -\n\n## Phase 1\n### T1-001: 구현\n**status**: ☐\n**read**: -\n**write**: a.ts\n**done**: file: a.ts\n**deps**: -\n`,
      integrationReadyContent: "✅ AUTONOMOUS ZONE 진입 가능",
    });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.ok).toBe(true);
  });

  // ── decisions.md ─────────────────────────────────────────────────────────

  it("decisions.md ⬜ 일반 항목은 unresolved_decisions에 포함된다", async () => {
    setup({
      decisionsContent: "| 에러 메시지 문구 | ⬜ 미결정 | 한국어 vs 영어 |\n| Cache | ✅ Redis | - |",
    });
    const result = await checkPhaseGate({ phase: 0 });
    expect(result.unresolved_decisions.length).toBeGreaterThan(0);
    expect(result.unresolved_decisions.some((d) => d.includes("⬜"))).toBe(true);
  });

  it("decisions.md DB/인증 등 인프라 ⬜ 항목은 blockers로 승격된다", async () => {
    setup({
      decisionsContent: "| DB | ⬜ 미결정 | PostgreSQL vs MySQL |\n| 인증 | ⬜ 미결정 | SSO vs 없음 |",
    });
    const result = await checkPhaseGate({ phase: 0 });
    // DB·인증 키워드는 critical → blockers로 승격 (unresolved_decisions에 없어야 함)
    expect(result.blockers.some((b) => b.includes("인프라·인증·보안 미결정"))).toBe(true);
    expect(result.unresolved_decisions.length).toBe(0);
  });

  it("decisions.md ⬜ 없으면 unresolved_decisions 비어있다", async () => {
    setup({
      decisionsContent: "| DB | ✅ PostgreSQL | 선택 완료 |",
    });
    const result = await checkPhaseGate({ phase: 0 });
    expect(result.unresolved_decisions).toHaveLength(0);
  });

  // ── state.json blockers ───────────────────────────────────────────────────

  it("state.json에 미해결 블로커 있으면 차단", async () => {
    setup({
      stateBlockers: [{ task: "T1-004", reason: "rollback 실행됨", since: new Date().toISOString() }],
    });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.ok).toBe(false);
    expect(result.blockers.some((b) => b.includes("T1-004"))).toBe(true);
  });

  // ── 이전 Phase 완료 ───────────────────────────────────────────────────────

  it("이전 Phase 미완료 태스크 있으면 차단", async () => {
    setup({
      tasksContent: `## Phase 1\n### T1-001: 미완료\n**status**: ☐\n**read**: -\n**write**: a.ts\n**done**: file: a.ts\n**deps**: -\n\n## Phase 2\n### T2-001: 구현\n**status**: ☐\n**read**: a.ts\n**write**: b.ts\n**done**: file: b.ts\n**deps**: T1-001\n`,
    });
    const result = await checkPhaseGate({ phase: 2 });
    expect(result.ok).toBe(false);
    expect(result.blockers.some((b) => b.includes("Phase 1 미완료"))).toBe(true);
  });

  // ── GNB 삽입 위치 후보 (create-spec Step 2.7 패턴별) ───────────────────────

  /** gnb_required=true 상태에서 GNB 스크립트 파일을 특정 경로에 작성한다. */
  function setupGnbProject(gnbFileRelPath: string) {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });

    const fullPath = join(dir, gnbFileRelPath);
    mkdirSync(join(fullPath, ".."), { recursive: true });
    writeFileSync(
      fullPath,
      `<Script src="https://ssl-test.nexon.com/s1/global/ngb_head.js" />\n` +
      `<Script src="https://rs-test.nxfs.nexon.com/common/js/gnb.min.js" />\n` +
      `<Script src="https://ssl-test.nexon.com/s1/global/ngb_bodyend.js" />\n`,
      "utf-8"
    );

    const state = {
      ...DEFAULT_STATE,
      schema_version: STATE_SCHEMA_VERSION,
      gnb_required: true,
    };
    writeFileSync(join(dir, ".claude/state.json"), JSON.stringify(state), "utf-8");
  }

  it("Next.js App Router: frontend/src/app/layout.tsx의 GNB 스크립트로 게이트 통과", async () => {
    setupGnbProject("frontend/src/app/layout.tsx");
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("GNB 스크립트 삽입 위치 없음"))).toBe(false);
    expect(result.blockers.some((b) => b.includes("GNB 스크립트 미삽입"))).toBe(false);
  });

  it("Vite SPA: frontend/index.html의 GNB 스크립트로 게이트 통과", async () => {
    setupGnbProject("frontend/index.html");
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("GNB 스크립트 삽입 위치 없음"))).toBe(false);
    expect(result.blockers.some((b) => b.includes("GNB 스크립트 미삽입"))).toBe(false);
  });

  // ── specs/.template placeholder false positive 방지 ───────────────────────

  it("specs/.template/decisions.md의 🔴 미결정 placeholder는 게이트에 영향 없음", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    mkdirSync(join(dir, "specs/.template"), { recursive: true });
    mkdirSync(join(dir, "specs/001-feature"), { recursive: true });

    writeFileSync(
      join(dir, "specs/.template/decisions.md"),
      "| DEC-01 | {주제} | {결정 내용} | {왜 이 선택인지} | ✅ 확정 / 🔴 미결정 |\n",
      "utf-8"
    );
    writeFileSync(
      join(dir, "specs/001-feature/decisions.md"),
      "| DB | ✅ PostgreSQL | 선택 완료 |\n",
      "utf-8"
    );
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({ ...DEFAULT_STATE, schema_version: STATE_SCHEMA_VERSION }),
      "utf-8"
    );

    const result = await checkPhaseGate({ phase: 0 });
    expect(result.unresolved_decisions).toHaveLength(0);
    expect(result.blockers.some((b) => b.includes("미결정"))).toBe(false);
  });

  it("specs/.template/integration-ready.md의 placeholder는 가짜 통과시키지 않는다", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    mkdirSync(join(dir, "specs/.template"), { recursive: true });

    // .template 의 placeholder 헤더에는 "✅ AUTONOMOUS ZONE 진입 가능" 문자열이 그대로 포함된다.
    // dot-prefix 제외가 동작하지 않으면 실제 integration-ready.md 없이도 게이트가 통과해버린다.
    writeFileSync(
      join(dir, "specs/.template/integration-ready.md"),
      "## 판정: {✅ AUTONOMOUS ZONE 진입 가능 / ❌ 미완료 항목 있음}\n",
      "utf-8"
    );
    writeFileSync(
      join(dir, "tasks.md"),
      `## Phase 0.5\n### T0-001: 연동\n**status**: ☑\n**read**: -\n**write**: integration-ready.md\n**done**: file: integration-ready.md\n**deps**: -\n\n## Phase 1\n### T1-001: 구현\n**status**: ☐\n**read**: -\n**write**: a.ts\n**done**: file: a.ts\n**deps**: T0-001\n`,
      "utf-8"
    );
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({ ...DEFAULT_STATE, schema_version: STATE_SCHEMA_VERSION }),
      "utf-8"
    );

    const result = await checkPhaseGate({ phase: 1 });
    expect(result.ok).toBe(false);
    expect(result.blockers.some((b) => b.includes("integration-ready.md 없음"))).toBe(true);
  });

  // ── PROGRESS.md "코드 패턴 메모" placeholder 잔존 ─────────────────────────

  it("Phase >= 2 진입 시 PROGRESS.md placeholder 잔존하면 차단", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({ ...DEFAULT_STATE, schema_version: STATE_SCHEMA_VERSION }),
      "utf-8"
    );
    writeFileSync(
      join(dir, "PROGRESS.md"),
      "## 현재 상태\n\n...\n\n## 코드 패턴 메모\n\n### 디렉터리 구조\n\n```\n{실제 프로젝트 구조 — 첫 Phase 완료 후 AI가 자동 기록}\n```\n\n### 핵심 인터페이스\n\n| 파일 | 이름 |\n|---|---|\n| {예: backend/app/middleware/auth.py} | {require_auth} |\n",
      "utf-8"
    );

    const result = await checkPhaseGate({ phase: 2 });
    expect(result.ok).toBe(false);
    expect(result.blockers.some((b) => b.includes("PROGRESS.md \"코드 패턴 메모\" placeholder 잔존"))).toBe(true);
    expect(result.blockers.some((b) => b.includes("{실제 프로젝트 구조"))).toBe(true);
    expect(result.blockers.some((b) => b.includes("{예:"))).toBe(true);
  });

  it("Phase 1 진입 시에는 PROGRESS.md placeholder 검사 생략", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({ ...DEFAULT_STATE, schema_version: STATE_SCHEMA_VERSION }),
      "utf-8"
    );
    writeFileSync(
      join(dir, "PROGRESS.md"),
      "## 코드 패턴 메모\n\n{실제 프로젝트 구조 ...}\n{예: ...}",
      "utf-8"
    );

    const result = await checkPhaseGate({ phase: 1 });
    // Phase 1 진입 시점에는 이전 Phase 가 없으므로 placeholder 검사 미작동
    expect(result.blockers.some((b) => b.includes("PROGRESS.md"))).toBe(false);
  });

  it("PROGRESS.md placeholder 치환된 경우 차단 없음", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({ ...DEFAULT_STATE, schema_version: STATE_SCHEMA_VERSION }),
      "utf-8"
    );
    writeFileSync(
      join(dir, "PROGRESS.md"),
      "## 코드 패턴 메모\n\n### 디렉터리 구조\n\n```\nbackend/\n  src/\n    api/v1/\n    services/\n```\n\n### 핵심 인터페이스\n\n| backend/src/middleware/auth.ts | authMiddleware |\n",
      "utf-8"
    );

    const result = await checkPhaseGate({ phase: 2 });
    expect(result.blockers.some((b) => b.includes("PROGRESS.md"))).toBe(false);
  });

  it("PROGRESS.md 없으면 placeholder 검사 생략", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({ ...DEFAULT_STATE, schema_version: STATE_SCHEMA_VERSION }),
      "utf-8"
    );

    const result = await checkPhaseGate({ phase: 2 });
    expect(result.blockers.some((b) => b.includes("PROGRESS.md"))).toBe(false);
  });

  // ── Step 2.7 INSIGN 자산 검증 (docs/case-studies/step27-validation-gap.md) ──

  /** auth_profile=insign 상태에서 Phase 1 게이트 검증용 환경 구성. */
  function setupInsignProject(opts: {
    insignFiles?: boolean;
    mockAuthContext?: boolean;
    storageState?: "missing" | "valid" | "expired";
    userApproved?: boolean;
    activityLog?: boolean;
  } = {}) {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    mkdirSync(join(dir, "frontend/src/lib"), { recursive: true });
    mkdirSync(join(dir, "frontend/src/context"), { recursive: true });

    // 기본 GNB 스크립트 (INSIGN 검증과 별개) — Phase 1 GNB 검증 통과용
    mkdirSync(join(dir, "frontend"), { recursive: true });
    writeFileSync(
      join(dir, "frontend/index.html"),
      `<script src="ngb_head.js"></script><script src="gnb.min.js"></script><script src="ngb_bodyend.js"></script>`,
      "utf-8"
    );

    if (opts.insignFiles !== false) {
      writeFileSync(join(dir, "frontend/src/lib/insign.ts"), "export {};", "utf-8");
      writeFileSync(join(dir, "frontend/src/context/InsignContext.tsx"), "export {};", "utf-8");
      writeFileSync(join(dir, "frontend/src/lib/apiClient.ts"), "export {};", "utf-8");
    }

    if (opts.mockAuthContext) {
      writeFileSync(
        join(dir, "frontend/src/context/AuthContext.tsx"),
        `const MOCK_USER = { name: "test" };\nlocalStorage.getItem('todo-mock-auth');`,
        "utf-8"
      );
    }

    if (opts.storageState && opts.storageState !== "missing") {
      mkdirSync(join(dir, "tests/e2e/.auth"), { recursive: true });
      const expires =
        opts.storageState === "valid"
          ? Math.floor(Date.now() / 1000) + 86400
          : Math.floor(Date.now() / 1000) - 86400;
      writeFileSync(
        join(dir, "tests/e2e/.auth/user.json"),
        JSON.stringify({ cookies: [{ name: "_ifwt", expires }] }),
        "utf-8"
      );
    }

    if (opts.activityLog) {
      mkdirSync(join(dir, "logs"), { recursive: true });
      writeFileSync(
        join(dir, "logs/boilerplate-activity.md"),
        "[SKILL] create-spec Step 2.7 user-approval — 2026-05-12\n",
        "utf-8"
      );
    }

    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({
        ...DEFAULT_STATE,
        schema_version: STATE_SCHEMA_VERSION,
        gnb_required: true,
        auth_profile: "insign",
        step27_user_approved: opts.userApproved ?? false,
      }),
      "utf-8"
    );
  }

  it("INSIGN 자산 누락 시 차단", async () => {
    setupInsignProject({ insignFiles: false, storageState: "valid", userApproved: true });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("INSIGN 자산 누락"))).toBe(true);
    expect(result.blockers.some((b) => b.includes("frontend/src/lib/insign.ts"))).toBe(true);
  });

  it("Mock AuthContext 잔존 시 차단", async () => {
    setupInsignProject({ mockAuthContext: true, storageState: "valid", userApproved: true });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("Mock AuthContext 잔존"))).toBe(true);
  });

  it("storageState 없음 시 차단", async () => {
    setupInsignProject({ storageState: "missing", userApproved: true });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("storageState 없음"))).toBe(true);
  });

  it("storageState 만료 시 차단", async () => {
    setupInsignProject({ storageState: "expired", userApproved: true });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("storageState 만료"))).toBe(true);
  });

  it("Step 2.7 사용자 승인 흔적 없으면 차단", async () => {
    setupInsignProject({ storageState: "valid", userApproved: false });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("Step 2.7 사용자 승인"))).toBe(true);
  });

  it("Step 2.7 사용자 승인 — activity log 이벤트로도 통과", async () => {
    setupInsignProject({ storageState: "valid", userApproved: false, activityLog: true });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("Step 2.7 사용자 승인"))).toBe(false);
  });

  it("INSIGN 모든 자산 갖춰진 경우 통과", async () => {
    setupInsignProject({ storageState: "valid", userApproved: true });
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("INSIGN"))).toBe(false);
    expect(result.blockers.some((b) => b.includes("Mock"))).toBe(false);
    expect(result.blockers.some((b) => b.includes("storageState"))).toBe(false);
    expect(result.blockers.some((b) => b.includes("Step 2.7"))).toBe(false);
  });

  it("auth_profile=none 이면 INSIGN 자산 검증 생략", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({
        ...DEFAULT_STATE,
        schema_version: STATE_SCHEMA_VERSION,
        auth_profile: "none",
      }),
      "utf-8"
    );
    const result = await checkPhaseGate({ phase: 1 });
    expect(result.blockers.some((b) => b.includes("INSIGN"))).toBe(false);
    expect(result.blockers.some((b) => b.includes("storageState"))).toBe(false);
  });

  // ── auth_profile 키워드 블랙리스트 (할루시네이션 방지) ────────────────────

  it("auth_profile=insign + prerequisites.md OAuth 키워드 차단", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    mkdirSync(join(dir, "specs/001-app"), { recursive: true });
    writeFileSync(
      join(dir, "specs/001-app/prerequisites.md"),
      "| NCSR Callback URL | 🔴 차단 | ⬜ | redirect_uri 필요 |\n",
      "utf-8"
    );
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({
        ...DEFAULT_STATE,
        schema_version: STATE_SCHEMA_VERSION,
        auth_profile: "insign",
      }),
      "utf-8"
    );
    const result = await checkPhaseGate({ phase: 0.5 });
    expect(result.ok).toBe(false);
    expect(result.blockers.some((b) => b.includes("금지된 OAuth 키워드"))).toBe(true);
    expect(result.blockers.some((b) => b.includes("redirect_uri"))).toBe(true);
  });

  it("auth_profile=nxas 면 OAuth 키워드 허용 (INSIGN 블랙리스트 적용 안 됨)", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    mkdirSync(join(dir, "specs/001-app"), { recursive: true });
    writeFileSync(
      join(dir, "specs/001-app/prerequisites.md"),
      "| redirect_uri | 🔴 차단 | ⬜ | callback url |\n",
      "utf-8"
    );
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({
        ...DEFAULT_STATE,
        schema_version: STATE_SCHEMA_VERSION,
        auth_profile: "nxas",
      }),
      "utf-8"
    );
    const result = await checkPhaseGate({ phase: 0.5 });
    expect(result.blockers.some((b) => b.includes("금지된 OAuth 키워드"))).toBe(false);
  });
});
