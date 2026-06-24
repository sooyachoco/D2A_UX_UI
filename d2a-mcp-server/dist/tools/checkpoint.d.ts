export interface CheckpointResult {
    ok: boolean;
    branch?: string;
    cleaned_branches?: string[];
    error?: string;
}
export interface RollbackResult {
    ok: boolean;
    recovery_branch?: string;
    head?: string;
    original_branch?: string;
    error?: string;
}
/**
 * 태스크 실행 전 현재 HEAD에 checkpoint 브랜치를 생성한다.
 * run-phase Step 2 태스크 시작마다 호출한다.
 */
export declare function createCheckpoint(args: {
    task_id: string;
}): Promise<CheckpointResult>;
/**
 * 지정된 task_id 의 checkpoint 시점으로 recovery 브랜치를 생성하여 복원한다.
 * run-phase Step 2-5 (2회 연속 실패) 에서 호출한다.
 *
 * 기존 `git reset --hard` 방식의 문제:
 *   - 현재 브랜치(main 등)의 HEAD를 과거로 이동시켜 원격 오염 위험이 있었음
 * 개선된 방식:
 *   - checkpoint SHA를 찾아 recovery/{task_id}-{timestamp} 브랜치를 새로 생성
 *   - 원래 브랜치는 변경되지 않음 (안전한 복원)
 */
export declare function rollbackToCheckpoint(args: {
    task_id: string;
}): Promise<RollbackResult>;
//# sourceMappingURL=checkpoint.d.ts.map