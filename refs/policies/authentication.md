# 인증 정책 — 라우터

> 이 파일은 인덱스입니다. 상세 내용은 아래 두 파일을 읽으세요.
> **Last Updated**: 2026-04-15

## 인증 시스템 판별

| 대상 | 인증 시스템 | 참조 파일 |
|---|---|---|
| **사내 직원** (관리자, 백오피스) | NXAS SSO | [`authentication-nxas.md`](./authentication-nxas.md) |
| **넥슨 회원 / GameScale 유저** (외부 유저) | INSIGN / GameScale SDK | [`authentication-external.md`](./authentication-external.md) |

**판별 키워드:**
- `nxas.nexon.com`, `EMPNO`, `DEPTCode` → **NXAS** (사내)
- `login.nexon.com`, `MemberSN`, `NexonID` → **넥슨 회원** (외부)
- `signin.nexon.com`, `GameScale SDK`, `_ifwt` → **INSIGN/GameScale** (외부)

## 빠른 결정

| 항목 | 결정 | 파일 |
|---|---|---|
| 사내 토큰 만료 | AccessToken 30분, RefreshToken 60분 | `authentication-nxas.md` A-4a |
| 사내 SSO 로그아웃 | `nxas.nexon.com/Logout?redirectUri=...` | `authentication-nxas.md` A-4a |
| 외부 유저 도메인 제약 | `*.nexon.com` 외 도메인은 `/insign` 페이지 필요 | `authentication-external.md` A-2d |
| API Gateway 로컬 개발 | Gateway → localhost 연결 불가, 직접 호출 전략 사용 | `authentication-external.md` A-9 |
| GNB 로컬 개발 | localhost 쿠키 접근 불가, hosts 설정 필요 | `authentication-external.md` A-10 |
