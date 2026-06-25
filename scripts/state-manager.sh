#!/usr/bin/env bash
# scripts/state-manager.sh
# .claude/state.json CRUD 유틸리티
#
# 사용법:
#   ./scripts/state-manager.sh init                        # 초기화 (없을 때만)
#   ./scripts/state-manager.sh get [field]                 # 전체 또는 특정 필드 읽기
#   ./scripts/state-manager.sh set-phase <N>               # Phase 번호 설정
#   ./scripts/state-manager.sh set-status <status>         # status 변경
#   ./scripts/state-manager.sh set-task <task_id>          # current_task 설정
#   ./scripts/state-manager.sh set-integration-ready       # integration_ready → true
#   ./scripts/state-manager.sh add-blocker <id> <reason>   # 블로커 추가
#   ./scripts/state-manager.sh clear-blockers              # 블로커 전체 삭제
#   ./scripts/state-manager.sh complete-task <task_id>     # 태스크 완료 기록
#   ./scripts/state-manager.sh touch                       # last_updated 갱신만

set -euo pipefail

STATE_FILE=".claude/state.json"
TEMP_FILE=".claude/state.json.tmp"

# python3 필수
if ! command -v python3 &>/dev/null; then
  echo "state-manager: python3 not found, skipping" >&2
  exit 0
fi

# state.json 초기값
INITIAL_STATE='{
  "phase": null,
  "status": "idle",
  "current_task": null,
  "integration_ready": false,
  "last_commit": null,
  "last_updated": null,
  "blockers": [],
  "completed_tasks": []
}'

# state.json이 없거나 비어 있으면 초기화
_ensure_init() {
  mkdir -p .claude
  if [ ! -f "$STATE_FILE" ] || [ ! -s "$STATE_FILE" ]; then
    printf '%s\n' "$INITIAL_STATE" > "$STATE_FILE"
  fi
}

CMD="${1:-}"
ARG2="${2:-}"
ARG3="${3:-}"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")

case "$CMD" in
  init)
    _ensure_init
    echo "[state] 초기화 완료: $STATE_FILE"
    ;;

  get)
    _ensure_init
    if [ -z "$ARG2" ]; then
      cat "$STATE_FILE"
    else
      python3 - "$ARG2" "$STATE_FILE" <<'PYEOF'
import json, sys
field, path = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = json.load(f)
val = d.get(field)
if val is None:
    print('null')
elif isinstance(val, (list, dict)):
    print(json.dumps(val, ensure_ascii=False))
else:
    print(val)
PYEOF
    fi
    ;;

  set-phase)
    _ensure_init
    python3 - "$ARG2" "$NOW" "$STATE_FILE" "$TEMP_FILE" <<'PYEOF'
import json, sys, os
phase_raw, now, path, tmp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path) as f:
    d = json.load(f)
d['phase'] = int(phase_raw) if phase_raw.isdigit() else phase_raw
d['status'] = 'running'
d['last_updated'] = now
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print(f'[state] phase → {phase_raw}')
PYEOF
    ;;

  set-status)
    _ensure_init
    python3 - "$ARG2" "$NOW" "$STATE_FILE" "$TEMP_FILE" <<'PYEOF'
import json, sys, os
status, now, path, tmp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path) as f:
    d = json.load(f)
d['status'] = status
d['last_updated'] = now
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print(f'[state] status → {status}')
PYEOF
    ;;

  set-task)
    _ensure_init
    python3 - "$ARG2" "$NOW" "$STATE_FILE" "$TEMP_FILE" <<'PYEOF'
import json, sys, os
task_id, now, path, tmp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path) as f:
    d = json.load(f)
d['current_task'] = task_id
d['last_updated'] = now
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print(f'[state] current_task → {task_id}')
PYEOF
    ;;

  set-integration-ready)
    _ensure_init
    python3 - "$NOW" "$STATE_FILE" "$TEMP_FILE" <<'PYEOF'
import json, sys, os
now, path, tmp = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    d = json.load(f)
d['integration_ready'] = True
d['last_updated'] = now
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print('[state] integration_ready → true')
PYEOF
    ;;

  add-blocker)
    _ensure_init
    LAST_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
    python3 - "$ARG2" "$ARG3" "$NOW" "$STATE_FILE" "$TEMP_FILE" <<'PYEOF'
import json, sys, os
blocker_id, reason, now, path, tmp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
with open(path) as f:
    d = json.load(f)
blockers = d.setdefault('blockers', [])
if not any(b.get('task') == blocker_id for b in blockers):
    blockers.append({'task': blocker_id, 'reason': reason, 'since': now})
d['status'] = 'blocked'
d['last_updated'] = now
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print(f'[state] blocker 추가: {blocker_id}')
PYEOF
    ;;

  clear-blockers)
    _ensure_init
    python3 - "$NOW" "$STATE_FILE" "$TEMP_FILE" <<'PYEOF'
import json, sys, os
now, path, tmp = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    d = json.load(f)
d['blockers'] = []
d['status'] = 'running'
d['last_updated'] = now
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print('[state] blockers 초기화')
PYEOF
    ;;

  complete-task)
    _ensure_init
    LAST_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
    python3 - "$ARG2" "$LAST_COMMIT" "$NOW" "$STATE_FILE" "$TEMP_FILE" <<'PYEOF'
import json, sys, os
task_id, commit, now, path, tmp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
with open(path) as f:
    d = json.load(f)
completed = d.setdefault('completed_tasks', [])
if task_id and task_id not in completed:
    completed.append(task_id)
if commit:
    d['last_commit'] = commit
d['last_updated'] = now
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print(f'[state] 완료: {task_id}')
PYEOF
    ;;

  touch)
    _ensure_init
    python3 - "$NOW" "$STATE_FILE" "$TEMP_FILE" <<'PYEOF'
import json, sys, os
now, path, tmp = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    d = json.load(f)
d['last_updated'] = now
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
PYEOF
    ;;

  *)
    echo "사용법: $0 {init|get|set-phase|set-status|set-task|set-integration-ready|add-blocker|clear-blockers|complete-task|touch}" >&2
    exit 1
    ;;
esac
