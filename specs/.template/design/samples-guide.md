# design/samples.html 생성 가이드

> `boilerplate-setup` Stage 1 Q6* 단계에서 AI가 이 가이드를 참조한다.
> 고정 템플릿을 쓰지 않는다. 레퍼런스 리서치 → 창의적 조합 → 구현 순서로 진행한다.

---

## 핵심 철학

```
이 파일에 "샘플 A는 이렇게, 샘플 B는 이렇게" 식의 처방은 없다.
있는 것은 두 가지뿐이다:

  1. 절대 금지 패턴  — 해서는 안 되는 것
  2. 기술 품질 기준  — 반드시 충족해야 하는 것

나머지는 레퍼런스 리서치와 AI의 창의적 판단으로 채운다.
```

---

## NX Basic 모드 (DESIGN_SYSTEM = nxbasic 일 때)

> `boilerplate-setup` [NX Basic 샘플 3종] 절차에서 이 모드로 진입한다.
> 일반(리서치 기반) 모드와의 차이만 정리한다 — 명시되지 않은 규칙은 아래 일반 규칙을 그대로 따른다.

```
NX Basic 모드의 원칙: "색상·타이포·컴포넌트는 고정, 레이아웃만 3종으로 변주한다."
```

| 항목 | NX Basic 모드 처리 |
|---|---|
| 색상 | NX Basic 컬러 토큰을 그대로 사용 (`colors.css`). 3종 샘플의 Primary 를 일부러 다르게 하지 않는다. |
| 타이포 | NX Basic type scale(`typography.css`)·폰트를 그대로 사용. 샘플별 폰트 변경 금지. |
| 컴포넌트 | NX Basic 18종(Button·TextField·Table·Dialog 등) 스타일을 따른다. `import { Button } from 'nxbasic'` 또는 Storybook props 기반 동등 구현. |
| **AI 클리셰 색상/폰트 금지** | **NX Basic 토큰 준수로 갈음** — 아래 "AI 클리셰 금지 hex/폰트 조합" 표는 적용하지 않는다. 토큰 외 임의 색·폰트 도입만 금지. |
| **레이아웃·구성** | **3종이 서로 달라야 한다** — 진입 영역·정보 밀도·배치를 다르게 설계 (예: 사이드바+콘텐츠 / 벤토 그리드 / 매거진 레이아웃). 아래 "절대 금지 패턴"·레이아웃 다양성 규칙은 그대로 적용. |
| 마이크로 인터랙션·접근성·가로폭 1440px·탭 바 | 일반 모드와 동일하게 충족한다. |

> 즉, NX Basic 모드의 3종은 **같은 디자인 시스템(색/타이포/컴포넌트)을 쓰되 화면 구성이 다른** 3가지 안이다.
> 사용자는 어떤 레이아웃이 서비스에 맞는지를 기준으로 A/B/C 를 고른다.

---

## 절대 금지 패턴

이 패턴이 한 개라도 발견되면 생성을 처음부터 다시 한다.

### 레이아웃 금지
- **Navbar → Hero → Cards 수직 스택** — AI의 기본 출력 안티패턴
- **모든 섹션 동일 max-width 컨테이너** (`max-w-7xl mx-auto px-4` 반복)
- **3개 샘플이 같은 레이아웃 구조** 사용
- **화면 상단 중앙 히어로 영역 — 형태 불문 전면 금지**  
  전체 너비 배경+텍스트 오버레이 / 중앙정렬 제목+부제+버튼 조합 /  
  풀스크린 랜딩 배너 / 상단 스플래시 섹션 등 모든 변형 포함
- **콘텐츠 가로폭 1440px 미제한** — nav·header·콘텐츠 블록 전체에 반드시 적용  
  (패턴 A/B 구분 적용 — 아래 "콘텐츠 가로 폭 제한" 섹션 참조)

### 섹션 반복 구조 금지

아래 조합이 **2개 이상 같은 샘플에** 등장하면 전체를 다시 생성한다.  
v0·Lovable·Bolt 등 AI 도구가 학습한 랜딩 페이지의 전형적 섹션 배열이다.

| 금지 섹션 | 전형적 형태 |
|---|---|
| 3열 Features | 아이콘 + 제목 + 2줄 설명, `grid-cols-3` 균일 배열 |
| Testimonials 슬라이더 | 아바타 이미지 + 별점 5개 + 인용문, 가로 슬라이드 |
| 3단 Pricing 티어 | Basic / Pro / Enterprise, 중간 카드만 `ring`·배경 강조 |
| 4열 Footer 링크 | Product / Company / Resources / Legal 4개 컬럼 |
| 상단 KPI 카드 4연속 | 동일 크기 카드 4개 가로 나열, 숫자 + 퍼센트 증감 |

### 첫 화면 진입 영역 필수 대안

히어로 대신, 각 샘플의 첫 화면 진입 영역은 아래 중 하나를 선택해야 한다.  
**3개 샘플 모두 서로 다른 대안을 사용해야 한다.**

| 대안 | 특징 |
|---|---|
| 비대칭 벤토 그리드 | 핵심 기능 타일을 다양한 크기로 즉시 노출 |
| 레이어드 캔버스 | 배경·중간·전면 레이어로 공간감 연출 |
| 분할 스크린 | 두 가지 사용자 역할·기능을 좌우로 대비 |
| 대각선 클리핑 | 섹션 경계를 사선 처리해 시각적 흐름 강조 |
| 매거진 레이아웃 | 핵심 지표·상태를 비정형 콜라주로 즉시 노출 |
| 사이드바+콘텐츠 구조 | 고정 네비게이션 + 우측 메인 콘텐츠 영역 |
| 타이포 블록 | 대형 헤드라인 자체가 진입점, 기능 바로 배치 |
| Broken Grid | 그리드 경계를 의도적으로 침범, 요소 간 긴장감 연출 |
| Scrollytelling 진입 | 스크롤 위치에 따라 핵심 기능이 단계별로 등장 |

