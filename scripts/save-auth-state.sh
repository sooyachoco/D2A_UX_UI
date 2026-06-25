#!/bin/bash
# 로그인 연동 1회 수동 검증 + Playwright storageState 저장
#
# 사용법:
#   ./scripts/save-auth-state.sh <접속 URL>
#
# 예시:
#   ./scripts/save-auth-state.sh https://local-myproject.nxgd.io     # NXAS
#   ./scripts/save-auth-state.sh https://local-myproject.nexon.com   # INSIGN
#
# 동작:
#   1. dev 서버가 떠 있는지 확인 (Caddy 게이트키퍼 → 프론트 dev 서버)
#   2. Playwright 헤드풀 Chromium 실행 (--save-storage 옵션)
#   3. 사용자가 직접 로그인 (INSIGN GNB 또는 NXAS SSO)
#   4. 브라우저 창을 닫으면 tests/e2e/.auth/user.json 에 storageState 저장
#   5. 인증 쿠키(_ifwt 또는 NXAS_TOKEN) 존재 검증
#
# 결과:
#   tests/e2e/.auth/user.json 이 생성되고, 이후 e2e 테스트가 이 파일을
#   storageState 로 사용하여 매번 로그인하지 않고 인증된 상태로 시작한다.
#
# 만료:
#   정책(refs/policies/authentication-external.md A-4b): INSIGN/GNB 세션 만료는 서버 측 관리.
#   storageState 만료 검증은 파일 mtime 이 아니라 인증 쿠키의 `expires` 가 단일 신뢰원이다.
#   mtime 30일은 보조 안전망. 다음 상황에서 이 스크립트를 재실행:
#     - 인증 쿠키가 세션 쿠키 (expires 없음/-1) → 다음 브라우저 실행에서 무효
#     - 인증 쿠키 expires 가 지남 → 서버 기준 만료
#     - 파일 30일 경과 → 안전망 만료

set -e

URL="${1:-}"

if [[ -z "$URL" ]]; then
  cat <<EOF
사용법: $0 <접속 URL>

예시:
  $0 https://local-myproject.nxgd.io     # NXAS / 자체 인증
  $0 https://local-myproject.nexon.com   # INSIGN / INSIGN+NXAS
EOF
  exit 1
fi

