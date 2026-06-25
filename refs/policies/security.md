# 보안 정책

> 실제 사내 보안 정책을 기록합니다.
> **담당 부서**: 보안팀 / 개인정보보호팀

**Last Updated**: 2026-04-15
**데이터 상태**: 📂 company-policies/ 참조 (C-1 ✅, C-3 ✅, C-5 ✅ 완전 커버 | C-2 🟡, C-6 🟡, C-7 🟡 상당 | C-4 🔵 부분)

> 이 파일은 **프로젝트별 수집 필드 기록용**입니다.
> 보안 정책 실제 내용은 `refs/company-policies/security/`를 직접 참조하세요.
> - C-1: `security/NEXON_SECURITY.md` (XSS/SQLi/CSRF 방어, 보안 리뷰 프로세스)
> - C-2: `security/NEXON_SECURITY.md` (SAST, Secret Detection)
> - C-3: `privacy/policies/personal_information_classification.md` (3등급 분류, 암호화 의무)
> - C-4: `security/policies/sensitive-data-protection.md` (암호화 일반 원칙)
> - C-5: `security/policies/sensitive-data-protection.md` (TLS 1.2+, HTTPS 강제)
> - C-6: `security/NEXON_SECURITY.md` (IP 접근 제어)
> - C-7: `privacy/policies/data_management_policy.md` (보관 기간 30일/3년/5년)

---

## C-1. 보안 진단 의무 (📂 ✅ company-policies 완전 커버)

| 항목 | 값 |
|---|---|
| 필수 대상 | |
| 진단 종류 | |
| 신청 방법 | |
| 소요 시간 | |
| 오픈 전 필수 | |

## C-2. 필수 보안 솔루션 (📂 🟡 상당 커버)

| # | 솔루션 | 버전 | 용도 |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

## C-3. 데이터 분류·암호화 (📂 ✅ company-policies 완전 커버)

| 항목 | 값 |
|---|---|
| 데이터 등급 | |
| 개인정보 수집 | |
| 저장 위치 제한 | |
| 저장 시 암호화 | |
| 전송 시 암호화 | |
| 필수 절차 | |

## C-4. S3/스토리지 보안 (📂 🔵 부분 커버)

| 항목 | 값 |
|---|---|
| 퍼블릭 버킷 | |
| 암호화 | |
| 접근 로그 | |
| 버킷 정책 | |

## C-5. HTTPS (📂 ✅ company-policies 완전 커버)

| 항목 | 값 |
|---|---|
| 필수 범위 | |
| 최소 TLS | |
| HTTP→HTTPS | |

## C-6. 접근 제어 (📂 🟡 상당 커버)

| 항목 | 값 |
|---|---|
| VPN 필수 범위 | |
| IP 화이트리스트 | |
| WAF | |
| SSH | |

## C-7. 로그 보관 (📂 🟡 상당 커버)

| 항목 | 값 |
|---|---|
| 보관 기간 | |
| 감사 로그 항목 | |
| 저장 위치 | |
| 모니터링 | |
