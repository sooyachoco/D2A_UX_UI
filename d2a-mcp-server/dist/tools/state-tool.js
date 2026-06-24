import fs from "fs";
import path from "path";
import { DEFAULT_STATE, migrateState } from "../shared/state-schema.js";
const STATE_FILE = ".claude/state.json";
const TEMP_FILE = ".claude/state.json.tmp";
const ERRORS_LOG = ".claude/hook-errors.log";
function getStatePath(cwd) {
    return {
        stateFile: path.join(cwd, STATE_FILE),
        tempFile: path.join(cwd, TEMP_FILE),
    };
}
function logStateError(cwd, message) {
    try {
        const logPath = path.join(cwd, ERRORS_LOG);
        const dir = path.dirname(logPath);
        if (!fs.existsSync(dir))
            fs.mkdirSync(dir, { recursive: true });
        const timestamp = new Date().toISOString().slice(11, 19);
        fs.appendFileSync(logPath, `[${timestamp}] state-tool: ${message}\n`, "utf-8");
    }
    catch { /* 로그 실패는 무시 */ }
}
function readState(stateFile) {
    const cwd = path.dirname(path.dirname(stateFile)); // .claude/ → project root
    try {
        if (!fs.existsSync(stateFile))
            return { ...DEFAULT_STATE };
        const raw = JSON.parse(fs.readFileSync(stateFile, "utf-8"));
        return migrateState(raw);
    }
    catch (e) {
        logStateError(cwd, `state.json 파싱 실패 → DEFAULT_STATE 반환: ${e.message}`);
        return { ...DEFAULT_STATE };
    }
}
function writeState(state, stateFile, tempFile) {
    const dir = path.dirname(stateFile);
    if (!fs.existsSync(dir))
        fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(tempFile, JSON.stringify(state, null, 2), "utf-8");
    fs.renameSync(tempFile, stateFile);
}
/**
 * state.json을 부분 업데이트(patch)한다. atomic write 보장.
 *
 * patch 예시:
 *   { "phase": 2, "status": "running" }
 *   { "current_task": "T1-003" }
 *   { "integration_ready": true }
 */
export async function updateState(args) {
    const cwd = process.cwd();
    const { stateFile, tempFile } = getStatePath(cwd);
    try {
        const current = readState(stateFile);
        const updated = {
            ...current,
            ...args.patch,
            last_updated: new Date().toISOString(),
        };
        writeState(updated, stateFile, tempFile);
        return { ok: true, state: updated };
    }
    catch (e) {
        return { ok: false, error: e.message };
    }
}
/** 현재 state.json 전체를 반환한다. */
export async function getState() {
    const cwd = process.cwd();
    const { stateFile } = getStatePath(cwd);
    return readState(stateFile);
}
//# sourceMappingURL=state-tool.js.map