# URL 화이트리스트 검증 (셸 인젝션 차단)
if ! [[ "$URL" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then
  echo "ERROR: URL 형식이 올바르지 않습니다: '$URL'"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTH_DIR="$PROJECT_ROOT/tests/e2e/.auth"
STORAGE_FILE="$AUTH_DIR/user.json"

mkdir -p "$AUTH_DIR"

# ── 1. .gitignore 자동 처리 (디렉터리 단위 강제 보호) ──────────
# 1-A. tests/e2e/.auth/.gitignore — 무조건 생성하여 인증 정보 절대 보호
#      (루트 .gitignore 가 누락/삭제되어도 이 파일이 살아있으면 user.json 차단)
AUTH_GITIGNORE="$AUTH_DIR/.gitignore"
if [[ ! -f "$AUTH_GITIGNORE" ]]; then
  cat > "$AUTH_GITIGNORE" <<'AUTH_GI_EOF'
# Playwright auth storageState — 개인 인증 정보 (_ifwt / NXAS Bearer / JWT 등)
# 이 디렉터리 안의 모든 파일은 절대 커밋되지 않는다.
*
!.gitignore
AUTH_GI_EOF
  echo "[1/4] tests/e2e/.auth/.gitignore 자동 생성 — 인증 정보 디렉터리 단위 보호"
else
  echo "[1/4] tests/e2e/.auth/.gitignore 이미 존재"
fi

# 1-B. 루트 .gitignore 에도 백업 패턴 추가 (이중 보호)
GITIGNORE="$PROJECT_ROOT/.gitignore"
GIT_PATTERN="tests/e2e/.auth/"
if [[ -f "$GITIGNORE" ]] && ! grep -qF "$GIT_PATTERN" "$GITIGNORE"; then
  printf '\n# Playwright auth storageState (개인 인증 정보 — 절대 커밋 금지)\n%s\n' "$GIT_PATTERN" >> "$GITIGNORE"
  echo "       루트 .gitignore 에도 패턴 추가됨"
fi

# ── 2. Playwright 사용 가능 확인 ──────────────────────────────
echo "[2/4] Playwright 확인..."
# 루트 / frontend / backend 순으로 .bin/playwright 직접 경로 탐색
# npx --no-install 은 PATH 를 무시하고 자체 검색하므로,
# @playwright/test 가 frontend/ 에만 설치된 모노레포 구조에서 detection 실패.
# 절대 경로 캡처 후 직접 호출하도록 변경.
PLAYWRIGHT_BIN=""
for d in "$PROJECT_ROOT/frontend" "$PROJECT_ROOT/backend" "$PROJECT_ROOT"; do
  if [ -x "$d/node_modules/.bin/playwright" ]; then
    PLAYWRIGHT_BIN="$d/node_modules/.bin/playwright"
    break
  fi
done
if [ -z "$PLAYWRIGHT_BIN" ] || ! "$PLAYWRIGHT_BIN" --version &>/dev/null; then
  echo "ERROR: Playwright 가 설치되지 않았습니다."
  echo "  → frontend/ 또는 루트에 @playwright/test 가 설치되어야 합니다"
  echo "  → boilerplate-setup Stage 2-E 또는 'pnpm add -D @playwright/test' 실행"
  exit 1
fi
echo "       → $PLAYWRIGHT_BIN"

# ── 3. 단계별 사전 조건 진단 ──────────────────────────────────
# URL 에서 호스트명 추출 (셸 메타문자 제거 보장)
HOST=$(printf '%s' "$URL" | sed -E 's|^https?://([^/:]+).*|\1|')

echo "[3/4] 사전 조건 진단..."

# 3-1. mkcert 인증서 존재
CERT_PATH=""
for d in "$PROJECT_ROOT/frontend" "$PROJECT_ROOT"; do
  if [[ -f "$d/$HOST.pem" && -f "$d/$HOST-key.pem" ]]; then
    CERT_PATH="$d/$HOST.pem"
    break
  fi
done
if [[ -z "$CERT_PATH" ]]; then
  cat <<EOF >&2

ERROR [3-1] mkcert 인증서가 없습니다: $HOST.pem
  조치:
    ./scripts/setup-https.sh $HOST frontend
EOF
  exit 1
fi
echo "      ✅ [3-1] 인증서 존재: $CERT_PATH"

# 3-2. /etc/hosts 등록
HOST_ESCAPED=$(printf '%s' "$HOST" | sed 's/[][\\.^$*/]/\\&/g')
if ! grep -qE "^[[:space:]]*127\.0\.0\.1[[:space:]]+([^#]*[[:space:]])?${HOST_ESCAPED}([[:space:]]|\$)" /etc/hosts; then
  cat <<EOF >&2

ERROR [3-2] /etc/hosts 에 $HOST 가 등록되지 않았습니다.
  조치:
    sudo sh -c 'echo "127.0.0.1  $HOST" >> /etc/hosts'
    sudo dscacheutil -flushcache    # macOS DNS 캐시 초기화
  또는 setup-https.sh 재실행 (자동 추가)
EOF
  exit 1
fi
echo "      ✅ [3-2] /etc/hosts 등록됨"

# 3-3. 게이트키퍼(Caddy 등) 동작 검사 — OS 무관 폴백 체인
# 기동 방식(brew services user-level / system-level / caddy start 직접 / systemd) 무관하게
# 두 가지 사실만 확인한다: ① 443 LISTEN ② URL 도달 가능
# (sudo 필요 없음 — 비특권 lsof 가 보이는 만큼 + curl 도달성으로 충분)
PORT_443_LISTENING=""
if command -v lsof &>/dev/null; then
  PORT_443_LISTENING=$(lsof -nP -iTCP:443 -sTCP:LISTEN 2>/dev/null \
    | awk 'NR>1 {print $1}' | sort -u | head -3 | tr '\n' ',' | sed 's/,$//' || true)
  # 비특권으로 못 보면 sudo -n 으로 한 번 더 시도 (NOPASSWD 환경에서만 동작)
  if [[ -z "$PORT_443_LISTENING" ]]; then
    PORT_443_LISTENING=$(sudo -n lsof -nP -iTCP:443 -sTCP:LISTEN 2>/dev/null \
      | awk 'NR>1 {print $1}' | sort -u | head -3 | tr '\n' ',' | sed 's/,$//' || true)
  fi
fi

URL_HTTP_CODE=$(curl -ks -o /dev/null -w '%{http_code}' --max-time 3 "$URL" 2>/dev/null || echo "000")

if [[ -z "$PORT_443_LISTENING" && "$URL_HTTP_CODE" == "000" ]]; then
  # 진단 ① brew services error 자동 출력 (Successfully started 거짓 양성 추적)
  BREW_DIAG=""
  if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
    BREW_CADDY_STATE=$(brew services list 2>/dev/null | grep -E '^caddy[[:space:]]' | awk '{print $2}' || true)
    if [[ "$BREW_CADDY_STATE" == "error" ]]; then
      for log in /opt/homebrew/var/log/caddy.log /usr/local/var/log/caddy.log; do
        if [[ -f "$log" ]]; then
          BREW_DIAG=$(printf '\n  brew services 가 error 상태 — %s 최근 10줄:\n' "$log"
                      tail -10 "$log" 2>/dev/null | sed 's/^/    /')
          break
        fi
      done
    fi
  fi

  cat <<EOF >&2

ERROR [3-3] 게이트키퍼(Caddy 등)가 동작하지 않습니다
  - 443 LISTEN: 없음
  - $URL : HTTP $URL_HTTP_CODE$BREW_DIAG

조치 (다음 중 한 가지로 재기동):

  ① 보일러플레이트 자동 셋업 재실행 (권장):
       ./scripts/setup-https.sh $HOST frontend

  ② user-level brew services (Homebrew 권장 방식):
       brew services start caddy

  ③ launchctl 우회 직접 실행 (macOS TCC 함정 회피용):
       caddy start --config /opt/homebrew/etc/Caddyfile

⚠️  macOS TCC 주의 — "Successfully started" 거짓 양성:
  launchd / brew services 로 띄운 caddy 는 ~/Desktop, ~/Documents, ~/Downloads
  영역의 파일 접근이 차단됩니다 (System Integrity / TCC). 인증서가 그 영역에 있다면
  brew services 가 "started" 후 곧바로 error 로 전환됩니다. 해결책:
    - ③번 방식 사용 (Terminal 권한 상속)
    - 또는 setup-https.sh 를 사용자 영역 밖 프로젝트 경로에서 재실행
  진단:  tail -20 /opt/homebrew/var/log/caddy.log

EOF
  exit 1
fi

if [[ -n "$PORT_443_LISTENING" ]]; then
  echo "      ✅ [3-3] 443 LISTEN 확인: $PORT_443_LISTENING (HTTP $URL_HTTP_CODE)"
else
  # lsof 가 없거나 권한 부족이지만 curl 은 통과한 경우
  echo "      ✅ [3-3] URL 도달 가능 (HTTP $URL_HTTP_CODE) — 게이트키퍼 동작 추정"
fi

# 3-4. dev 서버 도달성 (Caddy 경유)
HTTP_CODE=$(curl -ks -o /dev/null -w '%{http_code}' --max-time 5 "$URL" || echo "000")
if [[ "$HTTP_CODE" == "000" ]]; then
  cat <<EOF >&2

ERROR [3-4] $URL 에 도달할 수 없습니다 (HTTP 000 — connection refused).
  원인: 프론트 dev 서버가 미기동
  조치:
    1) 별도 터미널에서: cd frontend && npm run dev
    2) dev 서버가 정상 기동되면 이 스크립트를 다시 실행하세요
