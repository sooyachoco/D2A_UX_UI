# 프로젝트 진행 상태

> 이 파일은 AI가 자동으로 갱신합니다.
> 이탈 후 돌아왔을 때 "어디까지 했지?" 라고 입력하면 현재 상태를 안내합니다.
> 세션 체크포인트 시 "새 채팅 → 이어서 해줘"로 이어서 작업합니다.

---

## 현재 상태

| 항목 | 값 |
|---|---|
| **프로젝트** | NEXON Live (라이브 방송 시청·채팅·후원) |
| **현재 단계** | Phase 0 — boilerplate-setup 완료, create-spec 직전 |
| **상태** | 🔄 세션 체크포인트 (세션 재시작 대기) |
| **디자인 시스템** | NX Basic 1.0v 고정 (`design_system=nxbasic`) |
| **선택 디자인** | 샘플 A (사이드바+콘텐츠) — `design/samples.html` · `design/design-direction.md` |
| **review_status** | ⏳ pending |
| **다음 행동** | 세션 재시작 → `create-spec 실행해줘` |

> **⚠️ 세션 재시작 필요 이유**: 2026-06-25 운영 레이어 백필(scripts·`.claude/settings.json` hooks·`d2a-harness` MCP)을
> 적용했으나, hooks·MCP 하네스는 **세션 시작 시 로드**된다. 현재 세션엔 미발효 상태이므로,
> 강제 게이트(hook proof-of-work · MCP `ut:`)를 실제로 걸려면 **새 세션에서 create-spec**을 진행해야 한다.

### 👉 다음에 할 일

```
새 채팅에 입력: create-spec 실행해줘
```
- create-spec 이 spec.md → plan.md → tasks.md 생성 + Step 2.7 UI 프로토타입 + Step 2.7.5 AI UT 자동 게이트 수행
- 단일 source 근거: `refs/ux-research/` 7종 (페르소나·여정, 🟢 검증 = 5월 쇼케이스 설문 S5)
- 디자인: `design/design-direction.md` (NX Basic 토큰 + 샘플 A 레이아웃)

---

## 완료 이력

| 날짜 | 단계 | 내용 | 세션 |
|---|---|---|---|
| 2026-06-25 | 리서치 | 실제 NEXON 리서치 MCP(Notion) 연결 → ux-research 7종 🟢검증 주입 + `/ux-research-sync` 스킬 | `8c2e619` |
| 2026-06-25 | 셋업 | boilerplate-setup(경량) Stage 0~1 + NX Basic 샘플 3종 → 샘플 A 확정 | `0cbf0e0` |
| 2026-06-25 | 디자인 | 샘플 A 하단 피드(라이브·크리에이터·클립) + 신고 접근성 | `7995c02` |
| 2026-06-25 | 운영 | 운영 레이어 백필(scripts·hooks·스킬 22·specs 템플릿·tests) + Slack webhook 시크릿 제거 | `f40ffbe` |

---

## 미적용 / 후속 (Notion AI 페이지 플로우 기준)

- [ ] create-spec → STEP 0 점검 · spec/plan/tasks · Step 2.7 프로토타입 · Step 2.7.5 AI UT 자동
- [ ] frontend 프로토타입 + ai-usability-test 실행 → `ut:` done 게이트 검증
- [ ] (선택) §3.5 확정 락 — 샘플 A git 태그 + PNG 스냅샷
- [ ] (보안 후속) 본체 notify-slack.sh Webhook 로테이션 (task chip 발행됨)

---

## Phase 체크리스트

### Phase A~C: 환경 설정
- [ ] 보일러플레이트 설치
- [ ] 참조 문서 확인 (refs/company-policies/, refs/gamescale-docs/)
- [ ] Cursor 재시작

### Phase D: 프로젝트 세팅 위저드
- [ ] PRD 입력 또는 질문 응답 (Q1~Q5)
- [ ] Q6* 디자인 샘플 선택
- [ ] **Phase 0: React + Mock UI 구현**
  - [ ] React 프로젝트 초기화 + 디자인 시스템 셋업
  - [ ] 공통 레이아웃 + GNB/INSIGN 연동
  - [ ] 각 페이지 UI 컴포넌트 (Mock 서비스 레이어)
  - [ ] **사용자 UI 확인 + 피드백 반영 → TypeScript 타입 확정(Step 2.8)**