> **레이아웃 대안 선택 시 가로폭 처리 패턴(A·B·C)을 함께 결정한다.**  
> 대각선 클리핑·색 블록 분할처럼 배경이 전체 너비인 내용 섹션과  
> `max-width: 1440px` 섹션을 한 샘플 안에서 혼용하면 wide viewport에서 정렬이 깨진다.  
> → 패턴 선택 기준은 "콘텐츠 가로 폭 제한" 섹션 참조.

### 컬러 금지
- **Primary 단색 + 회색(Neutral)만** 사용
- **3개 샘플의 Primary가 동일한 색**
- shadcn / MUI / Ant Design **기본 테마 커스터마이징 없이** 사용

### 구조 금지
- **카드 그리드**: `grid-cols-3 gap-6`만 반복
- **트랜지션·애니메이션이 전혀 없는** 정적 UI
- **외부 UI 라이브러리 CDN** (Bootstrap, Tailwind Play CDN 등)
- **모든 카드에 `rounded-xl shadow-lg` 통일** — 위계 없는 균질 표면 처리
- **pill 뱃지(`border-radius: 9999px`) 전체 남용** — 판단 없이 모든 배지를 pill로 처리
- **다크 배경 + 보라/청록 글로우만으로 구성된 전체 페이지** — "다크 AI 스타트업" 클리셰

---

## AI 클리셰 — 절대 사용 금지

아래 항목은 AI가 학습 빈도 높은 패턴을 그대로 출력할 때 나타난다.
**이 중 하나라도 발견되면 해당 샘플 전체를 다시 생성한다.**

### 금지 컬러 (hex 기준)

| hex | 이름 | 이유 |
|---|---|---|
| `#6366f1` | Tailwind Indigo-500 | AI 기본 primary — 모든 AI 생성물에 등장 |
| `#8b5cf6` | Tailwind Violet-500 | Indigo 대체 클리셰 |
| `#3b82f6` | Tailwind Blue-500 | Tailwind 기본 blue |
| `#10b981` | Tailwind Emerald-500 | Tailwind 기본 green |
| `#f43f5e` | Tailwind Rose-500 | AI 강조색 클리셰 |

**금지 조합:**
- Purple → Blue 그래디언트 (`from-purple-500 to-blue-500` 변형 전체)
- Indigo + 흰 배경 + 회색 카드 조합 (shadcn 기본 테마와 동일)

> 대신: 레퍼런스 리서치에서 추출한 색상을 `--c-primary: #XXXXXX` 형태로 명시하고 사용한다.

### 금지 폰트 조합

| 조합 | 이유 |
|---|---|
| `Poppins` + `Inter` | AI 생성 UI의 가장 흔한 조합 |
| `Inter` 단독 | Tailwind/shadcn 기본값 |
| `Geist` 단독 | v0 기본 출력값 — 모든 v0 결과물에 등장 |
| `DM Sans` + `Inter` | Lovable/Bolt 빈출 조합 |
| `Nunito` + 파스텔 | 키즈·교육 AI 클리셰 |
| `Outfit` + `Noto Sans KR` | 한국어 AI 조합 클리셰 |

> 대신: 레퍼런스 리서치에서 서비스 도메인에 맞는 폰트를 직접 선택한다.
> 한국어가 포함된 서비스는 `Noto Sans KR`를 본문용으로 쓰되,
> 영문 헤드라인에는 레퍼런스에서 도출한 폰트를 별도 적용한다.
> **Variable Font 활용**: 굵기·너비가 스크롤·인터랙션에 따라 실시간 변하는 폰트를  
> "시각 재료 > 타이포 재료" 섹션에서 확인하고 적극 고려한다.

### 금지 장식 패턴

| 패턴 | 이유 |
|---|---|
| `backdrop-filter: blur` 카드 (glassmorphism) | 배경 없이는 효과 없음 — AI 남용 패턴 |
| `border-radius: 16px~24px` 전체 통일 | 모든 요소를 같은 radius로 둥글게 처리 |
| `border: 1px solid rgba(255,255,255,0.1)` 카드 | Glassmorphism 카드 클리셰 |
| Hero 영역에 이모지 아이콘 (`🚀`, `✨`, `💡`, `⚡`) | 이모지를 장식·아이콘 대용으로 사용 금지 |
| `linear-gradient(135deg, #667eea 0%, #764ba2 100%)` | AI가 암기한 보라-파란 그래디언트 |
| 모든 CTA 버튼이 `border-radius: 9999px` (pill) | 판단 없는 pill 버튼 남용 |
| 섹션마다 물결·사선 divider SVG 반복 | AI 채움 패턴 |

### 금지 컴포넌트 패턴

v0·Lovable·Bolt이 ShadCN 기반으로 출력하는 전형적 컴포넌트 조합이다.  
**아래 패턴이 2개 이상 같은 샘플에 등장하면 해당 샘플을 다시 생성한다.**

| 패턴 | 전형적 구현 |
|---|---|
| 다크 좌측 사이드바 | `bg-gray-900` 또는 `bg-slate-800` 배경, 흰 텍스트 메뉴 |
| 아바타 스택 + 사용자 수 | `flex -space-x-2` 아바타 3~5개 + "이미 X명이 사용" 문구 |
| `badge` 전체 pill | 모든 상태 뱃지에 `rounded-full` + `text-xs` 통일 |
| 빈 상태 일러스트 없음 | 데이터 없을 때 빈 div만 존재 (상태 다양성 부재) |
| 모달 단일 스타일 | 모든 모달이 `bg-white rounded-xl shadow-2xl p-6` 동일 |

