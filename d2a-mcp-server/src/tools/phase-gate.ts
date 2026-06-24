import fs from "fs";
import path from "path";
import crypto from "crypto";
import { D2AState, migrateState } from "../shared/state-schema.js";
import { findTasksFile, parseTasks } from "../shared/tasks-parser.js";

export interface PhaseGateResult {
  ok: boolean;
  blockers: string[];
  unresolved_decisions: string[];
}

/** 여러 후보 경로 중 첫 번째로 존재하는 파일을 반환한다. */
function findFile(cwd: string, candidates: string[]): string | null {
  for (const c of candidates) {
    const full = path.join(cwd, c);
    if (fs.existsSync(full)) return full;
  }
  return null;
}

/** decisions.md에서 ⬜ / 🔴 미결정 항목을 추출한다. */
function extractUnresolvedDecisions(decisionsPath: string): string[] {
  try {
    const content = fs.readFileSync(decisionsPath, "utf-8");
    return content
      .split("\n")
      .filter(
        (line) =>
          line.includes("⬜") ||
          (line.includes("🔴") && line.includes("미결정"))
      )
      .map((line) => line.trim())
      .filter(Boolean);
  } catch {
    return [];
  }
}

/**
 * 미결정 항목이 인프라·인증·보안 카테고리에 해당하는지 판별한다.
 * 해당하면 unresolved_decisions가 아닌 blockers로 승격된다.
 *
 * 판별 키워드: 인증, 보안, 인프라, DB, 데이터베이스, 클라우드, 캐시, 큐,
 *             Auth, Security, Infrastructure, Database, Cloud, Cache, Queue
 */
function isCriticalDecision(line: string): boolean {
  const CRITICAL_KEYWORDS = [
    "인증", "보안", "인프라", "DB", "데이터베이스", "클라우드", "캐시", "큐",
    "Auth", "Security", "Infrastructure", "Database", "Cloud", "Cache", "Queue",
    "SSO", "NXAS", "INSIGN", "GNB", "ACL", "SSL", "TLS", "OAuth",
  ];
  const upper = line.toUpperCase();
  return CRITICAL_KEYWORDS.some((kw) => upper.includes(kw.toUpperCase()));
}

/**
 * integration-ready.md의 HMAC 서명을 검증한다.
 *
 * 서명 형식: 파일 마지막 줄 `<!-- d2a-hmac: {hex} -->`
 * 서명 대상: `{프로젝트명}:{발급일}` (파일에서 추출)
 * 서명 키: `.claude/review-token-secret`
 *
 * 서명이 없으면 통과(하위 호환 — 기존 발급 파일 처리).
 * 서명이 있으나 키 파일이 없으면 경고 없이 통과(CI 환경 등).
 * 서명·키 모두 있을 때만 검증하여 불일치 시 블로커.
 */
function verifyIntegrationReadyHmac(content: string, cwd: string): string | null {
  const hmacMatch = content.match(/<!--\s*d2a-hmac:\s*([a-f0-9]+)\s*-->/);
  if (!hmacMatch) return null; // 서명 없음 → 하위 호환 통과

  const secretFile = path.join(cwd, ".claude/review-token-secret");
  if (!fs.existsSync(secretFile)) return null; // 키 없음 → 검증 생략

  const secret = fs.readFileSync(secretFile, "utf-8").trim();
  const projectMatch = content.match(/\*\*프로젝트\*\*:\s*(.+)/);
  const dateMatch = content.match(/\*\*발급일\*\*:\s*(.+)/);

  if (!projectMatch || !dateMatch) {
    return "integration-ready.md 서명 대상 필드(프로젝트·발급일)를 파싱할 수 없음";
  }

  const message = `${projectMatch[1].trim()}:${dateMatch[1].trim()}`;
  const expected = crypto.createHmac("sha256", secret).update(message).digest("hex");

  if (expected !== hmacMatch[1]) {
    return "integration-ready.md HMAC 서명 불일치 — 파일이 위조되었거나 review-token-secret 불일치";
  }

  return null; // 검증 통과
}

