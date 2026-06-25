# 사내 정책 빠른 참조 인덱스

> 이 문서는 기술 결정 시 빠르게 참조하는 인덱스입니다.
> 각 항목은 `refs/policies/` 파일에서 상세 내용을 확인할 수 있습니다.
> 실제 사내 정보가 수집되면 이 테이블도 함께 갱신합니다.

**Last Updated**: 2026-04-16
**데이터 상태**: 🤖 AI 제안 8개 + 🟢 확인 3개 + 🟡 추후 2개 + 📂 정책 문서 37개 + ⬜ 미수집 3개 (총 53개)

> 📂 사내 정책 문서(`refs/company-policies/`)에서 D-1 기술스택·B-1 클라우드 포함 디자인·글로벌라이제이션·법무 등을 직접 참조합니다.
> 매핑 상세: `refs/company-policies-map.md`

---

## 기술 선택 원칙 (🔴 1단계)

아래 6개 항목은 외부 부서 수집 없이 **AI가 프로젝트에 맞게 제안**합니다.
상세 원칙은 `CLAUDE.md` "기술 선택 원칙" 참조.

| 항목 | 결정 방식 | 근거 |
|---|---|---|
| 백엔드 (D-1) | 📂 **Python 3.9+ / Django 4.x** — company-policies 확인 | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` |
| 프론트엔드 (D-1) | 📂 **React 18+** — company-policies 확인 | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` |
| DB (D-1) | 📂 **PostgreSQL 14+** (기본) / **MongoDB 6.x** (비정형) | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` |
| 코드 컨벤션 (D-2) | 🤖 선택된 기술의 표준 린터/포맷터 자동 적용 | `deployment.md` D-2 |
| 사내 인증 (A-1a) | 📂 NXAS SSO OAuth 2.0 — company-policies 참조 | `authentication-nxas.md` A-1a |
| 유저 인증 (A-1b) | 🤖 `refs/gamescale-docs-index.md` 키워드로 참조 | `authentication-external.md` A-1b |
| 클라우드 (B-1) | 📂 **AWS** — company-policies 확인 | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` |
| 서비스 스택 (B-4) | 🤖 규모에 맞는 인프라 조합 제안 → 사용자 확인 | `infrastructure.md` B-4 |
| UI 프레임워크 (F-6) | 🤖 후보 제시 → 사용자 선택 | `deployment.md` F |

---

## 빠른 결정 가이드