### 금지 아이콘 처리

- **이모지를 아이콘으로 사용 금지** — 렌더링 환경에 따라 다르게 보임
- **Heroicons / Lucide 암기 패스 사용 금지** — 프로젝트 도메인과 무관한 범용 아이콘
- **모든 아이콘 동일 크기·동일 stroke-width** — 위계 없는 균질 아이콘

> 대신: "도메인 SVG 아이콘 가이드" 섹션에 따라 프로젝트 도메인 맞춤 아이콘을 직접 작성한다.

---

## 레퍼런스 리서치 방법론

HTML 생성 전에 반드시 `WebSearch`로 실제 레퍼런스를 수집한다.

### 도메인별 벤치마크 레퍼런스

PRD의 서비스 유형을 먼저 분류하고 해당 행의 벤치마크를 기준점으로 사용한다.  
벤치마크는 "이렇게 만들어라"가 아니라 **차별화의 출발점**이다.

| 서비스 유형 | 벤치마크 레퍼런스 | 차별화 방향 힌트 |
|---|---|---|
| SaaS 대시보드 | Linear, Vercel Dashboard, Raycast | 정보 밀도·단축키 UX·애니메이션 속도 |
| 게임·엔터테인먼트 | Persona 시리즈 공식 사이트, Clair Obscur | 세계관 컬러·시네마틱 전환·타이포 개성 |
| 사내 운영 도구 | Notion, Shopify Admin, Retool | 정보 위계·다크모드·역할별 맞춤 밀도 |
| 교육·청소년 | Duolingo, MasterClass, Khan Academy | 진행률 시각화·게임화 요소·따뜻한 팔레트 |
| 커머스 | Framer, Lusion, Fantasy Interactive | 제품 집중·단순 레이아웃·고해상도 비주얼 |
| 핀테크·금융 | Stripe, Brex, Mercury | 신뢰 컬러(네이비·딥블루)·수치 강조·미세 타이포 |

### 검색 전략

```
1차: 도메인 어워드
  "{서비스 도메인} website design award 2025"
  "awwwards {서비스 도메인} site of the day"

2차: 비주얼 트렌드
  "best {서비스 도메인} UI design 2025"
  "{핵심 키워드} editorial web design inspiration"

3차: 경쟁 차별화
  "{벤치마크 서비스명} design language analysis"
  "{벤치마크 서비스명} alternative design approach"

4차: 특수 기법 (필요 시)
  "variable font web design examples 2025"
  "broken grid editorial layout web design"
  "scrollytelling UI examples"
```

### 단계별 생성 전략

전체 페이지를 한 번에 생성하면 AI가 평균적 구조로 회귀한다.  
아래 순서로 **섹션별 독립 생성 후 조합**한다.

```
1단계: 진입 영역 (첫 화면) — 레이아웃 대안 중 하나 선택·구현
2단계: 핵심 기능 영역 — 서비스의 가장 중요한 1~2개 기능 시각화
3단계: 보조 영역 — 진입 영역과 대비되는 밀도·톤으로 설계
4단계: 조합 후 일관성 검토 — 컬러·타이포·여백 통일
```

> 단계 1~3을 각각 별도 설계·검증한 뒤 4단계에서 하나의 샘플로 통합한다.

### 레퍼런스 분석 프레임

수집한 사례 5개 이상에서 각각 추출:

| 항목 | 추출 내용 |
|---|---|
| 레이아웃 구조 | 섹션 배치, 그리드 방식, 비율 분할 |
| 컬러 전략 | 팔레트 조합, 그래디언트 방식, 대비 방법 |
| 시각 밀도 | 장식 요소 종류, 아이콘 스타일, 배경 처리 |
| 모션 성격 | 진입 방식, 호버 반응, 스크롤 연동 |
| 타이포 처리 | 크기 대비, gradient clip, stroke 활용, 굵기 대비 |

### 방향 도출

5개 레퍼런스 분석 후 **3가지 대조적인 방향**을 정의한다.  
방향은 레퍼런스에서 발견한 요소를 프로젝트 성격에 맞게 조합한 결과여야 한다.

**금지 표현** (상투적 분류 — 사용 금지):

| 금지 | 대신 쓸 것 |
|---|---|
| "클린 모던" | 구체적 레이아웃 기법 + 컬러 전략으로 서술 |
| "소프트 / 친근한" | 팔레트 범위 + 타이포 굵기 + radius 값으로 서술 |
| "임팩트 / 볼드" | 타이포 크기 대비 수치 + 컬러 대비 방식으로 서술 |
| "미니멀" | 정보 밀도 수준 + 여백 토큰 값으로 서술 |

---

## 시각 재료 목록 (조합의 원료)

레이아웃, 컬러, 장식, 타이포에서 각각 고를 수 있는 재료 목록이다.  
아래에서 **고른 것들을 조합**하여 각 샘플을 만든다.

### 레이아웃 재료

