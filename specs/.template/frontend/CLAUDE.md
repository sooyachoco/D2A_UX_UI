# 프론트엔드 전용 지침

> 이 파일은 `frontend/` 디렉토리에서 작업할 때 루트 `CLAUDE.md`에 추가로 로드된다.
> 루트 CLAUDE.md의 헌법·공통 규칙이 먼저 적용되며, 이 파일은 프론트엔드 전용 규칙을 정의한다.
> **Claude Code 기반 개발을 전제한다.**

---

## 빌드 검사 (프론트엔드)

소스 파일 수정 후 **같은 턴에서** 빌드 검사를 실행한다:

```bash
npm run build   # 또는 yarn build / pnpm build
```

실패 시 수정 후 재검사. 연속 2회 실패 시 세션 체크포인트를 생성하고 사용자에게 보고한다.

---

## 디자인 품질 기준

`design-direction.md`가 존재하면 **`Read("design-direction.md")`로 반드시 먼저 읽고** 정의된 톤·색상·타이포를 준수한다.

아래 **필수 디자인 요소**와 **안티패턴**은 `design-direction.md`에 해당 항목이 명시되지 않은 경우의 기본 기준이다. `design-direction.md`가 명시한 항목은 해당 파일이 우선한다.

**AI 기본 출력 안티패턴 — 금지:**
- 모든 섹션에 동일한 `max-w-7xl mx-auto px-4` 반복
- 히어로 영역: 중앙 정렬 제목 + 부제목 + CTA 버튼 1개 (기본 배치)
- 카드 그리드: `grid-cols-3 gap-6`만 반복
- Primary 단색 + Neutral(회색)만 사용
- shadcn/MUI/Ant Design 기본 테마를 커스터마이징 없이 사용
- 트랜지션/애니메이션이 전혀 없는 정적 UI
- **콘텐츠 가로폭 1440px 미제한** — 뷰포트 전체 너비 사용 (넓은 모니터에서 레이아웃 붕괴)

**필수 디자인 요소:**
- 시각적 위계 3단계 이상
- 섹션 간 여백은 컴포넌트 내부 여백보다 최소 2배 이상
- Primary의 tint/shade 변형 활용 (최소 4단계)
- 카드/패널에 레벨별 그림자 토큰 사용
- 버튼 호버 시 배경 + scale(1.02) + shadow 변화
- 페이지 진입: 섹션별 staggered fade-in

접근성: WCAG AA 이상, `prefers-reduced-motion` 지원 필수.

---

## 콘텐츠 가로폭 규칙 (width-constraint)

**모든 페이지의 콘텐츠 가로폭은 1440px로 제한한다.**
1440px 초과 뷰포트에서 콘텐츠가 좌우로 무제한 늘어나면 가독성·레이아웃 비율이 붕괴된다.

요소 유형에 따라 두 패턴을 구분 적용한다:

**패턴 A — nav/header (배경은 풀스크린, 내용물만 1440px)**

```css
/* Xpx = 기존 좌우 padding 값 */
.site-nav,
.site-header {
  padding-left:  max(Xpx, calc((100vw - 1440px) / 2 + Xpx));
  padding-right: max(Xpx, calc((100vw - 1440px) / 2 + Xpx));
}
/* 뷰포트 ≤ 1440px → padding = Xpx 고정 / 뷰포트 > 1440px → 내용물이 1440px 중앙 정렬 */
```

**패턴 B — 콘텐츠 블록 (그리드·카드·사이드바+메인)**

```css
.content-wrapper,
.page-grid,
.sidebar-layout {
  max-width: 1440px;
  margin-left: auto;
  margin-right: auto;
}
```

**Tailwind 프로젝트 적용 예시:**

```tsx
// 패턴 A: globals.css 또는 layout 컴포넌트
// .site-header { @apply px-6; padding-left: max(1.5rem, calc((100vw - 1440px) / 2 + 1.5rem)); ... }

// 패턴 B: 레이아웃 컴포넌트 wrapper
<div className="max-w-[1440px] mx-auto px-6">
  {children}
</div>
```

**섹션 간 가로폭 불일치 금지:**
- 페이지 내 모든 섹션의 콘텐츠 좌측 시작점이 동일해야 한다
- nav, hero, 카드 그리드, footer 등 전 섹션에 동일한 컨테이너 기준 적용

