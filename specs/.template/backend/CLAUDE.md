# 백엔드 전용 지침

> 이 파일은 `backend/` 디렉토리에서 작업할 때 루트 `CLAUDE.md`에 추가로 로드된다.
> 루트 CLAUDE.md의 헌법·공통 규칙이 먼저 적용되며, 이 파일은 백엔드 전용 규칙을 정의한다.
> **Claude Code 기반 개발을 전제한다.**

---

## 빌드 검사 (백엔드)

소스 파일 수정 후 **같은 턴에서** 빌드 검사를 실행한다:

| 스택 | 명령 |
|---|---|
| Python (FastAPI/Django) | `pytest` |
| Node.js | `npm run build` |

실패 시 수정 후 재검사. 연속 2회 실패 시 세션 체크포인트를 생성하고 사용자에게 보고한다.

---

## 테스트 커버리지 (백엔드)

| 코드 유형 | 필수 테스트 |
|---|---|
| API 엔드포인트 | 정상 응답 + 에러 응답 (최소 2개) |
| 비즈니스 로직 함수 | 정상 케이스 + 엣지 케이스 (최소 2개) |
| 인증/인가 로직 | 인증 성공 + 실패 + 권한 부족 (최소 3개) |

**테스트 불필요:** 설정 파일 변경, 타입 정의 파일, 마이그레이션 파일

| 스택 | 프레임워크 |
|---|---|
| Python | pytest |
| Node.js | vitest 또는 jest |

### 커버리지 임계값 강제 (필수)

threshold 가 없으면 회귀가 silent 통과한다. CI 신호로 가치를 갖도록 임계값을 명시한다.

**Node.js (vitest)** — `vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary"],
      thresholds: {
        lines: 70,        // 신규 프로젝트 기본 — 도메인에 따라 상향 가능
        functions: 70,
        branches: 60,
        statements: 70,
      },
      include: ["src/**/*.ts"],
      exclude: ["src/**/*.d.ts", "src/types/**", "src/**/__tests__/**"],
    },
  },
});
```

**Python (pytest-cov)** — `pyproject.toml` 또는 `pytest.ini`:

```toml
[tool.coverage.report]
fail_under = 70
```

> tasks.md 에서 `coverage:` done 기준을 쓰려면 먼저 `cmd:` 로 리포트를 생성해야 한다
> (`pytest --cov ... --cov-report=json` / `vitest run --coverage`).

---

## 환경변수 관리 (백엔드)

- 코드에 환경별 값을 직접 넣지 않는다 (폴백 하드코딩 포함)
- 외부 연동 변수는 모든 환경에서 실제 값이 필수 (Real-first 정책)
- `.env.example`에만 키를 커밋하고, 실제 값이 담긴 `.env*`는 gitignore

> **Python 예시** (Node.js 등 다른 스택은 해당 프레임워크의 동등 패턴 적용):

```python
# ❌ 금지
DB_HOST = os.getenv("DB_HOST", "192.168.1.1")

# ✅ 권장
def require_env(key: str) -> str:
    value = os.getenv(key)
    if not value:
        raise RuntimeError(f"Required environment variable {key} is not set")
    return value

DB_HOST = require_env("DB_HOST")
```

새 환경변수 추가 시: `.env.example`에 키·설명·필수 여부 추가 → `require_env()`로 참조 → `integration-registry.md` 갱신.

### CORS 설정 (환경변수 기반 필수, Python/FastAPI 기준)

> Node.js(Express/Fastify 등)는 해당 프레임워크의 동등 CORS 미들웨어 패턴 적용.

CORS `allow_origins`는 `["*"]`로 초기화하지 않는다.
프로젝트 생성 시점부터 환경변수 기반으로 설정한다.

```python
# app/config.py
from pydantic_settings import BaseSettings
from pydantic import validator

class Settings(BaseSettings):
    cors_origins: list[str] = ["http://localhost:3000"]

    @validator("cors_origins", pre=True)
    def parse_cors_origins(cls, v):
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v
```

