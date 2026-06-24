export interface NextTaskResult {
    ok: boolean;
    task_id: string | null;
    title: string;
    phase: number;
    read_files: string[];
    write_files: string[];
    deps: string[];
    done_criteria: string[];
    skill: string | null;
    all_done: boolean;
    review_token_missing?: boolean;
    error?: string;
}
export interface SubmitTaskResult {
    ok: boolean;
    passed: boolean;
    action: "next" | "retry" | "rollback";
    reason: string;
    next_task_id: string | null;
    criteria_results?: Array<{
        criterion: string;
        passed: boolean;
        reason: string;
    }>;
    /** changed_files 중 Critical Path에 해당하는 파일 목록 */
    critical_path_files?: string[];
    error?: string;
}
/**
 * 지정된 Phase에서 다음에 실행해야 할 태스크를 반환한다.
 *
 * Claude는 이 도구를 호출하여 "무엇을 구현해야 하는지"를 받는다.
 * 루프 로직·deps 확인·완료 판단은 모두 이 코드가 담당한다.
 */
export declare function getNextTask(args: {
    phase: number;
}): Promise<NextTaskResult>;
/**
 * 태스크 구현 완료를 제출하여 검증하고 다음 액션을 결정한다.
 *
 * Claude는 코드 작성 후 이 도구를 호출한다.
 * validate 실행·실패 카운트·rollback 결정은 이 코드가 담당한다.
 *
 * attempt=1 : 첫 번째 제출
 * attempt=2 : 1회 수정 후 재제출 → 실패 시 자동 rollback
 *
 * changed_files (선택): 이 태스크에서 수정된 파일 목록.
 *   Critical Path 파일(auth/login/session/middleware/contracts/)이 포함되면
 *   stderr 경고 및 응답에 critical_path_files 필드로 알린다.
 *   리뷰 생략 자가 판단 방지용 — 이 목록이 있으면 subagent-review를 강제 권고한다.
 */
export declare function submitTask(args: {
    task_id: string;
    attempt: 1 | 2;
    changed_files?: string[];
}): Promise<SubmitTaskResult>;
//# sourceMappingURL=phase-runner.d.ts.map