import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { updateState, getState } from "./state-tool.js";

export interface CheckpointResult {
  ok: boolean;
  branch?: string;
  cleaned_branches?: string[]; // B2: 정리된 이전 checkpoint 브랜치 목록
  error?: string;
}

export interface RollbackResult {
  ok: boolean;
  recovery_branch?: string; // 새로 생성된 recovery 브랜치 이름
  head?: string;
  original_branch?: string; // rollback 전 작업 중이던 브랜치 (변경되지 않음)
  error?: string;
}

const LAST_CHECKPOINT_FILE = ".claude/last-checkpoint";

function isGitRepo(cwd: string): boolean {
  try {
    execSync("git rev-parse --git-dir", { cwd, stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

function hasCommits(cwd: string): boolean {
  try {
    execSync("git rev-parse HEAD", { cwd, stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

/**
 * 태스크 실행 전 현재 HEAD에 checkpoint 브랜치를 생성한다.
 * run-phase Step 2 태스크 시작마다 호출한다.
 */
export async function createCheckpoint(args: { task_id: string }): Promise<CheckpointResult> {
  const { task_id } = args;
  const cwd = process.cwd();

  if (!isGitRepo(cwd)) {
    return { ok: false, error: "git 저장소가 아닙니다" };
  }
  if (!hasCommits(cwd)) {
    return { ok: false, error: "커밋이 없어 checkpoint를 생성할 수 없습니다" };
  }

  const timestamp = new Date().toISOString().replace(/[:\-.]/g, "").slice(0, 15) + "Z";
  const branch = `checkpoint/${task_id}-${timestamp}`;

  // B2: 동일 task_id의 이전 checkpoint 브랜치를 먼저 정리한다.
  // 재시도·재진입 시 브랜치 누적을 방지한다.
  const cleanedBranches: string[] = [];
  try {
    const existing = execSync(`git branch --list "checkpoint/${task_id}-*"`, {
      cwd,
      stdio: "pipe",
    }).toString();
    const toDelete = existing
      .split("\n")
      .map((b) => b.replace(/^[* ]+/, "").trim())
      .filter(Boolean);
    for (const b of toDelete) {
      execSync(`git branch -D "${b}"`, { cwd, stdio: "pipe" });
      cleanedBranches.push(b);
    }
  } catch { /* 브랜치 없음 — 무시 */ }

  try {
    execSync(`git branch "${branch}" HEAD`, { cwd, stdio: "pipe" });

    // .claude/last-checkpoint 기록
    const recordFile = path.join(cwd, LAST_CHECKPOINT_FILE);
    const dir = path.dirname(recordFile);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(recordFile, branch, "utf-8");

    return { ok: true, branch, cleaned_branches: cleanedBranches };
  } catch (e: unknown) {
    return { ok: false, error: (e as Error).message };
  }
}

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
export async function rollbackToCheckpoint(
  args: { task_id: string }
): Promise<RollbackResult> {
  const { task_id } = args;
  const cwd = process.cwd();

  if (!isGitRepo(cwd)) {
    return { ok: false, error: "git 저장소가 아닙니다" };
  }

  // 현재 브랜치 기록 (rollback 후에도 변경되지 않음)
  let originalBranch = "";
  try {
    originalBranch = execSync("git rev-parse --abbrev-ref HEAD", { cwd, stdio: "pipe" })
      .toString().trim();
  } catch { /* ignore */ }

  // checkpoint/{task_id}-* 브랜치 중 가장 최신 것 탐색
  let checkpointBranch: string | null = null;
  try {
    const result = execSync(`git branch --list "checkpoint/${task_id}-*"`, {
      cwd,
      stdio: "pipe",
    }).toString();
    const branches = result
      .split("\n")
      .map((b) => b.replace(/^[* ]+/, "").trim())
      .filter(Boolean)
      .sort();
    checkpointBranch = branches.at(-1) ?? null;
  } catch { /* ignore */ }

  // fallback: .claude/last-checkpoint
  if (!checkpointBranch) {
    const recordFile = path.join(cwd, LAST_CHECKPOINT_FILE);
    if (fs.existsSync(recordFile)) {
      checkpointBranch = fs.readFileSync(recordFile, "utf-8").trim();
    }
  }

  if (!checkpointBranch) {
    return {
      ok: false,
      error: `checkpoint/${task_id}-* 브랜치를 찾을 수 없습니다. checkpoint가 생성되지 않았거나 이미 삭제되었습니다.`,
    };
  }

  // checkpoint 브랜치가 가리키는 SHA 확인
  let checkpointSHA = "";
  try {
    checkpointSHA = execSync(`git rev-parse "${checkpointBranch}"`, { cwd, stdio: "pipe" })
      .toString().trim();
  } catch (e: unknown) {
    return { ok: false, error: `checkpoint 브랜치 SHA 조회 실패: ${(e as Error).message}` };
  }

  // uncommitted 변경이 있으면 stash로 보존 (원래 브랜치 보호)
  try {
    const status = execSync("git status --porcelain", { cwd, stdio: "pipe" })
      .toString().trim();
    if (status) {
      execSync(
        `git stash push -m "d2a-rollback-${task_id}-${Date.now()}"`,
        { cwd, stdio: "pipe" }
      );
    }
  } catch (stashErr: unknown) {
    return {
      ok: false,
      error: `uncommitted 변경이 있으나 git stash 실패 — 수동으로 변경 사항을 처리한 뒤 재시도: ${
        (stashErr as Error).message ?? String(stashErr)
      }`,
    };
  }

  // recovery 브랜치 생성 (원래 브랜치 HEAD 이동 없음)
  const timestamp = new Date().toISOString().replace(/[:\-.]/g, "").slice(0, 15) + "Z";
  const recoveryBranch = `recovery/${task_id}-${timestamp}`;

  try {
    execSync(`git checkout -b "${recoveryBranch}" "${checkpointSHA}"`, { cwd, stdio: "pipe" });
    const head = execSync("git rev-parse --short HEAD", { cwd, stdio: "pipe" })
      .toString().trim();

    // 기존 blockers를 유지하면서 새 blocker를 추가한다.
    const current = await getState();
    const existingBlockers = current.blockers ?? [];
    const alreadyBlocked = existingBlockers.some((b) => b.task === task_id);
    const newBlockers = alreadyBlocked
      ? existingBlockers
      : [
          ...existingBlockers,
          {
            task: task_id,
            reason: `rollback 실행됨 — recovery 브랜치: ${recoveryBranch}`,
            since: new Date().toISOString(),
          },
        ];

    await updateState({
      patch: {
        status: "blocked",
        blockers: newBlockers,
      },
    });

    // last-checkpoint 삭제
    const recordFile = path.join(cwd, LAST_CHECKPOINT_FILE);
    if (fs.existsSync(recordFile)) fs.unlinkSync(recordFile);

    return {
      ok: true,
      recovery_branch: recoveryBranch,
      original_branch: originalBranch,
      head,
    };
  } catch (e: unknown) {
    return { ok: false, error: (e as Error).message };
  }
}
