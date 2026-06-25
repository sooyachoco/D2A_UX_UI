---
name: refine-prd
description: PRD를 보일러플레이트 워크플로에 맞게 정제. PRD 정제, PRD 변환, PRD 정리 요청 시 사용.
---

# PRD 정제 워크플로

PRD(기획 문서)를 보일러플레이트 워크플로에 맞게 정제한다.
보안 정보 분리, 구현 코드 이동, 마일스톤 변환 등을 처리한다.

## 트리거

- "PRD 정제해줘"
- "PRD 정리해줘"
- "PRD를 보일러플레이트에 맞게 변환해줘"

## 기본 원칙

- 인증 경로 판별은 CLAUDE.md의 `check-policy-refs` 규칙의 인증 특별 규칙을 따른다.
- 보편적 관행(AWS, OWASP 등)은 `/internal-doc-survey` 스킬의 정책 조회 래더를 따른다.
- PRD의 미결정 항목은 프로젝트에 맞는 선택지를 **제안하고 decisions.md에 기록**한다.
- 내부 시스템 연동 스펙은 **refs/ 문서를 먼저 참조**하고, 정보가 없으면 사용자에게 질문한다.

---

## 처리 항목

### 1. 보안 정보 분리

PRD에서 실제 DB 접속 정보와 환경 변수 값을 분리한다.

변환 예시:
```
변환 전: | 개발 | 192.168.231.22:1433 | PORTAL_DB | devportal_service |
변환 후: | 환경 | 환경 변수 | 설명 |
         | 개발 | DB_SERVER, DB_PORT, DB_NAME, DB_USER | .env.local에서 관리 |
```

`.env.example` 파일을 생성/갱신한다 (값은 플레이스홀더).

### 2. 기술 스택 미결정 항목 처리

"또는", "TBD"로 표기된 항목을 분류한다:
- **결정 가능**: `refs/INDEX.md`에서 기준 확인 → 선택지 제안 → decisions.md 기록
- **사용자 판단 필요**: CLAUDE.md의 `ask-before-decide` 형식으로 질문

### 3. 마일스톤 → Phase 변환

PRD의 마일스톤을 D2A Phase 구조로 변환한다:

```
PRD 마일스톤:
- M1: UI 개발 → Phase 0 (UI 프로토타입)
- M2: API 연동 → Phase 0.5 (외부 연동 검증)
- M3: 핵심 기능 → Phase 1
- M4: 고도화 → Phase 2+
```

### 4. API 스펙 분리

PRD에 포함된 API 스펙을 `specs/.template/contracts/api-spec.yaml` 형식으로 변환한다.

### 5. 디자인 방향 추출

먼저 PRD 본문에서 **NX Basic 디자인 시스템** 키워드(`NX Basic` · `nxbasic` · `NX Basic 1.0v` · `nxbasic-mcp`, 대소문자·공백 무시)를 검사한다.

- **감지된 경우** → decisions.md `DESIGN_SYSTEM` 항목을 `nxbasic` 로 기록하고, "웹 리서치 생략, NX Basic 토큰 고정·레이아웃 3종 샘플 비교·선택 후 UI 프로토타입" 메모를 남긴다. 이후 `boilerplate-setup` 이 Stage 1.5(웹 리서치)만 건너뛰고 Q5\* 에서 NX Basic 토큰 기반 샘플 3종을 생성한다. (참조: `refs/design-systems/nxbasic-1.0v.md`)
- **감지되지 않은 경우** → PRD의 디자인 가이드라인이 있으면 `design-direction.md` 초안을 생성한다. 없으면 프로젝트 성격에 맞는 라이선스 문제 없는 UI 라이브러리를 제안하되, **NX Basic 1.0v 적용도 하나의 선택지로 함께 제시**한다 (디자인 리서치 단계에서 최종 선택).

---

## 완료

정제된 PRD와 생성된 파일 목록을 보고한다.
→ "PRD 정제가 완료되었습니다. `boilerplate-setup 실행해줘`를 입력해 세팅을 시작할까요?"