/**
 * PROGRESS.md "코드 패턴 메모" 섹션의 placeholder 토큰이 잔존하는지 검사한다.
 *
 * 이전 Phase 가 완료되었다면 `{실제 프로젝트 구조` / `{예:` 등의 placeholder 는
 * 실제 값으로 치환되어 있어야 한다. 잔존 시 다음 세션이 무가치한 brief 를 읽는
 * 문제(코드 패턴 메모 무가치화)를 초래하므로 blocker 로 승격한다.
 *
 * 검사 대상 토큰:
 *   - `{실제 프로젝트 구조` — 디렉터리 구조 placeholder
 *   - `{예:` — 공통 패턴 / 핵심 인터페이스 / 다음 세션 사전 메모 placeholder
 *
 * PROGRESS.md 가 없거나 "코드 패턴 메모" 섹션 자체가 없으면 검사 생략.
 */
function detectProgressPlaceholders(progressPath: string): string[] {
  try {
    const content = fs.readFileSync(progressPath, "utf-8");
    const sectionMatch = content.match(/##\s*코드 패턴 메모[\s\S]*$/);
    if (!sectionMatch) return [];

    const section = sectionMatch[0];
    const found: string[] = [];

    if (section.includes("{실제 프로젝트 구조")) {
      found.push("`{실제 프로젝트 구조` (디렉터리 구조 placeholder)");
    }
    if (section.includes("{예:")) {
      found.push("`{예:` (공통 패턴/핵심 인터페이스/사전 메모 placeholder)");
    }

    return found;
  } catch {
    return [];
  }
}

/**
 * Phase 전환 가능 여부를 코드로 검증한다.
 *
 * 검사 항목:
 *   1. Phase >= 1 이면 integration-ready.md 존재 + "✅ AUTONOMOUS ZONE 진입 가능" + HMAC 서명
 *   2. state.json 의 미해결 blockers 확인
 *   3. state.gnb_required = true 이면 prototype/index.html 에 실제 GNB 스크립트 존재 확인
 *   4. 이전 Phase 미완료 태스크 확인
 *   5. decisions.md 의 ⬜ 항목 확인 — 인프라·인증·보안 카테고리는 blockers로 승격
 *   6. Phase >= 2 진입 시 PROGRESS.md "코드 패턴 메모" placeholder 잔존 검사
 *   7. state.auth_profile ∈ {insign, insign-with-nxas} 이면 Step 2.7 INSIGN 자산 검증
 *      (lib/insign.ts·InsignContext·apiClient·storageState·Mock 잔존·user-approval activity log)
 *   8. state.auth_profile 별 키워드 블랙리스트 검사 (할루시네이션 방지)
 */
export async function checkPhaseGate(args: { phase: number }): Promise<PhaseGateResult> {
  const { phase } = args;
  const cwd = process.cwd();
  const blockers: string[] = [];
  const unresolved_decisions: string[] = [];

  // 1. integration-ready.md 확인 (Phase 1 이상, Phase 0.5가 tasks.md에 존재할 때만)
  if (phase >= 1) {
    const tasksFileForIR = findTasksFile(cwd);
    const hasPhase05 = tasksFileForIR
      ? (() => {
          try {
            return parseTasks(tasksFileForIR).some((t) => t.phase === 0.5);
          } catch {
            return false;
          }
        })()
      : false;

    if (hasPhase05) {
      const irFile = findFile(cwd, [
        "integration-ready.md",
        "specs/integration-ready.md",
      ]);

      // specs/**/integration-ready.md 탐색
      // dot-prefix 디렉토리(`.template`, `.git` 등)는 placeholder 파일이 들어 있어 제외.
      // `.template/integration-ready.md`에는 "✅ AUTONOMOUS ZONE 진입 가능" 문자열이
      // placeholder 형식으로 포함되므로 가짜 통과(false negative)를 막아야 한다.
      let found = irFile;
      if (!found) {
        const specsDir = path.join(cwd, "specs");
        if (fs.existsSync(specsDir)) {
          for (const entry of fs.readdirSync(specsDir, { withFileTypes: true })) {
            if (entry.isDirectory() && !entry.name.startsWith(".")) {
              const candidate = path.join(specsDir, entry.name, "integration-ready.md");
              if (fs.existsSync(candidate)) { found = candidate; break; }
            }
          }
        }
      }

      if (!found) {
        blockers.push(
          "integration-ready.md 없음 — /collect-prerequisites 실행 후 재시도"
        );
      } else {
        const content = fs.readFileSync(found, "utf-8");
        if (!content.includes("✅ AUTONOMOUS ZONE 진입 가능")) {
          blockers.push(
            `integration-ready.md 판정이 "✅ AUTONOMOUS ZONE 진입 가능"이 아님 (${path.relative(cwd, found)})`
          );
        } else {
          // HMAC 서명 검증 (서명이 있을 때만)
          const hmacError = verifyIntegrationReadyHmac(content, cwd);
          if (hmacError) {
            blockers.push(hmacError);
          }
        }
      }
    }
  }

  // 2. state.json 미해결 블로커 확인
  const stateFile = path.join(cwd, ".claude/state.json");
  let stateData: D2AState | null = null;
  if (fs.existsSync(stateFile)) {
    try {
      const raw = JSON.parse(fs.readFileSync(stateFile, "utf-8")) as Partial<D2AState>;
      stateData = migrateState(raw);
      for (const b of stateData.blockers ?? []) {
        blockers.push(`미해결 블로커: [${b.task}] ${b.reason}`);
      }
    } catch {
      // state.json 파싱 실패는 무시
    }
  }

  // 3. GNB 스크립트 실재 확인 (state.gnb_required = true 이면서 Phase 1 이상)
  if (phase >= 1 && stateData?.gnb_required === true) {
    // create-spec Step 2.7 패턴별 GNB 삽입 위치:
    //   - prototype: prototype/index.html
    //   - Vite SPA: frontend/index.html (Vite 5+ 표준)
    //   - CRA:      frontend/public/index.html
    //   - Next.js App Router (방안 A): frontend/src/app/layout.tsx 또는 frontend/app/layout.tsx
    // findFile은 첫 매치만 반환하므로 기존 프로젝트는 영향 없음.
    const protoFile = findFile(cwd, [
      "prototype/index.html",
      "frontend/index.html",
      "frontend/public/index.html",
      "public/index.html",
      "frontend/src/app/layout.tsx",
      "frontend/app/layout.tsx",
    ]);

    if (!protoFile) {
      blockers.push(
        "GNB 필수 프로젝트: GNB 스크립트 삽입 위치 없음 — prototype/index.html, frontend/index.html, 또는 frontend/src/app/layout.tsx 확인 필요"
      );
    } else {
      const html = fs.readFileSync(protoFile, "utf-8");
      const GNB_SCRIPTS = [
        "ngb_head.js",
        "gnb.min.js",
        "ngb_bodyend.js",
      ] as const;

      const missing = GNB_SCRIPTS.filter((s) => !html.includes(s));
      if (missing.length > 0) {
        blockers.push(
          `GNB 스크립트 미삽입 (${path.relative(cwd, protoFile)}): ${missing.join(", ")} — ` +
          "실제 GNB 스크립트를 삽입하고 GNB_PLACEHOLDER 주석을 제거하세요"
        );
      }
    }
  }

  // 3-A. Step 2.7 INSIGN 자산 검증 (auth_profile ∈ {insign, insign-with-nxas} & Phase >= 1)
  //      create-spec Step 2.7에서 생성되어야 할 자산이 누락된 채 Phase 1 진입 시 차단.
  //      케이스: docs/case-studies/step27-validation-gap.md 4.7 장치 1 일부.
  if (
    phase >= 1 &&
    (stateData?.auth_profile === "insign" ||
      stateData?.auth_profile === "insign-with-nxas")
  ) {
    // 7-1. INSIGN SDK 코드 자산
    const REQUIRED_INSIGN_FILES = [
      "frontend/src/lib/insign.ts",
      "frontend/src/context/InsignContext.tsx",
      "frontend/src/lib/apiClient.ts",
    ];
    for (const f of REQUIRED_INSIGN_FILES) {
      if (!fs.existsSync(path.join(cwd, f))) {
        blockers.push(
          `INSIGN 자산 누락: ${f} — create-spec Step 2.7 (L303-319)에서 InfaceTest 패턴 이식 필요`
        );
      }
    }

    // 7-2. Mock AuthContext 잔존 차단
    const authCtx = path.join(cwd, "frontend/src/context/AuthContext.tsx");
    if (fs.existsSync(authCtx)) {
      const src = fs.readFileSync(authCtx, "utf-8");
      if (/MOCK_USER|localStorage\.getItem\(['"][\w-]*mock[\w-]*auth/i.test(src)) {
        blockers.push(
          "Mock AuthContext 잔존 (frontend/src/context/AuthContext.tsx): MOCK_USER 또는 localStorage mock-auth 패턴 — " +
            "InsignProvider로 교체 필요 (create-spec Step 2.7)"
        );
      }
    }

    // 7-3. storageState 존재 + 쿠키 expires 검증
    const ssPath = path.join(cwd, "tests/e2e/.auth/user.json");
    if (!fs.existsSync(ssPath)) {
      blockers.push(
        "storageState 없음 (tests/e2e/.auth/user.json) — ./scripts/save-auth-state.sh 실행 필요"
      );
    } else {
      try {
        const ss = JSON.parse(fs.readFileSync(ssPath, "utf-8")) as {
          cookies?: Array<{ expires?: number }>;
        };
        const nowSec = Math.floor(Date.now() / 1000);
        const hasValidCookie = (ss.cookies ?? []).some(
          (c) => typeof c.expires === "number" && c.expires > nowSec
        );
        if (!hasValidCookie) {
          blockers.push(
            "storageState 만료 (tests/e2e/.auth/user.json): 유효한 인증 쿠키 없음 — " +
              "./scripts/save-auth-state.sh 재실행 필요"
          );
        }
      } catch {
        blockers.push("storageState 파싱 실패 (tests/e2e/.auth/user.json) — 재생성 필요");
      }
    }

    // 7-4. Step 2.7 사용자 승인 흔적 검증
    //      state.step27_user_approved 또는 boilerplate-activity 로그의 user-approval 이벤트.
    if (stateData?.step27_user_approved !== true) {
      const activityLog = path.join(cwd, "logs/boilerplate-activity.md");
      let hasApprovalEvent = false;
      if (fs.existsSync(activityLog)) {
        const log = fs.readFileSync(activityLog, "utf-8");
        hasApprovalEvent = /Step 2\.7 user-approval/.test(log);
      }
      if (!hasApprovalEvent) {
        blockers.push(
          "Step 2.7 사용자 승인 흔적 없음 — state.step27_user_approved=true 또는 " +
            'logs/boilerplate-activity.md "Step 2.7 user-approval" 이벤트 필요'
        );
      }
    }
  }

  // 3-B. auth_profile 키워드 블랙리스트 (할루시네이션 방지)
  //      케이스: docs/case-studies/step27-validation-gap.md 4.7 장치 2.
  //      INSIGN은 _ifwt 쿠키 기반이라 OAuth 표준 용어가 등장하면 거의 100% 추측.
  if (
    phase >= 0.5 &&
    (stateData?.auth_profile === "insign" ||
      stateData?.auth_profile === "insign-with-nxas")
  ) {
    const FORBIDDEN_INSIGN = [
      "redirect_uri",
      "Callback URL",
      "callback_url",
      "client_secret",
      "client_id",
      "authorization_code",
      "PKCE",
    ];
    const SCAN_FILES = ["prerequisites.md", "spec.md", "decisions.md"];
    const specsDir = path.join(cwd, "specs");
    const targets: string[] = [];
    if (fs.existsSync(specsDir)) {
      for (const entry of fs.readdirSync(specsDir, { withFileTypes: true })) {
        if (entry.isDirectory() && !entry.name.startsWith(".")) {
          for (const f of SCAN_FILES) {
            const p = path.join(specsDir, entry.name, f);
            if (fs.existsSync(p)) targets.push(p);
          }
        }
      }
    }
    for (const t of targets) {
      const content = fs.readFileSync(t, "utf-8");
      const hits = FORBIDDEN_INSIGN.filter((kw) => content.includes(kw));
      if (hits.length > 0) {
        blockers.push(
          `auth_profile=${stateData.auth_profile}에 금지된 OAuth 키워드가 ${path.relative(
            cwd,
            t
          )}에 등장: ${hits.join(", ")} — ` +
            "INSIGN은 _ifwt 쿠키 기반. refs/policies/authentication-external.md 재확인 필요"
        );
      }
    }
  }

  // 4. 이전 Phase 미완료 태스크 확인 (Phase 1 이상, tasks.md가 있을 때만)
  if (phase >= 1) {
    const tasksFile = findTasksFile(cwd);
    if (tasksFile) {
      try {
        const tasks = parseTasks(tasksFile);
        const prevPhase = phase - 1;
        const prevTasks = tasks.filter((t) => t.phase === prevPhase);
        const incomplete = prevTasks.filter((t) => t.status === "☐");
        if (prevTasks.length > 0 && incomplete.length > 0) {
          blockers.push(
            `Phase ${prevPhase} 미완료 태스크 ${incomplete.length}개: ${incomplete
              .map((t) => t.id)
              .join(", ")} — tasks.md ☑ 갱신 후 재시도`
          );
        }

        // Phase 1 진입 시 Phase 0.5 미완료 태스크도 확인
        if (phase === 1) {
          const phase05Tasks = tasks.filter((t) => t.phase === 0.5);
          const incomplete05 = phase05Tasks.filter((t) => t.status === "☐");
          if (phase05Tasks.length > 0 && incomplete05.length > 0) {
            blockers.push(
              `Phase 0.5 미완료 태스크 ${incomplete05.length}개: ${incomplete05
                .map((t) => t.id)
                .join(", ")} — tasks.md ☑ 갱신 후 재시도`
            );
          }
        }
      } catch { /* tasks.md 파싱 실패는 무시 */ }
    }
  }

  // 5. decisions.md 미결정 항목 확인 (인프라·인증·보안 카테고리는 blockers로 승격)
  const decisionsFile = findFile(cwd, [
    "decisions.md",
    "specs/decisions.md",
  ]);
  // dot-prefix 디렉토리(`.template`, `.git` 등) 제외.
  // `specs/.template/decisions.md`에는 "🔴 미결정" placeholder 행이 의도적으로 포함되어
  // false positive(가짜 차단)를 유발하므로 실제 spec 디렉토리(`001-*` 등)만 후보로 본다.
  let dFound = decisionsFile;
  if (!dFound) {
    const specsDir = path.join(cwd, "specs");
    if (fs.existsSync(specsDir)) {
      for (const entry of fs.readdirSync(specsDir, { withFileTypes: true })) {
        if (entry.isDirectory() && !entry.name.startsWith(".")) {
          const candidate = path.join(specsDir, entry.name, "decisions.md");
          if (fs.existsSync(candidate)) { dFound = candidate; break; }
        }
      }
    }
  }

  if (dFound) {
    const allUnresolved = extractUnresolvedDecisions(dFound);
    for (const item of allUnresolved) {
      if (isCriticalDecision(item)) {
        blockers.push(
          `decisions.md 인프라·인증·보안 미결정: ${item} — 정책 문서(refs/INDEX.md) 참조 후 결정 필요`
        );
      } else {
        unresolved_decisions.push(item);
      }
    }
  }

  // 6. PROGRESS.md "코드 패턴 메모" placeholder 잔존 검사 (Phase >= 2)
  //    이전 Phase 완료 시 run-phase.md Step 3-1 ③ 에 따라 채워야 하는 섹션.
  //    잔존 시 다음 세션 brief 가 무가치해지므로 차단.
  if (phase >= 2) {
    const progressPath = path.join(cwd, "PROGRESS.md");
    if (fs.existsSync(progressPath)) {
      const placeholders = detectProgressPlaceholders(progressPath);
      for (const p of placeholders) {
        blockers.push(
          `PROGRESS.md "코드 패턴 메모" placeholder 잔존: ${p} — ` +
          `Phase ${phase - 1} 완료 시 run-phase.md Step 3-1 ③ 에 따라 실제 값으로 치환 필요`
        );
      }
    }
  }

  return {
    ok: blockers.length === 0,
    blockers,
    unresolved_decisions,
  };
}