---

## 넥슨 GNB 컴플라이언스

**적용 대상**: PRD 또는 `spec.md`에 "GNB", "넥슨 GNB", "Global Navigation Bar" 키워드가 있는 프로젝트

**z-index 계층 규칙:**
- GNB 내부: **9,999,999** (변경 불가)
- 전체 화면 모달·다이얼로그: **10,000,000** (GNB 위 — 화면 전체를 덮는 경우)
- 드롭다운·툴팁: ≤ 8,000,000
- 고정 헤더·사이드바: ≤ 7,000,000
- 일반 오버레이: ≤ 6,000,000

> ⚠ GNB(9,999,999) 이하로 설정된 요소는 GNB가 열린 상태에서 GNB 아래로 가려진다.
> 화면 전체를 차지하는 모달·다이얼로그는 반드시 **10,000,000 이상**으로 설정한다.
> 드롭다운·툴팁 등 GNB와 겹치지 않아야 하는 요소는 GNB 아래 값을 유지한다.

**GNB 삽입 위치:** `<body>` 시작 직후 (다른 컨텐츠보다 먼저)

| 환경 | `GNB_LOGIN_ENV` | SSL 도메인 (공통 스크립트) | GNB 도메인 (본체) |
|---|---|---|---|
| 테스트 | `"test"` | `ssl-test.nexon.com` | `rs-test.nxfs.nexon.com` |
| 라이브 | `"live"` | `ssl.nexon.com` | `rs.nxfs.nexon.com` |

> GNB 스크립트는 **두 도메인**을 사용한다. 단일 `RESOURCE_DOMAIN` 변수로 관리하면
> 공통 스크립트(ssl-test)와 GNB 본체(rs-test) 도메인이 분리되어 있어 URL 조합 오류가 발생한다.
> `GNB_LOGIN_ENV` 하나로 두 도메인을 자동 계산하는 패턴을 사용한다.

**Next.js GNB 스크립트 로딩 전략 (Next.js `<Script>` 컴포넌트 필수):**

`<script async>` 태그 직접 사용은 Next.js hydration 타이밍과 충돌한다.
반드시 Next.js `<Script>` 컴포넌트의 `strategy` 를 명시한다.

```tsx
// app/layout.tsx
import Script from 'next/script'

const loginEnv = process.env.NEXT_PUBLIC_GNB_LOGIN_ENV ?? 'test'
const sslDomain = loginEnv === 'live' ? 'ssl.nexon.com' : 'ssl-test.nexon.com'
const gnbDomain = loginEnv === 'live' ? 'rs.nxfs.nexon.com' : 'rs-test.nxfs.nexon.com'
const gameCode  = process.env.NEXT_PUBLIC_GNB_GAME_CODE ?? ''

// <head> 안
<Script src={`https://${sslDomain}/s1/global/ngb_head.js`} strategy="beforeInteractive" />

// <body> 시작 직후
<Script src={`https://${sslDomain}/s1/global/ngb_bodystart.js`} strategy="afterInteractive" />
<Script
  src={`https://${gnbDomain}/common/js/gnb.min.js`}
  strategy="afterInteractive"
  data-gamecode={gameCode}
  data-ispublicbanner="false"
  data-loginenv={loginEnv}
  data-oncomplete="onGnbReady"
