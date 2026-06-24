/**
 * 통합 테스트: getNextTask → submitTask 전체 Phase 실행 흐름 검증
 *
 * 단위 테스트(phase-runner.test.ts)는 각 도구를 독립적으로 검증한다.
 * 이 파일은 실제 Phase 실행 시나리오를 end-to-end로 검증한다:
 *   1. 정상 흐름: 다중 태스크 Phase 완료까지 순차 실행
 *   2. 빌드 실패 에스컬레이션: retry → rollback → state.json blocker 기록
 *   3. deps 체인: A→B→C 순서 강제 검증
 *   4. 혼합 done 타입: file:, cmd:, contains: 복합 사용
 */
import { describe, it, expect, afterEach } from "vitest";
import { writeFileSync, readFileSync, existsSync, mkdirSync } from "fs";
import { join } from "path";
import { getNextTask, submitTask } from "../tools/phase-runner.js";
import { DEFAULT_STATE, STATE_SCHEMA_VERSION } from "../shared/state-schema.js";
import { createTempGitRepo, mockCwd } from "./helpers.js";
// ── 공통 셋업 ─────────────────────────────────────────────────────────────────
function setupPhase(tasksContent, stateOverride = {}) {
    const { dir, cleanup } = createTempGitRepo();
    const cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(join(dir, "tasks.md"), tasksContent, "utf-8");
    writeFileSync(join(dir, ".claude/state.json"), JSON.stringify({
        ...DEFAULT_STATE,
        schema_version: STATE_SCHEMA_VERSION,
        phase: 1,
        status: "running",
        ...stateOverride,
    }), "utf-8");
    return { dir, cleanup, cwdSpy };
}
// ── 시나리오 1: 정상 흐름 — 다중 태스크 Phase 완료 ─────────────────────────
describe("시나리오 1: 정상 흐름 — 2개 태스크 Phase 완료", () => {
    let cleanup;
    let cwdSpy;
    afterEach(() => {
        cwdSpy?.mockRestore();
        cleanup?.();
    });
    it("T1-001 → T1-002 → all_done 순서로 완료된다", async () => {
        const tasks = `## Phase 1
### T1-001: 파일 생성
**status**: ☐
**read**: -
**write**: src/hello.ts
**done**: file: src/hello.ts
**deps**: -

### T1-002: 내용 작성 (T1-001 의존)
**status**: ☐
**read**: src/hello.ts
**write**: src/world.ts
**done**: file: src/world.ts
**deps**: T1-001
`;
        const { dir, cleanup: c, cwdSpy: s } = setupPhase(tasks);
        cleanup = c;
        cwdSpy = s;
        // Step 1: 첫 번째 태스크 요청
        const t1 = await getNextTask({ phase: 1 });
        expect(t1.ok).toBe(true);
        expect(t1.task_id).toBe("T1-001");
        expect(t1.all_done).toBe(false);
        // Step 2: T1-001 구현 (디렉토리 + 파일 생성)
        mkdirSync(join(dir, "src"), { recursive: true });
        writeFileSync(join(dir, "src/hello.ts"), "export const hello = 'world';", "utf-8");
        // Step 3: T1-001 제출 → 통과
        const s1 = await submitTask({ task_id: "T1-001", attempt: 1 });
        expect(s1.ok).toBe(true);
        expect(s1.passed).toBe(true);
        expect(s1.action).toBe("next");
        // Step 4: 두 번째 태스크 요청 — T1-001 완료 후 T1-002 선택
        const t2 = await getNextTask({ phase: 1 });
        expect(t2.ok).toBe(true);
        expect(t2.task_id).toBe("T1-002");
        // Step 5: T1-002 구현 (src/ 이미 생성됨)
        writeFileSync(join(dir, "src/world.ts"), "export const world = 'hello';", "utf-8");
        // Step 6: T1-002 제출 → 통과
        const s2 = await submitTask({ task_id: "T1-002", attempt: 1 });
        expect(s2.ok).toBe(true);
        expect(s2.passed).toBe(true);
        expect(s2.action).toBe("next");
        // Step 7: 더 이상 태스크 없음 → all_done
        const done = await getNextTask({ phase: 1 });
        expect(done.ok).toBe(true);
        expect(done.all_done).toBe(true);
        expect(done.task_id).toBeNull();
        // state.json에 두 태스크가 completed_tasks에 기록됨
        const state = JSON.parse(readFileSync(join(dir, ".claude/state.json"), "utf-8"));
        expect(state.completed_tasks).toContain("T1-001");
        expect(state.completed_tasks).toContain("T1-002");
    });
});
// ── 시나리오 2: 빌드 실패 에스컬레이션 — retry → rollback ──────────────────
describe("시나리오 2: 빌드 실패 에스컬레이션 — retry → rollback", () => {
    let cleanup;
    let cwdSpy;
    afterEach(() => {
        cwdSpy?.mockRestore();
        cleanup?.();
    });
    it("attempt=1 실패 → retry, attempt=2 실패 → rollback + blocker 기록", async () => {
        const tasks = `## Phase 1
### T1-001: 항상 실패하는 태스크
**status**: ☐
**read**: -
**write**: out.txt
**done**: cmd: false
**deps**: -
`;
        const { dir, cleanup: c, cwdSpy: s } = setupPhase(tasks);
        cleanup = c;
        cwdSpy = s;
        // 1차 시도
        await getNextTask({ phase: 1 });
        const r1 = await submitTask({ task_id: "T1-001", attempt: 1 });
        expect(r1.passed).toBe(false);
        expect(r1.action).toBe("retry");
        // 2차 시도 — rollback
        const r2 = await submitTask({ task_id: "T1-001", attempt: 2 });
        expect(r2.passed).toBe(false);
        expect(r2.action).toBe("rollback");
        // state.json에 blocker 기록
        const state = JSON.parse(readFileSync(join(dir, ".claude/state.json"), "utf-8"));
        expect(state.blockers.length).toBeGreaterThan(0);
        expect(state.blockers[0].task).toBe("T1-001");
        expect(state.status).toBe("blocked");
    });
    it("attempt=1 실패 후 수정 → attempt=2 통과 시 next 반환", async () => {
        // done: file: 기준으로, 처음엔 파일 없음 → 실패, 이후 파일 생성 → 통과
        const tasks = `## Phase 1
### T1-001: 파일 필요
**status**: ☐
**read**: -
**write**: output.ts
**done**: file: output.ts
**deps**: -
`;
        const { dir, cleanup: c, cwdSpy: s } = setupPhase(tasks);
        cleanup = c;
        cwdSpy = s;
        await getNextTask({ phase: 1 });
        // 1차: 파일 없음 → 실패
        const r1 = await submitTask({ task_id: "T1-001", attempt: 1 });
        expect(r1.action).toBe("retry");
        // 수정: 파일 생성 후 2차 제출
        writeFileSync(join(dir, "output.ts"), "export default {};", "utf-8");
        const r2 = await submitTask({ task_id: "T1-001", attempt: 2 });
        expect(r2.passed).toBe(true);
        expect(r2.action).toBe("next");
    });
});
// ── 시나리오 3: deps 체인 — A→B→C 순서 강제 ────────────────────────────────
describe("시나리오 3: deps 체인 — A→B→C 순서 강제", () => {
    let cleanup;
    let cwdSpy;
    afterEach(() => {
        cwdSpy?.mockRestore();
        cleanup?.();
    });
    it("T1-003은 T1-001, T1-002 모두 완료 전에는 선택되지 않는다", async () => {
        const tasks = `## Phase 1
### T1-001: A
**status**: ☐
**read**: -
**write**: a.ts
**done**: cmd: true
**deps**: -

### T1-002: B (A 의존)
**status**: ☐
**read**: a.ts
**write**: b.ts
**done**: cmd: true
**deps**: T1-001

### T1-003: C (A, B 의존)
**status**: ☐
**read**: b.ts
**write**: c.ts
**done**: cmd: true
**deps**: T1-001, T1-002
`;
        const { dir, cleanup: c, cwdSpy: s } = setupPhase(tasks);
        cleanup = c;
        cwdSpy = s;
        // T1-001 완료
        await getNextTask({ phase: 1 });
        await submitTask({ task_id: "T1-001", attempt: 1 });
        // T1-002 선택 (T1-003 아직 불가)
        const next = await getNextTask({ phase: 1 });
        expect(next.task_id).toBe("T1-002");
        // T1-002 완료
        await submitTask({ task_id: "T1-002", attempt: 1 });
        // 이제 T1-003 선택 가능
        const final = await getNextTask({ phase: 1 });
        expect(final.task_id).toBe("T1-003");
    });
});
// ── 시나리오 4: 혼합 done 타입 ───────────────────────────────────────────────
describe("시나리오 4: 혼합 done 타입 — file: + contains:", () => {
    let cleanup;
    let cwdSpy;
    afterEach(() => {
        cwdSpy?.mockRestore();
        cleanup?.();
    });
    it("file: 존재 + contains: 내용 모두 충족해야 통과한다", async () => {
        const tasks = `## Phase 1
### T1-001: 설정 파일 생성
**status**: ☐
**read**: -
**write**: config.json
**done**: contains: config.json :: "version"
**deps**: -
`;
        const { dir, cleanup: c, cwdSpy: s } = setupPhase(tasks);
        cleanup = c;
        cwdSpy = s;
        await getNextTask({ phase: 1 });
        // 파일은 있지만 "version" 없음 → 실패
        writeFileSync(join(dir, "config.json"), '{"name": "d2a"}', "utf-8");
        const r1 = await submitTask({ task_id: "T1-001", attempt: 1 });
        expect(r1.action).toBe("retry");
        // "version" 포함 → 통과
        writeFileSync(join(dir, "config.json"), '{"name": "d2a", "version": "1.0.0"}', "utf-8");
        const r2 = await submitTask({ task_id: "T1-001", attempt: 2 });
        expect(r2.passed).toBe(true);
        expect(r2.action).toBe("next");
    });
    it("validate token 파일이 getNextTask 이후 올바르게 초기화된다", async () => {
        const tasks = `## Phase 1
### T1-001: 토큰 초기화 확인
**status**: ☐
**read**: -
**write**: out.ts
**done**: cmd: true
**deps**: -
`;
        const { dir, cleanup: c, cwdSpy: s } = setupPhase(tasks);
        cleanup = c;
        cwdSpy = s;
        const tokenPath = join(dir, ".claude/last-validate-result");
        // getNextTask 전에는 token 없음
        expect(existsSync(tokenPath)).toBe(false);
        await getNextTask({ phase: 1 });
        await submitTask({ task_id: "T1-001", attempt: 1 });
        // 통과 후 token 생성
        expect(existsSync(tokenPath)).toBe(true);
        // token 파일 내용은 "passed" 고정 — pre-bash-hook이 존재 여부로 커밋 허용 판단
        const token = readFileSync(tokenPath, "utf-8");
        expect(token).toBe("passed");
    });
});
//# sourceMappingURL=integration.test.js.map