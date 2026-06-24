import { describe, it, expect, afterEach } from "vitest";
import { writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { getNextTask, submitTask } from "../tools/phase-runner.js";
import { DEFAULT_STATE, STATE_SCHEMA_VERSION } from "../shared/state-schema.js";
import { createTempGitRepo, mockCwd } from "./helpers.js";

const SIMPLE_TASKS = `## Phase 1
### T1-001: 첫 번째 태스크
**status**: ☐
**read**: -
**write**: src/a.ts
**done**: cmd: true
**deps**: -

### T1-002: 두 번째 태스크 (T1-001 의존)
**status**: ☐
**read**: src/a.ts
**write**: src/b.ts
**done**: cmd: true
**deps**: T1-001
`;

describe("getNextTask", () => {
  let dir: string;
  let cleanup: () => void;
  let cwdSpy: ReturnType<typeof import("vitest").vi.spyOn>;

  afterEach(() => {
    cwdSpy?.mockRestore();
    cleanup?.();
  });

  function setup(
    tasksContent: string,
    stateOverride: Partial<typeof DEFAULT_STATE> = {}
  ) {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(join(dir, "tasks.md"), tasksContent, "utf-8");
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({ ...DEFAULT_STATE, schema_version: STATE_SCHEMA_VERSION, ...stateOverride }),
      "utf-8"
    );
  }

  it("deps가 없는 첫 번째 태스크를 반환한다", async () => {
    setup(SIMPLE_TASKS, { phase: 1, status: "running" });
    const result = await getNextTask({ phase: 1 });
    expect(result.ok).toBe(true);
    expect(result.task_id).toBe("T1-001");
    expect(result.all_done).toBe(false);
  });

  it("T1-001 완료 후 T1-002를 반환한다", async () => {
    setup(SIMPLE_TASKS, {
      phase: 1,
      status: "running",
      completed_tasks: ["T1-001"],
    });
    const result = await getNextTask({ phase: 1 });
    expect(result.ok).toBe(true);
    expect(result.task_id).toBe("T1-002");
  });

  it("모든 태스크 완료 시 all_done: true 반환", async () => {
    setup(SIMPLE_TASKS, {
      phase: 1,
      status: "running",
      completed_tasks: ["T1-001", "T1-002"],
    });
    const result = await getNextTask({ phase: 1 });
    expect(result.ok).toBe(true);
    expect(result.all_done).toBe(true);
    expect(result.task_id).toBeNull();
  });

  it("deps 미충족 시 ok:false + error 반환", async () => {
    // T1-001이 완료되지 않은 상태에서 T1-002는 선택 불가
    // 단, T1-001 자체는 선택 가능 — T1-001 deps가 없으므로 ok:true가 됨
    // deps 미충족 시나리오: 첫 태스크도 미완료이고 deps가 있는 경우
    const circularDeps = `## Phase 1
### T1-001: A
**status**: ☐
**read**: -
**write**: a.ts
**done**: cmd: true
**deps**: T1-002

### T1-002: B
**status**: ☐
**read**: -
**write**: b.ts
**done**: cmd: true
**deps**: T1-001
`;
    setup(circularDeps, { phase: 1, status: "running" });
    const result = await getNextTask({ phase: 1 });
    expect(result.ok).toBe(false);
    expect(result.error).toContain("deps 미충족");
  });

  it("tasks.md 없을 시 ok:false + error 반환", async () => {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({ ...DEFAULT_STATE, schema_version: STATE_SCHEMA_VERSION }),
      "utf-8"
    );
    const result = await getNextTask({ phase: 1 });
    expect(result.ok).toBe(false);
    expect(result.error).toContain("tasks.md");
  });

  it("Phase에 태스크 없을 시 ok:false + error 반환", async () => {
    setup(SIMPLE_TASKS, { phase: 1, status: "running" });
    const result = await getNextTask({ phase: 99 });
    expect(result.ok).toBe(false);
    expect(result.error).toContain("Phase 99");
  });

  it("normalizeTaskId: 소문자 deps도 올바르게 매칭한다", async () => {
    const lowerDeps = `## Phase 1
### T1-001: 첫 번째
**status**: ☑
**read**: -
**write**: a.ts
**done**: cmd: true
**deps**: -

### T1-002: 두 번째
**status**: ☐
**read**: a.ts
**write**: b.ts
**done**: cmd: true
**deps**: t1-001
`;
    setup(lowerDeps, { phase: 1, status: "running" });
    // T1-001이 ☑이므로 completed에 포함됨, T1-002의 deps "t1-001"이 정규화되어 매칭
    const result = await getNextTask({ phase: 1 });
    expect(result.ok).toBe(true);
    expect(result.task_id).toBe("T1-002");
  });
});

describe("submitTask", () => {
  let dir: string;
  let cleanup: () => void;
  let cwdSpy: ReturnType<typeof import("vitest").vi.spyOn>;

  afterEach(() => {
    cwdSpy?.mockRestore();
    cleanup?.();
  });

  function setup(done: string) {
    ({ dir, cleanup } = createTempGitRepo());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    const tasksContent = `## Phase 1
### T1-001: 테스트 태스크
**status**: ☐
**read**: -
**write**: out.txt
**done**: ${done}
**deps**: -
`;
    writeFileSync(join(dir, "tasks.md"), tasksContent, "utf-8");
    writeFileSync(
      join(dir, ".claude/state.json"),
      JSON.stringify({
        ...DEFAULT_STATE,
        schema_version: STATE_SCHEMA_VERSION,
        phase: 1,
        status: "running",
        current_task: "T1-001",
      }),
      "utf-8"
    );
  }

  it("done 기준 통과 시 action: next + validate token 생성", async () => {
    setup("cmd: true");
    const result = await submitTask({ task_id: "T1-001", attempt: 1 });
    expect(result.ok).toBe(true);
    expect(result.passed).toBe(true);
    expect(result.action).toBe("next");

    // validate token 파일이 생성되어야 한다
    const { existsSync } = await import("fs");
    expect(existsSync(join(dir, ".claude/last-validate-result"))).toBe(true);
  });

  it("attempt=1 실패 시 action: retry", async () => {
    setup("cmd: false");
    const result = await submitTask({ task_id: "T1-001", attempt: 1 });
    expect(result.ok).toBe(true);
    expect(result.passed).toBe(false);
    expect(result.action).toBe("retry");
  });

  it("attempt=2 실패 시 action: rollback (checkpoint 있음)", async () => {
    setup("cmd: false");
    // getNextTask를 먼저 호출하면 checkpoint가 생성된다
    await getNextTask({ phase: 1 });
    const result = await submitTask({ task_id: "T1-001", attempt: 2 });
    expect(result.passed).toBe(false);
    expect(result.action).toBe("rollback");
    // rollback 후 state.json에 blocker가 기록된다
    const { readFileSync } = await import("fs");
    const state = JSON.parse(readFileSync(join(dir, ".claude/state.json"), "utf-8"));
    expect(state.blockers.length).toBeGreaterThan(0);
    expect(state.blockers[0].task).toBe("T1-001");
  });

  it("통과 후 completed_tasks에 task_id가 추가된다", async () => {
    setup("cmd: true");
    await submitTask({ task_id: "T1-001", attempt: 1 });
    const { readFileSync } = await import("fs");
    const state = JSON.parse(readFileSync(join(dir, ".claude/state.json"), "utf-8"));
    expect(state.completed_tasks).toContain("T1-001");
  });
});
