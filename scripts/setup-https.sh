#!/bin/bash
# 로컬 HTTPS + Caddy 게이트키퍼 셋업 스크립트
#
# 사용법:
#   ./scripts/setup-https.sh <도메인> [인증서_디렉토리] [dev_포트]
#
# 예시 (인증 프로필별 권장 도메인 — 모두 'local-' 프리픽스):
#   ./scripts/setup-https.sh local-myproject.nexon.com frontend    # INSIGN/혼합 (정책 강제)
#   ./scripts/setup-https.sh local-myproject.nxgd.io frontend      # NXAS 단독 / 자체 인증
#   ./scripts/setup-https.sh local-myproject.test frontend         # 인증 없음 (RFC 6761)
#   ./scripts/setup-https.sh local-myproject.nxgd.io frontend 8010 # 포트 명시
#
# 환경변수:
#   CADDY_MODE=direct  brew services 를 건너뛰고 'caddy start --config' 로만 데몬 실행
#                      (회사 보안 정책 등으로 launchctl 사용이 차단된 환경)
#
# 동작:
#   1. mkcert + Caddy 설치 확인 (없으면 brew/apt-get 으로 자동 설치)
#   2. mkcert 로컬 CA 등록 (시스템 키체인)
#   3. 도메인 인증서 발급 (frontend/{도메인}.pem)
#   4. /etc/hosts 등록 (sudo 필요 — 자동 추가 옵션 제공)
#   5. dev 포트 자동 할당 (8010 부터 충돌 없는 포트 선택)
#   6. Caddy 사이트 등록 (https://{도메인}:443 → http://localhost:{dev_포트})
#   7. .env.example 에 LOCAL_DEV_HOST / LOCAL_DEV_PORT 자동 갱신
#
# 결과:
#   브라우저: https://{도메인} (포트 명시 없음 = 443) 으로 접속
#   여러 프로젝트가 다른 도메인 + 다른 dev 포트로 충돌 없이 동시 실행 가능
#
# 왜 Caddy 게이트키퍼인가:
#   - 단일 데몬이 443 점유, SNI 분기로 N개 프로젝트 동시 운영
#   - dev 서버는 평문 HTTP 고포트 → 매번 sudo 회피
#   - 프레임워크 무관 (Next.js / Vite / CRA / 기타)
#
# 데몬 시작 전략 (다중 fallback):
#   1순위: brew services start caddy   (user-level — Homebrew 최신 권장)
#   2순위: caddy start --config <file> (launchctl 우회, 직접 실행)
#   사전 정리: 좀비 system plist + root 변질된 caddy 경로 자동 감지
#
# 주의:
#   'sudo brew services start caddy' 는 사용하지 않습니다.
#   - Homebrew caddy formula 가 non-root 실행을 강제
#   - sudo 사용 시 caddy 바이너리 경로가 root 소유로 변질되는 부작용

set -e

DOMAIN="${1:-}"
CERT_DIR="${2:-frontend}"
DEV_PORT="${3:-}"

# ── 인수 검증 ──────────────────────────────────────────────────
if [[ -z "$DOMAIN" ]]; then
  cat <<EOF
사용법: $0 <도메인> [인증서_디렉토리] [dev_포트]

예시 (인증 프로필별 권장):
  $0 local-myproject.nexon.com frontend    # INSIGN / INSIGN+NXAS
  $0 local-myproject.nxgd.io frontend      # NXAS 단독 / 자체 인증
  $0 local-myproject.test frontend         # 인증 없음
  $0 local-myproject.nxgd.io frontend 8010 # 포트 명시

옵션:
  도메인          : 로컬 개발 호스트명 (모두 'local-' 프리픽스)
                    - .nexon.com  : INSIGN _ifwt 쿠키 정책 (refs/policies/authentication-external.md)
                    - .nxgd.io    : NXAS 개발 권장 (refs/policies/authentication-nxas.md)
                    - .test       : RFC 6761 예약 TLD (인증 없는 프로젝트)
  인증서_디렉토리 : .pem 출력 위치 (기본: frontend)
  dev_포트        : 프론트 dev 서버가 listen 할 포트 (기본: 자동 할당, 8010~8099)
EOF
  exit 1
fi

