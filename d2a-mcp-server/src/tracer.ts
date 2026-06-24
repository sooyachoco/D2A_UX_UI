/**
 * tracer.ts — MCP 도구 호출 추적 (방안 2)
 *
 * 각 도구 호출을 .claude/traces/current.jsonl 에 한 줄씩 JSON으로 기록한다.
 * validate-traces.sh 가 이 파일을 읽어 Phase별 기대 호출 시퀀스를 검증한다.
 *
 * 설계 원칙:
 * - best-effort: I/O 실패 시 조용히 무시하고 도구 실행을 막지 않는다.
 * - 세션 경계: MCP 서버 시작 시 current.jsonl 을 초기화하지 않는다
 *   (Claude Code 세션 여러 개가 동시에 쓸 수 있으므로 append 전용).
 * - 크기 제한: 5000줄 초과 시 오래된 절반을 trim하여 무제한 증가 방지.
 */

import fs from "fs";
import path from "path";

// .claude/traces/ 는 프로젝트 루트 기준
const TRACE_DIR = path.join(process.cwd(), ".claude", "traces");
const TRACE_FILE = path.join(TRACE_DIR, "current.jsonl");
const MAX_LINES = 5000;

export interface TraceEntry {
  ts: string;          // ISO 8601 타임스탬프
  tool: string;        // 도구 이름 (check_phase_gate, get_next_task 등)
  args: unknown;       // 입력 인자
  ok: boolean;         // 응답에 error가 없으면 true
  phase?: number;      // 가능하면 추출한 Phase 번호
  task_id?: string;    // 가능하면 추출한 태스크 ID
}

/**
 * 도구 호출 결과를 trace 파일에 기록한다.
 * @param tool  도구 이름
 * @param args  입력 인자 (Zod parse 이후 객체)
 * @param result 도구 반환값 (JSON 직렬화 가능)
 */
export function recordTrace(tool: string, args: unknown, result: unknown): void {
  try {
    const entry: TraceEntry = {
      ts: new Date().toISOString(),
      tool,
      args,
      ok: !isResultError(result),
    };

    // Phase / task_id 보조 추출
    if (args && typeof args === "object") {
      const a = args as Record<string, unknown>;
      if (typeof a.phase === "number")   entry.phase   = a.phase;
      if (typeof a.task_id === "string") entry.task_id = a.task_id;
    }

    ensureTraceDir();
    appendEntry(JSON.stringify(entry));
  } catch {
    // best-effort — 실패해도 도구 실행에 영향 없음
  }
}

// ── 내부 유틸 ────────────────────────────────────────────────────────────────

function isResultError(result: unknown): boolean {
  if (result && typeof result === "object") {
    const r = result as Record<string, unknown>;
    if (r.error) return true;
    if (Array.isArray(r.content)) {
      // MCP content 배열에서 error 키 탐색
      return (r.content as unknown[]).some(
        (c) => c && typeof c === "object" && (c as Record<string, unknown>).error
      );
    }
  }
  return false;
}

function ensureTraceDir(): void {
  if (!fs.existsSync(TRACE_DIR)) {
    fs.mkdirSync(TRACE_DIR, { recursive: true });
  }
}

function appendEntry(line: string): void {
  fs.appendFileSync(TRACE_FILE, line + "\n", "utf8");
  trimIfNeeded();
}

function trimIfNeeded(): void {
  try {
    const content = fs.readFileSync(TRACE_FILE, "utf8");
    const lines = content.split("\n").filter(Boolean);
    if (lines.length > MAX_LINES) {
      // 오래된 절반 제거
      const kept = lines.slice(Math.floor(lines.length / 2));
      fs.writeFileSync(TRACE_FILE, kept.join("\n") + "\n", "utf8");
    }
  } catch {
    // best-effort
  }
}