```python
# app/main.py
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)
```

```bash
# .env.example — HTTPS 필수 (INSIGN _ifwt 쿠키는 HTTPS에서만 동작)
CORS_ORIGINS=https://dev-{서비스}.nexon.com
# 스테이지: CORS_ORIGINS=https://test-{서비스}.nexon.com
# 라이브:   CORS_ORIGINS=https://{서비스}.nexon.com
```

---

## 레이어 아키텍처

```
router/       ← HTTP 요청 파싱, 응답 직렬화만
service/      ← 비즈니스 로직 (단독 테스트 가능)
repository/   ← DB 접근 추상화
models/       ← 도메인 모델 (로직 없음)
```

레이어 간 규칙:
- router → service만 호출 (repository 직접 호출 금지)
- service → repository만 호출 (HTTP 컨텍스트 참조 금지)
- 레이어 간 데이터 전달은 DTO/Schema 사용

---

## API Route 구현 필수 규칙

> 아래 규칙 위반은 subagent-review Security/Architecture 리뷰에서 Blocker로 탐지된다.

### 1. 사용자 식별은 반드시 서버 헬퍼 함수 경유

```typescript
// ❌ 금지 — 클라이언트가 body 값을 위조할 수 있음
const uid = req.body.uid;
const nexonId = req.body.nexonId;
const memberSn = req.headers.get("x-inface-user-membersn") ?? "";  // 폴백 없는 직접 읽기

// ✅ 필수 — lib/auth.ts 헬퍼 함수 사용
import { getUid, getMemberSn, requireAuth } from "@/lib/auth";
const uid = requireAuth(req);          // null이면 401 throw
const memberSn = getMemberSn(req);    // DEV_MEMBER_SN 폴백 포함
```

`lib/auth.ts` 필수 포함 함수:

```typescript
// lib/auth.ts
import { NextRequest, NextResponse } from "next/server";

// uid 획득 (로컬: DEV_UID 폴백, 프로덕션: Gateway 헤더)
export function getUid(req: NextRequest): string | null {
  return (
    req.headers.get("x-inface-user-uid") ??
    (process.env.NODE_ENV === "development" ? (process.env.DEV_UID ?? null) : null)
  );
}

// memberSn 획득 (로컬: DEV_MEMBER_SN 폴백)
export function getMemberSn(req: NextRequest): string | null {
  return (
    req.headers.get("x-inface-user-membersn") ??
    (process.env.NODE_ENV === "development" ? (process.env.DEV_MEMBER_SN ?? null) : null)
  );
}

// 인증 필수 엔드포인트 — null이면 401 반환
export function requireAuth(req: NextRequest): string {
  const uid = getUid(req);
  if (!uid) throw new Error("UNAUTHORIZED");
  return uid;
}
```

### 2. 복합 쓰기 작업은 트랜잭션 필수 (Prisma 기준)

```typescript
// ❌ 금지 — A 성공 후 B 실패 시 orphan 레코드 발생
const a = await prisma.challenge.create({ data: { ... } });
await prisma.participation.create({ data: { challengeId: a.id, ... } });

// ✅ 필수 — 원자적 처리
const result = await prisma.$transaction(async (tx) => {
  const a = await tx.challenge.create({ data: { ... } });
  const b = await tx.participation.create({ data: { challengeId: a.id, ... } });
  return { a, b };
});
```

### 3. 정원/한도 체크 후 쓰기 — TOCTOU 방지

```typescript
// ❌ 금지 — count와 create 사이에 다른 요청이 끼어들 수 있음
const count = await prisma.participation.count({ where: { challengeId: id } });
if (count >= maxParticipants) throw new Error("FULL");
await prisma.participation.create({ data: { ... } });  // 31번째 사용자 생성 가능

// ✅ 필수 — Serializable 트랜잭션으로 레이스 컨디션 방지
await prisma.$transaction(async (tx) => {
  const count = await tx.participation.count({ where: { challengeId: id, status: "active" } });
  if (count >= maxParticipants) throw new Error("FULL");
  return tx.participation.create({ data: { ... } });
}, { isolationLevel: "Serializable" });
```

