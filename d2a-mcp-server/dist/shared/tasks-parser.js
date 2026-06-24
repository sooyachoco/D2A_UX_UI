import fs from "fs";
import path from "path";
/** tasks.md 파일을 찾는다. 여러 경로를 순서대로 탐색. */
export function findTasksFile(cwd) {
    const candidates = [
        "tasks.md",
        "specs/tasks.md",
    ];
    // specs/**/tasks.md 패턴 탐색
    const specsDir = path.join(cwd, "specs");
    if (fs.existsSync(specsDir)) {
        try {
            const entries = fs.readdirSync(specsDir, { withFileTypes: true });
            for (const entry of entries) {
                if (entry.isDirectory() && !entry.name.startsWith('.')) {
                    candidates.push(`specs/${entry.name}/tasks.md`);
                }
            }
        }
        catch { /* ignore */ }
    }
    for (const c of candidates) {
        const full = path.join(cwd, c);
        if (fs.existsSync(full))
            return full;
    }
    return null;
}
/** tasks.md를 파싱하여 ParsedTask 배열을 반환한다. */
export function parseTasks(tasksFilePath) {
    const content = fs.readFileSync(tasksFilePath, "utf-8");
    const lines = content.split("\n");
    const tasks = [];
    let currentPhase = 0;
    let currentTask = null;
    // done 멀티라인 수집 상태
    let collectingDone = false;
    const saveTask = () => {
        if (!currentTask)
            return;
        tasks.push({
            id: currentTask.id,
            title: currentTask.title ?? "",
            phase: currentTask.phase ?? currentPhase,
            status: currentTask.status ?? "☐",
            read: currentTask.read ?? [],
            write: currentTask.write ?? [],
            done: currentTask.done ?? [],
            deps: currentTask.deps ?? [],
            skill: currentTask.skill ?? null,
            parallel: currentTask.parallel ?? [],
            noRead: currentTask.noRead ?? [],
            lineNo: currentTask.lineNo ?? 0,
        });
        currentTask = null;
        collectingDone = false;
    };
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const lineNo = i + 1;
        // Phase 헤더: ## Phase N
        const phaseMatch = line.match(/^##\s+Phase\s+([\d.]+)/i);
        if (phaseMatch) {
            saveTask();
            currentPhase = parseFloat(phaseMatch[1]);
            collectingDone = false;
            continue;
        }
        // 태스크 헤더: ### T001: ... 또는 ### T1-001: ... 또는 ### T1-review: ...
        const taskMatch = line.match(/^###\s+(T\d[\w\-]*)\s*:\s*(.*)/);
        if (taskMatch) {
            saveTask();
            currentTask = {
                id: taskMatch[1],
                title: taskMatch[2].trim(),
                phase: currentPhase,
                lineNo,
                read: [],
                write: [],
                done: [],
                deps: [],
                parallel: [],
                noRead: [],
            };
            collectingDone = false;
            continue;
        }
        if (!currentTask)
            continue;
        // 멀티라인 done 수집: "  - " 으로 시작하는 라인
        if (collectingDone) {
            const bulletMatch = line.match(/^\s+[-*]\s+(.*)/);
            if (bulletMatch && bulletMatch[1].trim()) {
                currentTask.done.push(bulletMatch[1].trim());
                continue;
            }
            // 새 필드 or 빈 줄 or 다른 내용 → done 수집 종료
            if (!line.match(/^\*\*/)) {
                collectingDone = false;
            }
        }
        // 필드 파싱: **field**: value
        const fieldMatch = line.match(/^\*\*([\w\-]+)\*\*\s*:\s*(.*)/);
        if (!fieldMatch)
            continue;
        collectingDone = false;
        const [, fieldName, rawValue] = fieldMatch;
        const value = rawValue.trim();
        switch (fieldName.toLowerCase()) {
            case "status":
                currentTask.status = value.includes("☑") ? "☑" : "☐";
                break;
            case "read":
                if (value) {
                    currentTask.read = value
                        .split(",")
                        .map((v) => v.trim())
                        .filter(Boolean);
                }
                break;
            case "write":
                if (value) {
                    currentTask.write = value
                        .split(",")
                        .map((v) => v.trim())
                        .filter(Boolean);
                }
                break;
            case "done":
                if (value) {
                    currentTask.done = [value];
                }
                else {
                    // 빈 값 → 다음 줄에서 bullet list 수집
                    collectingDone = true;
                }
                break;
            case "deps":
                if (value && value !== "-" && value !== "—") {
                    currentTask.deps = value
                        .split(",")
                        .map((v) => v.trim())
                        .filter((v) => v && v !== "-");
                }
                break;
            case "skill":
                currentTask.skill = value || null;
                break;
            case "parallel":
                if (value) {
                    currentTask.parallel = value
                        .split(",")
                        .map((v) => v.trim())
                        .filter(Boolean);
                }
                break;
            case "no-read":
                if (value) {
                    currentTask.noRead = value
                        .split(",")
                        .map((v) => v.trim())
                        .filter(Boolean);
                }
                break;
        }
    }
    saveTask();
    warnIfMixedIdFormats(tasks);
    return tasks;
}
/**
 * Task ID를 정규화하여 deps 비교에 사용한다.
 * 대소문자를 통일하고 앞뒤 공백을 제거한다.
 * "T001"과 "T1-001"은 의미가 다른 별개의 ID로 취급한다 — 혼용 시 경고만 기록.
 */
export function normalizeTaskId(id) {
    return id.trim().toUpperCase();
}
/** 특정 task ID로 태스크를 찾는다. 정규화된 ID 비교를 사용한다. */
export function findTask(tasks, taskId) {
    const normalized = normalizeTaskId(taskId);
    return tasks.find((t) => normalizeTaskId(t.id) === normalized);
}
/**
 * tasks.md에 T001 형식과 T1-001 형식이 혼용되는지 확인하고
 * 혼용이 감지되면 stderr에 경고를 출력한다.
 */
export function warnIfMixedIdFormats(tasks) {
    // T{N}-review 는 예약된 리뷰 태스크 ID — 혼용 감지에서 제외
    const nonReview = tasks.filter((t) => !/^T\d+-review$/i.test(t.id));
    const withDash = nonReview.filter((t) => /^T\d+-\d+$/i.test(t.id));
    const withoutDash = nonReview.filter((t) => /^T\d+$/i.test(t.id));
    if (withDash.length > 0 && withoutDash.length > 0) {
        process.stderr.write(`[d2a-harness] 경고: tasks.md에 Task ID 형식이 혼용되어 있습니다.\n` +
            `  T{N}-{seq} 형식: ${withDash.slice(0, 3).map((t) => t.id).join(", ")}...\n` +
            `  T{seq} 형식:     ${withoutDash.slice(0, 3).map((t) => t.id).join(", ")}...\n` +
            `  deps 참조가 잘못 연결될 수 있습니다. 형식을 통일하세요.\n`);
    }
}
//# sourceMappingURL=tasks-parser.js.map