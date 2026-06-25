# 사내 인증 정책 — NXAS SSO

> **적용 대상**: 사내 직원·관리자·백오피스 서비스
> **인증 시스템**: NXAS (Nexon Authentication Service) OAuth 2.0
> **담당 부서**: 플랫폼개발팀 — Jira `PLATFORM`, Slack `#platform-support`

---

## A-1a. 사내 인증 시스템 개요

| 항목 | 값 |
|---|---|
| 인증 방식 | NXAS OAuth 2.0 SSO |
| 대상 | 넥슨 및 연동 넥슨그룹 법인 임직원, 개발사, 외부 협력 업체 |
| 지원 인증 유형 | Authorization Code Grant (권장), Resource Owner Password Credentials Grant, Client Credentials Grant |
| 비지원 | Implicit Grant (보안상 신청 불가) |
| 인증 문서 위치 | `refs/company-policies/compliance/NEXON-OS/03_DEPENDENCIES/01_AUTH/NXAS/` |

### 서비스 환경 정보

| 환경 | URL | IP | 포트 | 비고 |
|---|---|---|---|---|
| 개발(Dev) | `https://dev-nxas.nexon.com/` | Private `10.248.194.121`, Public `183.110.50.89` | 443 | NeoDev |
| 스테이지(Stage, 개발망) | `https://stage-nxas.nexon.com/` | Private `10.248.194.90`, Public `183.110.50.76` | 443 | NeoDev |
| 스테이지(Stage, 라이브망) | `https://ls-nxas.nexon.com/` | LB `3.36.143.230`, `3.35.61.153` | 443 | AWS |
| 라이브(Live) | `https://nxas.nexon.com/` | AnyOpen (접근 제어 불필요) | 443 | L4 |

> Dev/Stage 환경 접근 시 NCSR을 통한 네트워크 ACL 신청 필요.

---

## A-2a. Authorization Code Grant 흐름

| 항목 | 값 |
|---|---|
| Authorization URL | `GET https://{env}-nxas.nexon.com/api/auth/authorize` |
| Token URL | `POST https://{env}-nxas.nexon.com/api/auth/token` |
| 콜백 URL 패턴 | 클라이언트 등록 시 지정 (라이브: HTTPS 필수) |
| Scope | `resource` |
| 사용자 정보 API | `GET https://{env}-nxas.nexon.com/api/service/user/GetProfile` |
| 토큰 타입 | `Bearer` |
| 리프레시 토큰 | 지원 (`grant_type=refresh_token`) |

### Authorization Code 발급 파라미터

| 파라미터 | 필수 | 비고 |
|---|---|---|
| `response_type=code` | 필수 | |
| `client_id` | 필수 | NCSR에서 발급 |
| `redirect_uri` | 선택 | 미입력 시 등록된 Callback URL |
| `state` | 선택 | CSRF 방어 — **강력 권장** |

### AccessToken 발급 파라미터

| 파라미터 | 필수 |
|---|---|
| `grant_type=authorization_code` | 필수 |
| `code` | 필수 |
| `redirect_uri` | 필수 |
| `client_id` | 필수 |

### AccessToken 응답

| 필드 | 값 |
|---|---|
| `access_token` | AccessToken |
| `token_type` | `Bearer` |
| `expires_in` | `1800` (30분) |
| `refresh_token` | RefreshToken |

### GetProfile 주요 필드

| 필드 | 설명 |
|---|---|
| `EMPNO` | 사번 |
| `EMPID` | 계정 |
| `CMPCode` / `CMPName` | 법인 코드/명 |
| `DEPTCode` / `DEPTName` | 부서 코드/명 |
| `TeamCode` / `TeamName` | 팀 코드/명 |
| `EMPEmail` | 이메일 |
| `EmpDisplayName` | 사원 표기명 (예: `홍길동 [honggildong]`) |

---

## A-3. 서비스 등록 절차

| 항목 | 값 |
|---|---|
| 클라이언트 등록 | NCSR — `https://ncsr.nexon.com/CSR/Write/23/161` → "클라이언트 등록" |
| 네트워크 ACL | NCSR — `https://ncsr.nexon.com/CSR/Write/16/327` |
| 필요 정보 | 클라이언트 이름, 인증 유형, Callback URL, Logout URL |
| SAML 연동 | NCSR — 동일 URL → "SAML 연동 신청" |

- Callback/Logout URL에 반드시 프로토콜(`HTTP`/`HTTPS`) 기입
- 라이브 환경은 **반드시 HTTPS**
- 사내 도메인 외 외부 도메인 사용 시 등록 요청에 명시

### A-3a. Callback URL 허용 도메인 목록

> 이 목록에 없는 도메인은 콜백이 차단됨. NCSR "클라이언트 변경"으로 추가 요청.

