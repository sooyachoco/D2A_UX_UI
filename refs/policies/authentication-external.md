# 외부 유저 인증 정책 — GameScale Web SDK (inface.js)

> **적용 대상**: 외부 유저(게임 유저·넥슨 회원) 대상 서비스
> **표준 인증 방식**: GameScale Web SDK (inface.js) — `_ifwt` 쿠키 기반
> **담당 문의**: insign@nexon.co.kr / inface_gw@nexon.co.kr
>
> ℹ️ **inface.js와 GNB는 별개**. inface.js가 인증 SDK이고 GNB는 UI/정책 의무.
> inface.js는 GNB 없이도 단독으로 로그인·로그아웃·유저 정보 조회 가능.

---

## A-1b. 넥슨 회원 인증 — GameScale Web SDK (inface.js)

| 항목 | 값 |
|---|---|
| **인증 SDK** | `inface.js` (`https://signin.nexon.com/sdk/inface.js`) |
| 인증 흐름 | `inface.js` 로드 → `_ifwt` 쿠키 기반 세션 → `inface.auth.getUserProfile()` |
| 대상 | 게임 유저, 보호자, 일반 회원 |
| uid 획득 | `inface.auth.getUserProfile()` → `data.uid` |
| 로그인 | `inface.auth.gotoSignIn()` — GNB 없이도 직접 호출 가능 |
| 로그아웃 | `inface.auth.gotoSignOut()` — GNB가 있으면 GNB에 위임 |
| GNB | **정책 의무** (전 넥슨 서비스 적용). 인증 자체에는 불필요 — GNB가 있으면 로그인 UI를 GNB가 담당 |

> NXAS(`nxas.nexon.com`)와 완전히 다른 시스템.
> 사전 신청 항목: GID 발급 + INSIGN 도메인 허용(nexon.com 외 도메인 사용 시)

---

## A-1c. GameScale 유저 인증

| 항목 | 값 |
|---|---|
| 인증 방식 | GameScale 인증 (넥슨 로그인, 게스트, 소셜, 계정 연동) |
| 대상 | 신규 게임 사용자 |
| 문서 | `refs/gamescale-docs/public/docs/ko/service-integration/authentication/` |
| SDK | GameScale SDK (인증·결제·푸시·소셜 통합) |

---

## A-2d. INSIGN 도메인 제약사항

INSIGN 인증 쿠키(`_ifwt`)는 **`.nexon.com` 도메인에만 발급**됨.

| 서비스 도메인 | `_ifwt` 접근 | `/insign` 페이지 | 도메인 허용 요청 |
|---|---|---|---|
| `*.nexon.com` | ✅ 직접 접근 | ❌ 불필요 | ❌ 불필요 |
| `*.nexon.com` 외 | ❌ 불가 | ✅ **필수** | ✅ **필수** |

### nexon.com 도메인 (권장)

```html
<meta name="inface-web-auth" content="mygame.nexon.com">
<script src="https://signin.nexon.com/sdk/inface.js"></script>
```

### nexon.com 외 도메인 추가 절차

**1. 도메인 허용 요청** (`insign@nexon.co.kr`)
```
제목: [INSIGN] 도메인 허용 요청 — {서비스명}
본문: 서비스명, 허용 요청 도메인, 사용 환경(개발/스테이지/라이브), GID
```

**2. `/insign` 페이지 구현**
```html
<!-- https://mygame.com/insign -->
<meta name="inface-web-auth" content="mygame.com">
<script src="https://signin.nexon.com/sdk/inface.js"></script>
```

### 로컬 개발 — INSIGN

- `*.nexon.com` 도메인: `authentication-nxas.md` A-3b의 hosts 설정과 동일하게 적용
- `*.nexon.com` 외 도메인: 개발 시 `dev-{서비스}.nexon.com`으로 hosts 설정 권장

### NXAS vs INSIGN 비교

| 항목 | NXAS (사내) | INSIGN (외부) |
|---|---|---|
| 도메인 허용 방법 | NCSR 클라이언트 등록 | `insign@nexon.co.kr` 이메일 |
| localhost | ❌ hosts 설정 필요 | ❌ hosts 설정 필요 |
| 인증 방식 | NXAS SSO Bearer 토큰 | `_ifwt` 쿠키 |

