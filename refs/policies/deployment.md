# 배포·운영·개발표준 정책

> 실제 사내 개발·배포·운영 정책을 기록합니다.
> **담당 부서**: 개발팀/CTO, DevOps팀, 디자인팀, PM/QA팀

**Last Updated**: 2026-04-16
**데이터 상태**: D-1 📂 ✅ company-policies 확인 / E-1, E-2, D-7 🟢 / F-1, F-2 🟡 추후

---

## D-1. 기술 스택 (📂 ✅ company-policies 완전 커버)

> 출처: `refs/company-policies/compliance/NEXON-OS/02_INFRASTRUCTURE/01_TECH_STACK_GUIDE.md`

| 항목 | 값 |
|---|---|
| 백엔드 언어 | **Python 3.9+** |
| 백엔드 프레임워크 | **Django 4.x** |
| 프론트엔드 | **React 18+** |
| DB (기본) | **PostgreSQL 14+** (특별한 경우 외 우선 사용) |
| DB (비정형) | **MongoDB 6.x** |
| 클라우드 | **AWS** |
| Node.js | |
| TypeScript | |
| 패키지 매니저 | |
| UI 프레임워크 | |

## D-2. 코드 컨벤션

| 항목 | 값 |
|---|---|
| Python 린터 | |
| Python 포맷터 | |
| JS/TS 린터 | |
| JS/TS 포맷터 | |
| import 정렬 | |
| 네이밍 | |

## D-3. Git 브랜치 전략

| 항목 | 값 |
|---|---|
| 전략 | |
| main 보호 | |
| 네이밍 | |
| 릴리즈 | |

## D-4. 커밋 규칙

| 항목 | 값 |
|---|---|
| 형식 | |
| 이슈 트래커 | |
| 언어 | |

## D-5. 코드 리뷰

| 항목 | 값 |
|---|---|
| MR 필수 | |
| 승인자 | |
| CI 통과 조건 | |
| 도구 | |

## D-6. 테스트 기준

| 항목 | 값 |
|---|---|
| 커버리지 | |
| 필수 종류 | |
| 프레임워크 | |
| CI 자동 | |

## D-7. 사내 패키지 (🟢 확인 완료)

| 항목 | 값 |
|---|---|
| 공통 라이브러리 | **없음** (별도 사내 패키지 없음) |
| 레지스트리 | **공개 레지스트리 사용** (npm, PyPI 등 기본) |
| 외부 패키지 | 제한 없음 |

> **확인 일자**: 2026-03-24 (사용자 직접 확인)

---

## E-1. CI/CD (🟢 실제 확인 완료)

| 항목 | 값 |
|---|---|
| 소스 관리 | **GitLab CE v18.4.4** (온프레미스, `gitlab.nexon.com`) |
| CI | **GitLab CI/CD** (`.gitlab-ci.yml`) |
| CD | **ArgoCD** (ECS 배포) |
| 접근 | GitLab (VPN) + ArgoCD 대시보드 (VPN) |
| Instance Runners | **1,218개** (Kubernetes 기반, Linux + Windows) |
| Runner 태그 (Linux) | `kubu-autoscale-linux`, `kubu-shared-runner` |
| Runner 태그 (Large) | `kubu-autoscale-linux-large`, `kubu-shared-runner-large` |
| Runner 태그 (DinD) | `privileged` (Docker-in-Docker) |
| Runner 태그 (Windows) | `windows-docker`, `windows-runner` |
| Container Registry | **GitLab 내장** (활성화, 실사용 중) |
| Package Registry | **GitLab 내장** (npm 500MiB, PyPI 3GiB) |
| 보안 스캔 | GitLab SAST + Secret Detection (내장) |
| CE 제한 | Custom Project Templates 미지원, MR Approval Rules 미지원 |

> **확인 일자**: 2026-03-18 (브라우저에서 실제 GitLab 인스턴스 확인)

## E-2. 배포 환경 (🟢 확인 완료)

| 환경 | 접근 | 스펙 | 환경변수 |
|---|---|---|---|
| dev | | | |
| test | | | |
| live | | | |

> **확인 일자**: 2026-03-24 (사용자 직접 확인)
> **환경 구분**: dev → test → live (3단계)

## E-3. 모니터링

| 항목 | 값 |
|---|---|
| 도구 | |
| 필수 항목 | |
| 알림 임계값 | |

## E-4. 알림

| 항목 | 값 |
|---|---|
| 채널 | |
| P1 (긴급) | |
| P2 (높음) | |
| P3 (보통) | |
| P4 (낮음) | |

## E-5. 장애 대응

| 항목 | 값 |
|---|---|
| 에스컬레이션 | |
| 롤백 | |
| 장애 보고서 | |
| Post-mortem | |

---

## F. 디자인 시스템

| 항목 | 값 |
|---|---|
| 디자인 시스템 | **현재 없음** (추후 반영 예정) |
| 브랜드 가이드 | **현재 없음** (추후 반영 예정) |
| Figma | |
| Storybook | |
| 컴포넌트 | |
| 테마 | |
| Primary 색상 | |
| 헤딩 폰트 | |
| 본문 폰트 | |
| 아이콘 | |
| 다크모드 | |
| 반응형 | |
| 접근성 | |

> **확인 일자**: 2026-03-24 (사용자 직접 확인)
> F-1(디자인 시스템), F-2(브랜드 가이드) 모두 현재 미보유, 추후 도입 예정

### F-GNB. GNB / Footer (📂 🔵 부분 커버)

> 출처: `refs/company-policies/compliance/NEXON-OS/04_DESIGN/02_COMMON_UI_ELEMENTS/`

| 항목 | 값 |
|---|---|
| GNB 유형 | |
| 필수 링크 | |
| GNB 반응형 | |
| Footer 규격 | |

> company-policies에 스켈레톤 가이드 존재. 실제 규격은 디자인팀 확인 필요.

---

## I18N. 다국어 / 현지화 (📂 🔵 부분 커버)

> 출처: `refs/company-policies/compliance/NEXON-OS/05_GLOBALIZATION/`

| 항목 | 값 |
|---|---|
| 인코딩 | **UTF-8** 필수 |
| 텍스트 관리 | 키 기반 렌더링 — 하드코딩 금지 |
| 날짜 포맷 | |
| 통화 포맷 | |
| 숫자 포맷 | |
| 번역 프로세스 | |
| 텍스트 확장 고려 | |

> 상세 포맷 가이드: `05_GLOBALIZATION/02_L10N_GUIDE/FORMATTING/` (DATETIME, CURRENCY, NUMBER)

---

## G. 프로세스·거버넌스

| 항목 | 값 |
|---|---|
| 프로젝트 등록 | |
| 등록 소요 | |
| 오픈 전 체크리스트 | |
| 외부 서비스 승인 | |
| API 문서 | |
| 운영 가이드 | |
| 인수인계 | |
