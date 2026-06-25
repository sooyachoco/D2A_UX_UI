#!/bin/bash
# 인증 프로필 변경 자동화 — boilerplate-setup 부록 A 의 6단계 수동 절차를 1회 명령으로 처리.
#
# 사용법:
#   ./scripts/change-auth-profile.sh <새 프로필>
#
# 새 프로필 (5가지):
#   insign            — 외부 유저 (GameScale Web SDK / _ifwt)
#   nxas              — 사내 SSO (NXAS / Bearer)
#   insign-with-nxas  — 외부+사내 모두
#   custom            — 자체 인증 (JWT/세션/NextAuth/Passport/Firebase 등)
#   none              — 인증 없음
#
# 동작 (모두 자동):
#   ① 사용자 확인 (대화형)
#   ② tests/e2e/.auth/user.json 삭제 (storageState)
#   ③ tests/e2e/fixtures/auth-mock.ts 삭제 (Stage 2-E 가 새 모드로 재생성)
#   ④ Caddy 사이트 파일 삭제 + reload
#   ⑤ state.json 정리 (auth_profile / local_dev_host / https_ready / auth_storage_ready 제거)
#   ⑥ .env.example 정리 (LOCAL_DEV_HOST / LOCAL_DEV_PORT / LOCAL_BACKEND_PORT 제거)
#   ⑦ 다음 단계 안내 (boilerplate-setup 재실행)

set -e

NEW_PROFILE="${1:-}"

VALID_PROFILES=(insign nxas insign-with-nxas custom none)

usage() {
  cat <<EOF
사용법: $0 <새 프로필>

새 프로필 (5가지):
  insign            외부 유저 (GameScale Web SDK / _ifwt)
  nxas              사내 SSO (NXAS / Bearer)
  insign-with-nxas  외부+사내 모두
  custom            자체 인증 (JWT/세션/NextAuth/Passport/Firebase 등)
  none              인증 없음

이 스크립트는 기존 인증 셋업(인증서·storageState·fixture·Caddy 사이트·state.json·.env)
을 모두 정리하고, 다음에 boilerplate-setup 재실행 시 새 프로필로 셋업되도록 준비합니다.
EOF
  exit 1
}

if [[ -z "$NEW_PROFILE" ]]; then
  usage
fi

# 화이트리스트 검증
VALID=false
for p in "${VALID_PROFILES[@]}"; do
  [[ "$p" == "$NEW_PROFILE" ]] && VALID=true
done
if [[ "$VALID" != "true" ]]; then
  echo "ERROR: 알 수 없는 프로필: $NEW_PROFILE"
  echo "지원 프로필: ${VALID_PROFILES[*]}"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.claude/state.json"