---

## A-4b. 세션 정책 (INSIGN / GNB)

| 항목 | 값 |
|---|---|
| 세션 저장소 | `_ifwt` 쿠키 (GNB가 `.nexon.com` 도메인에 발급) |
| uid 획득 | `inface.auth.getUserProfile()` → `data.uid` |
| 세션 만료 | GNB/INSIGN 서버 측 관리 — 서비스에서 별도 토큰 만료 처리 불필요 |
| 로그아웃 | GNB에 위임 — `inface?.auth?.logout()` 또는 GNB 로그아웃 버튼 |

> PRD에 별도 세션 정책 명시 시 해당 정책 우선 적용. 미명시 시 위 방식 사용.

## A-4c. 세션 정책 (GameScale)

`refs/gamescale-docs/public/docs/ko/service-integration/authentication/` 직접 참조.

---

## A-5. 외부 유저 인증 옵션

| 옵션 | 참조 |
|---|---|
| 넥슨 로그인 / 게스트 / 소셜 로그인 / 계정 연동 | GameScale SDK 문서 |
| 2차 인증 | GameScale "Two Factor Authentication" |

---

## A-7. API Gateway 입점 (외부 유저 프로젝트)

> **적용 조건**: 서비스 대상이 외부 유저인 프로젝트만.
> 사내 직원 전용(NXAS SSO) 서비스는 해당 없음.

### Gateway 타입

| 대상 트래픽 | Gateway 타입 | 도메인 |
|---|---|---|
| 게임 클라이언트, 웹 브라우저 | **Public GW** | `public.api.nexon.com` |
| 서버 간 통신 | **Private GW** | `private.api.nexon.com` |
| 테스트 환경 | **Sandbox GW** | `sandbox.api.nexon.com` |

### Gateway 입점 사전 발급 게이트 (개발 차단 항목)

> 아래 항목이 미완료 상태이면 **개발을 차단**한다. 선택지를 제공하지 않는다.

| 항목 | 발급 방법 |
|---|---|
| INFACE Console 계정 활성화 | NCSR `https://ncsr.nexon.com/CSR/Write/7/1232` |
| GID (게임 식별자) | 담당 기술PM 요청 |
| API Key / `x-inface-api-key` | Gateway 콘솔 생성 + `insign@nexon.co.kr` 요청 |
| 네트워크 ACL | NCSR `https://ncsr.nexon.com/CSR/Write/16/327` |

**NAT IP 목록 (ACL 허용 시 사용):**
- Public/Private/Admin: `52.79.92.145`, `54.180.43.244`, `54.180.221.0`, `54.199.205.216`, `52.192.209.11`, `54.238.115.8`, `52.33.97.218`, `44.229.237.92`, `3.17.45.193`, `52.15.118.88`, `18.167.79.68`, `18.162.93.141`, `52.221.151.14`, `13.250.91.193`, `18.185.218.217`, `3.78.143.189`
- Sandbox: `3.36.218.43`, `3.36.79.148`

### 토큰 검증 연동

| Authorization 헤더 | 업스트림 추가 헤더 |
|---|---|
| `Web {IAS_WEB_TOKEN}` | `x-inface-user-uid` |
| `Game {IAS_GAME_TOKEN}` | `x-inface-user-guid` |

Gateway가 검증 처리 → 백엔드는 헤더만 읽어 유저 식별 (토큰 검증 로직 불필요).

### Gateway 기본 설정 (서비스 생성 후 필수)

| 설정 항목 | 권장 값 |
|---|---|
| API Key | **활성화 필수** (기본이 any open) |
| 토큰 검증 | 활성화 |
| 요청 타임아웃 | 9초 |
| CORS | 활성화 + Origin 설정 |

---

## A-9. API Gateway 로컬 개발 제약사항

INFACE API Gateway는 `localhost`를 업스트림으로 등록할 수 없다 (NAT Gateway 구조상 도달 불가).

### 로컬 HTTPS 설정 (필수 선행 조건)

INSIGN `_ifwt` 쿠키와 GNB 로그인은 **`.nexon.com` 도메인 + HTTPS** 에서만 동작한다.
`http://localhost`나 `http://dev-*.nexon.com`으로는 인증이 불가하다.

**1단계 — 인증서 생성 (mkcert)**