| 기법 | 설명 |
|---|---|
| 비대칭 벤토 그리드 | 크기가 다른 타일 모자이크, CSS Grid `grid-template-areas` |
| 레이어드 캔버스 | 배경·중간·전면 3레이어, `position: absolute` 깊이 구성 |
| 분할 스크린 | 40:60, 30:70 등 비대칭 좌우 분할 |
| 대각선 클리핑 | `clip-path: polygon(...)` 으로 섹션 경계를 사선 처리 |
| 오프셋 오버랩 | 카드·이미지가 섹션 경계를 침범하여 겹침 |
| 타이포 블록 | 대형 헤드라인이 섹션 자체 — 텍스트가 히어로 역할 |
| 매거진 레이아웃 | 텍스트와 비주얼 블록이 비정형 콜라주 |
| 풀블리드 핀 | 스크롤 시 배경 고정, 전면 콘텐츠만 이동 (CSS sticky) |
| Broken Grid | 요소가 컬럼 경계를 침범 — `margin-left: -Xpx` 또는 `grid-column: span N` 오버플로우 |
| Scrollytelling | `IntersectionObserver`로 섹션 진입 시 기능·데이터를 순차 등장, 서사 구조 연출 |
| Spatial Layering | z축 깊이감 강조 — `perspective`, `translateZ`, `scale` 조합으로 전·중·후경 분리 |

### 컬러 재료

| 기법 | CSS 구현 |
|---|---|
| 메시 그래디언트 | `radial-gradient` 3~5개 레이어링 |
| 듀오톤 | 2색만으로 이미지·배경 재해석 |
| 다크 + 네온 | `#0d0d0d` 배경 + 고채도 형광 Accent |
| 컬러 블록 분할 | 섹션별 독립 배경색, 강한 대비 전환 |
| 그래디언트 테두리 | `border-image: linear-gradient(...)` |
| 글로우 / 할로 | `box-shadow: 0 0 40px {color}50` |

### 장식 재료

| 재료 | 구현 방법 |
|---|---|
| 도메인 SVG 워터마크 | inline SVG, `opacity: 0.06~0.15`, 배경 장식 |
| 블러 오브(blob) | `border-radius: 50%`, `filter: blur(60px)`, 절대 위치 |
| 도트 패턴 | `radial-gradient(circle, color 1px, transparent 1px)` repeat |
| 라인 그리드 | `repeating-linear-gradient` 미세 선 |
| 노이즈 오버레이 | SVG `<feTurbulence>` 필터 |
| 오로라 스트리크 | `conic-gradient` + `blur(80px)` 느린 회전 |
| 부유 배지 | `position: absolute`, `box-shadow`, 통계·특징 수치 |
| 그래디언트 보더 카드 | `background-clip: padding-box` + pseudo-element 테두리 |

### 타이포 재료

| 기법 | CSS 구현 |
|---|---|
| Gradient text | `background-clip: text; -webkit-text-fill-color: transparent` |
| 아웃라인 텍스트 | `-webkit-text-stroke: 2px {color}` |
| 초대형 타이포 | `font-size: clamp(60px, 10vw, 140px)` |
| 스플릿 컬러 | 단어별 다른 색상 적용 |
| 레터 스페이싱 드라마 | `letter-spacing: 0.2em` + 대문자 |
| Variable Font 굵기 전환 | `font-variation-settings: 'wght' N` — 스크롤·호버에 따라 100→900 실시간 변화 |
| Ultra-bold + Ultra-thin 대비 | 같은 헤드라인 안에서 `font-weight: 900`과 `font-weight: 100`을 단어 단위로 교차 |
| Serif + Sans-serif 혼용 | 헤드라인은 Serif(존재감), 본문은 Sans-serif(가독성) — 에디토리얼 감성 |
| 초대형 배경 타이포 | 배경 장식으로 `opacity: 0.04~0.08`, `font-size: clamp(120px, 20vw, 280px)`, `user-select: none` |

---

## 도메인별 디자인 전략

PRD의 서비스 유형에 따라 레이아웃·컬러·밀도 전략을 다르게 가져간다.  
아래는 방향 힌트다 — 처방이 아니다. 레퍼런스 리서치로 발견한 구체 요소와 조합한다.

### SaaS 대시보드·관리 도구

| 항목 | 전략 |
|---|---|
| 첫 진입 영역 | 환영 메시지 + 핵심 메트릭 — 히어로 없이 즉시 데이터 노출 |
| 정보 밀도 | 높음 — 빈 여백보다 데이터 우선, 단 그룹 간 공기 확보 |
| 컬러 | 뉴트럴 베이스 + 시맨틱 컬러 (빨강=경고, 초록=정상, 파랑=핵심 KPI) |
| 차별화 포인트 | cmd+K 팔레트 힌트, 단축키 배지, 인라인 편집 패턴 |
| 피해야 할 것 | 4개 동일 KPI 카드 가로 나열, 다크 사이드바 기본값 |

### 게임·엔터테인먼트

| 항목 | 전략 |
|---|---|
| 첫 진입 영역 | 세계관을 담은 레이어드 캔버스 또는 풀블리드 핀 |
| 정보 밀도 | 낮음 — 비주얼이 주, 텍스트는 최소 |
| 컬러 | 게임·서비스 세계관 기반 팔레트 — 레퍼런스 없이 임의 네온 금지 |
| 차별화 포인트 | 배경 미세 파티클, 게임 UI 오마주 요소, 스크롤 패럴랙스 |
| 피해야 할 것 | 일반 SaaS 대시보드 레이아웃 그대로 적용 |

### 사내 운영 도구·내부 시스템

| 항목 | 전략 |
|---|---|
| 첫 진입 영역 | 사이드바+콘텐츠 구조 또는 매거진 레이아웃 |
| 정보 밀도 | 매우 높음 — 업무 데이터를 한 화면에 최대한 노출 |
| 컬러 | 기능적 시맨틱 컬러 체계 + 다크모드 고려, 장식 최소화 |
| 차별화 포인트 | 역할별 다른 정보 구성, 테이블 인라인 액션, 상태 배지 위계 |
| 피해야 할 것 | 외부 서비스 느낌의 랜딩 페이지형 구성 |

### 교육·청소년·보호자

