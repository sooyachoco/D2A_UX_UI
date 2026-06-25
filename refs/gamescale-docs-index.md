# GameScale 문서 인덱스

> 갱신일: 2026-04-02 | 총 문서: 2,920건
> 원본: `refs/gamescale-docs/public/docs/ko/`

이 인덱스는 AI가 사용자 요청을 GameScale 문서 카테고리로 빠르게 라우팅하기 위한 참조 문서입니다.
문서 조회 시 `refs/gamescale-docs/public/docs/ko/{경로}` 디렉터리에서 직접 읽습니다.

---

## 키워드 → 카테고리 라우팅

사용자 요청에서 아래 키워드가 감지되면 해당 카테고리를 참조합니다.

### 인증 (authentication)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 로그인, 회원가입, 인증, 로그아웃 | login, sign-in, sign-up, auth, logout | 넥슨 로그인, 넥슨ID |
| OAuth, 인가 코드, 토큰 | OAuth, authorization code, token | access token, refresh token, bearer |
| SSO, 세션, 게임 세션 | SSO, session, game session | single sign-on, 세션 관리 |
| 게스트 로그인, 소셜 로그인 | guest login, social login | 비회원 로그인, 간편 로그인, Apple/Google/Steam 로그인 |
| 계정 연동, 계정 링크, 플랫폼 인증 | account link, platform auth | 계정 통합, 크로스 플랫폼 로그인, 대표 플랫폼 |
| 넥슨 계정, 회원 정책 | Nexon account, member policy | NXAS, 계정 시스템 |

**로컬 경로**: `service-integration/authentication/`, `sdk-and-api/gamescale-sdk/authentication/`

### 게임 경제 (game-economy)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 결제, 인앱결제, 인앱구매 | payment, in-app purchase, IAP | 빌링, billing, 과금, 유료 |
| 캐시, 넥슨캐시, 재화, 게임코인 | cash, Nexon Cash, currency, game coin | NC, 게임머니, 골드, 다이아 |
| 상점, 스토어, 아이템 | store, shop, item | Alltem, 올템, NISMS, 판다 |
| 거래소, 옥션, 마켓 | auction house, market | 유저간 거래, P2P 거래 |
| 마일리지, 플레이포인트 | mileage, play point | 적립, 리워드, 보상 포인트 |
| 영수증 검증, 환불 | receipt validation, refund | 결제 검증, 구매 복원, restore |
| 직접결제, 간접결제, PG | direct pay, indirect pay, PG | KCP, 쿠콘, 다날, 디지털결제 |
| 구독, 정기결제 | subscription | 자동결제, 반복결제 |

**로컬 경로**: `service-integration/game-economy/`, `sdk-and-api/currency/`

### 분석 (analytics)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 로그, 이벤트, 로깅 | log, event, logging | NxLog, 표준로그, 커스텀로그 |
| 분석, 데이터, 통계 | analytics, data, statistics | 데이터 분석, 게임 분석 |
| KPI, 지표, DAU, MAU | KPI, metrics, DAU, MAU | 핵심 지표, 활성 유저 |
| AB테스트, 실험 | A/B test, experiment | 스플릿 테스트, 변수 테스트 |
| 유저 행동 분석, 퍼널, 리텐션 | user behavior, funnel, retention | 이탈 분석, 복귀율 |
| 트래킹, 추적, 어트리뷰션 | tracking, attribution | 이벤트 추적, 유입 분석 |
| NxData, NxCommand, NxLog | NxData, NxCommand, NxLog | 데이터 파이프라인, 명령어 연동 |
| DataSDK, 데이터 수집 | DataSDK, data collection | 서버 DataSDK, 클라이언트 SDK |
| Trendi, Monolake, UX분석 | Trendi, Monolake, UX analysis | 대시보드, 리포트 |

**로컬 경로**: `service-integration/analytics/`, `sdk-and-api/datasdk/`, `sdk-and-api/nxlog/`, `getting-started/nxdata/`