```bash
# 프로젝트 루트에서 실행
./scripts/setup-https.sh dev-{서비스}.nexon.com frontend

# 완료 후 생성 파일:
#   frontend/dev-{서비스}.nexon.com.pem
#   frontend/dev-{서비스}.nexon.com-key.pem
```

> `setup-https.sh` 내부 동작:
> 1. mkcert 설치 확인 (없으면 brew로 자동 설치)
> 2. `JAVA_HOME="" mkcert -install` — Java keystore 오류 방지 후 로컬 CA 등록
> 3. `mkcert {도메인}` — 인증서 생성
> 4. `/etc/hosts` 확인 및 자동 추가 (sudo 필요)

**2단계 — vite.config.ts 설정**

```typescript
// frontend/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'fs';
import path from 'path';

const DOMAIN = process.env.VITE_LOCAL_DOMAIN ?? 'dev-{서비스}.nexon.com';
const certDir = path.resolve(__dirname);
const keyPath  = path.join(certDir, `${DOMAIN}-key.pem`);
const certPath = path.join(certDir, `${DOMAIN}.pem`);
const hasCerts = fs.existsSync(keyPath) && fs.existsSync(certPath);

if (!hasCerts) {
  console.warn(`\n⚠️  HTTPS 인증서가 없습니다. 아래 명령을 먼저 실행하세요:\n  ./scripts/setup-https.sh ${DOMAIN} frontend\n`);
}

export default defineConfig({
  plugins: [react()],
  server: {
    host: DOMAIN,
    port: 443,         // HTTPS 표준 포트 — sudo npm run dev 또는 pfctl 포워딩 필요
    https: hasCerts
      ? { key: fs.readFileSync(keyPath), cert: fs.readFileSync(certPath) }
      : undefined,     // 인증서 없으면 HTTP로 기동 (오류 방지)
    proxy: {
      '/api': { target: 'http://localhost:{백엔드포트}', changeOrigin: true },
    },
  },
});
```

**.gitignore 확인 (인증서 파일 제외 필수):**

```
*.pem
*-key.pem
```

**포트 443 바인딩 방법:**

> Unix 계열에서 1024 미만 포트는 root 권한이 필요하다. 아래 중 하나를 선택한다.

| 방법 | vite 포트 | 실행 명령 | 접속 URL |
|------|------|------|------|
| **sudo 실행** | `443` | `sudo npm run dev` | `https://dev-*.nexon.com` |
| **macOS pfctl 포워딩** (1회 설정 후 sudo 불필요) | `443` | `npm run dev` | `https://dev-*.nexon.com` |
| 고포트 4430 (URL에 포트 노출) | `4430` | `npm run dev` | `https://dev-*.nexon.com:4430` |

**macOS pfctl 포워딩 설정 (1회, 재부팅 전까지 유효):**

```bash
# 443으로 들어오는 TCP를 로컬 443으로 허용 (root 권한 위임 없이 Vite가 443 사용 가능)
sudo sysctl -w net.inet.ip.portrange.reservedhigh=0

# 재부팅 후에도 유지하려면 /etc/sysctl.conf에 추가:
# net.inet.ip.portrange.reservedhigh=0
```

또는 pfctl 리다이렉트 방식 (Vite port: 4430으로 변경 시):

```bash
sudo sh -c 'echo "rdr pass inet proto tcp from any to any port 443 -> 127.0.0.1 port 4430" | pfctl -ef -'
# 재부팅 후 유지: /etc/pf.conf에 위 rdr 줄 추가 후 sudo pfctl -f /etc/pf.conf
```

> NXAS·INFACE 콘솔에 callback URL 등록 시: 포트 443은 URL에서 생략 — `https://dev-{서비스}.nexon.com/auth/callback`

### 로컬 개발 전략

**전략 1: uid Passthrough (권장)**

```
[로컬]          브라우저 → https://dev-{서비스}.nexon.com (Vite HTTPS, 포트 443)
                        → 로컬 백엔드 직접 호출 (Gateway 우회)
                프론트: API Key + Authorization + x-inface-user-uid 헤더 직접 주입
                백엔드: API Key + Authorization 검증 후 uid 헤더 읽기 (로컬 환경만)
[스테이지/라이브] 브라우저 → public.api.nexon.com → Gateway → EC2
                프론트: API Key + Authorization 헤더만 전달
                Gateway: 토큰 검증 후 x-inface-user-uid 자동 주입
                백엔드: uid 헤더만 읽기
```

