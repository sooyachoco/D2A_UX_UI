# 사내 정책 저장소 매핑

> `refs/company-policies/`의 사내 정책 문서가
> 보일러플레이트의 어떤 항목을 커버하는지 매핑합니다.
>
> **소스**: `gitlab.nexon.com/frontdev/inhouse/replatform-playground/company-policies`
> **로컬 경로**: `refs/company-policies/` (보일러플레이트 설치 시 자동 포함)

---

## 커버리지 요약

| 수준 | 항목 수 | 설명 |
|---|---|---|
| ✅ 완전 커버 | 11개 | 정책 문서가 해당 항목을 상세히 다룸 |
| 🟡 상당 커버 | 7개 | 핵심 정보 포함, 일부 프로젝트별 확인 필요 |
| 🔵 부분 커버 | 22개 | 스켈레톤 또는 일반 가이드 수준 |
| ⬜ 미커버 | 17개 | 해당 문서 없음 (부서별 수집 필요) |

---

## 완전 커버 (✅) — 직접 참조 가능

| tracker ID | 항목 | 정책 문서 경로 | 핵심 내용 |
|---|---|---|---|
| D-1 | 기술 스택 | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` | Python 3.9+, Django 4.x, React 18+, PostgreSQL 14+, MongoDB 6.x, AWS |
| B-1 | 클라우드 | `compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md` | AWS 기본, 계정 분리 정책 |
| A-1a | 사내 인증 (NXAS SSO) | `compliance/NEXON-OS/03_DEPENDENCIES/01_AUTH/NXAS/` | OAuth 2.0 SSO 전체 연동 가이드, 환경별 URL/IP, API 스펙, GetProfile |
| A-2a | 사내 OAuth 흐름 | `compliance/NEXON-OS/03_DEPENDENCIES/01_AUTH/NXAS/NXAS_연동_가이드_converted.md` | AuthCode → Token → GetProfile → RefreshToken → Logout 전체 스펙 |
| C-1 | 보안 진단 의무 | `security/NEXON_SECURITY.md` | XSS/SQLi/CSRF 방어, TLS 1.2+, 쿠키 보안, 보안 리뷰 프로세스 |
| C-3 | 데이터 분류·암호화 | `privacy/policies/personal_information_classification.md` | 3등급 분류 체계, 등급별 암호화 의무 |
| C-5 | HTTPS | `security/policies/sensitive-data-protection.md` | TLS 1.2+ 필수, HTTPS 강제, PII 마스킹, Secure 쿠키 |
| L-2 | 개인정보처리방침 | `privacy/policies/privacy_policy.md` | 필수 19개 항목 작성 가이드 |
| L-3 | 법무 검토 | `compliance/NEXON-OS/01_COMMON_RULES/01_LEGAL_REVIEW/PROCESS_GUIDE.md` | Jira LEGAL 프로세스, Slack `#legal-review` |
| I-1 | i18n 원칙 | `compliance/NEXON-OS/05_GLOBALIZATION/01_I18N_STRATEGY.md` | 하드코딩 금지, 키 기반 렌더링, UTF-8 필수 |
| SEC-CODE | 보안 코드 개발 기준 | `security/NEXON_SECURITY.md` + `security/policies/code-development-standards.md` | 명확한 네이밍, 단일책임, 레이어 분리 — 보안 검수 통과 기준 |

## 상당 커버 (🟡) — 기본 정보 포함, 프로젝트별 확인 필요

| tracker ID | 항목 | 정책 문서 경로 | 포함 내용 | 추가 확인 필요 |
|---|---|---|---|---|
| C-6 | 접근 제어 | `security/NEXON_SECURITY.md` | IP 기반 접근 제어, 인증 체계 | VPN 범위, WAF 설정 |
| C-7 | 로그 보관 | `privacy/policies/data_management_policy.md` | 보관 기간 기준 (30일/3년/5년) | 감사 로그 항목, 저장 위치 |
| DH-1 | 개인정보 수집 항목 | `privacy/policies/personal_information_classification.md` | 분류 체계, 수집 원칙 | 프로젝트별 수집 항목 확정 |
| B-2 | AWS 계정 | `privacy/policies/common_security_measures.md` | 계정 분리 원칙, 신청 URL (`eng.nexon.co.kr/cloud_requests`) | 소요 시간, IAM 권한 |
| C-2 | 필수 보안 솔루션 | `security/NEXON_SECURITY.md` | SAST, Secret Detection (GitLab 내장) | 추가 필수 솔루션 목록 |
| A-3 | 서비스 등록 절차 | `compliance/NEXON-OS/03_DEPENDENCIES/01_AUTH/NXAS/NXAS_연동_가이드_converted.md` | NCSR 클라이언트 등록, 네트워크 ACL, 등록 필요 정보 | 소요 시간 |
| A-4a | 세션 정책 (NXAS) | `compliance/NEXON-OS/03_DEPENDENCIES/01_AUTH/NXAS/NXAS_연동_가이드_converted.md` | AccessToken 30분, RefreshToken 60분, SSO 글로벌 로그아웃 | 동시 로그인 상세 |