# 화이트리스트 검증 — 셸 메타문자·path traversal·개행 차단
if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]{0,253}[a-zA-Z0-9])?$ ]]; then
  echo "ERROR: 도메인 형식이 올바르지 않습니다 — 영숫자·점·하이픈만 허용: '$DOMAIN'"
  exit 1
fi
if [[ "$CERT_DIR" =~ \.\. || "$CERT_DIR" =~ ^/ ]]; then
  echo "ERROR: 인증서 디렉토리는 상대 경로여야 하며 '..' 를 포함할 수 없습니다: '$CERT_DIR'"
  exit 1
fi
if ! [[ "$CERT_DIR" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
  echo "ERROR: 인증서 디렉토리에 특수문자 사용 불가: '$CERT_DIR'"
  exit 1
fi
if [[ -n "$DEV_PORT" ]] && ! [[ "$DEV_PORT" =~ ^[0-9]+$ && "$DEV_PORT" -ge 1024 && "$DEV_PORT" -le 65535 ]]; then
  echo "ERROR: dev 포트는 1024~65535 정수여야 합니다: '$DEV_PORT'"
  exit 1
fi

# 절대 경로 변환 (스크립트 위치 기준 상위 → 프로젝트 루트)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERT_OUT="$PROJECT_ROOT/$CERT_DIR"

# ── OS 환경 감지 + 비macOS 안내 ───────────────────────────────
case "$OSTYPE" in
  darwin*) OS_KIND="macos" ;;
  linux*)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      OS_KIND="wsl"
    else
      OS_KIND="linux"
    fi
    ;;
  *) OS_KIND="other" ;;
esac

if [[ "$OS_KIND" != "macos" ]]; then
  cat <<EOF
⚠️  이 스크립트는 macOS 에 최적화되어 있습니다.
    감지된 환경: $OS_KIND ($OSTYPE)

지원 상태:
  Linux     : △ mkcert 자동 설치, Caddy 는 수동 설치 후 재실행 필요
  WSL       : △ Caddy 가 Windows 의 443 과 충돌할 수 있음 — Windows 호스트의 IIS/Skype 등 점검
  Windows   : ❌ bash 미지원 — WSL 에서 실행하거나 mkcert·Caddy 수동 셋업

진행 시 다음 단계는 수동으로 처리해야 할 수 있습니다:
  1) Caddy 설치 — https://caddyserver.com/docs/install
  2) Caddy 데몬 시작 — systemd / nssm 등 OS 별 방식
  3) /etc/hosts 권한 확인

계속 진행하려면 Enter, 중단하려면 Ctrl+C ...
EOF
  read -r _ || true
fi

# ── Caddyfile 위치 자동 감지 ──────────────────────────────────
# brew --prefix 우선, 폴백으로 후보 디렉터리 검사
detect_caddyfile() {
  if command -v brew &>/dev/null; then
    local brew_prefix
    brew_prefix=$(brew --prefix caddy 2>/dev/null || true)
    if [[ -n "$brew_prefix" ]]; then
      # brew Caddy 의 etc 위치는 brew --prefix (formula prefix 가 아닌 cellar 가 반환될 수도 있음)
      local etc_path
      etc_path="$(brew --prefix 2>/dev/null)/etc/Caddyfile"
      if [[ -f "$etc_path" || -d "$(dirname "$etc_path")" ]]; then
        echo "$etc_path"
        return
      fi
    fi
  fi
  for p in /opt/homebrew/etc/Caddyfile /usr/local/etc/Caddyfile /etc/caddy/Caddyfile; do
    if [[ -f "$p" || -d "$(dirname "$p")" ]]; then
      echo "$p"
      return
    fi
  done
}

CADDYFILE=""
CADDY_SITES_DIR=""

echo "=== 로컬 HTTPS + Caddy 게이트키퍼 셋업 ==="
echo "  도메인     : $DOMAIN"
echo "  인증서     : $CERT_OUT"
echo ""

# ── 1. mkcert 설치 확인 ────────────────────────────────────────
if ! command -v mkcert &>/dev/null; then
  echo "[1/7] mkcert 설치..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install mkcert
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y libnss3-tools
    curl -fsSL https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64 \
      -o /usr/local/bin/mkcert && sudo chmod +x /usr/local/bin/mkcert
  else
    echo "ERROR: mkcert 수동 설치 필요 — https://github.com/FiloSottile/mkcert"
    exit 1
  fi
else
  echo "[1/7] mkcert 확인됨"