환경변수:
```bash
# .env.local (Vite)
VITE_APP_ENV=local
VITE_API_BASE_URL=/api                             # Vite proxy 경유
VITE_INFACE_API_KEY=your-api-key-here

# .env.production (Vite)
VITE_APP_ENV=live
VITE_API_BASE_URL=https://public.api.nexon.com/{서비스}
VITE_INFACE_API_KEY=your-api-key-here

# Next.js는 NEXT_PUBLIC_ 접두사 사용
```

**`lib/apiClient.ts` — 환경별 인증 헤더 분기:**

```typescript
// lib/apiClient.ts
import type { Insign, ProfileData } from "@/types/insign";

const API_BASE = (import.meta.env.VITE_API_BASE_URL as string) ?? "/api";
const APP_ENV  = (import.meta.env.VITE_APP_ENV  as string) ?? "local";

function buildAuthHeaders(insign?: Insign, profile?: ProfileData): Record<string, string> {
  const headers: Record<string, string> = {
    "x-inface-api-key": import.meta.env.VITE_INFACE_API_KEY as string,
  };
  if (insign?.webToken) headers["Authorization"] = `Web ${insign.webToken}`;

  if (APP_ENV === "local") {
    // 로컬: Gateway 없음 — 프론트가 게이트웨이 역할 시뮬레이션
    // 백엔드가 로컬 환경에서 uid 헤더를 직접 읽기 위해 주입
    // ⚠ review-suppress 처리 필요 — 의도된 설계
    if (profile?.uid) headers["x-inface-user-uid"] = profile.uid;
  }
  // 스테이지/라이브: Gateway가 x-inface-user-uid를 자동 주입 → 프론트에서 주입하지 않음

  return headers;
}

export interface ApiFetchOptions extends Omit<RequestInit, "headers"> {
  auth?: { insign?: Insign; profile?: ProfileData };
  headers?: Record<string, string>;
}

export async function apiFetch(path: string, options: ApiFetchOptions = {}): Promise<Response> {
  const { auth, headers: extraHeaders = {}, ...rest } = options;
  const url = `${API_BASE}${path.startsWith("/") ? "" : "/"}${path}`;

  return fetch(url, {
    ...rest,
    headers: {
      "Content-Type": "application/json",
      ...buildAuthHeaders(auth?.insign, auth?.profile),
      ...extraHeaders,
    },
  });
}
```

사용 예:
```typescript
// 인증 필요 API 호출
const res = await apiFetch("/verify", { auth: { insign, profile: user } });
const data = await res.json();
```

> **로컬 uid 주입 패턴** — 서브에이전트 보안 리뷰에서 경고를 발생시킬 수 있다.
> `프로젝트루트/.claude-suppress.yaml`에 아래 항목을 추가해 의도된 설계임을 표시한다:
> ```yaml
> security:
>   - file: frontend/src/lib/apiClient.ts
>     issue: "로컬 환경 x-inface-user-uid 헤더 프론트 직접 주입 — 의도된 설계"
> ```

**전략 2: Sandbox Gateway (통합 테스트용)**

공인 IP 서버를 Sandbox GW 업스트림으로 등록하여 실제 Gateway 흐름 테스트.

### 백엔드 설계 원칙

```
[인증 미들웨어]
  x-inface-user-uid 있음 → 로그인 (로컬: 프론트 주입 / 스테이지·라이브: Gateway 주입)
  x-inface-user-uid 없음 → 비로그인
  ↓
[비즈니스 로직] — request.user_uid로 통일
```

백엔드는 헤더 출처(Gateway vs 프론트)를 구분하지 않는다. 동일한 미들웨어로 처리.
`AUTH_MODE` 등의 별도 환경변수 불필요.

---

## A-10. GNB 로컬 개발 제약사항

GNB 로그인 기능은 `.nexon.com` 쿠키 의존 → `localhost`에서 동작 불가.