| 주제 | 규칙 | 근거 |
|---|---|---|
| **— 인증 —** | | |
| 사내 인증 | 📂 NXAS OAuth 2.0 (Authorization Code Grant) | `authentication-nxas.md` A-1a |
| 유저 인증 | 🤖 `refs/gamescale-docs-index.md` 키워드로 참조 | `authentication-external.md` A-1b |
| 토큰 저장 (사내) | 📂 Bearer AccessToken 30분, RefreshToken 60분 | `authentication-nxas.md` A-4a |
| 세션 만료 (사내) | 📂 AccessToken 1800초, RefreshToken 3600초, SSO 글로벌 로그아웃 | `authentication-nxas.md` A-4a |
| 토큰/세션 (유저) | 🤖 `refs/gamescale-docs-index.md` 키워드로 참조 | `authentication-external.md` A-4b |
| API Gateway (외부 유저) | 🤖 외부 유저 프로젝트 시 Public GW 입점 — NCSR Day 0 신청 | `authentication-external.md` A-7 |
| API Gateway 로컬 개발 | 🤖 Gateway → 로컬 서버 연결 불가 — 환경별 API 경로 분리 필수 | `authentication-external.md` A-9 |
| **— 기술 스택 / 인프라 —** | | |
| 백엔드 | 📂 **Python 3.9+ / Django 4.x** | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` D-1 |
| 프론트엔드 | 📂 **React 18+** | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` D-1 |
| DB | 📂 **PostgreSQL 14+** (기본) / **MongoDB 6.x** (비정형) | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` D-1 |
| 클라우드 | 📂 **AWS** (계정 분리 정책) | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` B-1 |
| 캐시 | 🤖 프로젝트 규모에 맞게 제안 | `infrastructure.md` B-4 |
| CDN | 🤖 프로젝트 규모에 맞게 제안 | `infrastructure.md` B-4 |
| 배포 환경 | **dev/test/live** 🟢 | `deployment.md` E-2 |
| CI/CD | **GitLab CI/CD + ArgoCD** 🟢 | `deployment.md` E-1 |
| 모니터링 | 🤖 GitLab CI 알림 + 사내 모니터링 도구. 구체적 도구는 운영팀 확인 권장 | `deployment.md` E-3 |
| 브랜치 전략 | 🤖 `main` + `feature/*` (GitHub Flow). 팀 규칙 있으면 사용자 확인 후 확정 | `deployment.md` D-3 |
| MR 승인 | 🤖 최소 1인 승인 필수, 작성자 self-merge 금지. 팀 규칙 있으면 사용자 확인 후 확정 | `deployment.md` D-5 |
| 테스트 커버리지 | 🤖 단위 테스트 60% 이상, CI 게이트에서 강제. 팀 기준 있으면 사용자 확인 후 확정 | `deployment.md` D-6 |
| **— 보안 —** | | |
| 보안 진단 | 📂 XSS/SQLi/CSRF 방어, 보안 리뷰 프로세스 (상/중 취약점: 오픈 전 필수) | `security/NEXON_SECURITY.md` C-1 ✅ |
| 보안 코드 기준 | 📂 명확한 네이밍·단일책임·레이어분리 — AI 코드 작성 시 필수 준수 | `security/NEXON_SECURITY.md` + `security/policies/` |
| SSL | 📂 TLS 1.2+ 필수, HTTPS 강제 | `security/policies/sensitive-data-protection.md` C-5 ✅ |
| 도메인 | 📂 TLS 요구사항만 | `security/policies/sensitive-data-protection.md` B-5 🔵 |
| 퍼블릭 버킷 | 📂 암호화 일반 원칙 | `security/policies/sensitive-data-protection.md` C-4 🔵 |
| 암호화(저장) | 📂 3등급 분류, 등급별 암호화 의무 | `privacy/policies/personal_information_classification.md` C-3 ✅ |
| 암호화(전송) | 📂 TLS 1.2+, HTTPS 강제 | `security/policies/sensitive-data-protection.md` C-5 ✅ |
| WAF | {수집 필요} | `security.md` C-6 |
| 로그 보관 | 📂 보관 기간 기준 (30일/3년/5년) | `privacy/policies/data_management_policy.md` C-7 🟡 |
| 사내 로깅 | 📂 NxLog 표준 로깅 시스템 (포맷·필수 필드·KPI 전송 규격 포함) | `compliance/NEXON-OS/03_DEPENDENCIES/03_LOGGING/NXLOG_USAGE_GUIDE.md` 🔵 |
| **— 개인정보 / 법규 —** | | |
| 개인정보 분류 | 📂 3등급 분류 체계, 수집 원칙 | `privacy/policies/personal_information_classification.md` DH-1 🟡 |
| 개인정보처리방침 | 📂 필수 19개 항목 작성 가이드 | `privacy/policies/privacy_policy.md` L-2 ✅ |
| 개인정보 수집·표시 | 📂 수집 원칙, 화면 표시 가이드 | `compliance/NEXON-OS/01_COMMON_RULES/03_PRIVACY/` 🔵 |
| 법무 검토 | 📂 Jira `LEGAL` 프로젝트 티켓, Slack `#legal-review` | `compliance/NEXON-OS/01_COMMON_RULES/01_LEGAL_REVIEW/PROCESS_GUIDE.md` L-3 ✅ |
| 법규 준수 (국내) | 📂 연령등급, 법정대리인 동의 가이드 | `compliance/NEXON-OS/01_COMMON_RULES/02_LAW_REGULATION/KR/` 🔵 |
| 법규 준수 (글로벌) | 📂 GDPR(EU), CCPA(US), COPPA(US) 가이드 | `compliance/NEXON-OS/01_COMMON_RULES/02_LAW_REGULATION/` 🔵 |
| **— 결제 —** | | |
| 결제 API (사내) | 📂 플랫폼개발팀 담당 — Jira `PLATFORM`, Slack `#platform-support` | `compliance/NEXON-OS/03_DEPENDENCIES/02_PAYMENT/API_GUIDE.md` 🔵 |
| 결제/현금 아이템 정책 | 📂 캐시 아이템 정책, 결제 처리 가이드 | `compliance/NEXON-OS/01_COMMON_RULES/04_ACCOUNTING/` 🔵 |
| 결제 SDK (GameScale) | 🤖 `refs/gamescale-docs-index.md` → `game-economy` 키워드 | `service-integration/game-economy/` |
| **— 디자인 / UX —** | | |
| UI 프레임워크 | 🤖 후보 제시 → 사용자 선택 | `deployment.md` F-6 |
| 디자인 시스템 (NX Basic) | 🟢 PRD에 `NX Basic`/`nxbasic` 키워드 → 웹 리서치 생략, NX Basic 토큰 고정·레이아웃 3종 샘플 비교·선택 후 UI 프로토타입. 없으면 리서치 선택지로 제시. 컴포넌트 18종·토큰 144개 | `design-systems/nxbasic-1.0v.md` |
| GNB (Global Nav Bar) | 📂 전 넥슨 서비스 적용 의무 — 유형·필수 링크·반응형 가이드 포함 | `compliance/NEXON-OS/04_DESIGN/02_COMMON_UI_ELEMENTS/GNB_GUIDE.md` 🔵 |
| Footer | 📂 전 넥슨 서비스 공통 Footer 규격 | `compliance/NEXON-OS/04_DESIGN/02_COMMON_UI_ELEMENTS/FOOTER_GUIDE.md` 🔵 |
| 디자인 시스템 | 📂 색상·타이포·간격·아이콘·컴포넌트 가이드 | `compliance/NEXON-OS/04_DESIGN/01_NEXON_DESIGN_SYSTEM_GUIDE.md` 🔵 |
| 서비스 링크 | 📂 넥슨 서비스간 공통 링크 목록 | `compliance/NEXON-OS/04_DESIGN/03_NEXON_SERVICE_LINKS.md` 🔵 |
| **— 다국어 / 현지화 —** | | |
| i18n 전략 | 📂 하드코딩 금지, 키 기반 렌더링, **UTF-8** 필수 | `compliance/NEXON-OS/05_GLOBALIZATION/01_I18N_STRATEGY.md` 🔵 |
| 날짜·통화·숫자 포맷 | 📂 로케일별 포맷 가이드 | `compliance/NEXON-OS/05_GLOBALIZATION/02_L10N_GUIDE/FORMATTING/` 🔵 |
| 번역 프로세스 | 📂 번역 정책·실행·검수 가이드 | `compliance/NEXON-OS/05_GLOBALIZATION/` 🔵 |