| 항목 | 전략 |
|---|---|
| 첫 진입 영역 | 비대칭 벤토 그리드 또는 분할 스크린 (보호자 / 자녀 역할 대비) |
| 정보 밀도 | 중간 — 진행률·상태를 시각적으로, 복잡한 수치는 단순화 |
| 컬러 | 따뜻하고 접근 가능한 팔레트, 고채도 원색 지양, 파스텔 Nunito 조합 금지 |
| 차별화 포인트 | 진행률 바·레벨·배지 등 게임화 요소, 상태 다양성 (완료/진행중/미시작) |
| 피해야 할 것 | AI 교육 클리셰 (Nunito + 파스텔 + 별 아이콘 조합) |

---

## 도메인 SVG 아이콘 가이드

외부 아이콘 라이브러리 금지. 프로젝트 도메인에 맞는 SVG 패스를 **직접 작성**한다.

```html
<!-- viewBox="0 0 24 24" 기준, stroke 또는 fill 방식 통일 -->
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"
     stroke-linecap="round" stroke-linejoin="round">
  <path d="…"/>
</svg>
```

**배경 워터마크 사용 시:**
```css
.deco-icon {
  position: absolute;
  width: clamp(160px, 35vw, 480px);
  height: auto;
  opacity: 0.07;          /* 0.06~0.15 범위에서 조정 */
  color: var(--primary);  /* currentColor 상속 */
  pointer-events: none;
  user-select: none;
}
```

도메인별 아이콘 소재 예시:

| 도메인 | 아이콘 소재 |
|---|---|
| 교육·청소년 | 책 펼침, 연필, 별, 방패, 성장 화살표 |
| 게임·엔터 | 컨트롤러, 트로피, 번개, 팔각별, 검/방패 |
| 사내 운영·관리 | 격자, 체크박스, 막대차트, 톱니바퀴, 사람 그룹 |
| 헬스케어 | 하트, 십자, 물방울, 클립보드, 파동 |
| 커머스 | 쇼핑백, 가격 태그, 선물상자, 별점 |
| 핀테크·금융 | 코인, 상승 꺾은선, 자물쇠, 신용카드 |

---

## 넥슨 GNB 플레이스홀더 (GNB_REQUIRED = true 일 때만 적용)

PRD에 넥슨 GNB가 명시된 경우, 각 샘플 최상단에 GNB 플레이스홀더를 삽입한다.
실제 GNB 스크립트는 도메인 설정 후 교체되므로, 샘플 단계에서는 시각적 영역 확보와 안내만 제공한다.

### 플레이스홀더 HTML

```html
<!-- 각 .sample 섹션의 첫 번째 자식으로 삽입 -->
<div class="gnb-placeholder">
  <!-- 좌측: 넥슨 로고 + 메뉴 -->
  <div class="gnb-left">
    <span class="gnb-logo">NEXON</span>
    <nav class="gnb-nav">
      <span>전체 메뉴</span>
      <span>MY게임</span>
      <span>쪽지</span>
    </nav>
  </div>
  <!-- 우측: 로그인 영역 -->
  <div class="gnb-right">
    <span class="gnb-login">로그인</span>
    <span class="gnb-join">회원가입</span>
  </div>
  <!-- 안내 뱃지 -->
  <div class="gnb-notice">
    ⚠ 넥슨 GNB 영역 — 도메인 설정 후 실제 스크립트로 교체됩니다
  </div>
</div>
```

### 플레이스홀더 CSS

```css
.gnb-placeholder {
  position: fixed;
  top: 56px;                  /* tab-bar 높이 — CSS 변수 사용 시 var(--tab-h)로 대체 */
  left: 0;
  right: 0;
  height: 60px;               /* 실제 GNB 높이 기준 */
  background: #0d0d0d;
  border-bottom: 1px solid #2a2a2a;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  box-sizing: border-box;
  z-index: 9000;              /* tab-bar(10000)보다 낮게 */
}
.gnb-logo {
  color: #00b4d8;
  font-weight: 900;
  font-size: 18px;
  letter-spacing: 0.1em;
  margin-right: 24px;
}
.gnb-nav {
  display: flex;
  gap: 20px;
}
.gnb-nav span {
  color: #aaa;
  font-size: 13px;
  cursor: pointer;
}
.gnb-right {
  display: flex;
  gap: 12px;
  align-items: center;
}
.gnb-login, .gnb-join {
  font-size: 13px;
  padding: 5px 14px;
  border-radius: 4px;
  cursor: pointer;
}
.gnb-login {
  color: #fff;
  border: 1px solid #444;
}
.gnb-join {
  background: #00b4d8;
  color: #fff;
  border: none;
}
/* 안내 뱃지: 플레이스홀더 우측 하단 */
.gnb-notice {
  position: absolute;
  bottom: -26px;
  right: 12px;
  background: #f59e0b;
  color: #000;
  font-size: 11px;
  font-weight: 600;
  padding: 3px 10px;
  border-radius: 0 0 6px 6px;
  white-space: nowrap;
  z-index: 100;
}
```

### GNB 삽입 시 레이아웃 오프셋 규칙

```css
/* 샘플 전체 콘텐츠 시작점: GNB 높이만큼 아래로 */
.sample-content {
  padding-top: 60px;   /* GNB 높이 */
}

/* 샘플 내 자체 고정 헤더가 있다면 GNB 아래에 위치 */
.site-header-fixed {
  top: 60px;           /* GNB 높이 오프셋 */
}

/* 모든 고정 요소 z-index 제약 (GNB = 9,999,999) */
.site-header-fixed { z-index: 7000000; }  /* 고정 헤더 */
.modal-overlay     { z-index: 9000000; }  /* 모달 */
.dropdown-menu     { z-index: 8000000; }  /* 드롭다운 */
.toast-container   { z-index: 50000;   }  /* 토스트 */
```