/>
<Script src={`https://${sslDomain}/s1/global/ngb_bodyend.js`} strategy="afterInteractive" />
```

**GNB 높이 동적 보정 (`--gnb-h` CSS 변수):**

GNB 스크립트는 렌더링 후 `body.paddingTop`을 실제 GNB 높이로 덮어쓴다.
고정(fixed) 요소의 `top` 오프셋을 CSS 변수로 동적 관리한다.

**`onGnbReady` 패턴 (스크롤 재동기화 포함):**

```html
<!-- layout.tsx 또는 globals 스크립트에 추가 -->
<script dangerouslySetInnerHTML={{ __html: `
  function syncGnbOffset() {
    var h = parseInt(getComputedStyle(document.body).paddingTop, 10) || 116;
    document.documentElement.style.setProperty('--gnb-h', h + 'px');
  }
  function onGnbReady() {
    requestAnimationFrame(function() {
      syncGnbOffset();
      // GNB는 스크롤 시 허브 바를 숨기며 body.paddingTop을 변경한다 — 매 스크롤마다 재동기화
      window.addEventListener('scroll', syncGnbOffset, { passive: true });
    });
  }
  window.addEventListener('load', onGnbReady);
` }} />
```

> `onGnbReady` 1회 실행만으로는 스크롤 시 GNB가 허브 바를 숨기며 `body.paddingTop`이 바뀔 때
> 고정 서비스 헤더 위치가 어긋난다. `scroll` 이벤트로 매번 재동기화해야 한다.

```css
/* globals.css */
:root {
  /**
   * GNB 렌더링 전 초기값. onGnbReady에서 실제 값으로 덮어씌워진다.
   * 설정 기준:
   *   - 게임 GNB만 표시되는 서비스: 60px
   *   - 넥슨 허브 바 + 게임 GNB 포함: 116px
   *   - 모를 경우: 116px (콘텐츠가 내려가는 쪽이 GNB에 가려지는 것보다 안전)
   * 실제 높이는 local-{서비스}.nexon.com에서 GNB 로드 후 측정한다.
   */
  --gnb-h: 116px;
}

/* fixed 요소는 var(--gnb-h)로 오프셋 */
.site-header { top: var(--gnb-h); }
```

> ⚠ 앱 루트 컨테이너(`#root`, `.layout` 등) **그리고 페이지 레벨 요소(`<main>`, `<section>`, 페이지 wrapper `<div>` 등)** 에
> `padding-top: var(--gnb-h)`를 지정하면 GNB 높이가 두 배(≈232px)로 적용된다.
> GNB가 `body.paddingTop`을 단독 관리하므로 **어떤 컨테이너에도 `var(--gnb-h)` 기반 `padding-top`을 두지 않는다.**

**❌ 안티패턴 (페이지 컴포넌트 — 가장 흔한 함정):**
```tsx
<main style={{ paddingTop: 'var(--gnb-h)' }}>...</main>
<main style={{ paddingTop: 'calc(var(--gnb-h) + var(--space-12))' }}>...</main>
```

**✅ 올바른 패턴 — 디자인 여백은 `--space-*` 토큰만:**
```tsx
<main style={{ paddingTop: 'var(--space-12)' }}>...</main>
```

> `var(--gnb-h)` 는 **`.site-header` 같은 `position: fixed/sticky` 요소의 `top` 오프셋 전용**이다.
> AI write 시점에 `(padding-top|paddingTop).*var(--gnb-h)` 패턴은 `pre-write-hook.sh` 가 차단한다.

**`body.paddingTop` 선점 금지:**

> ⛔ GNB 로드 전에 아래 두 패턴으로 `body.paddingTop`을 선점하면 절대 안 된다.

```css
/* CSS — 금지 */
body { padding-top: 116px; }
```

```js
/* JS 인라인 — 금지 */
document.body.style.paddingTop = '116px';
```

> 이유: GNB 스크립트는 `body.paddingTop`을 읽어 자신을 그 위치에 고정 렌더링한다.
> 사전에 값이 설정되어 있으면 GNB가 `top:0` 대신 해당 offset에서 렌더링되어
> 빈 공간이 생기고 서비스 헤더가 가려진다.
> `body.paddingTop`은 GNB 스크립트가 단독으로 쓴다. `onGnbReady`에서는 읽기만 한다.

**GNB 폴백 UI 처리:**

```html
<!-- 권장: 역방향 패턴 — GNB 로드 성공을 기본으로 가정, 실패 시만 표시 -->
<div id="gnb-fallback" style="display:none">...</div>
<script>
  // GNB 로드 실패(타임아웃 등) 감지 시 폴백 표시
</script>
```

```js
// 불가피하게 기본 표시 폴백을 쓸 경우 — onGnbReady에서 숨김 처리 필수
function onGnbReady() {
  requestAnimationFrame(function() {
    var fallback = document.getElementById('gnb-fallback');
    if (fallback) fallback.style.display = 'none';  // ← 반드시 추가
    syncGnbOffset();
    window.addEventListener('scroll', syncGnbOffset, { passive: true });
  });
}
```