### 커뮤니티 (community)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 커뮤니티, 게시판, 댓글 | community, board, comment | 유저 게시판, 포럼 |
| 공지사항, 소셜, UGC | notice, social, UGC | 유저 콘텐츠 |
| 채팅, 메시지 | chat, message | Sendbird, Vivox, 인게임 채팅 |
| 디스코드, 플레이톡 | Discord, Playtalk | 디스코드 봇, Discotech |
| 친구, 소셜 기능, 공유 | friends, social, share | 친구 목록, SNS 공유 |
| Open API | Open API | 외부 연동 API |

**로컬 경로**: `service-integration/community/`, `sdk-and-api/gamescale-sdk/social/`

### 런칭 (launch)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 런칭, 출시, 오픈 | launch, release, go-live | 서비스 오픈, 라이브 |
| 배포, 패치, 빌드 | deployment, patch, build | NxPatcher, NGM, onebd |
| 런처, 실행 | launcher, execution | 웹 런치, PC 런처 |
| 사전등록, NDR | pre-registration, NDR | 사전예약, GRAM |
| 넥슨 홈, 게임 홈 | Nexon Home, game home | GNB, 웹 로그인 |
| 버전 관리, 업데이트 | version, update | 핫픽스, 유지보수 패치 |

**로컬 경로**: `service-integration/launch/`, `sdk-and-api/deployment/`, `sdk-and-api/launcher/`

### 마케팅 (marketing)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 푸시 알림, 알림, 노티 | push, notification, noti | 리모트 푸시, 로컬 푸시 |
| 캠페인, 프로모션, 배너 | campaign, promotion, banner | 이벤트 배너, 인게임 배너 |
| 쿠폰, 보상 | coupon, reward | NICMS, TEN, 쿠폰플러스, 웹 쿠폰 |
| 타겟팅, 세그먼트 | targeting, segment | 유저 분류, 그룹 |
| 광고, 애드몹, 앱러빈 | ad, AdMob, AppLovin | CEM, 넥슨 광고, MAX |
| 크리에이터즈, 인플루언서 | Creators, influencer | 크리에이터 마케팅 |
| PC방, PC카페 | PC cafe, PC bang | GUSS, PC방 제휴 |
| Twitch Drops, 치지직 | Twitch Drops, Chzzk | 방송 연동, 드롭스 |
| Nexon Prime | Nexon Prime | 프라임 보상 |

**로컬 경로**: `service-integration/marketing/`, `sdk-and-api/coupons/`, `sdk-and-api/gamescale-sdk/push/`, `sdk-and-api/gamescale-sdk/promotion/`

### 운영/CS (operations-customer-support)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 운영, 운영 도구, 백오피스 | operations, backoffice, admin | GOT, 게임 운영 도구 |
| 고객지원, CS, 고객센터 | customer support, CS, help center | 문의, 티켓, 1:1 문의 |
| 제재, 밴, 차단 | sanction, ban, block | 이용 제한, 접근 제한 |
| 복구, 롤백 | recovery, rollback | 아이템 복구, 계정 복구 |
| 공지, 점검 | notice, maintenance | 서버 점검, 긴급 점검 |
| 자동 응답, ACS | auto calling, ACS | 자동 전화 시스템 |
| 넥슨 플레이 | Nexon Play | 게임 관리 |
| NARK | NARK | 운영 로그 도구 |

**로컬 경로**: `service-integration/operations-customer-support/`, `sdk-and-api/game-operation-tool/`, `sdk-and-api/customer-center/`

### 개발 지원 (development-support)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 개발 환경, 테스트 서버 | dev environment, test server | 스테이징, sandbox |
| API 게이트웨이 | API gateway | 게이트웨이, 라우팅 |
| 빌드 공유, 앱박스 | share builds, Appbox | 테스트 빌드, 내부 배포 |
| 다국어, 현지화, 번역 | localization, translation, i18n | TLM, 텍스트 관리, 다국어 지원 |
| 웹뷰, 하이브리드 | webview, hybrid | 인앱 웹뷰 |
| 서버 빌드 라이브러리 | server building library | 서버 프레임워크 |
| 예스장 | Yesjang | QA 도구, 테스트 플랫폼 |
| LiveTV | LiveTV | 라이브 방송 |

**로컬 경로**: `service-integration/development-support/`