### 실제 GNB 교체 안내 (samples.html 주석)

```html
<!--
  ============================================================
  넥슨 GNB 플레이스홀더 — Phase 0 디자인 확인용
  ============================================================
  실제 서비스 구현 시 이 블록을 아래 스크립트로 교체합니다:

  [테스트 환경]
  <script src="https://rs-test.nxfs.nexon.com/common/js/gnb.min.js"
    data-gamecode="{GID 4자리}"
    data-ispublicbanner="true"
    data-loginenv="test">
  </script>

  [라이브 환경]
  <script src="https://rs.nxfs.nexon.com/common/js/gnb.min.js"
    data-gamecode="{GID 4자리}"
    data-ispublicbanner="true"
    data-loginenv="live">
  </script>

  게임코드(GID)는 prerequisites.md → GNB 섹션에서 확인하세요.
  ============================================================
-->
```

---

## 콘텐츠 가로 폭 제한 (필수)

모든 샘플의 콘텐츠 영역은 최대 가로 폭을 **1440px**로 제한한다.
요소 유형에 따라 두 가지 패턴을 구분 적용한다.

### 패턴 A — 배경·테두리가 풀스크린이어야 하는 요소 (nav, header)

`padding` 트릭으로 배경은 화면 끝까지 유지하면서 내용물만 1440px 안에 중앙 정렬한다.

```css
.site-nav,
.site-header {
  /* 기존 좌우 padding이 Xpx인 경우 */
  padding-left:  max(Xpx, calc((100vw - 1440px) / 2 + Xpx));
  padding-right: max(Xpx, calc((100vw - 1440px) / 2 + Xpx));
}
/* 뷰포트 < 1440px → padding = Xpx 고정 (기존 유지)  */
/* 뷰포트 > 1440px → padding 증가 → 내용물이 1440px 폭 중앙 정렬 */
```

### 패턴 B — 콘텐츠 블록 (그리드, 카드 영역, 본문)

```css
.content-area,
.bento-grid,
.magazine-grid {
  max-width: 1440px;
  margin-left: auto;
  margin-right: auto;
  padding: 0 24px; /* 고정값만 허용 — calc((100vw - 1440px)/2 + Xpx) 금지 */
}
```

> **⚠ 두 패턴 혼용 절대 금지**: `max-width`가 있는 요소에 패턴 A의 `calc((100vw - 1440px)/2 + Xpx)` 패딩을 동시에 적용하면 뷰포트 > 1440px(2K·4K 모니터)에서 내부 콘텐츠 너비가 0에 수렴한다.
>
> 예) viewport=2560px: `padding = (2560-1440)/2+24 = 584px` → 내부 너비 = `1440 - 584×2 = 272px` → 텍스트가 세로로 쌓임
>
> **판별 기준**: 해당 요소에 `max-width`가 있으면 반드시 고정 패딩(`padding: 0 24px`)만 사용한다.

### 패턴 C — 배경 전체 너비 + 내부 정렬이 필요한 내용 섹션

대각선 클리핑·색 블록 분할처럼 **배경이 뷰포트 끝까지 확장되어야 하는 내용 섹션**에 적용한다.  
nav/header가 아닌 진입 영역·KPI 블록 등 콘텐츠 섹션에 전체 너비가 필요한 경우 사용한다.

```css
/* 배경은 전체 너비, 내부 콘텐츠는 1440px 경계에 정렬 */
.full-bleed-section {
  width: 100%;
  /* max-width 없음 — 배경 색/이미지가 뷰포트 끝까지 확장 */
  padding-left:  max(0px, calc((100vw - 1440px) / 2));
  padding-right: max(0px, calc((100vw - 1440px) / 2));
}

/* 내부 고정 패딩 — 상위에서 이미 1440px 정렬했으므로 고정값만 */
.full-bleed-section .inner {
  padding: 0 48px; /* 고정값 */
}
```

> **⚠ 한 샘플 내 가로폭 전략 일관성 — 패턴 B와 패턴 C 혼용 금지**
>
> 색 블록 분할·대각선 클리핑(패턴 C)과 `max-width: 1440px` 섹션(패턴 B)이 혼재하면  
> 섹션 간 좌측 기준점이 달라져 wide viewport(2K·4K)에서 콘텐츠 정렬이 깨진다.
>
> **한 샘플 내 선택 원칙:**
> - 색 블록·클리핑 배경이 뷰포트 끝까지 확장되어야 한다 → **전체 섹션에 패턴 C 사용**, `max-width` 섹션 없음
> - 색 블록이 1440px 안에서만 표현되어도 된다 → **`max-width: 1440px; overflow: hidden`으로 패턴 B에 포함**
>
> 두 선택지 중 하나만 고른다. 혼용은 어떤 이유로도 허용되지 않는다.

### 샘플 유형별 적용 대상 예시

| 첫 진입 레이아웃 | 패턴 A 적용 대상 | 패턴 B 적용 대상 | 패턴 C 적용 대상 |
|---|---|---|---|
| 비대칭 벤토 그리드 | nav 있을 경우 | 그리드 영역 | — |
| 사이드바+콘텐츠 구조 | — | 사이드바+메인 전체 | — |
| 매거진 레이아웃 | 헤더 | 콘텐츠 그리드 | — |
| 분할 스크린 | nav 있을 경우 | 분할 섹션 전체 | — |
| 타이포 블록 | nav 있을 경우 | 타이포 섹션 | — |
| Broken Grid | nav 있을 경우 | 그리드 컨테이너 | — |
| Scrollytelling 진입 | nav 있을 경우 | 각 섹션 개별 적용 | — |
| **색 블록 분할** | — | `overflow:hidden` 래핑 권장 **(추천)** | 색 블록이 뷰포트 끝까지 필요 시 |
| **대각선 클리핑** | — | `overflow:hidden` 래핑 권장 **(추천)** | 클리핑 배경이 전체 너비여야 할 때 |