EOF
  exit 1
fi

# 502 = Caddy 가 dev 서버에 연결 실패 (Caddy 는 떠 있으나 upstream 미기동)
if [[ "$HTTP_CODE" == "502" || "$HTTP_CODE" == "503" ]]; then
  cat <<EOF >&2

ERROR [3-4] Caddy 가 dev 서버 upstream 에 연결 실패 (HTTP $HTTP_CODE).
  원인: Caddy 는 떠 있으나 dev 서버 (localhost:고포트) 가 미기동
  조치:
    cd frontend && npm run dev
EOF
  exit 1
fi

echo "      ✅ [3-4] dev 서버 도달 가능: HTTP $HTTP_CODE"

# ── 4. Playwright 헤드풀 브라우저 실행 + storageState 저장 ────
cat <<EOF

[4/4] Playwright 브라우저가 곧 열립니다.

브라우저에서 다음을 수행하세요:
  ① 페이지가 정상 로드되는지 확인
  ② 로그인 버튼 클릭 (INSIGN GNB / NXAS 사내 로그인)
  ③ 외부 인증 페이지(signin.nexon.com 또는 nxas.nexon.com)에서 로그인
  ④ 자동으로 $URL 로 복귀했는지 확인
  ⑤ 사용자 프로필이 화면에 표시되는지 확인
  ⑥ 브라우저 창을 닫으면 storageState 가 자동 저장됩니다

