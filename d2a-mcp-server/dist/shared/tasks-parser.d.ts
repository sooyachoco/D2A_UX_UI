export interface ParsedTask {
    id: string;
    title: string;
    phase: number;
    status: "☐" | "☑";
    read: string[];
    write: string[];
    done: string[];
    deps: string[];
    skill: string | null;
    parallel: string[];
    noRead: string[];
    lineNo: number;
}
/** tasks.md 파일을 찾는다. 여러 경로를 순서대로 탐색. */
export declare function findTasksFile(cwd: string): string | null;
/** tasks.md를 파싱하여 ParsedTask 배열을 반환한다. */
export declare function parseTasks(tasksFilePath: string): ParsedTask[];
/**
 * Task ID를 정규화하여 deps 비교에 사용한다.
 * 대소문자를 통일하고 앞뒤 공백을 제거한다.
 * "T001"과 "T1-001"은 의미가 다른 별개의 ID로 취급한다 — 혼용 시 경고만 기록.
 */
export declare function normalizeTaskId(id: string): string;
/** 특정 task ID로 태스크를 찾는다. 정규화된 ID 비교를 사용한다. */
export declare function findTask(tasks: ParsedTask[], taskId: string): ParsedTask | undefined;
/**
 * tasks.md에 T001 형식과 T1-001 형식이 혼용되는지 확인하고
 * 혼용이 감지되면 stderr에 경고를 출력한다.
 */
export declare function warnIfMixedIdFormats(tasks: ParsedTask[]): void;
//# sourceMappingURL=tasks-parser.d.ts.map