### 보안 · 리스크 관리 (risk-management)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 보안, 게임 보안, 해킹 방지 | security, game protection, anti-hack | 치팅 방지, 핵 방지 |
| NGS, NGS-X, NGSM | NGS, NGS-X, NGSM | 게임 가드, 보안 모듈, 엔진 패치 |
| 치트 탐지, 이상 행위 | cheat detection, anomaly detection | 봇 탐지, 오토 탐지, 매크로 |
| 부정결제, 결제 이상 탐지 | payment anomaly, fraud detection | 환불 사기, 현금화 제한 |
| 2차 인증, OTP, MFA | 2FA, OTP, MFA, two-factor auth | ISOU, 간편인증, 안심기기 |
| 계정 보호, 계정 신뢰도 | account protection, account trust | 탈취 방지, 해킹 방지 |
| 접근 제한, 네트워크 차단 | game restriction, network blocking | IP 차단, 접속 차단 |
| 텍스트 탐지, 이미지 탐지 | text detection, image detection | 욕설 필터, 음란 필터, 콘텐츠 필터링 |
| 비전 핵, 화면 캡처 | vision hack, screen capture | 스크린 캡처 방지 |
| 개인정보, 개인정보 보호 | personal information, privacy | GDPR, 개인정보 수집/관리 |
| 위변조 방지 | anti-tampering | NCOOB, 무결성 검증 |

**로컬 경로**: `service-integration/risk-management/`, `sdk-and-api/game-protection/`

### 정책 (policy)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 정책, 약관, 이용약관 | policy, terms, ToS | 서비스 약관 |
| 개인정보, GDPR | privacy, GDPR | 개인정보 처리방침 |
| 미성년자, 게임법, 연령 제한 | minor, game law, age restriction | 청소년 보호, 셧다운제 |
| 확률 공개, 가챠 | loot box odds, gacha | 뽑기 확률, 확률형 아이템 |
| GRAM, 사전등록 | GRAM, pre-registration | 사전예약 페이지 |

**로컬 경로**: `service-integration/policy/`, `sdk-and-api/minor-protection/`

### QA (quality-assurance)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| QA, 품질, 테스트 | QA, quality, test | 품질 보증, 테스팅 |
| 버그, 크래시, 에러 | bug, crash, error | 충돌, 비정상 종료, 크래시 리포트 |
| 호환성, 디바이스 | compatibility, device | 기기 호환, 해상도 |
| 자동화 테스트 | automation test | 테스트 자동화, CI 테스트 |
| 성능 측정 | performance measurement | FPS, 프레임, 메모리, 렌더링 |
| NES | NES | Nexon Evaluation System |

**로컬 경로**: `service-integration/quality-assurance/`

### 추천 (recommendation)

| 한글 키워드 | 영문 키워드 | 유사어·약어 |
|------------|-----------|-----------|
| 추천, 개인화 | recommendation, personalization | 맞춤 추천 |
| 콘텐츠 추천, 아이템 추천 | content recommendation, item recommendation | 상품 추천 |
| 소셜 추천, 친구 추천 | social recommendation | 함께 플레이 |
| 커스텀 포탈 | custom portal | 포탈 페이지 |
| 매치몹 | Matchmob | 매칭 |

**로컬 경로**: `service-integration/recommendation/`

---

## SDK & API 상세 (sdk-and-api)

GameScale SDK 하위 기능별 라우팅입니다.