EOF

read -r -p "준비되면 Enter 를 눌러 브라우저를 실행하세요... " _

# Playwright open 명령 — 브라우저 종료 시 storageState 저장
# --ignore-https-errors: Playwright 자체 Chromium 이 mkcert root CA 를 자동 신뢰하지
#                        않을 수 있으므로 자체 서명 경고 우회
"$PLAYWRIGHT_BIN" open --save-storage="$STORAGE_FILE" --ignore-https-errors "$URL" || {
  echo "ERROR: Playwright 실행 실패"
  exit 1
}

# ── 검증 ───────────────────────────────────────────────────────
if [[ ! -f "$STORAGE_FILE" ]]; then
  echo ""
  echo "ERROR: storageState 파일이 생성되지 않았습니다 — 로그인 미완료 추정"
  exit 1
fi

# 인증 쿠키 + expires 검증 — 환경변수 전달로 셸 보간 위험 회피
# 정책: INSIGN/GNB 서버 측 세션 만료 → 쿠키 expires 가 단일 신뢰원
AUTH_STATUS=$(STORAGE_FILE="$STORAGE_FILE" node -e '
  const fs = require("fs");
  try {
    const state = JSON.parse(fs.readFileSync(process.env.STORAGE_FILE, "utf8"));
    const cookies = state.cookies || [];
    const authNames = ["_ifwt", "NXAS_TOKEN", "access_token", "authToken", "next-auth.session-token"];
    const auth = cookies.filter(c => c.name && authNames.some(n => c.name.toLowerCase().includes(n.toLowerCase())));
    if (auth.length === 0) { console.log("NO_AUTH_COOKIE"); process.exit(0); }
    const persistent = auth.filter(c => typeof c.expires === "number" && c.expires > 0);
    const names = auth.map(c => c.name).join(",");
    if (persistent.length === 0) { console.log("SESSION_ONLY:" + names); process.exit(0); }
    const now = Math.floor(Date.now() / 1000);
    const maxExp = Math.max(...persistent.map(c => c.expires));
    const days = Math.floor((maxExp - now) / 86400);
    if (days < 0) { console.log("EXPIRED:" + (-days) + ":" + names); process.exit(0); }
    console.log("VALID:" + days + ":" + names);
  } catch (e) { console.log("INVALID"); }
' 2>/dev/null || echo "INVALID")

cat <<EOF

=== 로그인 연동 검증 결과 ===

  storageState : $STORAGE_FILE
  상태         : $AUTH_STATUS

EOF

case "$AUTH_STATUS" in
  VALID:*)
    DAYS="${AUTH_STATUS#VALID:}"; DAYS="${DAYS%%:*}"
    NAMES="${AUTH_STATUS#VALID:*:}"
    echo "✅ 인증 쿠키 발견 ($NAMES) — 만료까지 ${DAYS}일 남음"

    # ── state.json 갱신 (auth_storage_ready=true) ──────────────
    # Phase 1 게이트(check_phase_gate)가 이 플래그를 검사. 누락 시 Step 2.7 미완료로 차단.
    # MCP 서버 부재 환경에서도 동작하도록 직접 갱신 (atomic write).
    # 케이스 배경: docs/case-studies/step27-validation-gap.md 4.7 장치 1.
    if PROJECT_ROOT_FOR_STATE="$PROJECT_ROOT" node -e '
      const fs = require("fs"), path = require("path");
      const root = process.env.PROJECT_ROOT_FOR_STATE;
      const p = path.join(root, ".claude/state.json");
      const dir = path.dirname(p);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      let state = {};
      if (fs.existsSync(p)) {
        try { state = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
      }
      state.auth_storage_ready = true;
      state.auth_storage_saved_at = new Date().toISOString();
      const tmp = p + ".tmp";
      fs.writeFileSync(tmp, JSON.stringify(state, null, 2));
      fs.renameSync(tmp, p);
    ' 2>/dev/null; then
      echo "      ✅ .claude/state.json 갱신: auth_storage_ready=true"
    fi

    # ── 활동 로그 기록 (선택) ─────────────────────────────────
    if [[ -x "$PROJECT_ROOT/scripts/log-activity.sh" ]]; then
      "$PROJECT_ROOT/scripts/log-activity.sh" SETUP "save-auth-state 완료" \
        "storageState 저장됨 ($NAMES, 만료까지 ${DAYS}일) — auth_storage_ready=true 갱신" || true
    fi
    ;;
  SESSION_ONLY:*)
    NAMES="${AUTH_STATUS#SESSION_ONLY:}"
    cat <<EOF
