import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { findTasksFile, parseTasks, normalizeTaskId } from "../shared/tasks-parser.js";
import { getState, updateState } from "./state-tool.js";
import { validateTaskDone } from "./task-validator.js";
import { createCheckpoint, rollbackToCheckpoint } from "./checkpoint.js";
const VALIDATE_TOKEN = ".claude/last-validate-result";
// ─── 내부 유틸 ───────────────────────────────────────────────────────────────
/**
 * state.json의 completed_tasks와 tasks.md ☑ 상태를 합산하여 완료 태스크 ID 집합을 반환.
 * 모든 ID는 정규화(대문자 + trim)하여 저장한다.
 */
async function completedTaskIds(tasks) {
    const state = await getState();
    const fromState = new Set((state.completed_tasks ?? []).map(normalizeTaskId));
    // tasks.md의 ☑ 상태도 포함 (두 소스 합산)
    for (const t of tasks) {
        if (t.status === "☑")
            fromState.add(normalizeTaskId(t.id));
    }
    return fromState;
}
/** deps가 모두 완료된 첫 번째 미완료 태스크를 반환한다 */
function pickNextTask(tasks, phase, completed) {
    const phaseTasks = tasks.filter((t) => t.phase === phase);
    for (const task of phaseTasks) {
        if (completed.has(normalizeTaskId(task.id)))
            continue;
        // deps도 정규화하여 비교
        const depsOk = task.deps.every((dep) => completed.has(normalizeTaskId(dep)));
        if (depsOk)
            return task;
    }
    return null;
}
/**
 * state.json의 blockers 중 recovery 브랜치가 이미 삭제된(=사용자가 해결한) 항목을 자동 제거한다.
 * getNextTask 시작 시 호출하여 blocker 해결 후 자동 재개를 지원한다.
 */
async function autoResolveBlockers(cwd) {
    const state = await getState();
    if (!state.blockers || state.blockers.length === 0)
        return;
    const activeBlockers = state.blockers.filter((b) => {
        const match = b.reason.match(/recovery 브랜치: (recovery\/\S+)/);
        if (!match)
            return true; // recovery 브랜치 정보 없으면 유지
        const recoveryBranch = match[1];
        try {
            const result = execSync(`git branch --list "${recoveryBranch}"`, {
                cwd, stdio: "pipe",
            }).toString().trim();
            return result.length > 0; // 브랜치 존재 = 아직 해결 안 됨
        }
        catch {
            return true; // git 오류 시 보수적으로 유지
        }
    });
    if (activeBlockers.length < state.blockers.length) {
        const resolved = state.blockers.length - activeBlockers.length;
        process.stderr.write(`[d2a-harness] 블로커 자동 해제: ${resolved}개 (recovery 브랜치 소멸 감지)\n`);
        await updateState({ patch: { blockers: activeBlockers } });
    }
}
/** validate token 파일 생성 — pre-bash-hook이 git commit 전에 확인한다 */
function writeValidateToken(cwd) {
    const tokenPath = path.join(cwd, VALIDATE_TOKEN);
    const dir = path.dirname(tokenPath);
    if (!fs.existsSync(dir))
        fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(tokenPath, "passed", "utf-8");
}
// ─── 공개 함수 ───────────────────────────────────────────────────────────────
/**
 * 지정된 Phase에서 다음에 실행해야 할 태스크를 반환한다.
 *
 * Claude는 이 도구를 호출하여 "무엇을 구현해야 하는지"를 받는다.
 * 루프 로직·deps 확인·완료 판단은 모두 이 코드가 담당한다.
 */
export async function getNextTask(args) {
    const { phase } = args;
    const cwd = process.cwd();
    // recovery 브랜치가 삭제된 blocker는 자동 해제 (사용자가 수동으로 해결한 경우)
    await autoResolveBlockers(cwd);
    const tasksFile = findTasksFile(cwd);
    if (!tasksFile) {
        return {
            ok: false, task_id: null, title: "", phase,
            read_files: [], write_files: [], deps: [], done_criteria: [],
            skill: null, all_done: false, error: "tasks.md 파일을 찾을 수 없음",
        };
    }
    let tasks;
    try {
        tasks = parseTasks(tasksFile);
    }
    catch (e) {
        return {
            ok: false, task_id: null, title: "", phase,
            read_files: [], write_files: [], deps: [], done_criteria: [],
            skill: null, all_done: false, error: `tasks.md 파싱 실패: ${e.message}`,
        };
    }
    const completed = await completedTaskIds(tasks);
    const phaseTasks = tasks.filter((t) => t.phase === phase);
    if (phaseTasks.length === 0) {
        return {
            ok: false, task_id: null, title: "", phase,
            read_files: [], write_files: [], deps: [], done_criteria: [],
            skill: null, all_done: false, error: `Phase ${phase} 태스크가 tasks.md에 없음`,
        };
    }
    // 모든 태스크 완료 여부 — normalizeTaskId로 비교해야 T1-review 등 혼합 케이스 올바르게 처리
    const allDone = phaseTasks.every((t) => completed.has(normalizeTaskId(t.id)));
    if (allDone) {
        // 리뷰 토큰 존재 여부 확인 — 토큰 없이 Phase 완료하면 Gate 3 우회 위험
        const tokenPath = path.join(cwd, `.claude/review-tokens/phase-${phase}.token`);
        const reviewTokenMissing = !fs.existsSync(tokenPath);
        if (reviewTokenMissing) {
            process.stderr.write(`[d2a-harness] ⚠️  Phase ${phase} 완료: review token 없음 — ` +
                `.claude/review-tokens/phase-${phase}.token 미존재\n` +
                `  subagent-review Step 5가 완료되지 않았을 수 있습니다.\n`);
        }
        return {
            ok: true, task_id: null, title: "Phase 완료", phase,
            read_files: [], write_files: [], deps: [], done_criteria: [],
            skill: null, all_done: true,
            review_token_missing: reviewTokenMissing,
        };
    }
    const next = pickNextTask(tasks, phase, completed);
    if (!next) {
        // 미완료 태스크는 있으나 deps가 충족되지 않음
        const blocked = phaseTasks
            .filter((t) => !completed.has(t.id))
            .map((t) => `${t.id}(deps: ${t.deps.join(",")})`);
        return {
            ok: false, task_id: null, title: "", phase,
            read_files: [], write_files: [], deps: [], done_criteria: [],
            skill: null, all_done: false,
            error: `deps 미충족으로 실행 가능한 태스크 없음: ${blocked.join(", ")}`,
        };
    }
    // 체크포인트 자동 생성 (태스크 시작 전 안전망)
    await createCheckpoint({ task_id: next.id });
    // state.json에 현재 태스크 기록
    await updateState({ patch: { current_task: next.id, status: "running" } });
    return {
        ok: true,
        task_id: next.id,
        title: next.title,
        phase,
        read_files: next.read,
        write_files: next.write,
        deps: next.deps,
        done_criteria: next.done,
        skill: next.skill, // tasks.md **skill** 필드 전달
        all_done: false,
    };
}
/**
 * Critical Path 파일 패턴 — 인증·세션·미들웨어·계약 관련 경로
 * 이 패턴에 해당하는 파일이 changed_files에 포함되면 경고를 발생시킨다.
 */
