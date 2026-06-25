---
name: analyze-integrations
description: 외부 연동 시스템의 실제 스펙을 체계적으로 분석·수집. 연동 분석, 외부 API 스펙 확인, integration registry 작성 요청 시 사용.
---

# 외부 연동 분석 워크플로

프로젝트가 연동하는 외부 시스템의 실제 스펙을 체계적으로 분석한다.
신규 개발과 레거시 마이그레이션 모두에 적용된다.

## 트리거

- "연동 분석해줘"
- "외부 API 스펙 확인해줘"
- "integration registry 작성해줘"
- "연동 정보 정리해줘"
- `/create-spec` Step 2.5 완료 후 외부 시스템이 있는 프로젝트

## 기본 원칙

- 연동 스펙은 **구현 전에** 확보한다.
- "확인 불가"는 정당한 결과이다 — 확인 불가로 표시하고 담당자 확인 경로를 기록한다.
- 추론한 정보는 반드시 **⚠️ 추론** 태그를 붙인다.

---

## Step 1: 연동 시스템 식별

### 1-1. 정보 수집

다음 소스에서 외부 연동 시스템 목록을 추출한다:

| 우선순위 | 소스 | 추출 대상 |
|---|---|---|
| 1 | PRD (또는 spec.md) | "연동", "외부 API", "DB", "SOAP", "호출" 키워드 |
| 2 | CLAUDE.md 헌법 | 기술 스택에서 외부 서비스 |
| 3 | prerequisites.md | 사전 확인 필요 외부 시스템 |
| 4 | 기존 소스 코드 (마이그레이션 시) | import, HttpClient, ConnectionString |

### 1-2. 연동 시스템 분류

| 분류 | 설명 |
|---|---|
| **공개 API** | 공개 문서가 있는 외부 서비스 (Stripe, Google Maps 등) |
| **사내 API** | 사내 내부 네트워크의 HTTP API (Memberapi, 빌링 API 등) |
| **사내 DLL/SDK** | 사내 배포 바이너리 |
| **SOAP 서비스** | WSDL 기반 웹 서비스 |
| **데이터베이스** | SP 호출 또는 직접 쿼리 |
| **메시지 큐** | Kafka, RabbitMQ, SQS |

→ 사용자 확인: "누락된 연동 시스템이 있나요?"

---

## Step 2: 시스템별 스펙 수집

### 공개 API
WebSearch로 공식 문서 검색 → 필요한 엔드포인트 스펙 추출.

### 사내 API
`refs/INDEX.md` → `refs/policies/` → `refs/gamescale-docs-index.md` 순으로 참조.
부족한 항목은 사용자에게 질문.

```
🔶 {시스템명} 연동 스펙 미확인 항목:
| # | 항목 | 필요한 이유 | 확인 방법 |
| 1 | Base URL | API 호출 대상 | 담당팀 문의 |
지금 알려줄 수 있는 항목이 있나요?
```

### 사내 DLL/SDK
DLL 호출 코드에서 파라미터·반환값 추출 → 내부 구현은 "확인 불가"로 표시.

### 데이터베이스
Connection String에서 서버/포트/DB명 추출 (비밀번호 제외) → SP 목록 추출.

---

## Step 3: integration-registry.md 작성

`specs/{NNN}-{feature}/integration-registry.md`에 수집한 정보를 기록한다.
`specs/.template/integration-registry.md` 템플릿을 기반으로 작성한다.

작성 규칙:
1. 각 항목에 상태 표시 (✅ 확인 / ⚠️ 추론 / ❌ 미확인)
2. 확인 불가 항목은 사유와 확인 방법을 기록
3. 정보 출처를 반드시 기록
4. 연동 검증 체크리스트를 시스템별로 생성

---

## Step 4: prerequisites.md 생성/갱신

integration-registry.md에서 환경변수가 필요한 항목을 추출하여
`specs/{NNN}/prerequisites.md`를 생성하거나 갱신한다.
`.env.example`에 환경변수 키를 추가한다.

→ "연동 분석이 완료되었습니다. `collect-prerequisites 실행해줘`를 입력해 실제 값을 확보하세요."
