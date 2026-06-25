#!/bin/bash
# state.json 의 일부 키를 .env.example 로 자동 동기화한다.
# state.json 이 source of truth — 사용자가 .env.example 을 수동 변경해도
# 다음 동기화 시 state.json 값으로 덮어쓴다.
#
# 사용법:
#   ./scripts/sync-state-to-env.sh                # state.json -> .env.example 동기화
#   ./scripts/sync-state-to-env.sh --check        # 불일치 검사만 (변경 없음, 종료코드로 신호)
#
# 호출 시점:
#   - subagent-review Step 2-0 (Phase 경계 — 일치성 보장)
#   - run-phase Step 0 (Phase 진입 — 선택적)
#
# 동기화 대상 키:
#   - LOCAL_DEV_HOST
#   - LOCAL_DEV_PORT
#   - LOCAL_BACKEND_PORT

set -e

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.claude/state.json"

# state.json 없으면 noop (셋업 전 단계)
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# 동기화 대상 키 목록 (state.json key -> .env 변수명)
declare -A SYNC_KEYS=(
  [local_dev_host]=LOCAL_DEV_HOST
  [local_dev_port]=LOCAL_DEV_PORT
  [local_backend_port]=LOCAL_BACKEND_PORT
)

# .env.example 후보 — 우선순위 높은 것이 먼저
ENV_CANDIDATES=(
  "$PROJECT_ROOT/frontend/.env.example"
  "$PROJECT_ROOT/.env.example"
)

# 첫 발견된 .env.example 사용 (없으면 noop)
ENV_FILE=""
for c in "${ENV_CANDIDATES[@]}"; do
  if [[ -f "$c" ]]; then
    ENV_FILE="$c"
    break
  fi
done

if [[ -z "$ENV_FILE" ]]; then
  exit 0
fi

# python 으로 동기화 처리 — 안전한 JSON 파싱·정확한 라인 치환
RESULT=$(STATE_FILE="$STATE_FILE" ENV_FILE="$ENV_FILE" CHECK_ONLY="$CHECK_ONLY" python3 - <<'PYEOF'
import json, os, re, sys

state_file = os.environ['STATE_FILE']
env_file = os.environ['ENV_FILE']
check_only = os.environ['CHECK_ONLY'] == 'true'

with open(state_file, 'r', encoding='utf-8') as f:
    state = json.load(f)

# state.json key -> .env 변수명
sync_keys = {
    'local_dev_host': 'LOCAL_DEV_HOST',
    'local_dev_port': 'LOCAL_DEV_PORT',
    'local_backend_port': 'LOCAL_BACKEND_PORT',
}

with open(env_file, 'r', encoding='utf-8') as f:
    env_text = f.read()

mismatches = []
updates = []

for state_key, env_var in sync_keys.items():
    state_val = state.get(state_key)
    if state_val is None or state_val == '':
        continue
    state_val_str = str(state_val)

    # .env 파일에서 현재 값 찾기
    pattern = rf'^{re.escape(env_var)}=(.*)$'
    m = re.search(pattern, env_text, re.MULTILINE)
    current_val = m.group(1).strip().strip('"').strip("'") if m else None

    if current_val == state_val_str:
        continue  # 이미 일치

    mismatches.append((env_var, current_val, state_val_str))

    if not check_only:
        if m:
            # 기존 라인 교체
            env_text = re.sub(pattern, f'{env_var}={state_val_str}', env_text, count=1, flags=re.MULTILINE)
        else:
            # 라인 추가
            if not env_text.endswith('\n'):
                env_text += '\n'
            env_text += f'{env_var}={state_val_str}\n'
        updates.append(env_var)

if not check_only and updates:
    with open(env_file, 'w', encoding='utf-8') as f:
        f.write(env_text)

# 결과 출력 (셸이 파싱)
if mismatches:
    if check_only:
        for env_var, cur, new in mismatches:
            print(f"MISMATCH {env_var} env={cur!r} state={new!r}")
        sys.exit(2)  # 종료 코드로 신호
    else:
        for env_var in updates:
            print(f"UPDATED {env_var}")
        sys.exit(0)
else:
    print("IN_SYNC")
    sys.exit(0)
PYEOF
)

EXIT=$?

if [[ "$CHECK_ONLY" == "true" ]] && [[ $EXIT -eq 2 ]]; then
  echo "[sync-state-to-env] 불일치 발견 (check-only):"
  echo "$RESULT"
  exit 2
fi

if [[ -n "$RESULT" ]] && [[ "$RESULT" != "IN_SYNC" ]]; then
  echo "[sync-state-to-env] 동기화 완료:"
  echo "$RESULT"
fi
exit 0