---

## 정책 파일 목록

### refs/policies/ (프로젝트별 수집 레코드)

| 파일 | 내용 | 데이터 상태 |
|---|---|---|
| [`authentication.md`](./policies/authentication.md) | 인증 라우터 (판별 가이드) | 상세는 아래 두 파일 참조 |
| [`authentication-nxas.md`](./policies/authentication-nxas.md) | 사내 인증 (NXAS SSO) | 📂 ✅ A-1a/A-2a/A-3/A-4a/A-6 |
| [`authentication-external.md`](./policies/authentication-external.md) | 외부 유저 인증 (INSIGN/GameScale/GNB) | 📂 A-1b/A-2d/A-7/A-9/A-10, 🤖 A-1c/A-4b |
| [`infrastructure.md`](./policies/infrastructure.md) | 인프라·클라우드·비용 정책 | 📂 ✅ D-1/B-1 (Tech Stack Guide), 나머지 🤖/⬜ |
| [`security.md`](./policies/security.md) | 보안 진단·솔루션·접근제어 정책 | 📂 C-1/C-3/C-5 완전 커버, 나머지 부분/상당 |
| [`data-handling.md`](./policies/data-handling.md) | 데이터 분류·개인정보·암호화 정책 | 📂 DH-1 상당, DH-2/DH-3 부분 |
| [`deployment.md`](./policies/deployment.md) | 배포·운영·개발표준·디자인 정책 | 📂 ✅ D-1(기술스택), E-1/E-2/D-7 🟢, F-1/F-2 🟡 |

### refs/company-policies/ (직접 참조 사내 문서)

