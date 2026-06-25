# 프로젝트 진행 상태

> 이 파일은 AI가 자동으로 갱신합니다.
> 이탈 후 돌아왔을 때 "어디까지 했지?" 라고 입력하면 현재 상태를 안내합니다.
> 세션 체크포인트 시 "새 채팅 → 이어서 해줘"로 이어서 작업합니다.

---

## 현재 상태

| 항목 | 값 |
|---|---|
| **현재 단계** | Phase A — 사전 준비 |
| **상태** | ⏳ 진행 중 |
| **마지막 작업** | — |
| **세션 체크포인트** | — |
| **review_status** | — |
| **다음 행동** | 아래 참조 |

> 상태 값: ⏳ 진행 중 / ⏸️ 사용자 확인 대기 / 🔄 세션 체크포인트 / ✅ 완료
>
> **review_status 값 규칙:**
> - `—` : Phase 구현 미시작
> - `⏳ pending` : 해당 Phase 소스 변경 있음, 리뷰 미실행 (run-phase Step 3-1이 설정)
> - `✅ YYYY-MM-DD` : 리뷰 완료 날짜 (subagent-review Step 5가 설정)
> - `N/A` : 해당 Phase 소스 변경 없음 (문서만 변경)

### 👉 다음에 할 일

```
채팅에 입력: @SETUP.md 프로젝트 셋팅해줘
```

---

## 완료 이력

| 날짜 | 단계 | 내용 | 세션 |
|---|---|---|---|
| — | — | — | — |

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