- [ ] AI 기술 스택 제안 확인 (백엔드/DB/인프라)
- [ ] 사내 정보 확인 (해당 시)
- [ ] 세팅 결과 확정

### Phase E: 기능 명세
- [ ] spec.md 작성 + 사용자 확인 (Phase 0 React UI 기반)
- [ ] decisions.md + prerequisites.md
- [ ] plan.md 작성 + 사용자 확인
- [ ] data-model.md + api-spec.yaml
- [ ] tasks.md 생성 (Phase 0은 완료 상태)

### Phase F: 기능 구현

> `/run-phase` 실행 시 완료된 Phase를 [x]로 갱신한다.

- [ ] Phase 0.5: 외부 연동 검증
- [ ] Phase 1: {첫 번째 기능 Phase}
- [ ] Phase 2: {두 번째 기능 Phase}
- [ ] Phase N: … ← **진행 중**

### Phase G: 보안·품질 점검

> **트리거**: 모든 Feature Phase(Phase 1~N) ☑ 완료 직후 자동 진입.
> **실행**: `Skill("pre-launch-check")` 또는 `.claude/skills/pre-launch-check.md` 인라인 실행.
> **역할 분리**: subagent-review는 Phase 단위 코드 품질 점검 / Phase G는 전체 통합 보안·운영 점검.

- [ ] `"pre-launch-check 실행해줘"` 입력 — Step 2-D 반복 버그 패턴 자동 스캔
- [ ] Blocker(즉시수정) 0건 확인
- [ ] DB 안전성 항목 통과 (TOCTOU, 트랜잭션, 집계, 타임존)
- [ ] 보안 항목 통과 (신뢰 경계, NEXT_PUBLIC_ 인증 변수 없음)
- [ ] 사내 보안 진단 의뢰 (유저용 서비스 필수, 사내 도구 권장)

### Phase H: 배포
- [ ] 배포 준비 + 체크리스트
- [ ] 배포 실행 + 동작 확인

---

## 코드 패턴 메모

> 새 세션이 기존 코드와 일관된 스타일로 구현하기 위한 기술 브리핑.
> Phase 전환 / 블로커 발생 시 AI가 이 섹션을 갱신한다.
> 상세 설계 결정은 `decisions.md`에 영구 기록한다.

### 디렉터리 구조 (Phase N 완료 기준)

> AI가 Phase 완료 시 헤더의 Phase 번호를 업데이트한다.

```
{실제 프로젝트 구조 — 첫 Phase 완료 후 AI가 자동 기록}
예:
backend/
  app/
    api/v1/        ← 라우터
    services/      ← 비즈니스 로직
    models/        ← DB 모델
    schemas/       ← 요청/응답 스키마
  tests/
frontend/
  src/
    components/    ← 공통 컴포넌트
    pages/         ← 페이지 컴포넌트
    hooks/         ← 커스텀 훅
```

### 공통 패턴

| 항목 | 패턴 |
|---|---|
| 에러 응답 | {예: `{"detail": str, "code": str}`} |
| 인증 주입 | {예: `Depends(require_auth)`} |
| DB 세션 | {예: `Depends(get_db)`} |
| API 라우터 prefix | {예: `/api/v1`} |

### 핵심 인터페이스

> 다음 태스크가 참조할 함수·클래스·타입.

| 파일 | 이름 | 역할 |
|---|---|---|
| {예: backend/app/middleware/auth.py} | {require_auth} | {Depends 주입, request.state.user 설정} |
| {예: backend/app/schemas/user.py} | {UserPayload} | {id: int, email: str, role: str} |

### 다음 세션 사전 메모

- {예: 다음 태스크는 S3 presigned URL 필요 → .env.example에 S3_BUCKET_NAME 추가 필요}
- {예: spec.md 3.2절 프로필 이미지 크기 제한 5MB 적용 필요}