| 기능 영역 | 한글명 | 영문 경로 | 키워드 | 플랫폼 |
|----------|-------|----------|-------|-------|
| 인증 | 인증 | authentication | 로그인, 로그아웃, 게스트, 계정 연동, 계정 전환 | Android, iOS, Unity, Unreal, Windows |
| 결제 | 빌링 | billing | 인앱결제, 상품 목록, 구매 이력, 구매 복원, DLC | Android, iOS, Unity, Unreal |
| 커머스 | 커머스 | commerce | 장바구니, 게임코인, 카트 | Android, iOS, Unity, Unreal |
| 커뮤니티 | 커뮤니티 | community | 게시판, 댓글, 소셜 | Android, iOS, Unity, Unreal |
| 소셜 | 소셜 | social | 친구, 디스코드, 카카오, 공유, SNS | Android, iOS, Unity, Unreal, Windows |
| 스토어 | 스토어 | store | 구독, 스토어 타입, 국가별 차단, Apple 프로모션 | Android, iOS, Unity, Unreal |
| 푸시 | 푸시 | push | 리모트 푸시, 로컬 푸시, 뱃지, 인게임 이벤트 푸시, 유저 활동 감지 | Android, iOS, Unity, Unreal |
| 프로모션 | 프로모션 | promotion | 배너, 조건부 배너, 엔딩 배너, PLCC, Google 프로모션 | Android, iOS, Unity, Unreal |
| 운영 | 운영 | operation | 공지, 점검, 고객센터, 베이스플레이트, Today, FAQ, 스크린샷 | Android, iOS, Unity, Unreal |
| 정책 | 정책 | policy | IDFA, 광고ID, 전화번호 수집, 미성년자, 원격 푸시 정책, 권한 | Android, iOS, Unity, Unreal |
| 분석 | 분석 | analytics | NxLog 수집, Firebase Analytics, Firebase Crashlytics, UX 트래킹 | Android, iOS, Unity, Unreal |
| 현지화 | 현지화 | localization | 언어 설정, 국가 설정, 국가 차단 | Android, iOS, Unity, Unreal |
| 보안 | 보안 | security | 무결성 검증, 치팅 방지 | — |
| 서비스 | 서비스 | service | 약관 동의, 제재, 활동 비활동 | — |
| 지원 | 지원 | support | Epic Online Service, GPG, UI 스케일, 다크모드, 외부ID, Steam, PlayStation, Xbox | Unity, Unreal, Windows |
| 웹 | 웹 | web | 웹뷰 URL, 웹 연동 | Android, iOS, Unity, Unreal |
| 라이프사이클 | 라이프사이클 | lifecycle | SDK 초기화, 종료, 앱 상태 | — |
| SDK 연동 | SDK 연동 | integrate-sdk | 설치, 초기화, Gradle 설정, 빌드 설정 | Android, iOS, Unity, Unreal, Windows |
| 다운로드 | 다운로드 | download | SDK 다운로드, 버전 업그레이드 | — |
| 릴리즈 노트 | 릴리즈 노트 | release-notes | 버전 변경 이력 | Android, iOS, Unity, Unreal, Windows |

### 기타 SDK & API

| SDK/서비스 | 한글 | 키워드 · 유사어 |
|-----------|------|---------------|
| DataSDK | 데이터SDK | 서버 DataSDK, 로그 수집, 디바이스ID, 시스템 데이터, 보안 전송 |
| NxPatcher | 넥슨패처 | 게임 패치, 빌드 관리, 패치 다운로드, CI 연동, Unity/Unreal/Android/iOS |
| NGS | 넥슨게임시큐리티 | 클라이언트 보안, 서버 연동, 스크린캡처, 사설서버 탐지, HWID |
| NGS-X | 넥슨게임시큐리티X | 차세대 보안, 앱/클라이언트/서버 연동, 캡처 방지 |
| NGSM | 넥슨게임시큐리티모바일 | 모바일 보안, v4/v5, 팜 탐지, SDK/Native/Unity/Unreal |
| GameScale Web SDK | 웹SDK | 웹 인증, 웹 빌링 |
| GOT | 게임운영도구 | GOT v1/v2, 단건/다건/벌크 요청, 서버 API |
| 쿠폰 (NICMS) | 쿠폰관리 | 쿠폰 발급, 쿠폰 사용, 쿠폰함, 쿠폰 퍼블리싱 |
| 쿠폰 (TEN) | 웹쿠폰 | 웹 쿠폰 연동 |
| Alltem | 올템 | 아이템 스토어 API, 리소스 모델 |
| NISMS/Panda | 닛심스/판다 | 직접결제, 스토어 연동 |
| CEM | 콘텐츠노출관리 | 넥슨 광고, 클라이언트/서버 연동 |
| ISOU | 아이소 | 2차 인증, OTP 대체 |
| Launcher | 런처 | 웹 런치, PC 게임 실행 제어 |
| AdMob/AppLovin | 광고SDK | AdMob 비딩, AppLovin MAX, 유니티 |
| Nexon Home | 넥슨 홈 | 넥슨 쪽지 API, 게임 홈 |
| Nexon Play | 넥슨 플레이 | 멤버십, 접근 권한 |
| Currency | 재화 | 넥슨캐시, 게임코인, 직접결제 마일리지 |
| PG 결제 | PG결제 | KCP, 쿠콘, 다날, 디지털결제, 자동결제 |