fi

# ── 2. Caddy 설치 ──────────────────────────────────────────────
if ! command -v caddy &>/dev/null; then
  echo "[2/7] Caddy 설치..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install caddy
  elif command -v apt-get &>/dev/null; then
    echo "ERROR: Linux 는 Caddy 공식 가이드 참조 — https://caddyserver.com/docs/install"
    exit 1
  else
    echo "ERROR: Caddy 수동 설치 필요"
    exit 1
  fi
else
  echo "[2/7] Caddy 확인됨"
fi

# Caddyfile 위치 감지 (데몬 시작 전에 필요 — direct 실행 fallback 에서 --config 인자로 사용)
CADDYFILE=$(detect_caddyfile)
if [[ -z "$CADDYFILE" ]]; then
  echo "ERROR: Caddyfile 위치 감지 실패 — Caddy 설치 후 재실행"
  exit 1
fi
CADDY_SITES_DIR="$(dirname "$CADDYFILE")/d2a-sites"
mkdir -p "$CADDY_SITES_DIR"
echo "      Caddyfile  : $CADDYFILE"
echo "      Sites Dir  : $CADDY_SITES_DIR"

# Caddyfile 이 없으면 미리 생성 (direct 실행 시 --config 가 실재 파일을 요구)
if [[ ! -f "$CADDYFILE" ]]; then
  cat > "$CADDYFILE" <<EOF
{
  auto_https off
  local_certs
}