## 부분 커버 (🔵) — 스켈레톤/일반 가이드 수준

| tracker ID | 항목 | 정책 문서 경로 | 참고 수준 |
|---|---|---|---|
| B-3 | VPC·서브넷 | `compliance/NEXON-OS/03_ACCESS_POLICY.md` | 접근 정책 스켈레톤 |
| C-4 | S3/스토리지 보안 | `security/policies/sensitive-data-protection.md` | 암호화 일반 원칙 |
| DH-2 | 개인정보영향평가 | `privacy/checklists/` | 체크리스트 템플릿 |
| DH-3 | 외부 데이터 전송 | `privacy/policies/data_management_policy.md` | 제3자 제공 기준 |
| D-3 | Git 브랜치 전략 | `development/` | 일반 개발 가이드 |
| D-5 | 코드 리뷰 | `development/` | 리뷰 일반 원칙 |
| D-6 | 테스트 기준 | `development/` | 테스트 일반 가이드 |
| L-1 | 이용약관 | `privacy/policies/privacy_policy.md` | 개인정보처리방침 내 일부 참조 |
| F-3 | 반응형 기준 | `compliance/NEXON-OS/04_DESIGN/` | 디자인 가이드라인 일부 |
| F-4 | 접근성 기준 | `compliance/NEXON-OS/04_DESIGN/` | 접근성 일반 원칙 |
| B-5 | 도메인·SSL | `security/policies/sensitive-data-protection.md` | TLS 요구사항만 |
| G-2 | 오픈 전 체크리스트 | `security/checklists/`, `privacy/checklists/` | 보안/개인정보 체크리스트 (3+3개) |
| GNB | GNB/Footer | `compliance/NEXON-OS/04_DESIGN/02_COMMON_UI_ELEMENTS/` | 유형·필수링크·반응형 스켈레톤 |
| DS-1 | 디자인 시스템 | `compliance/NEXON-OS/04_DESIGN/01_NEXON_DESIGN_SYSTEM_GUIDE.md` | 색상·타이포·아이콘·컴포넌트 스켈레톤 |
| DS-2 | 서비스 링크 | `compliance/NEXON-OS/04_DESIGN/03_NEXON_SERVICE_LINKS.md` | 넥슨 서비스간 공통 링크 목록 |
| L10N | 날짜·통화·숫자 포맷 | `compliance/NEXON-OS/05_GLOBALIZATION/02_L10N_GUIDE/FORMATTING/` | 로케일별 포맷 가이드 (3개 파일) |
| TRANS | 번역 프로세스 | `compliance/NEXON-OS/05_GLOBALIZATION/` | 번역 정책·실행·검수·UI 레이아웃 (4개 파일) |
| LAW-KR | 국내 법규 | `compliance/NEXON-OS/01_COMMON_RULES/02_LAW_REGULATION/KR/` | 연령등급·법정대리인 동의 가이드 |
| LAW-EU | GDPR | `compliance/NEXON-OS/01_COMMON_RULES/02_LAW_REGULATION/EU/GDPR_GUIDE.md` | EU GDPR 준수 가이드 |
| LAW-US | CCPA/COPPA | `compliance/NEXON-OS/01_COMMON_RULES/02_LAW_REGULATION/US/` | 미국 개인정보·아동 보호 가이드 |
| PRIV-DISP | 개인정보 수집·표시 | `compliance/NEXON-OS/01_COMMON_RULES/03_PRIVACY/` | 수집 원칙·화면표시·필수수집항목 (3개 파일) |
| PAY-API | 결제 API | `compliance/NEXON-OS/03_DEPENDENCIES/02_PAYMENT/API_GUIDE.md` | 플랫폼개발팀 담당 스켈레톤 |
| PAY-POL | 결제/현금 아이템 정책 | `compliance/NEXON-OS/01_COMMON_RULES/04_ACCOUNTING/` | 캐시아이템 정책·결제처리 가이드 (2개 파일) |
| LOG-NX | NxLog 사내 로깅 | `compliance/NEXON-OS/03_DEPENDENCIES/03_LOGGING/NXLOG_USAGE_GUIDE.md` | 로그 포맷·필수필드·KPI 전송 스켈레톤 |
| PROJ-TPL | 신규 서비스 템플릿 | `compliance/NEXON-OS/my-new-service/` | PRD 작성 프로토콜·템플릿·대시보드 생성 |