---

## 시작 가이드 (getting-started)

| 하위 카테고리 | 한글 | 키워드 · 유사어 |
|-------------|------|---------------|
| Infrastructure | 인프라 | Aurora 커넥션, 동시접속자, DB샤딩, MySQL, MSSQL, Redis 랭킹, 캐싱, KPI 데이터, 성능테스트 |
| NxData | 넥슨데이터 | NxCommand(명령어 연동), NxLog(로그), NxGameMeta(메타데이터), 게임 연동 서버 |
| (루트) | 시작 | GameScale SDK 이해, 주요 식별자, GameScale 출시 가이드 |

**로컬 경로**: `getting-started/`

---

## 레퍼런스 (reference)

| 하위 카테고리 | 한글 | 키워드 · 유사어 |
|-------------|------|---------------|
| Archive | 아카이브 | 이전 버전 문서, 빌링 1.0, ARA, NxAds, SSO, 네이버 채널링, 웹, 미성년자 결제 |
| FAQ | 자주 묻는 질문 | GameScale SDK FAQ, KRPC FAQ |
| Glossary | 용어집 | 용어 정의, SDK 용어, KRPC 용어, NGSM 용어 |
| (루트) | 레퍼런스 | 국가 코드, 가이드 변경 이력, 문서 수정 신청 |

**로컬 경로**: `reference/`

---

## 교차 참조 (한글 ↔ 영문 빠른 찾기)

| 한글 | 영문 | 카테고리 |
|------|------|---------|
| 인증 | authentication | 인증 |
| 결제 | payment / billing | 게임 경제 |
| 재화 | currency | 게임 경제 |
| 분석 | analytics | 분석 |
| 로그 | log / NxLog | 분석 |
| 커뮤니티 | community | 커뮤니티 |
| 채팅 | chat | 커뮤니티 |
| 런칭 | launch | 런칭 |
| 배포 | deployment | 런칭 |
| 패치 | patch / NxPatcher | 런칭 |
| 마케팅 | marketing | 마케팅 |
| 푸시 | push notification | 마케팅 |
| 쿠폰 | coupon / NICMS / TEN | 마케팅 |
| 광고 | ad / AdMob / CEM | 마케팅 |
| 운영 | operations | 운영/CS |
| 고객센터 | customer center / CS | 운영/CS |
| 제재 | sanction / ban | 운영/CS |
| 보안 | security / game protection | 리스크 관리 |
| 치팅 | cheat / hack | 리스크 관리 |
| 2차인증 | 2FA / OTP / ISOU | 리스크 관리 |
| 정책 | policy | 정책 |
| 미성년자 | minor / game law | 정책 |
| QA | quality assurance | QA |
| 크래시 | crash | QA |
| 추천 | recommendation | 추천 |
| 개발지원 | development support | 개발 지원 |
| 현지화 | localization / i18n | 개발 지원 |
| 스토어 | store / Alltem | 게임 경제 |
| 거래소 | auction house | 게임 경제 |
| 친구 | friends / social | 커뮤니티 |
| 디스코드 | Discord | 커뮤니티 |
| SDK | GameScale SDK | SDK/API |
| 웹SDK | GameScale Web SDK | SDK/API |
| 데이터SDK | DataSDK | 분석 |
| 게임가드 | NGS / NGSM / NGS-X | 리스크 관리 |
| 런처 | launcher | 런칭 |
| PC방 | PC cafe / GUSS | 마케팅 |
| 사전등록 | pre-registration / GRAM | 정책 |
| 빌드공유 | share builds / Appbox | 개발 지원 |
| 예스장 | Yesjang | 개발 지원 |