### 4. 집계 쿼리 — take/limit 기반 `.length` 금지

```typescript
// ❌ 금지 — take:60 이후 총 인증 횟수가 60으로 고정
const p = await prisma.participation.findUnique({
  include: { checkIns: { take: 60 } }
});
const totalCheckins = p.checkIns.length;  // 최대 60

// ✅ 필수 — _count 사용
const p = await prisma.participation.findUnique({
  include: {
    _count: { select: { checkIns: true } },   // 전체 카운트
    checkIns: { orderBy: { checkedAt: "desc" }, take: 60 },  // 스트릭 계산용
  }
});
const totalCheckins = p._count.checkIns;  // 정확한 전체 값
```

### 5. 날짜 계산 — 타임존 유틸리티 사용

UTC 서버 배포 시 `new Date() + setHours(0,0,0,0)`은 KST와 9시간 오차가 발생한다.

```typescript
// lib/date.ts — KST 기준 날짜 처리
export function getKSTToday(): { today: Date; tomorrow: Date } {
  const now = new Date();
  const kstOffset = 9 * 60 * 60 * 1000;
  const kst = new Date(now.getTime() + kstOffset);
  kst.setUTCHours(0, 0, 0, 0);
  const today = new Date(kst.getTime() - kstOffset);
  const tomorrow = new Date(today.getTime() + 86_400_000);
  return { today, tomorrow };
}

// 사용:
const { today, tomorrow } = getKSTToday();
const existing = await prisma.checkIn.findFirst({
  where: { checkedAt: { gte: today, lt: tomorrow } }
});
```

> 또는 서버 환경변수 `TZ=Asia/Seoul`을 설정하면 `new Date()`가 KST 기준으로 동작한다.

### 5-1. 사용자 입력 날짜 — round-trip 검증 필수

`new Date("2026-02-30")` 은 throw 하지 않고 `2026-03-02` 로 **자동 보정** 한다. 윤일·존재하지
않는 날짜를 사용자가 입력하면 silent 변형되어 데이터 일관성이 깨진다. round-trip 검증으로 차단:

```typescript
// lib/date.ts
/**
 * "YYYY-MM-DD" 형식의 날짜 문자열을 검증·파싱한다.
 * 자동 보정(2026-02-30 → 2026-03-02)을 round-trip 으로 감지하여 거부한다.
 */
export function parseDateStrict(input: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(input)) {
    throw new Error(`Invalid date format: ${input} (expected YYYY-MM-DD)`);
  }
  const d = new Date(`${input}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) {
    throw new Error(`Invalid date: ${input}`);
  }
  // round-trip 검증 — 입력과 다시 직렬화한 값이 다르면 자동 보정된 것
  const roundtrip = d.toISOString().slice(0, 10);
  if (roundtrip !== input) {
    throw new Error(`Invalid calendar date: ${input} (auto-corrected to ${roundtrip})`);
  }
  return d;
}
```

> 사용자 입력 → DB 저장 전 반드시 이 헬퍼를 경유. `Date(input)` 직접 사용 금지.

---

## INFACE API Gateway 인증

백엔드는 `x-inface-user-uid` 헤더 유무로 로그인 여부만 판별한다.
토큰 검증은 API Gateway가 처리하므로 백엔드에 검증 로직을 두지 않는다.

| 환경 | 헤더 출처 |
|---|---|
| 스테이지/라이브 | Gateway가 토큰 검증 후 자동 주입 |
| 로컬 개발 | 프론트엔드가 inface.js에서 uid 추출 후 직접 주입 |

---

### 인증 미들웨어 — Node.js / Express (TypeScript)

#### 환경변수 필수값 검증 (`lib/env.ts`)

```typescript
// lib/env.ts
export function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) throw new Error(`Required environment variable ${key} is not set`);
  return value;
}