## 미커버 (⬜) — company-policies 문서 없음

> 이 섹션은 `refs/company-policies/` 문서가 없는 항목만 나열합니다.
> ★ 표시는 다른 수단(🟢 직접 확인, 🤖 AI 제안, 🟡 추후)으로 이미 결정된 항목입니다.

| tracker ID | 항목 | 필요 부서 | 비고 |
|---|---|---|---|
| B-4 | 표준 서비스 스택 (상세 스펙) | 인프라팀 | 🤖 AI 제안으로 부분 결정 (프론트 EC2 🟢 확정) |
| B-6 | 비용 승인 프로세스 | 인프라팀 | ⬜ 미수집 |
| D-2 | 코드 컨벤션 (상세) | 개발팀 | 🤖 AI가 기술스택 기준으로 자동 선택 |
| D-4 | 커밋 규칙 | 개발팀 | ⬜ 미수집 |
| D-7 | 사내 패키지/레지스트리 | 개발팀 | ★ 🟢 확인 완료 (없음, 공개 레지스트리) |
| E-1 | CI/CD 도구 | DevOps팀 | ★ 🟢 확인 완료 (GitLab CE v18.4.4) |
| E-2 | 배포 환경 구분 | DevOps팀 | ★ 🟢 확인 완료 (dev/test/live) |
| E-3 | 모니터링 도구 | DevOps팀 | ⬜ 미수집 |
| E-4 | 알림 채널 | DevOps팀 | ⬜ 미수집 |
| E-5 | 장애 대응 프로세스 | DevOps팀 | ⬜ 미수집 |
| F-1 | 디자인 시스템 유무 | 디자인팀 | ★ 🟡 추후 (현재 없음) |
| F-2 | 브랜드 가이드 | 디자인팀 | ★ 🟡 추후 (현재 없음) |
| F-5 | 다크모드 지원 | 디자인팀 | ⬜ 미수집 |
| F-6 | UI 프레임워크 (상세) | 디자인팀 | 🤖 AI가 후보 제시 → 사용자 선택 |
| G-1 | 프로젝트 등록 절차 | PM | ⬜ 미수집 |
| G-3 | 외부 서비스 연동 승인 | PM | ⬜ 미수집 |
| G-4 | 문서화 의무 | PM/QA | ⬜ 미수집 |
| A-4 | 세션 정책 (외부 유저 상세) | IT인프라팀 | ⬜ 미수집 |
| A-5 | 외부 사용자 인증 옵션 | IT인프라팀 | ⬜ 미수집 |

---

## 디렉터리 구조

