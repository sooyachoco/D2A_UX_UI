import { describe, it, expect, afterEach } from "vitest";
import { writeFileSync, mkdirSync, readFileSync } from "fs";
import { join } from "path";
import { updateState, getState } from "../tools/state-tool.js";
import { DEFAULT_STATE, STATE_SCHEMA_VERSION } from "../shared/state-schema.js";
import { createTempDir, mockCwd } from "./helpers.js";

describe("state-tool", () => {
  let dir: string;
  let cleanup: () => void;
  let cwdSpy: ReturnType<typeof import("vitest").vi.spyOn>;

  afterEach(() => {
    cwdSpy?.mockRestore();
    cleanup?.();
  });

  function setup(initialContent?: string) {
    ({ dir, cleanup } = createTempDir());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    if (initialContent !== undefined) {
      writeFileSync(join(dir, ".claude/state.json"), initialContent, "utf-8");
    }
  }

  // ── getState ─────────────────────────────────────────────────────────────

  it("파일 없을 시 DEFAULT_STATE를 반환한다", async () => {
    setup();
    const state = await getState();
    expect(state.phase).toBe(DEFAULT_STATE.phase);
    expect(state.status).toBe(DEFAULT_STATE.status);
    expect(state.schema_version).toBe(STATE_SCHEMA_VERSION);
  });

  it("파싱 실패 시 DEFAULT_STATE를 반환한다", async () => {
    setup("{invalid json}");
    const state = await getState();
    expect(state.status).toBe("idle");
    expect(state.schema_version).toBe(STATE_SCHEMA_VERSION);
  });

  it("schema_version 없는 구 버전 state를 마이그레이션한다 (v0 → v1)", async () => {
    setup(JSON.stringify({
      phase: 1,
      status: "running",
      current_task: "T1-003",
      integration_ready: true,
      last_commit: null,
      last_updated: null,
      blockers: [],
      completed_tasks: ["T1-001", "T1-002"],
      // schema_version 없음 (v0)
    }));
    const state = await getState();
    expect(state.schema_version).toBe(STATE_SCHEMA_VERSION);
    expect(state.phase).toBe(1);
    expect(state.current_task).toBe("T1-003");
    expect(state.completed_tasks).toEqual(["T1-001", "T1-002"]);
  });

  // ── updateState ───────────────────────────────────────────────────────────

  it("patch를 기존 state에 병합한다", async () => {
    setup(JSON.stringify({ ...DEFAULT_STATE, schema_version: 1, phase: 1, status: "running" }));
    await updateState({ patch: { current_task: "T1-005" } });
    const state = await getState();
    expect(state.phase).toBe(1);
    expect(state.status).toBe("running");
    expect(state.current_task).toBe("T1-005");
  });

  it("atomic write: tmp 파일 → rename으로 저장한다", async () => {
    setup();
    await updateState({ patch: { phase: 2, status: "running" } });

    // tmp 파일은 남지 않아야 한다
    const { existsSync } = await import("fs");
    expect(existsSync(join(dir, ".claude/state.json.tmp"))).toBe(false);

    // state.json은 유효한 JSON이어야 한다
    const raw = readFileSync(join(dir, ".claude/state.json"), "utf-8");
    const parsed = JSON.parse(raw);
    expect(parsed.phase).toBe(2);
    expect(parsed.schema_version).toBe(STATE_SCHEMA_VERSION);
  });

  it("last_updated를 자동으로 갱신한다", async () => {
    setup();
    const before = new Date().toISOString();
    await updateState({ patch: { phase: 1 } });
    const state = await getState();
    expect(state.last_updated).not.toBeNull();
    expect(new Date(state.last_updated!).getTime()).toBeGreaterThanOrEqual(
      new Date(before).getTime()
    );
  });

  it("blockers 배열을 올바르게 업데이트한다", async () => {
    setup();
    const blocker = { task: "T1-004", reason: "test blocker", since: new Date().toISOString() };
    await updateState({ patch: { blockers: [blocker], status: "blocked" } });
    const state = await getState();
    expect(state.blockers).toHaveLength(1);
    expect(state.blockers[0].task).toBe("T1-004");
    expect(state.status).toBe("blocked");
  });
});