// 화이트리스트 검증 — 잘못된 환경값을 부팅 단에서 즉시 차단
export function requireOneOf<T extends string>(key: string, allowed: readonly T[]): T {
  const value = requireEnv(key);
  if (!(allowed as readonly string[]).includes(value)) {
    throw new Error(`${key} must be one of [${allowed.join(", ")}], got "${value}"`);
  }
  return value as T;
}

// APP_ENV 별 환경 키 fail-closed 검증 — index.ts 부팅 시 즉시 호출
// 운영 환경에서 인증 비밀이 비어 있으면 즉시 boot 실패 (런타임 우회 차단)
const APP_ENV_VALUES = ["local", "dev", "test", "live"] as const;
export function assertEnvForApp(): void {
  const appEnv = requireOneOf("APP_ENV", APP_ENV_VALUES);

  // 운영 등급(local 외)은 INFACE_API_KEY 필수 — 빈 값이면 인증 우회 가능성 차단
  if (appEnv !== "local") {
    requireEnv("INFACE_API_KEY");
  }

  // CORS_ORIGINS 도 항상 필수 — 누락 시 와일드카드 폴백을 막는다
  requireEnv("CORS_ORIGINS");
}
```

`index.ts` 에서 dotenv 로드 직후 호출:

```typescript
import { assertEnvForApp } from "./lib/env";
assertEnvForApp();  // ← 부팅 단 fail-fast (운영에서 비밀 누락 시 boot 실패)
```

#### 인증 헬퍼 (`lib/auth.ts`)

```typescript
// lib/auth.ts
import type { Request } from "express";

export interface InfaceUser {
  uid: string;
}

export interface AuthRequest extends Request {
  infaceUser: InfaceUser;
}

// uid 획득 — 헤더 출처(Gateway vs 로컬 프론트)를 구분하지 않는다
export function getUid(req: Request): string | null {
  const uid = req.headers["x-inface-user-uid"];
  return typeof uid === "string" && uid ? uid : null;
}

// 인증 필수 미들웨어 — uid 없으면 401
export function requireAuth(req: Request): string {
  const uid = getUid(req);
  if (!uid) throw Object.assign(new Error("Unauthorized"), { status: 401 });
  return uid;
}
```

#### 인증 미들웨어 (`middleware/auth.ts`)

로컬 환경에서는 Gateway가 없으므로 백엔드가 API Key와 Authorization 헤더를 직접 검증한다.
스테이지/라이브에서는 Gateway가 검증을 완료한 뒤 `x-inface-user-uid`를 주입하므로 uid 헤더만 읽는다.

```typescript
// middleware/auth.ts
import type { Request, Response, NextFunction } from "express";
import { getUid } from "../lib/auth";
import type { AuthRequest } from "../lib/auth";

const APP_ENV = process.env.APP_ENV ?? "local";

export function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  if (APP_ENV === "local") {
    // 로컬: Gateway 없음 — API Key + Authorization 헤더를 백엔드가 직접 검증
    const apiKey = req.headers["x-inface-api-key"];
    if (!apiKey || apiKey !== process.env.INFACE_API_KEY) {
      res.status(403).json({ error: { name: "forbidden", message: "Invalid API Key" } });
      return;
    }
    const authorization = req.headers["authorization"];
    if (!authorization || !authorization.startsWith("Web ")) {
      res.status(401).json({ error: { name: "unauthorized", message: "Missing Authorization header (expected: Web <token>)" } });
      return;
    }
  }

  // 모든 환경 공통: Gateway(운영) 또는 프론트(로컬)가 주입한 uid 헤더 읽기
  const uid = getUid(req);
  if (!uid) {
    res.status(401).json({ error: { name: "unauthorized", message: "Missing x-inface-user-uid" } });
    return;
  }
  (req as AuthRequest).infaceUser = { uid };
  next();
}
```

라우터에서 사용:

```typescript
// routes/items.ts
import { Router } from "express";
import { authMiddleware } from "../middleware/auth";
import type { AuthRequest } from "../lib/auth";