# 현재 프로필 조회 — 환경변수 전달로 셸 보간 위험 회피 (다른 스크립트와 패턴 통일)
CURRENT_PROFILE=$(STATE_FILE="$STATE_FILE" python3 -c "
import json, os, pathlib
p = pathlib.Path(os.environ['STATE_FILE'])
if p.exists():
    d = json.loads(p.read_text())
    print(d.get('auth_profile', '') or '(미설정)')
else:
    print('(state.json 없음)')
" 2>/dev/null)

CURRENT_HOST=$(STATE_FILE="$STATE_FILE" python3 -c "
import json, os, pathlib
p = pathlib.Path(os.environ['STATE_FILE'])
if p.exists():
    d = json.loads(p.read_text())
    print(d.get('local_dev_host', '') or '(미설정)')
else:
    print('(state.json 없음)')
" 2>/dev/null)

# ── ① 사용자 확인 ────────────────────────────────────────────
cat <<EOF

=== 인증 프로필 변경 ===

  현재 프로필 : $CURRENT_PROFILE
  현재 호스트 : $CURRENT_HOST
  새 프로필   : $NEW_PROFILE

다음 항목이 모두 정리됩니다:
  - tests/e2e/.auth/user.json       (storageState — 재로그인 필요)
  - tests/e2e/fixtures/auth-mock.ts (fixture — Stage 2-E 가 새 모드로 재생성)
  - Caddy 사이트 파일 (현재 호스트 기준)
  - state.json 의 auth_profile / local_dev_host / https_ready / auth_storage_ready
  - .env.example 의 LOCAL_DEV_HOST / LOCAL_DEV_PORT / LOCAL_BACKEND_PORT

⚠️ 진행 중인 Phase 가 있다면 e2e 가 깨질 수 있습니다.
   Phase 경계에서 수행하는 것을 권장합니다.

EOF

read -r -p "계속 진행하시겠습니까? [y/N] " ans
ans="${ans:-N}"
if ! [[ "$ans" =~ ^[Yy]$ ]]; then
  echo "취소됨."
  exit 0
fi

# ── ② storageState 삭제 ────────────────────────────────────
echo ""
echo "[1/5] storageState 삭제..."
STORAGE="$PROJECT_ROOT/tests/e2e/.auth/user.json"
[[ -f "$STORAGE" ]] && rm -f "$STORAGE" && echo "      → 삭제: $STORAGE" || echo "      → 없음 (skip)"

# ── ③ fixture 삭제 ─────────────────────────────────────────
echo "[2/5] auth-mock fixture 삭제..."
FIXTURE="$PROJECT_ROOT/tests/e2e/fixtures/auth-mock.ts"
[[ -f "$FIXTURE" ]] && rm -f "$FIXTURE" && echo "      → 삭제: $FIXTURE" || echo "      → 없음 (skip)"

# ── ④ Caddy 사이트 파일 삭제 + reload ──────────────────────
echo "[3/5] Caddy 사이트 정리..."
if [[ "$CURRENT_HOST" != "(미설정)" ]] && [[ "$CURRENT_HOST" != "(state.json 없음)" ]]; then
  # Caddyfile 위치 자동 감지 (setup-https.sh 와 동일 로직)
  CADDYFILE=""
  for p in /opt/homebrew/etc/Caddyfile /usr/local/etc/Caddyfile /etc/caddy/Caddyfile; do
    if [[ -f "$p" ]]; then
      CADDYFILE="$p"
      break
    fi
  done
  if [[ -n "$CADDYFILE" ]]; then
    SITE_FILE="$(dirname "$CADDYFILE")/d2a-sites/$CURRENT_HOST.caddy"
    # 호스트명 화이트리스트 재검증 — '..' 명시 거부로 path traversal 차단
    if [[ "$CURRENT_HOST" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] \
       && [[ "$CURRENT_HOST" != *".."* ]] \
       && [[ -f "$SITE_FILE" ]]; then
      rm -f "$SITE_FILE"
      echo "      → 삭제: $SITE_FILE"
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo -n brew services reload caddy 2>/dev/null \
          || sudo brew services reload caddy 2>/dev/null \
          || sudo brew services restart caddy 2>/dev/null \
          || echo "      ⚠️  Caddy reload 실패 — 수동: sudo brew services reload caddy"
      fi
    else
      echo "      → 사이트 파일 없음 또는 호스트명 검증 실패 (skip)"
    fi
  else
    echo "      → Caddyfile 미감지 (skip)"
  fi
else
  echo "      → 현재 호스트 미설정 (skip)"
fi

# ── ⑤ state.json 정리 + auth_profile_pending 마커 추가 ─────
echo "[4/5] state.json 정리..."
if [[ -f "$STATE_FILE" ]]; then
  STATE_FILE="$STATE_FILE" NEW_PROFILE="$NEW_PROFILE" python3 -c "
import json, os, pathlib
p = pathlib.Path(os.environ['STATE_FILE'])
d = json.loads(p.read_text())
removed = []
for k in ['auth_profile', 'local_dev_host', 'local_dev_port', 'local_backend_port', 'https_ready', 'auth_storage_ready', 'auth_storage_saved_at']:
    if k in d:
        removed.append(k)
        d.pop(k)
# 다음 boilerplate-setup 재실행을 보장하기 위한 pending 마커
# run-phase Step 0 / session-phase-workflow Part E 가 이 마커를 감지하면
# Phase 진입을 차단하고 boilerplate-setup 으로 회귀시킨다.
d['auth_profile_pending'] = os.environ['NEW_PROFILE']
p.write_text(json.dumps(d, indent=2, ensure_ascii=False))
print(f'      → 제거: {removed}' if removed else '      → 정리할 키 없음')
print(f'      → 마커 추가: auth_profile_pending = {os.environ[\"NEW_PROFILE\"]}')
"
else
  echo "      → state.json 없음 (skip)"
fi

# ── ⑥ .env.example 정리 ────────────────────────────────────
echo "[5/5] .env.example 정리..."
for ENV_FILE in "$PROJECT_ROOT/frontend/.env.example" "$PROJECT_ROOT/.env.example"; do
  if [[ -f "$ENV_FILE" ]]; then
    ENV_FILE="$ENV_FILE" python3 -c "
import re, os, pathlib
p = pathlib.Path(os.environ['ENV_FILE'])
text = p.read_text()
removed = []
for var in ['LOCAL_DEV_HOST', 'LOCAL_DEV_PORT', 'LOCAL_BACKEND_PORT']:
    pattern = rf'^{var}=.*\n?'
    if re.search(pattern, text, re.MULTILINE):
        text = re.sub(pattern, '', text, flags=re.MULTILINE)
        removed.append(var)
p.write_text(text)
print(f'      → {os.environ[\"ENV_FILE\"]}: 제거 {removed}' if removed else f'      → {os.environ[\"ENV_FILE\"]}: 정리할 항목 없음')
"
  fi
done

# ── ⑦ 다음 단계 안내 ───────────────────────────────────────
cat <<EOF

=== 정리 완료 ===

다음 단계:
  1) 'boilerplate-setup 실행해줘' 를 다시 입력하면 Stage 1.6-A 에서
     새 프로필 ($NEW_PROFILE) 로 시작합니다.
  2) 사용자가 Stage 1.6-A 의 AskUserQuestion 에서 '$NEW_PROFILE' 를 선택하세요.

선택지 매핑 (참고):
  insign            → "A) 외부 유저 (GameScale)"
  nxas              → "B) 사내 SSO (NXAS)"
  insign-with-nxas  → "C) 외부+사내"
  custom            → "D) 자체 인증"
  none              → "E) 인증 없음"

EOF