| 카테고리 | 도메인 |
|---|---|
| 넥슨 핵심 | `.nexon.com`, `.nexon.co.kr`, `.nexon.co.jp`, `.nexon.io`, `.nexon.net` |
| 넥슨 관계사 | `.neople.co.kr`, `.nexon-networks.co.kr`, `.nexon-communications.co.kr` |
| 넥슨 클라우드·개발 | `.nexoncloud.com`, `.nxdev.kr`, `.gamescale.io`, `.nxgd.io` |
| AWS 인프라 | `.ap-northeast-2.elb.amazonaws.com`, `.us-west-2.amazoncognito.com` |

**차단 도메인**: `localhost`, `127.0.0.1`, `*.vercel.app`, `*.netlify.app` — 모두 ❌

### A-3b. 로컬 개발 환경 HTTPS + hosts 설정

`localhost`는 NXAS 허용 도메인이 아니므로 hosts 파일 설정 필수.
또한 INSIGN `_ifwt` 쿠키는 HTTPS에서만 정상 발급된다 — **로컬도 HTTPS 필수**.

**HTTPS 인증서 생성 (mkcert):**

```bash
# 프로젝트 루트에서 실행 — hosts 등록까지 자동 처리
./scripts/setup-https.sh dev-{서비스}.nexon.com frontend
```

hosts만 수동으로 추가할 경우:

```bash
# Mac/Linux
sudo sh -c 'echo "127.0.0.1  dev-{서비스}.nexon.com" >> /etc/hosts'
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder  # Mac DNS 초기화

# 설정 확인
ping -c 1 dev-{서비스}.nexon.com  # 127.0.0.1이 나오면 성공
```

Windows: 메모장 관리자 권한으로 `C:\Windows\System32\drivers\etc\hosts` 편집 후 `ipconfig /flushdns`

**Callback URL 패턴:**

| 환경 | Callback URL |
|---|---|
| 로컬 | `https://dev-{서비스}.nexon.com/auth/callback` |
| 스테이지 | `https://stage-{서비스}.nexon.com/auth/callback` |
| 라이브 | `https://{서비스}.nexon.com/auth/callback` |

> 로컬은 포트 443 표준 사용 (`sudo npm run dev` 또는 pfctl 포워딩).
> 포트 4430을 불가피하게 쓰는 경우 NCSR 등록 URL에 `:4430`을 반드시 포함해야 한다.

### A-3c. DNS 도메인 등록 (NCSR)

| 항목 | 값 |
|---|---|
| NCSR URL | `https://ncsr.nexon.com/CSR/Write/23/551` |
| 긴급 문의 | `system_dns@nexon.co.kr` |

**도메인 용도별 정책:**

| 도메인 | 개발 환경 | 라이브 환경 |
|---|---|---|
| `nexon.com` | ❌ 반려 | ✅ 대고객 서비스만 |
| `nxgd.io` | ✅ **권장** | ❌ |
| `stg.nexon.com` | ✅ | ✅ |

> `nexon.com`으로 개발/스테이지 도메인 신청 시 **반려**. 신규 개발 환경은 `nxgd.io` 사용.

### A-3d. 네트워크 ACL

| 대상 | ACL 필요 여부 |
|---|---|
| NXAS 라이브 (`nxas.nexon.com`) | ❌ AnyOpen |
| NXAS Dev (`dev-nxas.nexon.com`) | ✅ Private IP |
| NXAS Stage 개발망 | ✅ Private IP |
| INSIGN (`signin.nexon.com`) | ❌ 공개 서비스 |

ACL 신청: NCSR `https://ncsr.nexon.com/CSR/Write/16/327`

---

## A-4a. 세션 정책

| 항목 | 값 |
|---|---|
| AccessToken 만료 | 1800초 (30분) |
| RefreshToken 만료 | 3600초 (60분) |
| 동시 로그인 | SSO 전역 세션 공유 |
| 세션 저장소 | NXAS 서버 측 관리 |
| 로그아웃 URL | `https://nxas.nexon.com/Logout?redirectUri={callbackUrl}` |

- SSL 미적용 서비스: 타 서비스 로그아웃 호출 시 실패 가능
- `nexon.com` 외 도메인: CORS 문제로 로그아웃 실패 가능 → NXAS 도메인 CORS 예외 등록 필요

---

## A-6. 추가 연동 옵션

### SAML 2.0

| URI | 값 |
|---|---|
| Login | `/api/auth/saml/Login` |
| Logout (POST) | `/api/auth/saml/Logout` |
| Logout (GET) | `https://nxas.nexon.com/Logout?redirectUri={url}` |
| MetaData | `/api/auth/saml/MetaData` |

### 2차 인증 (OTP Login)

- SSO 연동 선행 필수
- 인증 수단: Google OTP, Spoon+ App
- 인증 URI: `GET /OTPLogin?redirect_uri={url}&state={state}`
- 검증 URI: `POST /api/otp/LoginValidation` (Bearer AccessToken 필요)
- 검증 유효 시간: 로그인 후 **10초**

### OneLogin (토큰 기반 웹 세션)

- Client Credentials Grant 방식 필요
- Token URI: `POST /api/auth/OneLoginToken`
- 서비스 접근: `GET /OneLogin?empno={사번}&token={토큰}`
