---
name: integrate-external-system
description: 외부 시스템 연동 — Real-first 직접 구현. 외부 시스템 연동, PRE 항목 해결, 실제 연동 요청 시 사용.
---

# 외부 시스템 연동 (Real-first)

외부 시스템과의 연동을 수행한다.
**연동 단위별로 실제 값으로 연결 → 테스트 → 통과** 후 다음으로 진행한다.

> CLAUDE.md의 `env-management` 규칙의 Real-first 정책을 따른다.

## 트리거

- "외부 시스템 연동해줘"
- "PRE 항목 해결해줘"
- "실제 연동해줘"
- "Real-first로 구현해줘"

## 전제 조건

- `integration-registry.md`가 존재해야 한다 (없으면 "`analyze-integrations 실행해줘`를 입력하세요" 안내)
- `prerequisites.md`의 해당 시스템 🔴 항목이 모두 ✅
- 모든 필수 환경변수가 `.env.local`에 설정

미해결 항목이 있으면 "`collect-prerequisites 실행해줘`를 입력하세요"로 먼저 해결을 안내한다.

---

## R-Step 1: Prerequisite 확인

prerequisites.md를 읽고 해당 시스템의 모든 🔴 항목이 ✅인지 확인한다.

```
📋 {시스템명} 연동 준비 상태

| # | 필요한 항목 | 준비 상태 | ENV 변수명 |
|---|---|---|---|
| 1 | {항목} | ✅ 준비됨 / ⬜ 미준비 | {ENV_KEY} |

{모두 ✅이면} → 구현을 시작합니다.
{⬜가 있으면} → ⛔ {N}개 미준비. collect-prerequisites 실행 후 재시도.
```

---

## R-Step 2: 스펙 확인 — refs 우선 참조

integration-registry.md의 스펙을 기반으로, 불분명하거나 누락된 항목은 아래 순서로 보완한다:

1. `refs/INDEX.md` 빠른 결정 가이드 확인
2. `refs/policies/` 관련 파일 확인
3. GameScale 관련 항목은 `refs/gamescale-docs-index.md`에서 키워드로 카테고리 찾기
   → `refs/gamescale-docs/public/docs/ko/{경로}` 직접 읽기
4. 위 경로에서 찾지 못한 항목만 사용자에게 질문

확인 항목:
- Base URL (환경별: 개발 / 테스트 / 라이브)
- 인증 방식 및 토큰 형식
- 엔드포인트 목록 및 요청·응답 스펙
- 에러 코드 체계

---

## R-Step 3: 연동 코드 구현

CLAUDE.md 헌법의 아키텍처 원칙에 따라 구현한다:
- `service/` 레이어에 외부 시스템 클라이언트 구현
- `repository/` 패턴으로 추상화
- 환경변수는 `requireEnv()` 패턴 사용

### 하이브리드 Mock 패턴 (로컬 개발 필수 적용)

> **적용 대상**: 로컬 개발 환경에서 실패하거나 느린 외부 API (샌드박스 401, 타임아웃, 오프라인)
> 매 요청마다 실패 후 fallback하는 방식은 노이즈·지연·빈 데이터 문제를 일으킨다.
> `USE_{SERVICE}_MOCK` 환경변수로 mock/실제 호출을 분기하는 패턴을 기본으로 적용한다.

```typescript
// lib/{service}-api.ts 표준 패턴 (TypeScript / Next.js 기준)
const IS_DEV = process.env.NODE_ENV === "development";
const USE_MOCK = IS_DEV && process.env.USE_{SERVICE}_MOCK !== "false";

// Mock 데이터 (실제 API 응답 구조와 동일하게 작성)
const MOCK_DATA = {
  // 유의미한 샘플 데이터 — 빈 배열 금지 (UI 전체 경로 검증 불가)
  items: [
    { id: "1", title: "샘플 항목 1", createdAt: new Date(Date.now() - 3_600_000).toISOString() },
    { id: "2", title: "샘플 항목 2", createdAt: new Date(Date.now() - 86_400_000).toISOString() },
  ],
};

export async function fetchItems(...): Promise<ItemList> {
  if (USE_MOCK) {
    return MOCK_DATA;  // 즉시 반환, 외부 호출 없음 (~5ms)
  }
  try {
    return await callExternalApi(...);
  } catch (e) {
    if (IS_DEV) {
      console.warn("[{service}-api] dev fallback:", String(e));
      return MOCK_DATA;  // USE_MOCK=false인 경우에도 실패 시 fallback
    }
    throw e;  // 프로덕션에서는 에러 전파
  }
}

// 쓰기 작업 Mock — payload를 로깅하여 실제 호출 없이 검증
export async function sendData(payload: unknown): Promise<void> {
  if (USE_MOCK) {
    console.log("[{service}-api mock] sendData →", JSON.stringify(payload, null, 2));
    return;
  }
  await callExternalApiWrite(payload);
}
```

`.env.example`에 추가:

```dotenv
# ── {SERVICE} 외부 API Mock 제어 ─────────────────────────────────────────────
# development 환경 기본값: mock 사용 (외부 호출 없음, ~5ms 즉시 응답)
# 실제 sandbox 호출 원할 때: USE_{SERVICE}_MOCK=false
# USE_{SERVICE}_MOCK=false
```

| 환경 | `USE_MOCK` | 동작 |
|---|---|---|
| `development` (기본) | `true` | 외부 호출 없이 즉시 mock 응답 |
| `development` + `USE_{SERVICE}_MOCK=false` | `false` | 실제 sandbox 호출 (실패 시 dev fallback) |
| `production` | `false` | 실제 API 호출 (실패 시 에러 전파) |

**에러 응답 표준:**

upstream 실패 시 성공(200)으로 위장하지 않는다:
```typescript
// ❌ 위장 금지 — 클라이언트가 에러와 정상을 구분 불가
return { items: [], _fallback: true };  // 200 반환

// ✅ 권장 — 명시적 에러 상태
if (!USE_MOCK && error) {
  return NextResponse.json({ error: "Upstream error" }, { status: 502 });
}
```

---

## R-Step 4: 연결 테스트 실행

구현 후 즉시 연결 테스트를 실행한다:

```bash
# 서버 헬스체크
curl -sI {BASE_URL}/health

# 인증 테스트
curl -H "Authorization: Bearer {TOKEN}" {BASE_URL}/auth/verify
```

테스트 실패 시:
- Connection refused → URL/포트 확인
- 401 → 인증 토큰 확인
- 403 → IP 화이트리스트 등록 요청
- Timeout → VPN/방화벽 확인

---

## R-Step 5: 테스트 코드 작성

CLAUDE.md의 `ensure-test-coverage` 규칙에 따라 테스트를 작성한다.
외부 호출은 mock 처리한다 (런타임 개발 환경 우회가 아닌 테스트 격리).

---

## R-Step 6: 완료 보고

```
✅ {시스템명} 연동 완료

- 구현: service/{시스템명}.{ts|py}
- 테스트: tests/service/{시스템명}.test.{ts|py}
- 연결 테스트: ✅ 통과

integration-registry.md, prerequisites.md 상태 업데이트 완료.
```