const router = Router();

router.get("/items", authMiddleware, (req, res) => {
  const { uid } = (req as AuthRequest).infaceUser;
  // ...
});

// ⚠ POST/PUT/DELETE/PATCH 등 모든 변경 엔드포인트에 authMiddleware 적용 필수
router.post("/items", authMiddleware, (req, res) => { /* ... */ });
router.delete("/items/:id", authMiddleware, (req, res) => { /* ... */ });
```

#### dotenv 로드 (`index.ts` 최상단 — 반드시 첫 줄)

`requireEnv` 가 동작하려면 `process.env` 가 채워져 있어야 한다. `.env.local`(gitignore 대상,
개발 시 실제 값) 을 우선 로드하고 `.env` 로 폴백하는 패턴을 표준으로 적용한다.

```typescript
// index.ts — 다른 어떤 import 보다 먼저 실행되어야 한다
import path from "node:path";
import { config as loadEnv } from "dotenv";

// ① .env.local 우선 (gitignore 대상, 개인 개발자 실제 값)
loadEnv({ path: path.join(process.cwd(), ".env.local") });
// ② .env 폴백 (커밋되는 공유 기본값) — 이미 채워진 키는 덮어쓰지 않음
loadEnv({ path: path.join(process.cwd(), ".env") });
```

`package.json` dependencies 에 `dotenv` 포함 필수 — devDependencies 아님 (런타임에 로드되므로).

> ⚠️ **NestJS** 는 `ConfigModule.forRoot({ envFilePath: [".env.local", ".env"] })` 로 동일 효과를
> 얻을 수 있으므로 별도 `dotenv` import 불필요. Express/Fastify 등 경량 프레임워크에서만 위 패턴 사용.

#### CORS 환경별 설정 (`index.ts`)

`credentials: true` 와 배열 형태 origin 을 함께 쓰면 `Origin: null` (file://, sandboxed iframe,
data: URL 등) 요청이 통과될 수 있다. **함수형 origin** 으로 화이트리스트 매칭 + Origin 헤더
누락·`"null"` 명시 거부 패턴을 표준으로 사용한다.

```typescript
// index.ts (위의 dotenv 로드 + assertEnvForApp() 다음에 이어짐)
import express from "express";
import cors, { type CorsOptions } from "cors";
import { requireEnv } from "./lib/env";

const APP_ENV = requireEnv("APP_ENV");
const PORT    = requireEnv("PORT");

// CORS_ORIGINS 는 환경변수로 받아 콤마로 분리 — 코드 내 하드코딩 폴백 금지
// 와일드카드("*") 는 credentials:true 와 호환 불가 + 보안 위험 → 명시 차단
function parseCorsOrigins(): Set<string> {
  const raw = requireEnv("CORS_ORIGINS");
  const list = raw.split(",").map((s) => s.trim()).filter(Boolean);
  if (list.includes("*")) {
    throw new Error("CORS_ORIGINS must not include '*' — explicit list required");
  }
  return new Set(list);
}
const CORS_WHITELIST = parseCorsOrigins();

const corsOptions: CorsOptions = {
  // 함수형 origin: 헤더 누락(undefined) / "null" 문자열 / 화이트리스트 외 모두 거부
  origin(origin, cb) {
    if (!origin || origin === "null") return cb(new Error("Origin required"));
    if (!CORS_WHITELIST.has(origin)) return cb(new Error(`Origin not allowed: ${origin}`));
    cb(null, true);
  },
  credentials: true,
  maxAge: 600,  // preflight 캐시 — 명시값으로 브라우저 기본값 의존 제거
};

const app = express();
app.use(cors(corsOptions));
app.use(express.json({ limit: "16kb" }));  // 본문 한도 명시 — 운영 DoS 방어