import $CADDY_SITES_DIR/*.caddy
EOF
  echo "      → Caddyfile 신규 생성 (auto_https off + import)"
fi

# Caddy 데몬 시작 — 다중 fallback 전략
#   1순위: brew services start caddy   (user-level, Homebrew 권장)
#   2순위: caddy start --config ...    (launchctl 우회)
# 환경변수 CADDY_MODE=direct → 1순위 건너뛰고 2순위만 사용 (회사 보안 환경 대응)
# sudo -n 으로 비대화형 환경에서 무한 대기 방지
if [[ "$OSTYPE" == "darwin"* ]]; then
  PORT_443_OWNER=$(sudo -n lsof -nP -iTCP:443 -sTCP:LISTEN 2>/dev/null \
    | awk 'NR>1 {print $1}' | sort -u | head -3 | tr '\n' ',' | sed 's/,$//' || true)

  CADDY_OWNS_443=false
  if [[ -n "$PORT_443_OWNER" ]] && echo "$PORT_443_OWNER" | grep -qi caddy; then
    CADDY_OWNS_443=true
  fi

  if [[ "$CADDY_OWNS_443" == "true" ]]; then
    echo "      Caddy 가 이미 443 을 점유 중 (재사용)"
  elif [[ -n "$PORT_443_OWNER" ]]; then
    cat <<EOF >&2

ERROR: 443 포트가 다른 프로세스에 의해 점유 중입니다.
  점유 프로세스: $PORT_443_OWNER

조치 방법:
  ① 점유 프로세스 종료:
       sudo lsof -nP -iTCP:443 -sTCP:LISTEN
       sudo kill <PID>
  ② 또는 점유 프로세스가 다른 dev 도구(nginx·orbstack 등)이면 그쪽을 먼저 멈추기

해결 후 이 스크립트를 다시 실행하세요.
EOF
    exit 1
  else
    # ── 사전 정리 ① 좀비 system plist (sudo brew services 잔재) ──
    # Bootstrap failed: 5 에러의 주범 — system domain 에 plist 가 등록되어 있으나 활성화 실패 상태
    if [[ -f /Library/LaunchDaemons/homebrew.mxcl.caddy.plist ]]; then
      if ! sudo -n launchctl print system/homebrew.mxcl.caddy &>/dev/null; then
        echo "      ⚠️  이전 caddy system plist 좀비 감지 — 정리 시도 (sudo 필요)"
        sudo launchctl bootout system/homebrew.mxcl.caddy 2>/dev/null || true
        sudo rm -f /Library/LaunchDaemons/homebrew.mxcl.caddy.plist 2>/dev/null || true
        echo "      → 좀비 plist 정리 완료"
      fi
    fi

    # ── 사전 정리 ② caddy 경로 root 소유 변질 감지 ──
    # 이전에 sudo brew services 를 실행하면 Homebrew 가 caddy 경로 소유권을 root 로 변경하는 부작용
    # 이 상태로는 brew upgrade/uninstall 이 실패하고 user-level 시작도 망가짐
    BREW_CADDY_PREFIX=$(brew --prefix caddy 2>/dev/null || true)
    if [[ -n "$BREW_CADDY_PREFIX" && -d "$BREW_CADDY_PREFIX" ]]; then
      OWNER=$(stat -f '%Su' "$BREW_CADDY_PREFIX" 2>/dev/null || true)
      if [[ "$OWNER" == "root" ]]; then
        cat <<MSG >&2

ERROR: Caddy 설치 경로가 root 소유로 변질되었습니다 (이전 'sudo brew services' 부작용)
  $BREW_CADDY_PREFIX (owner: $OWNER)

복구 명령:
  sudo chown -R "\$(whoami):admin" \\
    /opt/homebrew/Cellar/caddy \\
    /opt/homebrew/opt/caddy \\
    /opt/homebrew/var/homebrew/linked/caddy

복구 후 이 스크립트를 다시 실행하세요.
MSG
        exit 1
      fi
    fi

    # ── Caddy 시작 fallback 체인 ──
    started=false
    start_log=""

    if [[ "${CADDY_MODE:-}" != "direct" ]]; then
      echo "      Caddy 시작 시도 [1/2]: brew services start (user-level, sudo 없음)"
      if start_log=$(brew services start caddy 2>&1); then
        sleep 2
        if pgrep -x caddy &>/dev/null \
           || lsof -nP -iTCP:443 -sTCP:LISTEN 2>/dev/null | grep -qi caddy; then
          started=true
          echo "      → 성공 (brew services)"
        else
          echo "      → brew services 명령은 통과했으나 caddy 프로세스 미감지"
        fi
      else
        echo "      → 실패: $(echo "$start_log" | head -2)"
      fi
    else
      echo "      CADDY_MODE=direct — brew services 건너뛰고 직접 실행 모드 사용"
    fi

    if [[ "$started" == "false" ]]; then
      echo "      Caddy 시작 시도 [2/2]: caddy start --config (launchctl 우회, 직접 실행)"
      if start_log=$(caddy start --config "$CADDYFILE" --adapter caddyfile 2>&1); then
        sleep 2
        if pgrep -x caddy &>/dev/null; then
          started=true
          echo "      → 성공 (caddy start 직접 실행)"
        else
          echo "      → caddy start 명령은 통과했으나 caddy 프로세스 미감지"
        fi
      else
        echo "      → 실패: $(echo "$start_log" | head -2)"
      fi
    fi

    if [[ "$started" == "false" ]]; then
      cat <<MSG >&2

❌ Caddy 데몬 시작 실패 (모든 fallback 소진)

마지막 에러:
$start_log

가능한 원인 + 복구 절차:

① 좀비 system plist (Bootstrap failed: 5 에러 시):
   sudo launchctl bootout system/homebrew.mxcl.caddy 2>/dev/null
   sudo rm -f /Library/LaunchDaemons/homebrew.mxcl.caddy.plist

② root 소유 경로 복구 (이전에 'sudo brew services' 사용 흔적이 있는 경우):
   sudo chown -R "\$(whoami):admin" \\
     /opt/homebrew/Cellar/caddy \\
     /opt/homebrew/opt/caddy \\
     /opt/homebrew/var/homebrew/linked/caddy

③ 위 조치 후 다음 명령으로 직접 실행 가능 여부 확인:
   caddy start --config $CADDYFILE
   pgrep -x caddy   # PID 가 표시되면 성공

④ 회사 보안 정책 등으로 launchctl 자체가 차단된 경우:
   CADDY_MODE=direct $0 $DOMAIN $CERT_DIR ${DEV_PORT:-}

MSG
      exit 1
    fi
  fi
fi

# ── 3. 로컬 CA 등록 ────────────────────────────────────────────
# JAVA_HOME 공백: Java keystore 등록 시도 건너뜀 (Java 환경에서 keytool 오류 방지)
echo "[3/7] mkcert 로컬 CA 등록..."
JAVA_HOME="" JAVA_TOOL_OPTIONS="" mkcert -install

# ── 4. 도메인 인증서 발급 ──────────────────────────────────────
echo "[4/7] 도메인 인증서 발급: $DOMAIN"
mkdir -p "$CERT_OUT"
( cd "$CERT_OUT" && JAVA_HOME="" JAVA_TOOL_OPTIONS="" mkcert "$DOMAIN" )

KEY_FILE="$CERT_OUT/$DOMAIN-key.pem"
CERT_FILE="$CERT_OUT/$DOMAIN.pem"
[[ -f "$CERT_FILE" && -f "$KEY_FILE" ]] || {
  echo "ERROR: 인증서 생성 실패"; exit 1;
}
# Caddy 데몬(root 실행)이 키 파일을 읽을 수 있도록 권한 명시
# macOS 에서는 root 가 사용자 파일 자유 접근 가능, 다만 일부 Linux 마운트 옵션에서 차단될 수 있음
chmod 0644 "$CERT_FILE"
chmod 0640 "$KEY_FILE"
echo "      → $CERT_FILE  (mode 0644)"
echo "      → $KEY_FILE  (mode 0640 — Caddy 가 root 로 읽음)"

# ── 5. /etc/hosts 등록 ─────────────────────────────────────────
# IP 앵커 + 도메인 이스케이프 + 주석 라인 제외 매칭
echo "[5/7] /etc/hosts 확인..."
DOMAIN_ESCAPED=$(printf '%s' "$DOMAIN" | sed 's/[][\\.^$*/]/\\&/g')
if grep -qE "^[[:space:]]*127\.0\.0\.1[[:space:]]+([^#]*[[:space:]])?${DOMAIN_ESCAPED}([[:space:]]|\$)" /etc/hosts; then
  echo "      → 이미 등록됨: $DOMAIN"