```
refs/company-policies/
├── compliance/
│   └── NEXON-OS/
│       ├── 01_COMMON_RULES/
│       │   ├── 01_LEGAL_REVIEW/      ← L-3 ✅ 법무 심의 절차 (Jira LEGAL)
│       │   ├── 02_LAW_REGULATION/    ← 법규 🔵 (KR: 연령등급/법정대리인, EU: GDPR, US: CCPA/COPPA)
│       │   ├── 03_PRIVACY/           ← 개인정보 🔵 (수집원칙, 화면표시, 필수항목)
│       │   ├── 04_ACCOUNTING/        ← 결제정책 🔵 (캐시아이템, 결제처리)
│       │   └── 05_SECURITY/          ← 보안정책 스켈레톤
│       ├── 02_INFRASTRUCTURE/
│       │   └── 01_TECH_STACK_GUIDE.md ← D-1 ✅, B-1 ✅ (Python/Django/React/PG/Mongo/AWS)
│       ├── 03_DEPENDENCIES/
│       │   ├── 01_AUTH/
│       │   │   ├── API_GUIDE.md      ← 공통 인증 API 스켈레톤
│       │   │   └── NXAS/             ← A-1a, A-2a, A-3, A-4a ✅ (8개 파일)
│       │   │       ├── NXAS_연동_가이드_converted.md        ← 핵심: OAuth 전체 연동 스펙
│       │   │       ├── SSO_OAuth_연동_가이드_converted.md    ← OAuth 프로토콜 개념
│       │   │       ├── NXAS_SAML_연동_가이드_converted.md    ← SAML 연동
│       │   │       ├── NXAS_2차인증_로그인_가이드_converted.md ← OTP 2차 인증
│       │   │       ├── OneLogin_웹_인증_가이드_converted.md   ← OneLogin 토큰
│       │   │       ├── NXAS_연동_참고_가이드_converted.md     ← 허용 도메인, 구SSO 제거
│       │   │       ├── 연동_이전_가이드_NOSTS_NXAS_converted.md ← NOSTS→NXAS 마이그레이션
│       │   │       ├── NXAS_연동_이전_가이드_converted.md     ← FPSTS→NXAS 마이그레이션
│       │   │       └── FPSTS_NOSTS_연동_이전_가이드_converted.md ← FPSTS→NOSTS
│       │   ├── 02_PAYMENT/API_GUIDE.md  ← 결제 API 🔵 (플랫폼개발팀 스켈레톤)
│       │   └── 03_LOGGING/NXLOG_USAGE_GUIDE.md ← NxLog 🔵 (로그포맷·KPI 스켈레톤)
│       ├── 04_DESIGN/
│       │   ├── 01_NEXON_DESIGN_SYSTEM_GUIDE.md  ← 디자인시스템 🔵
│       │   ├── 02_COMMON_UI_ELEMENTS/
│       │   │   ├── GNB_GUIDE.md     ← GNB 규격 🔵
│       │   │   └── FOOTER_GUIDE.md  ← Footer 규격 🔵
│       │   └── 03_NEXON_SERVICE_LINKS.md ← 서비스 링크 목록 🔵
│       ├── 05_GLOBALIZATION/         ← i18n ✅ / l10n 🔵 (6개 파일)
│       │   ├── 01_I18N_STRATEGY.md  ← i18n ✅ (UTF-8, 키 기반)
│       │   └── 02_L10N_GUIDE/       ← 날짜·통화·숫자·번역·UI 레이아웃
│       └── my-new-service/           ← PRD 작성 프로토콜·템플릿
├── development/                      ← D-3, D-5, D-6 일반 개발 가이드 🔵
├── privacy/
│   ├── policies/
│   │   ├── personal_information_classification.md  ← C-3 ✅ 데이터 분류
│   │   ├── data_management_policy.md               ← C-7 🟡 보관 기간
│   │   ├── privacy_policy.md                       ← L-2 ✅ 개인정보처리방침
│   │   ├── common_security_measures.md             ← B-2 🟡 AWS 계정
│   │   ├── consent_form.md                         ← 개인정보 동의서 🔵
│   │   ├── third_party_provision_policy.md         ← 제3자 제공 정책 🔵
│   │   ├── personal_information_system_security_guide.md ← 개인정보 시스템 보안 🔵
│   │   └── security_measures.md                    ← 보안 조치 기준 🔵
│   └── checklists/                   ← DH-2 영향평가·침해대응 체크리스트 🔵 (3개)
└── security/
    ├── NEXON_SECURITY.md             ← C-1 ✅ 보안진단, SEC-CODE ✅ 코드기준
    ├── policies/
    │   ├── sensitive-data-protection.md  ← C-5 ✅ HTTPS/TLS
    │   ├── code-development-standards.md ← 코드 개발 표준 🔵
    │   ├── error-handling-and-validation.md ← 에러처리·입력검증 🔵
    │   └── security-vulnerability-defense.md ← 취약점 방어 🔵
    └── checklists/                   ← G-2 🔵 코드개발·보안리뷰·취약점 체크리스트 (3개)
```

---

## 정책 원본 위치

| 정책 파일 | 원본 위치 | 담당 부서 | 마지막 확인 |
|---|---|---|---|
| authentication.md | `refs/company-policies/compliance/NEXON-OS/03_DEPENDENCIES/01_AUTH/NXAS/` (사내 SSO), `refs/gamescale-docs/public/docs/ko/service-integration/authentication/` (유저) | 플랫폼실 (연동서비스개발팀) | 2026-03-27 확인 |
| infrastructure.md | {확인 필요} | 인프라팀 | ⬜ 미확인 |
| security.md | {확인 필요} | 보안팀 | ⬜ 미확인 |
| data-handling.md | {확인 필요} | 개인정보보호팀 | ⬜ 미확인 |
| deployment.md | {확인 필요} | DevOps팀 | 일부 확인 (E-1) |

---

## AI 에이전트 사용 가이드

구현 중 정책 확인이 필요하면:

1. `refs/INDEX.md`의 빠른 결정 가이드를 먼저 확인
2. `refs/policies/` 해당 파일에 값이 비어있으면 이 매핑 테이블에서 관련 문서 확인
3. `refs/company-policies/{경로}`를 직접 읽어 상세 내용 참조
4. GameScale 관련이면 `refs/gamescale-docs-index.md` 키워드로 `refs/gamescale-docs/public/docs/ko/{경로}` 참조
