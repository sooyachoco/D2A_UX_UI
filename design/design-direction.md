# 디자인 방향 — NEXON Live

> boilerplate-setup (경량 모드) Q5* 디자인 샘플 선택 직후 생성.
> create-spec Step 2.7(UI 프로토타입)에서 실제 코드로 구현한다.

## 디자인 시스템

- 디자인 시스템: **NX Basic 1.0v** (`DESIGN_SYSTEM=nxbasic`)
- 적용 경로: 사용자 선택 (NX Basic 고정) — 웹 디자인 리서치 생략
- 참조: `refs/design-systems/nxbasic-1.0v.md` · 토큰 출처 `nxbasic-mcp` (`https://nxbasic-mcp.sooyachoco.workers.dev/mcp`)
- 토큰 준수: 색상·타이포·컴포넌트는 NX Basic 18종/토큰 144개를 고정. 임의 변주 금지(`design-quality-guard` 갈음).

## 선택된 디자인 샘플

- 선택된 샘플: **A — 사이드바 + 콘텐츠** (좌측 네비 레일 + 중앙 플레이어 + 우측 고정 채팅)
- 디자인 톤: 역동성 + 혁신/모던함 (라이브 스트리밍) → NX Basic 토큰으로 표현
- UI 프레임워크: React + `nxbasic` 패키지 (`import { Button } from 'nxbasic'`) — 미설치 시 Storybook 스펙 기반 동등 구현
- HTML 프리뷰: `design/samples.html` (A/B/C 비교, A 확정)

## 확정된 방향

- 레이아웃: **3-column 클래식 스트리밍** — 좌측 아이콘 레일(72px) · 중앙 플레이어+방송정보 · 우측 실시간 채팅(340px 고정)
- 색상: NX Basic point color(pc) primary `#0A74FF` + basic color(bc) 중립 + 화이트 surface
- 톤앤매너: 단골 시청자에게 익숙한 트위치/치지직형 구조 + 넥슨 정체성(파랑 primary). 다크 플레이어 / 라이트 채팅·정보 영역 대비.

## 리서치 근거 연결 (refs/ux-research 단일 source)

선택 레이아웃은 검증된 페인포인트(5월 쇼케이스 설문 S5, 🟢 검증)를 직접 반영한다:

| 페인포인트 (출처) | 레이아웃 A 반영 |
|---|---|
| 첫 진입 음소거 인지 못함 | 플레이어에 음소거 코치마크("🔇 소리 켜기") 상시 노출, 첫 상호작용 시 해제 |
| 채팅 시인성(닉네임 구분·PC 폰트) | 닉네임 색상 구분, 본인 메시지 강조(좌측 바+배경), 운영자 메시지 별도 UI, 14px 본문 |
| 신고 UX 비표준 | 채팅 메시지 호버 시 "신고" 어포던스 노출 |
| 도네이션·인터랙션 니즈 | 우측 채팅 하단 리액션 바(❤️😆👏) + 넥슨캐시 후원 버튼 상시 |
| 서비스 정체성(스트리밍 인식) | 라이브쇼핑형이 아닌 스트리밍형 3분할 구조 채택 |

> 페르소나·여정 단일 source: [refs/ux-research/PERSONA.md](../refs/ux-research/PERSONA.md), [USER_JOURNEY_MAP.md](../refs/ux-research/USER_JOURNEY_MAP.md)

## 색상 시스템 (NX Basic 토큰 — nxbasic-mcp 실측값)

| 역할 | 토큰 | Hex | 용도 |
|---|---|---|---|
| Primary 100 | `--color-pc-100` | #ecf1f9 | 연한 배경, 선택/호버 |
| Primary 200 | `--color-pc-200` | #cce2ff | 보조 배경, 태그 |
| Primary 500 | `--color-pc-500` | #6babff | 강조 |
| Primary 600 | `--color-pc-600` | #57a0ff | action.primary |
| Primary 700 | `--color-pc-700` | #3d91ff | action.primaryHover |
| **Primary 800** | `--semantic-primary` (pc-800) | **#0a74ff** | **기본 (버튼·링크·강조)** |
| Primary 900 | `--semantic-primary-hover` (pc-900) | #0056c7 | 호버 |
| Primary 1000 | `--semantic-primary-pressed` (pc-1000) | #1e4b85 | 눌림 |
| Neutral 100 | `--color-bc-100` | #e8ebf2 | 페이지 배경 |
| Neutral 200 | `--color-bc-200` | #d2d6e0 | 구분선(soft) |
| Neutral 300 | `--semantic-border` (bc-300) | #c6ccd7 | 테두리 |
| Neutral 500 | `--semantic-text-disabled` (bc-500) | #a1a7b5 | placeholder/비활성 |
| Neutral 700 | `--semantic-text-sub` (bc-700) | #747a86 | 보조 텍스트 |
| Neutral 900 | `--semantic-text` (bc-900) | #3d4148 | 본문 |
| Neutral 1000 | `--semantic-text-strong` (bc-1000) | #17191c | 제목/강조 텍스트 |
| Surface | `--color-surface-default` | #fcfcfd | 카드/패널 배경 |
| Surface muted | `--color-surface-muted` | #f9fafb | 보조 영역 |
| Success | `--color-success` | #59e387 | 완료/온라인 |
| Warning | `--color-warning` | #ffbb00 | 경고 |
| Error/Danger | `--color-danger` | #ef5d5d | LIVE 뱃지·신고·에러 |