| 경로 | 내용 | 커버 항목 |
|---|---|---|
| `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` | 공식 기술 스택 목록 | D-1 ✅, B-1 ✅ |
| `compliance/NEXON-OS/03_DEPENDENCIES/01_AUTH/NXAS/` | NXAS SSO 전체 연동 가이드 (8개 파일) | A-1a ✅, A-2a ✅, A-4a 🟡 |
| `compliance/NEXON-OS/03_DEPENDENCIES/02_PAYMENT/API_GUIDE.md` | 결제 API 가이드 (스켈레톤) | 결제 🔵 |
| `compliance/NEXON-OS/03_DEPENDENCIES/03_LOGGING/NXLOG_USAGE_GUIDE.md` | NxLog 표준 로깅 가이드 | 로깅 🔵 |
| `compliance/NEXON-OS/04_DESIGN/01_NEXON_DESIGN_SYSTEM_GUIDE.md` | 넥슨 디자인 시스템 | F-3/F-4 🔵 |
| `compliance/NEXON-OS/04_DESIGN/02_COMMON_UI_ELEMENTS/GNB_GUIDE.md` | GNB 규격 가이드 | GNB 🔵 |
| `compliance/NEXON-OS/04_DESIGN/02_COMMON_UI_ELEMENTS/FOOTER_GUIDE.md` | Footer 규격 가이드 | Footer 🔵 |
| `compliance/NEXON-OS/04_DESIGN/03_NEXON_SERVICE_LINKS.md` | 넥슨 서비스 링크 목록 | 서비스링크 🔵 |
| `compliance/NEXON-OS/05_GLOBALIZATION/01_I18N_STRATEGY.md` | i18n 전략 (UTF-8, 키 기반) | i18n 🔵 |
| `compliance/NEXON-OS/05_GLOBALIZATION/02_L10N_GUIDE/FORMATTING/` | 날짜·통화·숫자 포맷 (3개 파일) | l10n 포맷 🔵 |
| `compliance/NEXON-OS/01_COMMON_RULES/01_LEGAL_REVIEW/PROCESS_GUIDE.md` | 법무 심의 절차 (Jira LEGAL) | L-3 ✅ |
| `compliance/NEXON-OS/01_COMMON_RULES/02_LAW_REGULATION/` | GDPR/CCPA/COPPA/국내법 가이드 | 법규 🔵 |
| `compliance/NEXON-OS/01_COMMON_RULES/03_PRIVACY/` | 개인정보 수집·표시 원칙 | 개인정보 🔵 |
| `compliance/NEXON-OS/01_COMMON_RULES/04_ACCOUNTING/` | 현금아이템·결제 정책 | 결제정책 🔵 |
| `security/NEXON_SECURITY.md` | 보안 코드 가이드 (XSS/SQLi/CSRF 포함) | C-1 ✅, C-2 🟡 |
| `security/policies/sensitive-data-protection.md` | TLS/HTTPS·PII 마스킹·쿠키 보안 | C-5 ✅ |
| `security/checklists/` | 코드개발·보안리뷰·취약점 체크리스트 (3개) | G-2 🔵 |
| `privacy/policies/privacy_policy.md` | 개인정보처리방침 (19개 필수 항목) | L-2 ✅ |
| `privacy/policies/personal_information_classification.md` | 개인정보 3등급 분류 체계 | C-3 ✅, DH-1 🟡 |
| `privacy/policies/data_management_policy.md` | 데이터 보관 기간 (30일/3년/5년) | C-7 🟡 |
| `privacy/checklists/` | 개인정보 영향평가·침해 대응 체크리스트 | DH-2 🔵 |
| `compliance/NEXON-OS/my-new-service/PROKIT_PROTOCOL.md` | 신규 서비스 PRD 작성 프로토콜 | 프로젝트 템플릿 |

### 데이터 상태 범례

- 🤖 AI 제안: boilerplate-setup 위저드에서 AI가 프로젝트에 맞게 결정
- 📂 ✅ 완전 커버: 사내 정책 문서(`refs/company-policies/`)에서 직접 참조 가능
- 📂 🟡 상당 커버: 핵심 정보 포함, 프로젝트별 확인 필요
- 📂 🔵 부분 커버: 일반 가이드 수준, 부서 확인 권장
- ⬜ 미수집: 아직 수집하지 않음. 해당 부서에 문의 필요.
- 🟡 확인 중: 담당 부서에 확인 요청 중.
- 🟢 확인 완료: 실제 정보 확인 또는 AI 제안 사용자 확정.