else
  echo ""
  echo "      ⚠️  /etc/hosts 에 다음 줄을 추가합니다 (sudo 필요):"
  echo "         127.0.0.1  $DOMAIN"
  read -r -p "      자동 추가? [Y/n] " ans
  ans="${ans:-Y}"
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    echo "127.0.0.1  $DOMAIN" | sudo tee -a /etc/hosts >/dev/null
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sudo dscacheutil -flushcache 2>/dev/null || true
      sudo killall -HUP mDNSResponder 2>/dev/null || true
    fi
    echo "      → 추가 완료"
  else
    echo "      → 수동 추가 필요:"
    echo "        sudo sh -c 'echo \"127.0.0.1  $DOMAIN\" >> /etc/hosts'"
  fi
fi

# ── 6. dev_포트 자동 할당 ──────────────────────────────────────
echo "[6/7] dev 포트 결정..."
mkdir -p "$CADDY_SITES_DIR"

if [[ -z "$DEV_PORT" ]]; then
  for p in $(seq 8010 8099); do
    in_caddy=$(grep -rh "reverse_proxy localhost:$p\b" "$CADDY_SITES_DIR" 2>/dev/null | head -1 || true)
    in_listen=$(lsof -nP -iTCP:$p -sTCP:LISTEN 2>/dev/null | tail -n +2 | head -1 || true)
    if [[ -z "$in_caddy" && -z "$in_listen" ]]; then
      DEV_PORT=$p
      break
    fi
  done
  [[ -n "$DEV_PORT" ]] || { echo "ERROR: 8010-8099 사용 가능한 포트 없음"; exit 1; }
  echo "      자동 할당: $DEV_PORT"
else
  echo "      명시: $DEV_PORT"
fi

# ── 7. Caddy 사이트 등록 + reload ──────────────────────────────
echo "[7/7] Caddy 사이트 등록..."
SITE_FILE="$CADDY_SITES_DIR/$DOMAIN.caddy"

cat > "$SITE_FILE" <<EOF
$DOMAIN:443 {
  tls $CERT_FILE $KEY_FILE
  reverse_proxy localhost:$DEV_PORT
}
EOF
echo "      → $SITE_FILE"

# 메인 Caddyfile 에 import 라인이 없으면 추가
IMPORT_LINE="import $CADDY_SITES_DIR/*.caddy"
if [[ ! -f "$CADDYFILE" ]]; then
  cat > "$CADDYFILE" <<EOF
{
  auto_https off
  local_certs
}

$IMPORT_LINE
EOF
  echo "      → Caddyfile 신규 생성 + import 추가"
elif ! grep -qF "$IMPORT_LINE" "$CADDYFILE"; then
  printf '\n%s\n' "$IMPORT_LINE" >> "$CADDYFILE"
  echo "      → Caddyfile 에 import 라인 추가"