| 단계 | GNB 처리 |
|---|---|
| Phase 0 (디자인) | 플레이스홀더 바 유지 (60px 다크 바) |
| 로컬 개발 (hosts 전) | 플레이스홀더 또는 스크립트 로드만 확인 |
| 로컬 개발 (hosts 후) | 실제 GNB 스크립트, `data-loginenv="test"` |
| 스테이지/라이브 | `data-loginenv="live"` |

hosts 설정은 `authentication-nxas.md` A-3b와 동일. SSO + GNB 공용.

### GNB 스크립트 구성 (4개)

> ⚠️ 공통 스크립트(head/bodystart/bodyend)와 GNB 본체는 **도메인이 다르다**.
> 하나의 RESOURCE_DOMAIN 환경변수로 통일하면 404가 발생한다.

| 역할 | 파일 | 위치 | 도메인 |
|---|---|---|---|
| 공통 초기화 | `ngb_head.js` | `<head>` | `ssl[-test].nexon.com` |
| GNB 렌더링 준비 | `ngb_bodystart.js` | `<body>` 첫 줄 | `ssl[-test].nexon.com` |
| **GNB 본체** | `gnb.min.js` | bodystart 직후 | `rs[-test].nxfs.nexon.com` |
| 로그인 모달·후처리 | `ngb_bodyend.js` | `</body>` 직전 | `ssl[-test].nexon.com` |

**환경별 도메인:**

| 환경 | SSL_DOMAIN | GNB_DOMAIN |
|---|---|---|
| test (로컬·스테이지) | `https://ssl-test.nexon.com` | `https://rs-test.nxfs.nexon.com` |
| live (운영) | `https://ssl.nexon.com` | `https://rs.nxfs.nexon.com` |

**gnb.min.js 필수 data 속성:**

| 속성 | 값 | 설명 |
|---|---|---|
| `data-gamecode` | GID (예: `1234`) | 게임 식별자 |
| `data-ispublicbanner` | `"false"` | 공개 배너 비활성 |
| `data-loginenv` | `"test"` / `"live"` | 환경 분기 |
| `data-oncomplete` | `"onGnbReady"` | 렌더링 완료 콜백 |
| `data-skiptocontentsid` | `"gnb-anchor"` | 접근성 — 본문으로 바로가기 대상 ID |

### 환경변수 패턴

`SSL_DOMAIN`과 `GNB_DOMAIN`은 `NEXT_PUBLIC_GNB_LOGIN_ENV` 하나에서 코드로 파생한다.
`NEXT_PUBLIC_GNB_RESOURCE_DOMAIN`은 사용하지 않는다.

```bash
# .env.local
NEXT_PUBLIC_GNB_LOGIN_ENV=test
NEXT_PUBLIC_GNB_GAME_CODE=1234

# Inface SDK (GNB와 별도 관리 — 인증 SDK는 GNB와 독립)
NEXT_PUBLIC_INFACE_SDK_URL=https://signin.nexon.com/sdk/inface.js
NEXT_PUBLIC_INFACE_WEB_AUTH=test-live.nexon.com
NEXT_PUBLIC_INFACE_ENV=test
NEXT_PUBLIC_INFACE_PLATFORM=krpc

# .env.production
NEXT_PUBLIC_GNB_LOGIN_ENV=live
NEXT_PUBLIC_GNB_GAME_CODE=1234

NEXT_PUBLIC_INFACE_SDK_URL=https://signin.nexon.com/sdk/inface.js
NEXT_PUBLIC_INFACE_WEB_AUTH=live.nexon.com
NEXT_PUBLIC_INFACE_ENV=live
NEXT_PUBLIC_INFACE_PLATFORM=krpc
```

### Next.js App Router 구현 예시