> 폴백 UI를 기본 표시로 두고 `onGnbReady`에서 숨기지 않으면
> 실제 GNB와 폴백 UI가 동시에 표시되는 이중 레이어가 된다.

**GNB 시뮬레이터 / 커스텀 fixed 상단 바 금지:**

> ⛔ GNB 스크립트가 정상 로드되는 환경에서 아래 요소를 별도로 만들지 않는다.
> - `position: fixed` 커스텀 탭바, 허브 바 목업, GNB 대체 요소
> - body 최상단에 고정 높이를 차지하는 커스텀 헤더
>
> 이유: GNB 스크립트 자체가 탭바·허브 바·게임 GNB를 모두 포함해 렌더링한다.
> 커스텀 요소를 추가하면 실제 GNB와 겹쳐 이중 레이어가 되고 `body.paddingTop` 계산이 깨진다.
>
> 로컬 개발 중 GNB 스크립트 없이 레이아웃을 확인해야 할 경우:
> - `local-{서비스}.nexon.com` 호스트 등록 후 실제 GNB 스크립트를 로드한다
> - 브라우저 개발자 도구에서 `--gnb-h` CSS 변수를 수동으로 설정해 레이아웃을 확인한다

---

## 컴포넌트 작성 규칙

**파일 구조:**
```
ComponentName/
├── index.tsx          ← 진입점 (export만)
├── ComponentName.tsx  ← 구현
├── ComponentName.test.tsx
└── ComponentName.module.css  (CSS Modules 사용 시)
```

**상태 관리 (React 기준 — 다른 프레임워크는 해당 생태계의 동등 패턴 적용):**
- 서버 상태: React Query / SWR (로컬 캐시, 동기화)
- UI 상태: useState / useReducer (컴포넌트 스코프)
- 전역 상태: Context API 또는 Zustand (최소화)

**접근성:**
- 인터랙티브 요소는 키보드로 조작 가능해야 함
- `role`, `aria-label`, `aria-describedby` 적절히 사용
- 색상만으로 정보를 전달하지 않음 (아이콘 또는 텍스트 병행)

---

## inface.js 로드 (INSIGN 인증 프로젝트 필수)

**적용 대상**: `spec.md`에 외부 유저 인증(INSIGN)이 명시된 프로젝트

`window.inface` 객체는 inface.js가 로드된 이후에만 사용할 수 있다.
미로드 시 `window.inface?.auth?.getUserProfile()` 호출이 `undefined`를 반환하여 인증이 동작하지 않는다.

**GNB 없는 프로젝트 (`GNB_REQUIRED = false`):**

```tsx
// app/layout.tsx — <head> 내부
import Script from 'next/script'

// inface-web-auth: 허용 도메인 선언
// *.nexon.com이 아닌 도메인은 /insign 페이지 구현 + insign@nexon.co.kr 도메인 허용 요청 필수
<meta name="inface-web-auth" content={process.env.NEXT_PUBLIC_SERVICE_DOMAIN} />
<Script
  src="https://signin.nexon.com/sdk/inface.js"
  strategy="beforeInteractive"
/>
```

**GNB 있는 프로젝트 (`GNB_REQUIRED = true`):**

GNB 스크립트(ngb_head.js · gnb.min.js 등)는 inface.js를 자동 포함하지 않는다.
`ngb_head.js` 직후에 명시적으로 추가한다:

```tsx
// app/layout.tsx — <head> 내부 (순서 유지)
<Script src={`https://${sslDomain}/s1/global/ngb_head.js`} strategy="beforeInteractive" />
<meta name="inface-web-auth" content={process.env.NEXT_PUBLIC_SERVICE_DOMAIN} />
<Script
  src="https://signin.nexon.com/sdk/inface.js"
  strategy="beforeInteractive"
