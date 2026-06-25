---
name: design-research
description: Phase 0 디자인 리서치 워크플로 — 레퍼런스 조사, 시각 기법 카탈로그, 크리에이티브 레시피, 디자인 시스템 셋업 절차. 디자인 리서치, 디자인 레퍼런스, 히어로 디자인, 비주얼 시그니처 요청 시 사용.
---

# 디자인 리서치 스킬

Phase 0 시작 시 실행하는 디자인 리서치 워크플로이다.
AI 내장 지식이 아닌 실제 어워드급 사이트의 최신 트렌드를 기반으로 디자인한다.

> 이 스킬의 결과물은 `design-direction.md`에 기록한다.
> UI 코드 작성 시의 가드/제약 규칙은 CLAUDE.md의 `design-quality-guard` 섹션을 따른다.

---

## Step 0 — NX Basic 디자인 시스템 분기·선택지 확인

리서치 검색을 시작하기 전에, 넥슨 사내 디자인 시스템(NX Basic 1.0v) 적용 여부를 먼저 확인한다.

1. **이미 확정된 경우 — 웹 리서치를 종료한다.**
   `state.json.design_system == "nxbasic"` 이거나 `DESIGN_SYSTEM=nxbasic` 이면,
   디자인 방향은 NX Basic 토큰으로 이미 확정된 상태다. 웹 리서치(Step 1~4)는 수행하지 않는다.
   디자인 샘플 3종(레이아웃 비교)은 `boilerplate-setup` [NX Basic 샘플 3종] 절차에서 NX Basic 토큰을
   고정한 채 생성·선택되므로, 그 결과(`design/samples.html`, `design/design-direction.md`)를 그대로 둔다.

2. **미확정인 경우 — 리서치 결과와 함께 선택지로 제시한다.**
   `refs/design-systems/nxbasic-1.0v.md` 를 읽어 NX Basic 개요(컴포넌트 18종·토큰 144개·Storybook)를
   파악하고, Step 1~3 의 웹 리서치 결과를 정리한 뒤 **Step 3.5** 에서 NX Basic 을 하나의 선택지로
   함께 제안한다. 사용자가 NX Basic 을 선택하면 `DESIGN_SYSTEM=nxbasic` 으로 확정하고 Step 4 를
   NX Basic 토큰 기준으로 작성한다.

---

## Step 1 — 도메인별 레퍼런스 검색

프로젝트 성격에 맞는 키워드로 **WebSearch 3회 이상** 검색한다:

```
"{프로젝트 도메인} website design award {현재 연도}"
"best {프로젝트 유형} hero section design {현재 연도}"
"Awwwards site of the day {프로젝트 키워드}"
```

검색 소스 우선순위:
1. Awwwards — 웹 디자인 어워드 최신 수상작
2. Dribbble — 시각 디자인 트렌드
3. Behance — 완성도 높은 프로젝트 케이스
4. Godly.website — 큐레이팅된 웹 디자인 갤러리

---

## Step 2 — 레퍼런스 분석 및 기록

검색 결과에서 **시각적 밀도와 독창성이 높은 사례 3~5개**를 선별하여
`design-direction.md`에 기록한다:

```markdown
## 디자인 레퍼런스

### 레퍼런스 1: {사이트명}
- URL: {URL}
- 차용 포인트:
  - 컬러: {팔레트 전략}
  - 레이아웃: {구조}
  - 타이포: {처리 방식}
  - 효과: {시각 기법}
  - 모션: {인터랙션}
```

---

## Step 3 — 비주얼 시그니처 정의

레퍼런스에서 추출한 요소를 조합하여 프로젝트만의 **비주얼 시그니처**를 정의한다.

- **핵심 시각 기법** 2~3가지
- **컬러 무드**
- **모션 성격**

---

## 시각 기법 카탈로그 — 최소 4가지 조합

**표면·질감**: 메시 그래디언트 / 글라스모피즘 / 노이즈·그레인 / 오로라·라이트 스트리크 / 도트·라인 그리드 / 그래디언트 보더

**타이포그래피**: 초대형 타이포(120~180px) / 타이포 마스크 클립 / 스플릿 텍스트 애니메이션 / 아웃라인 텍스트