```typescript
const GNB_LOGIN_ENV = process.env.NEXT_PUBLIC_GNB_LOGIN_ENV ?? "test";
const GNB_GAME_CODE = process.env.NEXT_PUBLIC_GNB_GAME_CODE ?? "1234";
const isLive = GNB_LOGIN_ENV === "live";
const SSL_DOMAIN = isLive ? "https://ssl.nexon.com" : "https://ssl-test.nexon.com";
const GNB_DOMAIN = isLive ? "https://rs.nxfs.nexon.com" : "https://rs-test.nxfs.nexon.com";

// onGnbReady는 레이아웃 오프셋 동기화 전용 — 인증 로직을 여기에 넣지 않는다
// 기본값: 공개 배너 없는 일반 GNB = 60px, 공개 배너 포함 GNB = 116px
const onGnbReadyScript = `
function syncGnbOffset() {
  var h = parseInt(getComputedStyle(document.body).paddingTop, 10) || 116;
  document.documentElement.style.setProperty('--gnb-h', h + 'px');
}
function onGnbReady() {
  requestAnimationFrame(function() {
    syncGnbOffset();
    window.addEventListener('scroll', syncGnbOffset, { passive: true });
  });
}
window.addEventListener('load', onGnbReady);
`.trim();

// layout.tsx <html> 내부:
// <head>
//   <script src={`${SSL_DOMAIN}/s1/global/ngb_head.js`} />
// </head>
// <body>
//   <script src={`${SSL_DOMAIN}/s1/global/ngb_bodystart.js`} />
//   <script dangerouslySetInnerHTML={{ __html: onGnbReadyScript }} />
//   <div id="gnb-anchor" />  {/* 접근성 — 본문으로 바로가기 앵커 */}
//   <script src={`${GNB_DOMAIN}/common/js/gnb.min.js`}
//     data-gamecode={GNB_GAME_CODE}
//     data-ispublicbanner="false"
//     data-loginenv={GNB_LOGIN_ENV}
//     data-oncomplete="onGnbReady"
//     data-skiptocontentsid="gnb-anchor" />
//   {children}
//   <script src={`${SSL_DOMAIN}/s1/global/ngb_bodyend.js`} />
// </body>
```

### Vite index.html 패턴

Vite(React SPA) 프로젝트는 `index.html`에서 `%VITE_*%` 환경변수 치환을 사용한다.

> `VITE_GNB_SSL_DOMAIN`과 `VITE_GNB_RESOURCE_DOMAIN`은 **반드시 분리**해야 한다.
> 두 도메인을 하나의 변수로 통일하면 404가 발생한다.

```bash
# .env.local / .env.development
VITE_GNB_SSL_DOMAIN=https://ssl-test.nexon.com
VITE_GNB_RESOURCE_DOMAIN=https://rs-test.nxfs.nexon.com
VITE_GNB_GAME_CODE=1234
VITE_GNB_LOGIN_ENV=test

# .env.production
VITE_GNB_SSL_DOMAIN=https://ssl.nexon.com
VITE_GNB_RESOURCE_DOMAIN=https://rs.nxfs.nexon.com
VITE_GNB_GAME_CODE=1234
VITE_GNB_LOGIN_ENV=live
```

```html
<!-- index.html -->
<!doctype html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <script src="%VITE_GNB_SSL_DOMAIN%/s1/global/ngb_head.js"></script>
</head>
<body>
  <script src="%VITE_GNB_SSL_DOMAIN%/s1/global/ngb_bodystart.js"></script>
  <script>
    function syncGnbOffset() {
      var h = parseInt(getComputedStyle(document.body).paddingTop, 10) || 116;
      document.documentElement.style.setProperty('--gnb-h', h + 'px');
    }
    function onGnbReady() {
      requestAnimationFrame(function () {
        syncGnbOffset();
        window.addEventListener('scroll', syncGnbOffset, { passive: true });
      });
    }
    window.addEventListener('load', onGnbReady);
  </script>
  <div id="gnb-anchor"></div>
  <script type="text/javascript"
    src="%VITE_GNB_RESOURCE_DOMAIN%/common/js/gnb.min.js"
    data-gamecode="%VITE_GNB_GAME_CODE%"
    data-ispublicbanner="false"
    data-loginenv="%VITE_GNB_LOGIN_ENV%"
    data-oncomplete="onGnbReady"
    data-skiptocontentsid="gnb-anchor">
  </script>

  <div id="root"></div>
  <script type="module" src="/src/main.tsx"></script>

  <script src="%VITE_GNB_SSL_DOMAIN%/s1/global/ngb_bodyend.js"></script>
</body>
</html>
```

> `lib/insign.ts`의 SDK URL은 `VITE_*` 변수를 따로 지정하거나 기본값(`https://signin.nexon.com/sdk/inface.js`)을 사용한다.

### inface.js SDK 유틸리티 (GNB 독립)