/>
```

> `NEXT_PUBLIC_SERVICE_DOMAIN`: boilerplate-setup Stage Q7-B에서 수집한 서비스 도메인 (예: `mygame.nexon.com`).
> `*.nexon.com` 외 도메인은 `insign@nexon.co.kr` 도메인 허용 요청이 선행되어야 한다 (refs/policies/authentication-external.md A-2d 참조).

---

## API 호출 패턴 (INFACE API Gateway, Next.js 기준)

> **적용 대상**: Nexon INFACE API Gateway를 사용하는 Next.js 프로젝트. 다른 스택은 해당 프레임워크의 동등 패턴으로 대체한다.

| 환경 | API 경로 | 인증 처리 |
|---|---|---|
| 로컬 | 백엔드 직접 호출 | inface.js에서 uid 추출 → `x-inface-user-uid` 헤더 수동 주입 |
| 스테이지/라이브 | API Gateway 경유 | Gateway가 `x-inface-user-uid` 자동 주입 |

### API 클라이언트

```typescript
// lib/api-client.ts
const USE_GATEWAY = process.env.NEXT_PUBLIC_USE_GATEWAY === 'true'
const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL

declare global {
  interface Window {
    inface?: {
      auth?: {
        getUserProfile?: () => Promise<{ data?: { uid?: string } }>
      }
    }
  }
}

async function getAuthHeaders(): Promise<Record<string, string>> {
  if (USE_GATEWAY) return {}
  // 로컬: inface.js에서 uid 추출 후 헤더로 직접 전달
  const result = await window.inface?.auth?.getUserProfile?.()
  const uid = result?.data?.uid
  return uid ? { 'x-inface-user-uid': uid } : {}
}

export async function apiFetch(path: string, init: RequestInit = {}) {
  const authHeaders = await getAuthHeaders()
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...authHeaders,
      ...init.headers,
    },
  })

  // 401 → /login 으로 리다이렉트 시 원래 경로를 from 쿼리로 보존
  // (로그인 후 사용자가 원래 보려던 화면으로 복귀 가능)
  if (res.status === 401 && typeof window !== 'undefined') {
    const current = window.location.pathname + window.location.search
    // 이미 /login 페이지면 무한 루프 방지 — 호출자가 직접 처리
    if (!window.location.pathname.startsWith('/login')) {
      window.location.assign(`/login?from=${encodeURIComponent(current)}`)
    }
  }

  return res
}
```

> `/login` 페이지에서 로그인 성공 시 `useSearchParams().get('from')` 으로 원래 경로를 읽어
> 안전 검증(같은 origin, `/` 시작) 후 `router.push(from)` 으로 복귀시킨다.

### 환경변수

```bash
# .env.local — INSIGN(HTTPS) 로컬 개발
# ⚠️ HTTPS 프론트에서 http:// 백엔드를 NEXT_PUBLIC_API_BASE_URL로 직접 지정하면
#    브라우저가 Mixed Content로 차단한다. BACKEND_URL + rewrites() 프록시를 사용한다.
BACKEND_URL=http://localhost:8000   # next.config.ts rewrites() 대상 (server-side 전용)
NEXT_PUBLIC_USE_GATEWAY=false
# NEXT_PUBLIC_API_BASE_URL 미설정 → api-client.ts의 API_BASE = '' → rewrites()가 프록시 처리

# .env.production (스테이지/라이브)
NEXT_PUBLIC_API_BASE_URL=https://public.api.nexon.com/{서비스}
NEXT_PUBLIC_USE_GATEWAY=true
```

**주의**: `NEXT_PUBLIC_USE_GATEWAY=true`는 스테이지/라이브에만 설정. 로컬에서 `true`로 설정하면 uid가 전달되지 않아 모든 인증 API가 401을 반환한다.

### 로컬 개발 API 프록시 (next.config.ts)

로컬에서 프론트엔드 → 백엔드 API 호출 시 CORS 문제를 피하려면 Next.js 개발 서버를 프록시로 사용한다.

**⚠️ Self-referencing proxy 방지 필수**

`BACKEND_URL`이 Next.js 서버와 동일 포트이면 자기 자신에게 무한 프록시가 발생한다.
`isSelfProxy` 체크로 이를 방지한다.

```typescript
// next.config.ts
import type { NextConfig } from 'next'

const backendUrl = process.env.BACKEND_URL;

// BACKEND_URL이 미설정이거나 Next.js 서버 자신을 가리키면 rewrites 비활성화
const isSelfProxy =
  !backendUrl ||
  backendUrl.includes("localhost:3000") ||
  backendUrl.includes("127.0.0.1:3000");