const CRITICAL_PATH_PATTERNS = [
    /auth/i,
    /login/i,
    /session/i,
    /middleware/i,
    /contracts\//i,
    /data-model/i,
    /api-spec/i,
];
function detectCriticalPathFiles(changedFiles) {
    return changedFiles.filter((f) => CRITICAL_PATH_PATTERNS.some((re) => re.test(f)));
}
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
export async function submitTask(args) {
    const { task_id, attempt, changed_files } = args;
    const cwd = process.cwd();
    // Critical Path 파일 감지
    const criticalFiles = changed_files ? detectCriticalPathFiles(changed_files) : [];
    if (criticalFiles.length > 0) {
        process.stderr.write(`[d2a-harness] ⚠️  Critical Path 파일 감지 (${task_id}):\n` +
            criticalFiles.map((f) => `  - ${f}`).join("\n") + "\n" +
            `  인증·세션·계약 파일 변경 시 subagent-review(--full)를 반드시 실행하세요.\n`);
    }
    // done 기준 검증
    const validateResult = await validateTaskDone({ task_id });
    if (validateResult.passed) {
        // ── 통과 처리 ──────────────────────────────────────────────────────────
        // validate token 생성 — pre-bash-hook이 git commit을 허용하는 조건
        writeValidateToken(cwd);
        // state.json 업데이트 (completed_tasks에 추가, 정규화하여 중복 방지)
        const current = await getState();
        const completedTasks = (current.completed_tasks ?? []).map(normalizeTaskId);
        const normalizedId = normalizeTaskId(task_id);
        if (!completedTasks.includes(normalizedId))
            completedTasks.push(normalizedId);
        // 다음 태스크 탐색
        const tasksFile = findTasksFile(cwd);
        let nextTaskId = null;
        if (tasksFile) {
            try {
                const tasks = parseTasks(tasksFile);
                const phase = current.phase ?? 0;
                // completedTasks와 task_id 모두 정규화하여 pickNextTask의 normalizeTaskId 비교와 일치시킨다
                const completedSet = new Set([...completedTasks, normalizeTaskId(task_id)]);
                const next = pickNextTask(tasks, phase, completedSet);
                nextTaskId = next?.id ?? null;
            }
            catch { /* ignore */ }
        }
        await updateState({
            patch: {
                status: "running",
                current_task: nextTaskId,
                completed_tasks: completedTasks,
                last_commit: null, // 커밋 후 post-tool-hook이 갱신
            },
        });
        return {
            ok: true,
            passed: true,
            action: "next",
            reason: validateResult.reason,
            next_task_id: nextTaskId,
            criteria_results: validateResult.criteria_results,
            critical_path_files: criticalFiles.length > 0 ? criticalFiles : undefined,
        };
    }
    // ── 실패 처리 ────────────────────────────────────────────────────────────
    if (attempt === 1) {
        // 1차 실패 → 수정 후 재시도 지시
        return {
            ok: true,
            passed: false,
            action: "retry",
            reason: validateResult.reason,
            next_task_id: null,
            criteria_results: validateResult.criteria_results,
        };
    }
    // 2차 실패 → 자동 rollback
    const rollbackResult = await rollbackToCheckpoint({ task_id });
    if (!rollbackResult.ok) {
        return {
            ok: false,
            passed: false,
            action: "rollback",
            reason: `validate 2회 실패 + rollback 실패: ${rollbackResult.error}`,
            next_task_id: null,
            criteria_results: validateResult.criteria_results,
        };
    }
    return {
        ok: true,
        passed: false,
        action: "rollback",
        reason: [
            `validate 2회 연속 실패 — 자동 rollback 완료`,
            `recovery 브랜치: ${rollbackResult.recovery_branch}`,
            `원래 브랜치(변경 없음): ${rollbackResult.original_branch}`,
            `실패 원인:\n${validateResult.reason}`,
        ].join("\n"),
        next_task_id: null,
        criteria_results: validateResult.criteria_results,
    };
}
//# sourceMappingURL=phase-runner.js.map