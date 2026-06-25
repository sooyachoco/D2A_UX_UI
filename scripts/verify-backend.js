/**
 * Phase 0.7 T072 전용 — INSIGN 헤더 전달 검증 최소 백엔드
 *
 * Node.js 내장 모듈만 사용 (npm install 불필요)
 * 실제 백엔드(Phase 1 이후)가 구현되면 이 파일은 사용하지 않는다.
 *
 * 사용법:
 *   INFACE_API_KEY=your-key PORT=4000 APP_ENV=local node scripts/verify-backend.js
 *
 * 지원 엔드포인트:
 *   POST /api/verify  — 로컬 환경 인증 헤더 3종 검증 후 uid 반환
 */

'use strict';

const http = require('http');

const PORT          = parseInt(process.env.PORT || '4000', 10);
const APP_ENV       = process.env.APP_ENV || 'local';
const INFACE_API_KEY = process.env.INFACE_API_KEY || '';

if (!INFACE_API_KEY) {
  console.warn('\n⚠  INFACE_API_KEY 환경변수가 설정되지 않았습니다.');
  console.warn('   모든 /api/verify 요청이 403을 반환합니다.\n');
}

// ── 요청 body 파싱 ─────────────────────────────────────────────────
function readBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (chunk) => { data += chunk; });
    req.on('end', () => resolve(data));
  });
}

// ── CORS 헤더 (serve-https-prototype.sh 프록시를 경유하므로 * 허용) ─
function setCors(res, origin) {
  res.setHeader('Access-Control-Allow-Origin', origin || '*');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Headers',
    'Content-Type, x-inface-api-key, Authorization, x-inface-user-uid');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

function json(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body, null, 2));
}

// ── 메인 핸들러 ───────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  const origin = req.headers['origin'] || '*';
  setCors(res, origin);

  // preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const { url, method } = req;

  // ── POST /api/verify ──────────────────────────────────────────
  if (url === '/api/verify' && method === 'POST') {
    await readBody(req);  // body 소비 (내용은 미사용)

    // 로컬 환경: API Key + Authorization 헤더 직접 검증
    if (APP_ENV === 'local') {
      const apiKey = req.headers['x-inface-api-key'];
      if (!apiKey || apiKey !== INFACE_API_KEY) {
        console.log(`[verify] ❌ 403 — API Key 불일치 (received: ${apiKey ? apiKey.substring(0, 8) + '…' : '없음'})`);
        return json(res, 403, {
          error: { name: 'forbidden', message: 'Invalid or missing x-inface-api-key' },
        });
      }

      const auth = req.headers['authorization'];
      if (!auth || !auth.startsWith('Web ')) {
        console.log(`[verify] ❌ 401 — Authorization 헤더 없음 또는 형식 오류`);
        return json(res, 401, {
          error: {
            name: 'unauthorized',
            message: 'Missing or invalid Authorization header (expected: Web <token>)',
          },
        });
      }
    }

    // 모든 환경 공통: x-inface-user-uid 헤더 확인
    const uid = req.headers['x-inface-user-uid'];
    if (!uid) {
      console.log(`[verify] ❌ 401 — x-inface-user-uid 헤더 없음`);
      return json(res, 401, {
        error: { name: 'unauthorized', message: 'Missing x-inface-user-uid header' },
      });
    }

    console.log(`[verify] ✅ 200 — uid=${uid}`);
    return json(res, 200, {
      verified: true,
      uid,
      env: APP_ENV,
      headers_received: {
        'x-inface-api-key':  req.headers['x-inface-api-key']
          ? req.headers['x-inface-api-key'].substring(0, 8) + '…(마스킹)'
          : '없음',
        'Authorization':     req.headers['authorization']
          ? req.headers['authorization'].substring(0, 16) + '…(마스킹)'
          : '없음',
        'x-inface-user-uid': uid,
      },
    });
  }

  // ── 그 외 경로 ────────────────────────────────────────────────
  json(res, 404, { error: 'Not found', supported: ['POST /api/verify'] });
});

server.listen(PORT, () => {
  console.log('');
  console.log('✅ INSIGN 검증 백엔드 (Phase 0.7 전용)');
  console.log(`   엔드포인트  : http://localhost:${PORT}/api/verify`);
  console.log(`   APP_ENV     : ${APP_ENV}`);
  console.log(`   INFACE_API_KEY: ${INFACE_API_KEY ? INFACE_API_KEY.substring(0, 8) + '…(설정됨)' : '⚠ 미설정'}`);
  console.log('');
  console.log('   서버를 실행한 채로 serve-https-prototype.sh를 별도 터미널에서 기동하세요.');
  console.log('   종료: Ctrl+C');
  console.log('');
});