> **색 블록 분할·대각선 클리핑에서 패턴 C를 선택한 경우**:  
> 해당 섹션 아래의 모든 콘텐츠 섹션도 패턴 C 또는 패턴 A로 통일해야 한다.  
> `max-width: 1440px` 섹션(패턴 B)과 혼용하면 섹션 간 좌측 기준점이 어긋난다.
>
> 사이드바 구조처럼 nav가 없는 경우, 사이드바+메인 전체 flex 컨테이너에 패턴 B를 적용한다.  
> 배경이 `body`와 거의 동일한 색이면 양쪽 여백이 자연스럽게 처리된다.

---

## 마이크로 인터랙션 기준

정적 UI는 금지. 모든 인터랙티브 요소에 적용한다.

```css
:root {
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
}

/* 카드 호버 */
.card {
  transition: transform 280ms var(--ease-out),
              box-shadow 280ms var(--ease-out);
}
.card:hover {
  transform: translateY(-4px) scale(1.01);
  box-shadow: 0 20px 40px rgba(0,0,0,0.15);
}

/* 버튼 */
.btn { transition: all 150ms var(--ease-out); }
.btn:hover  { transform: scale(1.03); }
.btn:active { transform: scale(0.97); }

/* 페이지 진입 stagger */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(20px); }
  to   { opacity: 1; transform: translateY(0); }
}
.fade-in { animation: fadeUp 500ms var(--ease-out) both; }
.fade-in:nth-child(2) { animation-delay: 80ms; }
.fade-in:nth-child(3) { animation-delay: 160ms; }

/* Variable Font 굵기 전환 (선택 재료) */
.vf-headline {
  font-variation-settings: 'wght' 300;
  transition: font-variation-settings 400ms var(--ease-out);
}
.vf-headline:hover,
.section-active .vf-headline {
  font-variation-settings: 'wght' 800;
}

/* Scrollytelling 진입 (선택 재료) */
.scroll-reveal {
  opacity: 0;
  transform: translateY(32px);
  transition: opacity 600ms var(--ease-out),
              transform 600ms var(--ease-out);
}
.scroll-reveal.is-visible {
  opacity: 1;
  transform: translateY(0);
}

/* 모션 감소 대응 (필수) */
@media (prefers-reduced-motion: reduce) {
  *, .fade-in, .scroll-reveal, .vf-headline {
    animation: none !important;
    transition: none !important;
    font-variation-settings: unset !important;
  }
}
```

### Scrollytelling 구현 패턴

```javascript
// IntersectionObserver로 .scroll-reveal 요소 활성화
const observer = new IntersectionObserver(
  (entries) => entries.forEach(e => {
    if (e.isIntersecting) e.target.classList.add('is-visible');
  }),
  { threshold: 0.15 }
);
document.querySelectorAll('.scroll-reveal').forEach(el => observer.observe(el));
```

## 접근성 기준

AI 출력물의 대다수가 저대비 텍스트를 포함한다. 생성 단계에서 명시적으로 적용한다.

### 필수 대비 기준

| 요소 | 최소 대비율 | 확인 방법 |
|---|---|---|
| 본문 텍스트 (18px 미만) | **4.5 : 1** | 배경색 vs 텍스트색 |
| 대형 텍스트 (18px 이상 또는 Bold 14px+) | **3 : 1** | — |
| UI 컴포넌트 경계 (버튼 테두리, 입력 필드 경계) | **3 : 1** | 배경색 vs 경계색 |
| 장식 요소 (워터마크, 배경 패턴) | 제한 없음 | — |

> 다크 배경 + 회색 텍스트 조합은 대비율 위반이 가장 잦다. 특히 주의.

### 색상 단독 정보 전달 금지

상태(성공/오류/경고)를 색상만으로 구분하면 색각 이상 사용자가 인식 불가.  
색상 + 아이콘(SVG) 또는 색상 + 텍스트 레이블을 반드시 병행한다.

```html
<!-- 금지: 색상만으로 구분 -->
<span class="badge-red">오류</span>

<!-- 허용: 색상 + 아이콘 + 텍스트 -->
<span class="badge-error">
  <svg><!-- X 아이콘 --></svg> 오류
</span>
```

---

## 공통 UI 구조

레이아웃은 샘플마다 자유롭게 설계하되, 아래 요소는 모든 샘플에 공통 적용한다.

### 상단 탭 바 (고정)

탭 바는 샘플 전환을 위한 **메타 UI**다. 특정 샘플의 디자인 컬러를 쓰지 않는다.

