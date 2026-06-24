/** .claude/state.json 타입 정의 */

/** 현재 스키마 버전. state.json 필드 구조가 변경될 때 증가한다. */
export const STATE_SCHEMA_VERSION = 3;

export interface Blocker {
  task: string;
  reason: string;
  since: string;
}

/** boilerplate-setup Stage 1.6-A에서 결정되는 인증 프로필. */
export type AuthProfile =
  | "insign"
  | "nxas"
  | "insign-with-nxas"
  | "custom"
  | "none"
  | null;

export interface D2AState {
  schema_version: number;
  phase: number | null;
  status: "idle" | "running" | "blocked" | "waiting" | "complete";
  current_task: string | null;
  integration_ready: boolean;
  /** 넥슨 GNB 사용 프로젝트 여부. boilerplate-setup Stage 1.5에서 true로 설정된다. */
  gnb_required: boolean;
  /** 인증 프로필. boilerplate-setup Stage 1.6-A의 AskUserQuestion 결과. */
  auth_profile: AuthProfile;
  /** save-auth-state.sh 완료 → tests/e2e/.auth/user.json 저장됨. */
  auth_storage_ready: boolean;
  /** Step 2.7에서 사용자가 A(승인)을 입력했는지. */
  step27_user_approved: boolean;
  last_commit: string | null;
  last_updated: string | null;
  blockers: Blocker[];
  completed_tasks: string[];
}

export const DEFAULT_STATE: D2AState = {
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
export function migrateState(raw: Partial<D2AState>): D2AState {
  const version = raw.schema_version ?? 0;
  const migrated: D2AState = { ...DEFAULT_STATE, ...raw };

  // v0 → v1: schema_version 필드 없음 → 추가
  if (version < 1) {
    migrated.schema_version = STATE_SCHEMA_VERSION;
  }

  // v1 → v2: gnb_required 필드 없음 → false로 초기화
  if (version < 2) {
    migrated.gnb_required = (raw as Record<string, unknown>).gnb_required === true ? true : false;
    migrated.schema_version = STATE_SCHEMA_VERSION;
  }

  // v2 → v3: auth_profile / auth_storage_ready / step27_user_approved 필드 도입
  if (version < 3) {
    const rec = raw as Record<string, unknown>;
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
