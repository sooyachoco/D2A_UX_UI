#!/bin/bash
# Phase 0.6/0.7 전용 HTTPS 프로토타입 서버
#
# 사용 목적:
#   - python3 -m http.server는 HTTP 전용이라 GNB/INSIGN 검증 불가.
#   - _ifwt 쿠키 및 INSIGN 로그인은 .nexon.com 도메인 + HTTPS 포트 443 에서만 동작한다.
#   - 이 스크립트는 Node.js 내장 모듈만 사용해 HTTPS 정적 서버 + /api 프록시를 기동한다.
#
# 사용법 (Mac — 사용자가 터미널을 직접 열고 아래 명령어를 직접 입력):
#   sudo ./scripts/serve-https-prototype.sh <도메인> [백엔드포트]
#
# ⚠️  이 명령어는 AI가 대신 실행할 수 없습니다.
#     Mac에서 sudo는 사용자가 터미널을 직접 열고 입력해야 합니다.
#
# 예시:
#   sudo ./scripts/serve-https-prototype.sh dev-myservice.nexon.com 4000
#   → HTTPS: https://dev-myservice.nexon.com
#   → /api/* → http://localhost:4000 (프록시)
#
# ⚠️  포트 443 필수: INSIGN 로그인은 포트 443이 아니면 동작하지 않는다.
#
# 사전 조건:
#   1. ./scripts/setup-https.sh <도메인> frontend 실행 완료
#   2. /etc/hosts에 127.0.0.1 <도메인> 등록 완료

set -e

DOMAIN="${1:-}"
BACKEND_PORT="${2:-4000}"
SERVER_PORT=443

if [[ -z "$DOMAIN" ]]; then
  echo "사용법: sudo $0 <도메인> [백엔드포트]"
  echo ""
  echo "예시:"
  echo "  sudo $0 dev-myservice.nexon.com 4000"
  echo "  → 접속: https://dev-myservice.nexon.com"
  echo ""
  echo "⚠️  포트 443 필수: INSIGN 로그인은 포트 443이 아니면 동작하지 않습니다."
  exit 1
fi

# root 권한 확인
if [[ "$EUID" -ne 0 ]]; then
  echo ""
  echo "❌ 포트 443 바인딩은 root 권한이 필요합니다."
  echo "   다시 실행하세요: sudo $0 $DOMAIN $BACKEND_PORT"
  echo ""
  echo "⚠️  포트 443 필수: INSIGN 로그인은 포트 443이 아니면 동작하지 않습니다."
  echo ""
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERT="$PROJECT_ROOT/frontend/${DOMAIN}.pem"
KEY="$PROJECT_ROOT/frontend/${DOMAIN}-key.pem"
PROTO_DIR="$PROJECT_ROOT/prototype"

if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
  echo ""
  echo "❌ HTTPS 인증서가 없습니다."
  echo "   먼저 실행하세요: ./scripts/setup-https.sh $DOMAIN frontend"
  echo ""
  exit 1
fi

if [[ ! -d "$PROTO_DIR" ]]; then
  echo "❌ prototype/ 디렉토리가 없습니다."
  exit 1
fi

ACCESS_URL="https://$DOMAIN"

echo ""
echo "=== HTTPS Prototype Server (Phase 0.6/0.7) ==="
echo "  도메인  : $DOMAIN"
echo "  포트    : $SERVER_PORT"
echo "  API 프록시: /api/* → http://localhost:$BACKEND_PORT"
echo ""

# Node.js 내장 모듈(https, http, fs, path, url)만 사용 — npm install 불필요
node - "$DOMAIN" "$BACKEND_PORT" "$SERVER_PORT" "$ACCESS_URL" "$CERT" "$KEY" "$PROTO_DIR" <<'NODEEOF'
const https = require('https');
const http  = require('http');
const fs    = require('fs');
const path  = require('path');
const url   = require('url');

const [,, DOMAIN, BACKEND_PORT, SERVER_PORT, ACCESS_URL, CERT, KEY, PROTO_DIR] = process.argv;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript',
  '.css':  'text/css',
  '.json': 'application/json',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
  '.woff2':'font/woff2',
};

const serverOpts = {
  cert: fs.readFileSync(CERT),
  key:  fs.readFileSync(KEY),
};

https.createServer(serverOpts, (req, res) => {
  const parsed  = url.parse(req.url);
  const pathname = parsed.pathname;

  // ── /api/* → 백엔드 프록시 ─────────────────────────────────────
  if (pathname.startsWith('/api')) {
    const proxyOpts = {
      hostname: 'localhost',
      port: parseInt(BACKEND_PORT, 10),
      path: req.url,
      method: req.method,
      headers: { ...req.headers, host: 'localhost:' + BACKEND_PORT },
    };
    const proxy = http.request(proxyOpts, (proxyRes) => {
      const resHeaders = {
        ...proxyRes.headers,
        'Access-Control-Allow-Origin': ACCESS_URL,
        'Access-Control-Allow-Credentials': 'true',
      };
      res.writeHead(proxyRes.statusCode, resHeaders);
      proxyRes.pipe(res);
    });
    proxy.on('error', (e) => {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        error: '백엔드 연결 실패',
        detail: e.message,
        hint: 'INFACE_API_KEY=... PORT=' + BACKEND_PORT + ' APP_ENV=local node scripts/verify-backend.js 먼저 실행하세요',
      }));
    });
    req.pipe(proxy);
    return;
  }

  // ── OPTIONS preflight ────────────────────────────────────────────
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    });
    res.end();
    return;
  }

  // ── 정적 파일 서빙 ───────────────────────────────────────────────
  let filePath = path.join(PROTO_DIR, pathname);
  try {
    const stat = fs.statSync(filePath);
    if (stat.isDirectory()) filePath = path.join(filePath, 'index.html');
  } catch (_) {
    filePath = path.join(PROTO_DIR, 'index.html');  // SPA fallback
  }

  const ext = path.extname(filePath).toLowerCase();
  try {
    const content = fs.readFileSync(filePath);
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'text/plain' });
    res.end(content);
  } catch (_) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('404 Not Found: ' + pathname);
  }

}).listen(parseInt(SERVER_PORT, 10), DOMAIN, () => {
  console.log('✅ 서버 기동 완료');
  console.log('');
  console.log('   프로토타입 URL    : ' + ACCESS_URL);
  console.log('   INSIGN 검증 페이지: ' + ACCESS_URL + '/#/insign-debug');
  console.log('   API 프록시        : /api/* → http://localhost:' + BACKEND_PORT);
  console.log('');
  console.log('   종료: Ctrl+C');
  console.log('');
});
NODEEOF