```html
<header id="tab-bar">
  <span class="tab-bar-title">{프로젝트명} — 디자인 샘플</span>
  <nav>
    <button class="tab active" data-target="a">A</button>
    <button class="tab"        data-target="b">B</button>
    <button class="tab"        data-target="c">C</button>
  </nav>
</header>

<style>
#tab-bar {
  position: fixed; top: 0; left: 0; right: 0; z-index: 10000;
  background: rgba(10,10,15,0.92);
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 24px;
  border-bottom: 1px solid rgba(255,255,255,0.10);
  font-family: 'Inter', 'Noto Sans KR', sans-serif;
}
.tab-bar-title { color: #64748b; font-size: 12px; letter-spacing: 0.02em; }
.tab {
  width: 36px; height: 36px; border-radius: 6px; border: none;
  background: rgba(255,255,255,0.06); color: #64748b;
  font-weight: 700; cursor: pointer;
  transition: all 150ms ease;
}
/* active: 무채색 흰색 계열 — 샘플 컬러를 침범하지 않음 */
.tab.active   { background: rgba(255,255,255,0.18); color: #fff; }
.tab:hover:not(.active) { background: rgba(255,255,255,0.10); color: #cbd5e1; }
.sample { display: none; padding-top: 56px; min-height: 100vh; }
.sample.active { display: block; }
</style>

<script>
document.querySelectorAll('.tab').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tab, .sample').forEach(el =>
      el.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById('s-' + btn.dataset.target).classList.add('active');
  });
});
</script>
```

---

## 더미 콘텐츠 기준

**샘플의 더미 데이터는 실제 서비스 데이터 구조를 반영해야 한다.**
"Lorem ipsum"이나 "제목 텍스트", "내용이 들어갑니다" 같은 무의미한 텍스트를 사용하지 않는다.

PRD에서 추출한 실제 기능·데이터로 채운다:

| 서비스 유형 | 더미 데이터 예시 |
|---|---|
| 청소년 게임시간 관리 | 자녀 이름, 평일/주말 허용시간, 게임 목록, 동의 상태 |
| 사내 운영 도구 | 실제 메뉴명, 업무 데이터 수치, 담당자명 형식 |
| 게임 서비스 | 게임 이름, 캐릭터, 랭킹 수치, 이벤트명 |

**상태 다양성**: 샘플 안에 최소 2가지 이상의 상태를 표현한다.
(예: 등록된 자녀 있음 / 없음, 시간 초과 / 정상 상태 등)

---

## 최종 품질 체크

**[AI 클리셰 — 생성 완료 후 1차 검증]**
- [ ] 금지 hex 컬러(`#6366f1` `#8b5cf6` `#3b82f6` `#10b981` `#f43f5e`) 없음
- [ ] Purple→Blue 그래디언트 없음
- [ ] Poppins+Inter, Inter 단독, Geist 단독, DM Sans+Inter 조합 없음
- [ ] Glassmorphism 카드(`backdrop-filter: blur`) 남용 없음
- [ ] 이모지 아이콘 없음 (`🚀` `✨` `💡` 등)
- [ ] 모든 요소 동일 `border-radius` 처리 없음 (`rounded-xl` 통일 금지)
- [ ] 섹션 반복 divider SVG 없음
- [ ] 탭 바가 샘플 Primary 컬러 사용하지 않음
- [ ] 3열 Features·Testimonials 슬라이더·3단 Pricing·4열 Footer 중복 없음
- [ ] 다크 사이드바(`bg-gray-900`) + 상단 KPI 카드 4연속 조합 없음
- [ ] `badge` 전체 pill(`rounded-full`) 남용 없음

**[가로폭 — 생성 전 필수 확인]**
- [ ] **nav/header**: 패턴 A(`padding: max(...)`) 적용 — 배경 풀스크린, 내용물 1440px
- [ ] **콘텐츠 블록**: 패턴 B(`max-width: 1440px; margin: 0 auto`) 적용, 내부 패딩은 고정값만
- [ ] **배경 풀스크린 내용 섹션** (색 블록 분할·대각선 클리핑): 패턴 B(`overflow: hidden` 포함) 또는 패턴 C 중 하나만 선택 — 한 샘플 내 패턴 B와 C 혼용 금지
- [ ] **섹션 간 가로폭 전략 일관성** — 브라우저 개발자 도구 Responsive mode를 2560px로 설정해 모든 섹션의 콘텐츠 좌측 시작점이 동일 x좌표인지 육안 점검

**[레이아웃·컬러]**
- [ ] 절대 금지 패턴이 어느 샘플에도 없음
- [ ] 화면 상단 중앙 히어로 영역이 어느 샘플에도 없음
- [ ] 3개 샘플이 레이아웃 구조 자체가 다름
- [ ] 각 샘플의 첫 진입 영역이 서로 다른 레이아웃 대안 사용
- [ ] 레퍼런스 리서치 결과가 디자인에 반영됨 (도메인별 벤치마크 검색 포함)
- [ ] 도메인별 디자인 전략 섹션의 "피해야 할 것"이 적용됨
- [ ] 도메인 SVG 아이콘이 배경 장식·카드 양쪽에 사용됨 (이모지 아님)
- [ ] 각 샘플의 Primary 컬러가 다름
- [ ] 컬러가 배경·타이포·장식·아이콘 층위에 다층 적용됨
- [ ] 방향 도출 시 "클린 모던/소프트/임팩트" 같은 상투적 표현 미사용

**[콘텐츠]**
- [ ] 더미 데이터가 실제 서비스 데이터 구조를 반영함 (Lorem ipsum 없음)
- [ ] 최소 2가지 상태(유/무, 정상/경고 등)가 표현됨

**[인터랙션·접근성]**
- [ ] 마이크로 인터랙션 (호버·진입 애니메이션) 구현됨
- [ ] Scrollytelling 또는 Variable Font 등 고급 재료 중 최소 1개 적용됨
- [ ] prefers-reduced-motion 분기 처리됨 (Variable Font·scroll-reveal 포함)
- [ ] WCAG AA 텍스트 대비 4.5:1 이상 — 다크 배경 + 회색 텍스트 조합 특히 점검
- [ ] 상태 정보가 색상 + 아이콘/텍스트 병행 표시됨 (색상 단독 금지)
- [ ] 탭 전환 동작 확인
- [ ] Google Fonts 외 외부 CDN 없음