fi

# Caddy 설정 검증 + reload
# caddy 데몬은 brew services / caddy start 어느 쪽으로 떠 있어도 admin API (localhost:2019) 로 reload 가능
# → 'caddy reload' 1순위, 그 다음 brew services 폴백, 모두 실패하면 안내
if caddy validate --config "$CADDYFILE" --adapter caddyfile 2>/dev/null; then
  if caddy reload --config "$CADDYFILE" --adapter caddyfile 2>/dev/null; then
    echo "      → Caddy 설정 reload 완료 (admin API)"
  elif [[ "$OSTYPE" == "darwin"* ]] && brew services reload caddy 2>/dev/null; then
    echo "      → Caddy 설정 reload 완료 (brew services)"
  elif [[ "$OSTYPE" == "darwin"* ]] && brew services restart caddy 2>/dev/null; then
    echo "      → Caddy 재시작 완료 (brew services restart)"
  else
    echo "      ⚠️  reload 실패 — 수동 재시작: caddy stop && caddy start --config $CADDYFILE"
  fi
else
  echo "      ⚠️  Caddyfile 검증 실패 — 수동 점검 필요: caddy validate --config $CADDYFILE"
fi

# ── .env.example 자동 갱신 ─────────────────────────────────────
ENV_EXAMPLE=""
for candidate in "$CERT_OUT/.env.example" "$PROJECT_ROOT/.env.example"; do
  if [[ -f "$candidate" ]]; then
    ENV_EXAMPLE="$candidate"
    break
  fi
done

if [[ -n "$ENV_EXAMPLE" ]] && ! grep -qE '^LOCAL_DEV_HOST=' "$ENV_EXAMPLE"; then
  # 백엔드 포트는 dev 포트 + 10000 (8010 → 18010, 8011 → 18011 ...)
  # 충돌 회피: 백엔드는 보통 8000~8999, 프론트는 8010~ 이므로 18000+ 사용
  BE_PORT=$((DEV_PORT + 10000))
  {
    echo ""
    echo "# 로컬 HTTPS 셋업 (setup-https.sh 가 자동 추가)"
    echo "LOCAL_DEV_HOST=$DOMAIN"
    echo "LOCAL_DEV_PORT=$DEV_PORT"
    echo "LOCAL_BACKEND_PORT=$BE_PORT"
  } >> "$ENV_EXAMPLE"
  echo "      → $ENV_EXAMPLE 갱신: LOCAL_DEV_HOST=$DOMAIN, LOCAL_DEV_PORT=$DEV_PORT, LOCAL_BACKEND_PORT=$BE_PORT"
elif [[ -n "$ENV_EXAMPLE" ]] && ! grep -qE '^LOCAL_BACKEND_PORT=' "$ENV_EXAMPLE"; then
  # LOCAL_DEV_HOST 는 있으나 LOCAL_BACKEND_PORT 가 누락된 경우만 추가
  BE_PORT=$((DEV_PORT + 10000))
  printf '\nLOCAL_BACKEND_PORT=%s\n' "$BE_PORT" >> "$ENV_EXAMPLE"
  echo "      → $ENV_EXAMPLE 에 LOCAL_BACKEND_PORT=$BE_PORT 추가"
fi

# ── 결과 안내 ───────────────────────────────────────────────────
cat <<EOF

=== 셋업 완료 ===

  접속 URL:    https://$DOMAIN          (포트 명시 없음 = 443)
  dev 서버:    http://localhost:$DEV_PORT  (평문 HTTP — Caddy 가 TLS 종단)
  Caddy 사이트: $SITE_FILE

  프론트 dev 명령 (프레임워크별):
    Next.js : next dev -p $DEV_PORT
    Vite    : vite --port $DEV_PORT
    CRA     : PORT=$DEV_PORT npm start

  .gitignore 에 다음을 포함하세요:
    *.pem
    *-key.pem

  여러 프로젝트 동시 실행:
    각 프로젝트가 다른 도메인 + 다른 dev 포트로 setup-https.sh 를 1회 실행하면
    Caddy 가 SNI 분기로 충돌 없이 처리합니다.
    예) https://local-myproject.nxgd.io   → localhost:$DEV_PORT
        https://local-otherproj.nexon.com → localhost:$((DEV_PORT + 1))

EOF