const nextConfig: NextConfig = {
  allowedDevOrigins: [
    process.env.NEXT_PUBLIC_LOCAL_HOST ?? 'localhost',
  ],
  async rewrites() {
    if (isSelfProxy) return [];  // self-proxy 방지 — API Routes를 Next.js가 직접 처리
    return [
      {
        source: '/api/v1/:path*',
        destination: `${backendUrl}/api/v1/:path*`,
      },
    ]
  },
}

export default nextConfig
```

> **사용 패턴**: 프론트+백 통합(Next.js API Routes만 사용) 시 `BACKEND_URL` 미설정 → `isSelfProxy=true` → rewrites 비활성.
> 분리된 백엔드 서버가 있을 때만 `BACKEND_URL=http://localhost:8000` (포트 다름) 설정.

```typescript
// lib/api-client.ts — API_BASE를 빈 문자열로 고정, rewrites()가 프록시 처리
const API_BASE = ''  // next.config.ts rewrites()로 /api/v1/* → 백엔드 프록시

// 로컬에서 inface.js 미설치 환경 대비 DEV_UID 폴백
async function getAuthHeaders(): Promise<Record<string, string>> {
  if (USE_GATEWAY) return {}
  const result = await window.inface?.auth?.getUserProfile?.()
  const uid = result?.data?.uid ?? process.env.NEXT_PUBLIC_DEV_UID  // 로컬 개발용 폴백
  return uid ? { 'x-inface-user-uid': uid } : {}
}
```

```bash
# .env.local 추가 항목
# 분리된 백엔드가 있을 때만 설정 (포트 3000과 다른 포트 사용)
# BACKEND_URL=http://localhost:8000
NEXT_PUBLIC_LOCAL_HOST=local-{서비스}.nexon.com  # hosts 등록된 로컬 호스트
NEXT_PUBLIC_DEV_UID=                              # 로컬에서 inface.js 없을 때 테스트용 uid (NODE_ENV=development 가드 필수)
```

---

## SSR/하이드레이션 안전 패턴 (Next.js)

> 아래 규칙 위반은 개발 모드에서 "1 Issue" 오버레이로 나타나며,
> 프로덕션에서 콘솔 에러를 유발한다.

### 1. new Date() 서버 컴포넌트 직접 사용 금지

```typescript
// ❌ 금지 — SSR과 CSR의 new Date() 값이 다름 (타임존·시점 차이)
<div>{new Date().getFullYear()}년 {new Date().getMonth() + 1}월</div>

// ✅ useClientDate() 훅 사용 (클라이언트에서만 계산)
function useClientDate(): Date | null {
  const [now, setNow] = useState<Date | null>(null);
  useEffect(() => { setNow(new Date()); }, []);
  return now;
}

// 사용:
const now = useClientDate();
<div>{now ? `${now.getFullYear()}년 ${now.getMonth() + 1}월` : "..."}</div>
```

### 2. dangerouslySetInnerHTML 인라인 스크립트 — DOM 직접 조작 금지

```typescript
// ❌ 금지 — hydration 전에 DOM을 수정하면 서버/클라이언트 불일치 발생
<script dangerouslySetInnerHTML={{ __html: `
  document.documentElement.style.setProperty('--gnb-h', '60px');  // ← 하이드레이션 불일치
` }} />

// ✅ useEffect로 이관 — hydration 완료 후 실행
useEffect(() => {
  const h = parseInt(getComputedStyle(document.body).paddingTop, 10) || 60;
  document.documentElement.style.setProperty('--gnb-h', h + 'px');
}, []);

// 단, onGnbReady 콜백 선언 스크립트는 DOM 조작 없이 허용:
<script dangerouslySetInnerHTML={{ __html: `function onGnbReady(){}` }} />
```

### 3. toLocaleString() 직접 렌더링

```typescript
// ❌ 서버/클라이언트 로케일 차이로 불일치 가능
<em>{value.toLocaleString()}</em>

// ✅ suppressHydrationWarning 또는 클라이언트 상태
<em suppressHydrationWarning>{value?.toLocaleString() ?? "—"}</em>
```

---