inface.js는 GNB와 **완전히 별개**다. GNB 없이도 단독으로 로드·초기화 가능하며, GNB `onGnbReady` 콜백에 인증 로직을 넣지 않는다.

> `onGnbReady`는 레이아웃 오프셋 동기화 전용 — 여기에 `getUserProfile()` 등 인증 로직을 넣으면 GNB 장애 시 인증도 함께 깨진다.

```typescript
// types/insign.ts — SDK 전체 타입 정의
export type InfaceEnv = 'test' | 'pre' | 'live';
export type InfacePlatform = 'krpc' | 'jppc' | 'arena_west' | 'arena_th' | 'arena_tw' | 'arena_sea';

export interface InsignConfig {
  webAuth: string;
  env: InfaceEnv;
  platform: InfacePlatform;
  callbackOk: () => void;
  callbackFail: (error: Error) => void;
}

export interface GotoOptions {
  redirect_uri?: string;
  target?: '_self' | '_blank';
}

export interface ProfileData {
  uid: string;
  platform_type: string;
  platform_user_id: string;  // MemberSN(한국) / NXSN(일본) / GlobalUserNo(Arena)
  is_guest?: boolean;
}

export interface ProfileResult {
  data: ProfileData | Record<string, never>;
  error: { code: number; name: string; message: string; data: unknown } | null;
}

export interface Insign {
  init(config: InsignConfig): void;
  isSignedIn(): boolean;
  gotoSignIn(options?: GotoOptions): void;
  gotoSignOut(options?: GotoOptions): void;
  getUserProfile(): Promise<ProfileResult>;
  webToken?: string;
}
```

```typescript
// lib/insign.ts — GNB 독립 SDK 로더
import type { Insign, InsignConfig } from "@/types/insign";

function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) { resolve(); return; }
    const s = document.createElement("script");
    s.src = src;
    s.onload = () => resolve();
    s.onerror = reject;
    document.head.appendChild(s);
  });
}

export function getInsign(): Insign | undefined {
  if (typeof window !== "undefined")
    return (window as unknown as { inface?: { auth?: Insign } }).inface?.auth;
}

function waitForInsignAuth(timeoutMs = 5000): Promise<Insign> {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const poll = () => {
      const ins = getInsign();
      if (ins) return resolve(ins);
      if (Date.now() - start >= timeoutMs)
        return reject(new Error(`window.inface.auth 초기화 타임아웃 (${timeoutMs}ms)`));
      setTimeout(poll, 100);
    };
    poll();
  });
}

export async function initInsign(
  config: Omit<InsignConfig, "callbackOk" | "callbackFail">
): Promise<Insign> {
  const sdkUrl =
    process.env.NEXT_PUBLIC_INFACE_SDK_URL ?? "https://signin.nexon.com/sdk/inface.js";
  await loadScript(sdkUrl);
  const insign = await waitForInsignAuth();
  await new Promise<void>((resolve, reject) => {
    insign.init({ ...config, callbackOk: resolve, callbackFail: reject });
  });
  return insign;
}
```

### GNB 프로젝트에서 서비스 자체 헤더(SiteHeader) 로그인 상태 연결

GNB가 로그인 버튼·모달·로그아웃을 담당하므로 SiteHeader에 별도 로그인 버튼을 중복 구현하지 않는다.
그러나 사용자명 표시, 어드민 분기 등 서비스 헤더가 로그인 상태를 참조해야 하는 경우 아래 패턴을 따른다.

**원칙:**
- inface.js 초기화는 `lib/insign.ts`가 직접 로드 — GNB `onGnbReady`와 **무관**
- `isSignedIn()`으로 로그인 여부 선확인 후 `getUserProfile()` 호출 (비로그인 시 API 호출 방지)
- `cancelled` 플래그로 언마운트 후 상태 업데이트 방지 (React StrictMode 이중 실행 대응)
- 결과를 Context에 저장 → 필요한 컴포넌트가 `useAuth()`로 참조
- SiteHeader는 Context 값을 받아 표시만 한다 — 직접 inface.js를 호출하지 않는다
- 로그아웃은 GNB에 위임 — `insign.gotoSignOut()` 또는 GNB 로그아웃 버튼