**레이아웃**: 비정형 그리드(오프셋·오버랩) / 분할 레이아웃(비대칭 40:60) / 스크롤 연동 패럴랙스 / 핀드 섹션

**컬러·빛**: 듀오톤 / 글로우·할로 / 다크 모드 네온 악센트

---

## Step 3.5 — NX Basic 디자인 시스템을 선택지로 제안

> Step 0 에서 NX Basic 이 미확정인 경우에만 수행한다 (이미 확정이면 생략).

웹 리서치로 도출한 비주얼 시그니처(Step 3)와 **넥슨 사내 디자인 시스템(NX Basic 1.0v)** 을
나란히 제시하여 사용자가 선택하게 한다.

```
🎨 디자인 방향 선택

이 프로젝트에 적용할 디자인 방향을 골라주세요:

  R) 리서치 기반 커스텀 방향
     - 비주얼 시그니처: {Step 3 에서 도출한 핵심 시각 기법 2~3가지}
     - 컬러 무드: {Step 3 컬러 무드}
     - 참고 레퍼런스: {Step 2 레퍼런스 사이트 2~3개}

  N) NX Basic 1.0v 디자인 시스템 적용 (넥슨 사내 디자인 시스템)
     - 컴포넌트 18종(Button·TextField·Table·Dialog 등) + 토큰 144개를 그대로 사용
     - 웹 디자인 리서치는 생략하되, NX Basic 토큰을 고정한 채 레이아웃만 다른 샘플 3종으로 비교·선택
     - Storybook: https://sooyachoco.github.io/NXbasic1.0v/?path=/docs/introduction--docs
     - 참조: refs/design-systems/nxbasic-1.0v.md

R / N 중 선택해주세요.
```

**선택 결과 처리:**
- **R 선택** → Step 4 를 리서치 기반 시그니처로 작성한다.
- **N 선택** → `DESIGN_SYSTEM=nxbasic` 로 확정하고 아래를 수행한다. 디자인 샘플 3종(NX Basic 토큰 고정·레이아웃 변주) 생성·선택은 `boilerplate-setup` [NX Basic 샘플 3종] 절차를 따르며, Step 4 를 NX Basic 토큰 + 선택된 레이아웃으로 작성한다:
  ```
  mcp__d2a-harness__update_state({ patch: { design_system: "nxbasic" } })
  ```
  ```bash
  ./scripts/log-activity.sh DECISION "[DESIGN_SYSTEM]: nxbasic" "👤 design-research에서 선택 — NX Basic 적용" || true
  ./scripts/log-activity.sh POLICY "refs/design-systems/nxbasic-1.0v.md: NX Basic 1.0v 적용 결정" "" || true
  ```
  컬러·타이포·여백·컴포넌트 토큰은 Storybook(`colors.css` / `typography.css` / `tokens.ts`)을
  WebFetch 로 조회하여 채운다.

---

## Step 4: design-direction.md 최종 작성

`specs/.template/design-direction.md`를 기반으로 완성된 디자인 방향을 작성한다.

맨 위 "디자인 시스템" 항목에 선택 결과를 명시한다:
- R 선택: `디자인 시스템: 없음 (리서치 기반 커스텀)`
- N 선택: `디자인 시스템: NX Basic 1.0v (DESIGN_SYSTEM=nxbasic)`

포함 항목:
- 선택된 비주얼 시그니처 (N 선택 시 NX Basic 토큰 기준)
- 컬러 팔레트 (Primary, Secondary, Accent, Neutral)
- 타이포그래피 스케일
- 컴포넌트 스타일 가이드
- 모션 토큰

> **N(NX Basic) 선택 시**: 색상·타이포·여백·컴포넌트 스타일은 NX Basic 토큰 값을 그대로 옮긴다.
> 디자인 시스템을 따르는 것이 목표이므로 색상·타이포에는 임의 변주를 추가하지 않는다
> (`design-quality-guard` 의 "기본 테마 그대로 사용 금지" 규칙은 NX Basic 토큰 준수로 갈음).
> 단, **레이아웃·구성은 샘플 3종 중 사용자가 선택한 방향**을 "선택된 디자인 샘플" 항목에 기록한다.

→ "디자인 방향이 확정되었습니다. `boilerplate-setup 실행해줘`를 입력해 Stage 1.5에서 UI 구현을 시작할까요?"
