import { mkdirSync, writeFileSync, rmSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import { execSync } from "child_process";
import { vi } from "vitest";
/** 임시 디렉토리를 생성하고 정리 함수를 반환한다. */
export function createTempDir() {
    const dir = join(tmpdir(), `d2a-test-${Date.now()}-${Math.random().toString(36).slice(2)}`);
    mkdirSync(dir, { recursive: true });
    return {
        dir,
        cleanup: () => rmSync(dir, { recursive: true, force: true }),
    };
}
/** git 저장소가 초기화된 임시 디렉토리를 생성한다. */
export function createTempGitRepo() {
    const { dir, cleanup } = createTempDir();
    execSync("git init", { cwd: dir, stdio: "pipe" });
    execSync('git config user.email "test@d2a.test"', { cwd: dir, stdio: "pipe" });
    execSync('git config user.name "D2A Test"', { cwd: dir, stdio: "pipe" });
    writeFileSync(join(dir, "README.md"), "init");
    execSync("git add -A", { cwd: dir, stdio: "pipe" });
    execSync('git commit -m "init"', { cwd: dir, stdio: "pipe" });
    return { dir, cleanup };
}
/** process.cwd()를 지정된 디렉토리로 모킹한다. */
export function mockCwd(dir) {
    return vi.spyOn(process, "cwd").mockReturnValue(dir);
}
//# sourceMappingURL=helpers.js.map