⚠️  인증 쿠키 ($NAMES) 가 모두 세션 쿠키입니다 (expires 부재).
    정책(authentication-external.md A-4b): INSIGN/GNB 서버 측 세션 만료 관리.
    세션 쿠키는 브라우저 종료 시 만료되므로 이 storageState 는 다음 실행에서 무효일 수 있습니다.

확인:
    - 실제 로그인이 완료되었는지 (사용자 프로필이 화면에 표시되었는지)
    - 백엔드 측에서 _ifwt 또는 NXAS_TOKEN 의 Max-Age/Expires 가 설정되어 있는지
EOF
    ;;
  EXPIRED:*)
    DAYS_PAST="${AUTH_STATUS#EXPIRED:}"; DAYS_PAST="${DAYS_PAST%%:*}"
    NAMES="${AUTH_STATUS#EXPIRED:*:}"
    echo "⚠️  방금 저장한 인증 쿠키 ($NAMES) 의 expires 가 이미 ${DAYS_PAST}일 지났습니다 — 시스템 시계 또는 쿠키 만료 시각 점검 필요"
    ;;
  NO_AUTH_COOKIE)
    cat <<EOF
⚠️  인증 쿠키가 발견되지 않았습니다.
    실제 로그인이 완료되지 않았거나, 인증 쿠키 이름이 표준 패턴과 다를 수 있습니다.

다시 시도하려면:
    rm $STORAGE_FILE
    $0 $URL
EOF
    ;;
  *)
    echo "⚠️  storageState 파싱 실패 — rm $STORAGE_FILE 후 재시도"
    ;;
esac

cat <<EOF

이후 e2e 테스트가 이 storageState 를 자동 사용합니다.
다음 상황에서 이 스크립트를 다시 실행하세요:
  - subagent-review / pre-launch-check 가 만료를 보고할 때
  - 인증 쿠키 expires 가 지났을 때 (서버 기준)
  - 파일 30일 경과 시 (보조 안전망)

EOF
