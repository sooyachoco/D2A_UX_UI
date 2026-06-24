import { describe, it, expect, afterEach } from "vitest";
import { writeFileSync } from "fs";
import { join } from "path";
import {
  parseTasks,
  findTask,
  normalizeTaskId,
} from "../shared/tasks-parser.js";
import { createTempDir } from "./helpers.js";

// ── normalizeTaskId ─────────────────────────────────────────────────────────

describe("normalizeTaskId", () => {
  it("대문자로 변환한다", () => {
    expect(normalizeTaskId("t1-001")).toBe("T1-001");
  });

  it("앞뒤 공백을 제거한다", () => {
    expect(normalizeTaskId("  T1-001  ")).toBe("T1-001");
  });

  it("T001 형식도 그대로 반환한다", () => {
    expect(normalizeTaskId("t001")).toBe("T001");
  });
});

// ── parseTasks ───────────────────────────────────────────────────────────────

describe("parseTasks", () => {
  let dir: string;
  let cleanup: () => void;

  afterEach(() => cleanup?.());

  function writeTasks(content: string): string {
    ({ dir, cleanup } = createTempDir());
    const file = join(dir, "tasks.md");
    writeFileSync(file, content, "utf-8");
    return file;
  }

  it("Phase 헤더와 기본 태스크를 파싱한다 (T1-001 형식)", () => {
    const file = writeTasks(`## Phase 1
### T1-001: 첫 번째 태스크
**status**: ☐
**read**: src/api.ts, src/types.ts
**write**: src/handler.ts
**done**:
  - file: src/handler.ts
**deps**: -
`);
    const tasks = parseTasks(file);
    expect(tasks).toHaveLength(1);
    const t = tasks[0];
    expect(t.id).toBe("T1-001");
    expect(t.title).toBe("첫 번째 태스크");
    expect(t.phase).toBe(1);
    expect(t.status).toBe("☐");
    expect(t.read).toEqual(["src/api.ts", "src/types.ts"]);
    expect(t.write).toEqual(["src/handler.ts"]);
    expect(t.done).toEqual(["file: src/handler.ts"]);
    expect(t.deps).toEqual([]);
  });

  it("T001 형식(대시 없음)도 파싱된다", () => {
    const file = writeTasks(`## Phase 1
### T001: 대시 없는 형식
**status**: ☐
**read**: src/index.ts
**write**: src/output.ts
**done**: file: src/output.ts
**deps**: -
`);
    const tasks = parseTasks(file);
    expect(tasks[0].id).toBe("T001");
  });

  it("☑ 상태를 올바르게 파싱한다", () => {
    const file = writeTasks(`## Phase 1
### T1-001: 완료된 태스크
**status**: ☑
**read**: src/a.ts
**write**: src/b.ts
**done**: file: src/b.ts
**deps**: -
`);
    const tasks = parseTasks(file);
    expect(tasks[0].status).toBe("☑");
  });

  it("deps를 쉼표 구분으로 파싱한다", () => {
    const file = writeTasks(`## Phase 1
### T1-001: 선행 태스크
**status**: ☐
**read**: -
**write**: src/a.ts
**done**: file: src/a.ts
**deps**: -

### T1-002: 의존 태스크
**status**: ☐
**read**: src/a.ts
**write**: src/b.ts
**done**: file: src/b.ts
**deps**: T1-001
`);
    const tasks = parseTasks(file);
    expect(tasks[1].deps).toEqual(["T1-001"]);
  });

  it("멀티라인 done 기준을 수집한다", () => {
    const file = writeTasks(`## Phase 1
### T1-001: 멀티 done
**status**: ☐
**read**: -
**write**: src/a.ts, src/b.ts
**done**:
  - file: src/a.ts
  - file: src/b.ts
  - cmd: echo ok
**deps**: -
`);
    const tasks = parseTasks(file);
    expect(tasks[0].done).toEqual(["file: src/a.ts", "file: src/b.ts", "cmd: echo ok"]);
  });

  it("Phase 0.5를 소수로 파싱한다", () => {
    const file = writeTasks(`## Phase 0.5
### T0-001: 연동 준비
**status**: ☐
**read**: -
**write**: integration-ready.md
**done**: file: integration-ready.md
**deps**: -
`);
    const tasks = parseTasks(file);
    expect(tasks[0].phase).toBe(0.5);
  });

  it("여러 Phase의 태스크를 모두 파싱한다", () => {
    const file = writeTasks(`## Phase 1
### T1-001: Phase 1 태스크
**status**: ☐
**read**: -
**write**: src/a.ts
**done**: file: src/a.ts
**deps**: -

## Phase 2
### T2-001: Phase 2 태스크
**status**: ☐
**read**: src/a.ts
**write**: src/b.ts
**done**: file: src/b.ts
**deps**: T1-001
`);
    const tasks = parseTasks(file);
    expect(tasks).toHaveLength(2);
    expect(tasks[0].phase).toBe(1);
    expect(tasks[1].phase).toBe(2);
  });
});

// ── findTask ─────────────────────────────────────────────────────────────────

describe("findTask", () => {
  it("정규화된 ID로 태스크를 찾는다", () => {
    const tasks = [
      { id: "T1-001", title: "test" } as ReturnType<typeof parseTasks>[0],
    ];
    expect(findTask(tasks, "t1-001")).toBeDefined();
    expect(findTask(tasks, "T1-001")).toBeDefined();
    expect(findTask(tasks, "T1-002")).toBeUndefined();
  });
});