## 타이포그래피

- 폰트 패밀리: NX Basic `--font-family-base` 기준. 본 프로토타입은 Pretendard → 시스템 한글 스택 폴백
  (`"Pretendard",-apple-system,"Malgun Gothic","Apple SD Gothic Neo",system-ui,sans-serif`)
- 스케일: NX Basic **type scale 13단계** (`type-default-*`) 사용. 굵기 `w-light`·`w-medium`·`w-bold`(700) 등 3종 이상.

| 요소 | 크기(대표) | 굵기 | 용도 |
|---|---|---|---|
| H1 | 24–28px | 800 | 방송 제목/페이지 헤더 |
| H2 | 17–19px | 700 | 섹션·스트리머명 |
| Body | 14px | 400/600 | 채팅·본문 |
| Body Small | 13px | 600 | 메타·라벨 |
| Caption | 11–12px | 600/700 | 태그·뱃지·시청자 수 |

> 채팅 본문은 시인성 검증 결과 반영: **14px 이상**, 닉네임 800 굵기 + 색상 구분, 본문/닉네임 대비 확보.

## 여백 · Radius · 모션

- 여백: 4px 그리드 (space-1=4 … space-6=24 … space-16=64). 레일/채팅 등 영역은 16–24px 내부 패딩.
- Radius: NX Basic 미정의 → 보일러플레이트 표준 적용 — `radius-md 8px`(버튼·입력), `radius-lg 12px`(카드), `radius-full`(아바타·태그·리액션).
- 모션: duration-fast 150ms(호버·토글) / normal 300ms(패널). 음소거 코치마크 bob 1.8s. `prefers-reduced-motion` 분기 필수.
- 마이크로 인터랙션: 버튼 호버 시 배경 밝기↑, 카드 호버 translateY(-2px), 리액션 호버 scale↑.

## 표면 & 깊이

| 레벨 | 용도 | 색상 |
|---|---|---|
| level-0 | 페이지 배경 | bc-100 #e8ebf2 |
| level-1 | 카드·사이드바·채팅 | white / surface #fcfcfd |
| level-2 | 선택/공지 영역 | pc-100 #ecf1f9 |
| level-3 | 오버레이(모달·드롭다운) | white + shadow |

플레이어는 예외적으로 다크(`#0d1b30→#0a1424`)로 시청 몰입 + 라이트 UI와 대비.

## 디자인 프리뷰

| HTML 프리뷰 | 파일 경로 | 용도 | 상태 |
|---|---|---|---|
| 디자인 샘플 3종 | `design/samples.html` | A/B/C 비교 선택용 | **선택 완료 — 샘플 A (사이드바+콘텐츠)** |

## 컴포넌트 커스터마이징 방향

- 버튼: NX Basic Button(filled/outline, primary). 후원 버튼만 pc-700→pc-1000 그래디언트로 시선 유도.
- 카드: NX Basic Card. 호버 elevation. 방송 정보·클립·편성 타일.
- 입력(채팅): NX Basic TextField. 포커스 시 pc-400 ring.
- 태그: NX Basic Tag. LIVE=danger, 해시태그=pc-100/pc-900.
- 채팅 메시지: 운영자(Notification 톤) / 본인(pc-100 강조) / 일반(닉네임 색 구분).

## 외부 공통 UI (넥슨 GNB)

- 적용 여부: ❓ **미확정** — PRD 부재로 GNB 키워드 미감지. NEXON Live가 nexon.com 서비스면 GNB 필요 가능성.
  → create-spec Step 2.7 또는 prerequisites에서 GNB 도메인·GID 수집 후 결정. (경량 모드: hosts/스크립트 셋업 보류)
- z-index 스케일: GNB 적용 시 모든 요소 < 9,999,999 준수.

## 비고 (경량 모드)

- 본 셋업은 scripts/·HTTPS·storageState 없이 진행(경량). HTTPS·인증·hooks는 Phase 1+ 또는 본체 동기화 시 보강.
- 다음 단계: `create-spec` 으로 spec.md → plan.md → tasks.md 생성 + UI 프로토타입(Step 2.7).