app.listen(Number(PORT), () => {
  console.log(`Server listening on http://localhost:${PORT} (env=${APP_ENV})`);
});
```

`.env.example`:

```bash
APP_ENV=local                                   # 필수: local | dev | test | live
PORT=4000                                       # 필수
INFACE_API_KEY=                                 # local 외 환경 필수
CORS_ORIGINS=https://local-{서비스}.nexon.com   # 필수: 콤마로 분리, 와일드카드 금지
```

> `.env.local` 은 `.gitignore` 대상 — 개인 개발자가 실제 값(API 키, DB 비밀번호 등)을 채우고,
> `.env.example` 을 복사해 시작한다. `.env` 는 공유 기본값(개발 환경 placeholder) 만 담아 커밋한다.

---

### 인증 미들웨어 — Python/Django

```python
# middleware/inface_auth.py

class InfaceAuthMiddleware:
    """
    x-inface-user-uid 헤더 유무로 로그인 여부 판별.
    Gateway 경유 시 Gateway 주입, 로컬에서는 프론트가 직접 주입.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request.user_uid = request.META.get("HTTP_X_INFACE_USER_UID")
        return self.get_response(request)
```

```python
# decorators.py
from functools import wraps
from django.http import JsonResponse

def login_required(view_func):
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if not request.user_uid:
            return JsonResponse({"error": "Unauthorized"}, status=401)
        return view_func(request, *args, **kwargs)
    return wrapper
```

`settings.py` MIDDLEWARE에 등록:

```python
MIDDLEWARE = [
    # ... 기존 미들웨어 ...
    "app.middleware.inface_auth.InfaceAuthMiddleware",
]
```

엔드포인트 보호:

```python
# views.py
@login_required
def my_view(request):
    uid = request.user_uid  # 로그인된 유저 uid
    ...
```

**주의**: 백엔드에 별도 인증 환경변수는 불필요. 헤더만 읽는다.

### 공통 인증 의존성 — FastAPI `deps.py` 패턴 (필수)

인증 의존성을 각 라우터에 개별 정의하면 DRY 위반이다.
`app/api/deps.py`에 한 곳에서 정의하고 모든 라우터에서 임포트한다.

```python
# app/api/deps.py
from fastapi import Header, HTTPException, status

async def require_uid(x_inface_user_uid: str | None = Header(default=None)) -> str:
    if not x_inface_user_uid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized")
    return x_inface_user_uid
```

```python
# app/api/v1/items.py — 사용 예
from fastapi import APIRouter, Depends
from app.api.deps import require_uid

router = APIRouter()

@router.get("/items")
async def list_items(uid: str = Depends(require_uid)):
    ...

@router.delete("/items/{id}")  # DELETE도 반드시 인증 적용
async def delete_item(id: int, uid: str = Depends(require_uid)):
    ...
```

> ⚠ `GET` 외 모든 변경 엔드포인트(`POST`, `PUT`, `DELETE`, `PATCH`)에 `require_uid` 의존성을 빠짐없이 적용한다.
> 누락 시 서브에이전트 보안 리뷰에서 CRITICAL로 탐지된다.

---

### 테스트 픽스처 공통화 (필수)

> **Python/pytest + SQLAlchemy 기준.** Node.js 프로젝트는 vitest/jest의 `beforeEach`/`afterEach` 또는 별도 fixture 유틸로 대체한다.

#### `conftest.py` (Python/pytest)

`tests/conftest.py`가 없으면 DB 픽스처가 테스트마다 중복 정의된다.
프로젝트 시작 시 반드시 아래 구조를 기본으로 생성한다.

```python
# tests/conftest.py
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database import Base, get_db

TEST_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="function")
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def client(db):
    def override_get_db():
        yield db
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()

@pytest.fixture
def auth_headers() -> dict:
    return {"x-inface-user-uid": "test-uid-123"}
```

> 통합 테스트에서 인증이 필요한 엔드포인트는 `auth_headers` 픽스처를 사용한다:
> `client.get("/api/v1/items", headers=auth_headers)`

---

