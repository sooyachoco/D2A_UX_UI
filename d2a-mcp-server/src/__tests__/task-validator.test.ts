import { describe, it, expect, afterEach, vi } from "vitest";
import { writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { validateTaskDone } from "../tools/task-validator.js";
import { createTempDir, mockCwd } from "./helpers.js";

// validateTaskDone은 process.cwd()에서 tasks.md를 찾는다.
// 각 테스트마다 임시 디렉토리를 생성하고 tasks.md를 작성한다.

function buildTasksMd(doneLines: string[]): string {
  const donePart =
    doneLines.length === 1
      ? `**done**: ${doneLines[0]}`
      : `**done**:\n${doneLines.map((l) => `  - ${l}`).join("\n")}`;

  return `## Phase 1
### T1-001: 테스트 태스크
**status**: ☐
**read**: -
**write**: out.txt
${donePart}
**deps**: -
`;
}

describe("validateTaskDone", () => {
  let dir: string;
  let cleanup: () => void;
  let cwdSpy: ReturnType<typeof vi.spyOn>;

  afterEach(() => {
    cwdSpy?.mockRestore();
    cleanup?.();
  });

  function setup(doneLines: string[], extraFiles: Record<string, string> = {}) {
    ({ dir, cleanup } = createTempDir());
    cwdSpy = mockCwd(dir);
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(join(dir, "tasks.md"), buildTasksMd(doneLines), "utf-8");
    for (const [rel, content] of Object.entries(extraFiles)) {
      const full = join(dir, rel);
      mkdirSync(join(full, ".."), { recursive: true });
      writeFileSync(full, content, "utf-8");
    }
  }

  // ── file: ────────────────────────────────────────────────────────────────

  // 헬퍼: criteria_results의 첫 번째 항목 이유를 반환
  function firstReason(result: Awaited<ReturnType<typeof validateTaskDone>>) {
    return result.criteria_results?.[0]?.reason ?? result.reason;
  }

  it("file: — 파일 존재 시 통과", async () => {
    setup(["file: out.txt"], { "out.txt": "hello" });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(true);
    expect(firstReason(result)).toContain("파일 존재");
  });

  it("file: — 파일 없을 시 실패", async () => {
    setup(["file: out.txt"]);
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("파일 없음");
  });

  // ── contains: ────────────────────────────────────────────────────────────

  it("contains: — 패턴 발견 시 통과", async () => {
    setup(["contains: out.txt :: Hello World"], { "out.txt": "Hello World!" });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(true);
    expect(firstReason(result)).toContain("패턴 발견");
  });

  it("contains: — 패턴 없을 시 실패", async () => {
    setup(["contains: out.txt :: MISSING"], { "out.txt": "Hello World" });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("패턴 없음");
  });

  // ── regex: ───────────────────────────────────────────────────────────────

  it("regex: — 정규식 매칭 시 통과", async () => {
    setup(["regex: out.ts :: export (default )?function main"], {
      "out.ts": "export default function main() {}",
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(true);
    expect(firstReason(result)).toContain("정규식 매칭");
  });

  it("regex: — 정규식 불일치 시 실패", async () => {
    setup(["regex: out.ts :: export class Foo"], {
      "out.ts": "export function bar() {}",
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("정규식 불일치");
  });

  it("regex: — 잘못된 정규식 패턴 시 실패", async () => {
    setup(["regex: out.ts :: [invalid"], { "out.ts": "content" });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("잘못된 정규식");
  });

  // ── json: ────────────────────────────────────────────────────────────────

  it("json: — dot-path 존재 시 통과", async () => {
    setup(["json: pkg.json :: .scripts.build"], {
      "pkg.json": JSON.stringify({ scripts: { build: "tsc" } }),
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(true);
    expect(firstReason(result)).toContain("JSON 경로 존재");
  });

  it("json: — dot-path 없을 시 실패", async () => {
    setup(["json: pkg.json :: .scripts.test"], {
      "pkg.json": JSON.stringify({ scripts: { build: "tsc" } }),
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("JSON 경로 없음");
  });

  it("json: — 값 일치 확인", async () => {
    setup(["json: pkg.json :: .name=my-app"], {
      "pkg.json": JSON.stringify({ name: "my-app" }),
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(true);
    expect(firstReason(result)).toContain("JSON 값 일치");
  });

  it("json: — 값 불일치 시 실패", async () => {
    setup(["json: pkg.json :: .name=other"], {
      "pkg.json": JSON.stringify({ name: "my-app" }),
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("JSON 값 불일치");
  });

  // ── cmd: ─────────────────────────────────────────────────────────────────

  it("cmd: — exit 0 시 통과", async () => {
    setup(["cmd: true"]);
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(true);
  });

  it("cmd: — non-zero exit 시 실패", async () => {
    setup(["cmd: false"]);
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
  });

  // ── 복합 기준 ─────────────────────────────────────────────────────────────

  it("모든 기준 실패 시 전체 결과를 보고한다 (early return 없음)", async () => {
    setup(["file: missing1.txt", "file: missing2.txt"], {});
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(result.criteria_results).toHaveLength(2);
    expect(result.criteria_results?.every((r) => !r.passed)).toBe(true);
  });

  it("일부 기준 통과, 일부 실패 시 전체 실패", async () => {
    setup(["file: out.txt", "file: missing.txt"], { "out.txt": "ok" });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(result.criteria_results).toHaveLength(2);
    expect(result.criteria_results?.[0].passed).toBe(true);
    expect(result.criteria_results?.[1].passed).toBe(false);
  });

  // ── coverage: ────────────────────────────────────────────────────────────

  function makeIstanbulReport(entries: Record<string, { total: number; covered: number }>) {
    const report: Record<string, unknown> = {};
    let grandTotal = 0;
    let grandCovered = 0;
    for (const [key, { total, covered }] of Object.entries(entries)) {
      report[key] = { lines: { total, covered, skipped: 0, pct: total > 0 ? (covered / total) * 100 : 0 } };
      grandTotal += total;
      grandCovered += covered;
    }
    report["total"] = { lines: { total: grandTotal, covered: grandCovered, skipped: 0, pct: grandTotal > 0 ? (grandCovered / grandTotal) * 100 : 0 } };
    return JSON.stringify(report);
  }

  function makePytestReport(files: Record<string, { statements: number; covered: number }>, totalPct?: number) {
    const filesObj: Record<string, unknown> = {};
    for (const [key, { statements, covered }] of Object.entries(files)) {
      filesObj[key] = { summary: { num_statements: statements, covered_lines: covered, percent_covered: statements > 0 ? (covered / statements) * 100 : 0 } };
    }
    return JSON.stringify({
      totals: { percent_covered: totalPct ?? 0 },
      files: filesObj,
    });
  }

  it("coverage: — Istanbul 리포트, 파일 경로 지정, 임계값 통과", async () => {
    const { dir: tmpDir, cleanup: c } = createTempDir();
    const cwdS = mockCwd(tmpDir);
    try {
      mkdirSync(join(tmpDir, ".claude"), { recursive: true });
      mkdirSync(join(tmpDir, "coverage"), { recursive: true });
      mkdirSync(join(tmpDir, "src"), { recursive: true });
      const srcFile = join(tmpDir, "src", "api.ts");
      writeFileSync(srcFile, "// placeholder");
      writeFileSync(
        join(tmpDir, "coverage", "coverage-summary.json"),
        makeIstanbulReport({ [srcFile]: { total: 100, covered: 85 } })
      );
      writeFileSync(join(tmpDir, "tasks.md"), buildTasksMd([`coverage: src/api.ts :: 80`]));
      const result = await validateTaskDone({ task_id: "T1-001" });
      expect(result.passed).toBe(true);
      expect(firstReason(result)).toContain("85");
    } finally { cwdS.mockRestore(); c(); }
  });

  it("coverage: — Istanbul 리포트, 디렉터리 경로 집계, 임계값 통과", async () => {
    const { dir: tmpDir, cleanup: c } = createTempDir();
    const cwdS = mockCwd(tmpDir);
    try {
      mkdirSync(join(tmpDir, ".claude"), { recursive: true });
      mkdirSync(join(tmpDir, "coverage"), { recursive: true });
      mkdirSync(join(tmpDir, "src"), { recursive: true });
      const f1 = join(tmpDir, "src", "a.ts");
      const f2 = join(tmpDir, "src", "b.ts");
      writeFileSync(f1, ""); writeFileSync(f2, "");
      // f1: 40/50=80%, f2: 30/50=60% → aggregate 70/100=70%
      writeFileSync(
        join(tmpDir, "coverage", "coverage-summary.json"),
        makeIstanbulReport({ [f1]: { total: 50, covered: 40 }, [f2]: { total: 50, covered: 30 } })
      );
      writeFileSync(join(tmpDir, "tasks.md"), buildTasksMd([`coverage: src :: 70`]));
      const result = await validateTaskDone({ task_id: "T1-001" });
      expect(result.passed).toBe(true);
    } finally { cwdS.mockRestore(); c(); }
  });

  it("coverage: — Istanbul 리포트, 임계값 미달", async () => {
    const { dir: tmpDir, cleanup: c } = createTempDir();
    const cwdS = mockCwd(tmpDir);
    try {
      mkdirSync(join(tmpDir, ".claude"), { recursive: true });
      mkdirSync(join(tmpDir, "coverage"), { recursive: true });
      mkdirSync(join(tmpDir, "src"), { recursive: true });
      const srcFile = join(tmpDir, "src", "api.ts");
      writeFileSync(srcFile, "");
      writeFileSync(
        join(tmpDir, "coverage", "coverage-summary.json"),
        makeIstanbulReport({ [srcFile]: { total: 100, covered: 70 } })
      );
      writeFileSync(join(tmpDir, "tasks.md"), buildTasksMd([`coverage: src/api.ts :: 80`]));
      const result = await validateTaskDone({ task_id: "T1-001" });
      expect(result.passed).toBe(false);
      expect(firstReason(result)).toContain("미달");
    } finally { cwdS.mockRestore(); c(); }
  });

  it("coverage: — Istanbul 리포트, 경로 없을 때 total fallback", async () => {
    const { dir: tmpDir, cleanup: c } = createTempDir();
    const cwdS = mockCwd(tmpDir);
    try {
      mkdirSync(join(tmpDir, ".claude"), { recursive: true });
      mkdirSync(join(tmpDir, "coverage"), { recursive: true });
      const otherFile = join(tmpDir, "other", "file.ts");
      mkdirSync(join(tmpDir, "other"), { recursive: true });
      writeFileSync(otherFile, "");
      writeFileSync(
        join(tmpDir, "coverage", "coverage-summary.json"),
        makeIstanbulReport({ [otherFile]: { total: 100, covered: 90 } })
      );
      writeFileSync(join(tmpDir, "tasks.md"), buildTasksMd([`coverage: src :: 80`]));
      const result = await validateTaskDone({ task_id: "T1-001" });
      // total = 90%, threshold 80 → pass
      expect(result.passed).toBe(true);
      expect(firstReason(result)).toContain("전체");
    } finally { cwdS.mockRestore(); c(); }
  });

  it("coverage: — pytest-cov 리포트, 임계값 통과", async () => {
    const { dir: tmpDir, cleanup: c } = createTempDir();
    const cwdS = mockCwd(tmpDir);
    try {
      mkdirSync(join(tmpDir, ".claude"), { recursive: true });
      mkdirSync(join(tmpDir, "backend", "app"), { recursive: true });
      const pyFile = join(tmpDir, "backend", "app", "users.py");
      writeFileSync(pyFile, "");
      writeFileSync(
        join(tmpDir, "coverage.json"),
        makePytestReport({ [pyFile]: { statements: 50, covered: 45 } }, 90)
      );
      writeFileSync(join(tmpDir, "tasks.md"), buildTasksMd([`coverage: backend/app :: 80`]));
      const result = await validateTaskDone({ task_id: "T1-001" });
      expect(result.passed).toBe(true);
    } finally { cwdS.mockRestore(); c(); }
  });

  it("coverage: — pytest-cov 리포트, 임계값 미달", async () => {
    const { dir: tmpDir, cleanup: c } = createTempDir();
    const cwdS = mockCwd(tmpDir);
    try {
      mkdirSync(join(tmpDir, ".claude"), { recursive: true });
      mkdirSync(join(tmpDir, "backend", "app"), { recursive: true });
      const pyFile = join(tmpDir, "backend", "app", "users.py");
      writeFileSync(pyFile, "");
      writeFileSync(
        join(tmpDir, "coverage.json"),
        makePytestReport({ [pyFile]: { statements: 50, covered: 30 } }, 60)
      );
      writeFileSync(join(tmpDir, "tasks.md"), buildTasksMd([`coverage: backend/app :: 80`]));
      const result = await validateTaskDone({ task_id: "T1-001" });
      expect(result.passed).toBe(false);
      expect(firstReason(result)).toContain("미달");
    } finally { cwdS.mockRestore(); c(); }
  });

  it("coverage: — 리포트 없을 시 실패 및 안내 메시지 포함", async () => {
    setup([`coverage: src :: 80`]);
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("리포트 없음");
  });

  it("coverage: % 기호 있어도 파싱 성공", async () => {
    const { dir: tmpDir, cleanup: c } = createTempDir();
    const cwdS = mockCwd(tmpDir);
    try {
      mkdirSync(join(tmpDir, ".claude"), { recursive: true });
      mkdirSync(join(tmpDir, "coverage"), { recursive: true });
      mkdirSync(join(tmpDir, "src"), { recursive: true });
      const srcFile = join(tmpDir, "src", "index.ts");
      writeFileSync(srcFile, "");
      writeFileSync(
        join(tmpDir, "coverage", "coverage-summary.json"),
        makeIstanbulReport({ [srcFile]: { total: 10, covered: 10 } })
      );
      writeFileSync(join(tmpDir, "tasks.md"), buildTasksMd([`coverage: src/index.ts :: 100%`]));
      const result = await validateTaskDone({ task_id: "T1-001" });
      expect(result.passed).toBe(true);
    } finally { cwdS.mockRestore(); c(); }
  });

  // ── ut: ────────────────────────────────────────────────────────────────

  const UT_REPORT = `# UT_FINDINGS_REPORT — 테스트

## Executive Summary

| 등급 | 건수 |
|---|---|
| S4 Critical | 0 |
| S3 Major | 2 |
| S2 Minor | 3 |
| S1 Cosmetic | 1 |
`;

  it("ut: — 임계 충족 시 통과 (S4=0,S3<=2)", async () => {
    setup(["ut: specs/001/ut/UT_FINDINGS_REPORT.md :: S4=0,S3<=2"], {
      "specs/001/ut/UT_FINDINGS_REPORT.md": UT_REPORT,
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(true);
    expect(firstReason(result)).toContain("UT 임계 통과");
  });

  it("ut: — S4 초과 시 실패 (배포 블로커)", async () => {
    const blocked = UT_REPORT.replace("| S4 Critical | 0 |", "| S4 Critical | 1 |");
    setup(["ut: specs/001/ut/UT_FINDINGS_REPORT.md :: S4=0,S3<=2"], {
      "specs/001/ut/UT_FINDINGS_REPORT.md": blocked,
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("S4=1 위반");
  });

  it("ut: — S3 임계 초과 시 실패 (S3<=2 인데 3건)", async () => {
    const tooMany = UT_REPORT.replace("| S3 Major | 2 |", "| S3 Major | 3 |");
    setup(["ut: specs/001/ut/UT_FINDINGS_REPORT.md :: S4=0,S3<=2"], {
      "specs/001/ut/UT_FINDINGS_REPORT.md": tooMany,
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("S3=3 위반");
  });

  it("ut: — 리포트 부재 시 실패 (UT 미실행을 통과로 오인 금지)", async () => {
    setup(["ut: specs/001/ut/UT_FINDINGS_REPORT.md :: S4=0"]);
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("리포트 없음");
  });

  it("ut: — Severity 카운트를 못 찾으면 실패", async () => {
    setup(["ut: specs/001/ut/UT_FINDINGS_REPORT.md :: S4=0"], {
      "specs/001/ut/UT_FINDINGS_REPORT.md": "# 빈 리포트\n내용 없음\n",
    });
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(firstReason(result)).toContain("찾지 못함");
  });

  // ── 엣지 케이스 ──────────────────────────────────────────────────────────

  it("tasks.md 없을 시 실패 반환", async () => {
    ({ dir, cleanup } = createTempDir());
    cwdSpy = mockCwd(dir);
    const result = await validateTaskDone({ task_id: "T1-001" });
    expect(result.passed).toBe(false);
    expect(result.reason).toContain("tasks.md");
  });

  it("존재하지 않는 task_id 시 실패 반환", async () => {
    setup(["file: out.txt"]);
    const result = await validateTaskDone({ task_id: "T9-999" });
    expect(result.passed).toBe(false);
    expect(result.reason).toContain("T9-999");
  });
});
