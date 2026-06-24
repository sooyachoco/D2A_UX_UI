/** .claude/state.json 타입 정의 */
/** 현재 스키마 버전. state.json 필드 구조가 변경될 때 증가한다. */
export const STATE_SCHEMA_VERSION = 3;
export const DEFAULT_STATE = {
    schema_version: STATE_SCHEMA_VERSION,
    phase: null,
    status: "idle",
    current_task: null,
    integration_ready: false,
    gnb_required: false,
    auth_profile: null,
    auth_storage_ready: false,
    step27_user_approved: false,
    last_commit: null,
    last_updated: null,
    blockers: [],
    completed_tasks: [],
};
/**
 * 오래된 state.json을 현재 스키마로 마이그레이션한다.
 * 새 필드를 추가할 때마다 여기서 기본값을 채운다.
 */
export function migrateState(raw) {
    const version = raw.schema_version ?? 0;
    const migrated = { ...DEFAULT_STATE, ...raw };
    // v0 → v1: schema_version 필드 없음 → 추가
    if (version < 1) {
        migrated.schema_version = STATE_SCHEMA_VERSION;
    }
    // v1 → v2: gnb_required 필드 없음 → false로 초기화
    if (version < 2) {
        migrated.gnb_required = raw.gnb_required === true ? true : false;
        migrated.schema_version = STATE_SCHEMA_VERSION;
    }
    // v2 → v3: auth_profile / auth_storage_ready / step27_user_approved 필드 도입
    if (version < 3) {
        const rec = raw;
        const ap = rec.auth_profile;
        migrated.auth_profile =
            ap === "insign" || ap === "nxas" || ap === "insign-with-nxas" || ap === "custom" || ap === "none"
                ? ap
                : null;
        migrated.auth_storage_ready = rec.auth_storage_ready === true;
        migrated.step27_user_approved = rec.step27_user_approved === true;
        migrated.schema_version = STATE_SCHEMA_VERSION;
    }
    return migrated;
}
//# sourceMappingURL=state-schema.js.map