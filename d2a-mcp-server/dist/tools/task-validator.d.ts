export interface TaskDoneResult {
    passed: boolean;
    reason: string;
    criteria_results?: Array<{
        criterion: string;
        passed: boolean;
        reason: string;
    }>;
}
/**
 * tasks.md에서 지정된 task_id의 done 기준을 독립적으로 재실행하여 검증한다.
 * run-phase의 Claude 판단과 별개로 외부 코드가 검증하는 핵심 강제 포인트.
 */
export declare function validateTaskDone(args: {
    task_id: string;
}): Promise<TaskDoneResult>;
//# sourceMappingURL=task-validator.d.ts.map