```typescript
// contexts/AuthContext.tsx
"use client";
import { createContext, useContext, useEffect, useState } from "react";
import { initInsign } from "@/lib/insign";
import type { Insign, ProfileData } from "@/types/insign";

interface AuthState {
  insign?: Insign;
  user: ProfileData | null;    // uid뿐 아니라 platform_type, platform_user_id, is_guest 포함
  loading: boolean;
  error?: Error;
}
const AuthContext = createContext<AuthState>({ user: null, loading: true });

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AuthState>({ user: null, loading: true });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const insign = await initInsign({
          webAuth: process.env.NEXT_PUBLIC_INFACE_WEB_AUTH!,
          env: process.env.NEXT_PUBLIC_INFACE_ENV as any,
          platform: process.env.NEXT_PUBLIC_INFACE_PLATFORM as any,
        });
        if (cancelled) return;

        let user: ProfileData | null = null;
        if (insign.isSignedIn()) {
          const r = await insign.getUserProfile();
          if (r.data && "uid" in r.data) user = r.data as ProfileData;
        }
        if (!cancelled) setState({ insign, user, loading: false });
      } catch (err) {
        if (!cancelled)
          setState({
            user: null,
            loading: false,
            error: err instanceof Error ? err : new Error(String(err)),
          });
      }
    })();
    return () => { cancelled = true; };
  }, []);

  return <AuthContext.Provider value={state}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
```

**패턴 2: middleware pass-through (페이지 보호 금지)**

```typescript
// middleware.ts — 페이지 인증 로직 제거
// INFACE Gateway 헤더(x-inface-user-uid)는 API 요청에만 주입됨.
// 페이지 네비게이션은 Gateway를 거치지 않으므로 헤더가 절대 존재하지 않음.
// → middleware에서 페이지 인증 판별 불가 — useRequireAuth() 클라이언트 훅이 담당.

export function middleware() {
  return NextResponse.next();
}
export const config = { matcher: ["/api/:path*"] };  // API 라우트만 적용
```

**패턴 3: useRequireAuth — 클라이언트 페이지 라우트 가드**

```typescript
// hooks/useRequireAuth.ts
import { useEffect } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { getInsign } from "@/lib/insign";

export function useRequireAuth() {
  const { user, loading } = useAuth();

  useEffect(() => {
    if (loading) return;
    if (!user) {
      // GNB 로그인 팝업 실행 (GNB에 위임)
      getInsign()?.gotoSignIn();
    }
  }, [user, loading]);

  return { user, loading, isAuthenticated: !!user };
}

// 보호 페이지에서 사용:
// const { user, loading } = useRequireAuth();
// if (loading) return <LoadingSpinner />;
// if (!user) return null;  // GNB 로그인 팝업이 자동으로 뜸
```

```typescript
// layout.tsx — AuthProvider로 앱 감싸기
// <AuthProvider>{children}</AuthProvider>

// SiteHeader.tsx
import { useAuth } from "@/contexts/AuthContext";

export default function SiteHeader() {
  const { user } = useAuth();
  return (
    <header>
      {user ? (
        <>
          <span>{user.uid}</span>
          {/* 로그아웃은 GNB에 위임 — 서비스에서 별도 처리 불필요 */}
        </>
      ) : null}
    </header>
  );
}
```

## A-8. 프로젝트 인증 아키텍처 결정 (프로젝트별 기입)

> 이 섹션은 `decisions.md`에 프로젝트별로 기록한다.
> boilerplate-setup Stage 3~4 완료 후 아키텍처가 확정되면 `decisions.md`에 이동.

### 아키텍처 예시 (SSR + API Gateway 하이브리드)

| 계층 | 기술 | 역할 |
|---|---|---|
| 프론트엔드 | INSIGN + SSR (EC2) | 넥슨 회원 로그인/세션 |
| API Gateway | INFACE Public GW | 토큰 검증, DDoS/보안 |
| 백엔드 | 업스트림 EC2 | 비즈니스 로직 (x-inface-user-uid로 식별) |

```
[1] 유저 → {서비스}.nexon.com 접속
[2] SSR 서버: _ifwt 쿠키 확인
    ├─ 있음 → private.api.nexon.com WebToken Verify → 페이지 렌더링
    └─ 없음 → signin.nexon.com/signin?redirect_uri=... 리다이렉트
[3] CSR API: Authorization: Web {_ifwt} → public.api.nexon.com → 백엔드
```
