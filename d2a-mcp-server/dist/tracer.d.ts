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
export interface TraceEntry {
    ts: string;
    tool: string;
    args: unknown;
    ok: boolean;
    phase?: number;
    task_id?: string;
}
/**
 * 도구 호출 결과를 trace 파일에 기록한다.
 * @param tool  도구 이름
 * @param args  입력 인자 (Zod parse 이후 객체)
 * @param result 도구 반환값 (JSON 직렬화 가능)
 */
export declare function recordTrace(tool: string, args: unknown, result: unknown): void;
//# sourceMappingURL=tracer.d.ts.map