import { D2AState } from "../shared/state-schema.js";
export interface UpdateStateResult {
    ok: boolean;
    state?: D2AState;
    error?: string;
}
/**
 * state.json을 부분 업데이트(patch)한다. atomic write 보장.
 *
 * patch 예시:
 *   { "phase": 2, "status": "running" }
 *   { "current_task": "T1-003" }
 *   { "integration_ready": true }
 */
export declare function updateState(args: {
    patch: Partial<D2AState>;
}): Promise<UpdateStateResult>;
/** 현재 state.json 전체를 반환한다. */
export declare function getState(): Promise<D2AState>;
//# sourceMappingURL=state-tool.d.ts.map