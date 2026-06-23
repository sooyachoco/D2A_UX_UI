---
name: ai-usability-test
description: AI 네이티브 사용성 테스트. Playwright + 다중 페르소나로 UI 결함을 자동 탐지하고 Nielsen 휴리스틱 기반 개선안을 산출한다. "사용성 테스트", "UT 돌려줘", "UI 결함 찾아줘", "접근성 검사", "UX 검증해줘" 등의 요청에 적용.
source: https://brunch.co.kr/@ghidesigner/492
last_updated: 2026-06-23
---

# AI 네이티브 사용성 테스트 (AI-Native Usability Test)

> **출처**: [AI 네이티브 사용성 테스트 방식](https://brunch.co.kr/@ghidesigner/492)  
> Playwright + AI 페르소나로 기존 인간 중심 UT의 비용·시간 문제를 해결한다.  
> AI는 반복적·기술적 결함(클릭 정확도, 접근성, 논리 오류)을 먼저 제거하고,  
> 인간 평가자는 더 깊은 창의적·맥락적 영역에 집중한다.

---

## 산출물 5종 (specs/{NNN}/ut/ 하위)

| 파일 | 역할 |
|---|---|
| `UT_PLAN.md` | 테스트 범위·목표·페르소나·성공 기준 |
| `UT_SCENARIOS.md` | 페르소나별 현실적 작업 시나리오 |
| `UT_OBSERVATION_SHEET.md` | Playwright 원시 신호 (클릭·머뭇거림·오류·스크린샷) |
| `UT_FINDINGS_REPORT.md` | Nielsen 10 휴리스틱 기반 결함 우선순위 리포트 |
| `REDESIGN_PROPOSAL.md` | 구체적 화면 개선안 (다중 레이아웃 포함) |

---

## Step 0: 대상 확인

```
🔶 사용성 테스트 대상 확인

**테스트할 화면**: {사용자가 지정 or 현재 프로젝트 메인 화면}
**테스트 URL**: {local-{프로젝트}.nexon.com/{경로} 또는 사용자 지정}
**특이 사항**: {기존 storageState 사용 여부, 게스트 허용 여부 등}

이대로 진행할까요?
```

→ 확인 후 `specs/{NNN}/ut/` 디렉토리 생성.

---

## Step 1: UT_PLAN.md 작성

`specs/{NNN}/ut/UT_PLAN.md` 생성.

### 1-1. 테스트 범위 정의

spec.md / PRD에서 다음을 추출한다:
- 검사 대상 화면 목록 (화면명 + URL)
- 개념 인증(conceptual validation) 목표: "이 기능을 왜 쓰는지 명확한가"
- 전환 최적화 목표: 핵심 전환 단계별 이탈 예상 지점

### 1-2. 페르소나 3종 정의

| 페르소나 | 정의 | Playwright 시뮬레이션 전략 |
|---|---|---|
| **초보자** | 첫 방문, 목표 불명확, 도움말 의존 | 느린 클릭·hover 많이·에러 발생 시 방황 |
| **파워유저** | 단축키·스킵 시도, 효율 최우선 | 빠른 클릭·키보드·직접 경로 탐색 |
| **접근성 사용자** | 스크린리더 환경, 키보드 전용 내비 | Tab/Enter/Arrow 전용, ARIA 확인 |

### 1-3. 성공 기준

```markdown
## 성공 기준 (합격 임계값)
- [ ] 초보자 시나리오 완료율 ≥ 80%
- [ ] 파워유저 시나리오 완료 시간 ≤ 목표치
- [ ] 접근성 사용자 핵심 동작 100% Tab 접근 가능
- [ ] Critical 오류 0건 (Nielsen severity 4)
- [ ] 클릭 정확도 오류 ≤ 목표치
```

### UT_PLAN.md 템플릿

```markdown
# UT_PLAN — {프로젝트명}

**작성일**: {YYYY-MM-DD}  
**버전**: {spec.md 버전}

## 검사 대상 화면
| 화면 | URL | 전환 목표 |
|---|---|---|
| {화면1} | {경로} | {전환 목표} |

## 타깃 페르소나
1. **초보자** — {구체적 사용자 프로필}
2. **파워유저** — {구체적 사용자 프로필}
3. **접근성 사용자** — {구체적 사용자 프로필}

## 성공 기준
{위 기준을 프로젝트에 맞게 수치화}

## 한계 및 범위 외 항목
- AI는 피로감·주의 분산 같은 인지 노이즈 재현 불가 → 정성적 피드백은 인간 UT 보완 필요
- {기타 프로젝트별 제약}
```

---

## Step 2: UT_SCENARIOS.md 작성

`specs/{NNN}/ut/UT_SCENARIOS.md` 생성.

### 시나리오 작성 원칙

- **현실적 맥락**: "버튼을 클릭하세요" 대신 "오늘 오후 발표자료에 쓸 배너를 만들어야 합니다"
- **목표 중심**: 인터페이스 언급 없이 사용자 목표만 기술
- **여정 구성**: 진입 → 핵심 작업 → 완료/이탈 3단계

### 시나리오 템플릿 (페르소나 × 화면)

```markdown
# UT_SCENARIOS — {프로젝트명}

## 초보자 시나리오

### S-B01: {화면} — {목표}
**맥락**: {현실적 상황 묘사}
**목표**: {사용자가 달성해야 하는 것, UI 언급 없이}
**성공 조건**: {어떤 상태가 되면 완료인가}
**예상 여정**:
1. {진입 단계}
2. {핵심 작업 단계}
3. {완료/이탈 단계}
**Playwright 재현 포인트**: {특히 검사할 인터랙션}

## 파워유저 시나리오
(동일 구조, 효율·단축경로 중심)

## 접근성 사용자 시나리오
(동일 구조, Tab/Enter 전용 경로 + ARIA 체크 포인트)
```

---

## Step 3: Playwright 테스트 실행 → UT_OBSERVATION_SHEET.md

### 3-1. 테스트 스크립트 생성

`tests/ut/usability-{화면명}.spec.ts` 생성.

**페르소나별 행동 패턴 구현:**

```typescript
// tests/ut/usability-{page}.spec.ts
import { test, expect, Page } from '@playwright/test';

// 페르소나: 초보자 (느린 탐색, 실수 포함)
async function beginnerBehavior(page: Page, scenario: string) {
  // 느린 클릭 (딜레이 200~800ms 랜덤)
  // 잘못된 요소 먼저 클릭 후 정정
  // 에러 발생 시 뒤로가기 후 재시도
}

// 페르소나: 파워유저 (빠른 탐색, 키보드 위주)
async function powerUserBehavior(page: Page, scenario: string) {
  // 빠른 클릭 (딜레이 50~150ms)
  // 키보드 단축키 시도
  // 직접 URL 진입
}

// 페르소나: 접근성 사용자 (Tab/Enter 전용)
async function accessibilityUserBehavior(page: Page, scenario: string) {
  // Tab 키 순서대로 이동
  // Enter/Space로 활성화
  // ARIA label 검증
}
```

**기록할 원시 신호:**

```typescript
interface ObservationSignal {
  persona: 'beginner' | 'power-user' | 'accessibility';
  scenario: string;
  timestamp: number;
  action: string;          // 클릭·입력·탭 이동 등
  target: string;          // 대상 요소 (selector)
  hesitationMs: number;    // 머뭇거림 시간
  isError: boolean;        // 오류 발생 여부
  errorType?: string;      // 'wrong-click' | 'dead-end' | 'form-error' | 'nav-confusion'
  screenshotPath?: string; // 오류/이탈 시점 스크린샷
  ariaIssue?: string;      // 접근성 위반 내용
}
```

### 3-2. 실행

```bash
# 페르소나별 순차 실행
npx playwright test tests/ut/ --headed --reporter=json > tests/ut/raw-observations.json
```

### 3-3. UT_OBSERVATION_SHEET.md 작성

`specs/{NNN}/ut/UT_OBSERVATION_SHEET.md` 생성.

```markdown
# UT_OBSERVATION_SHEET — {프로젝트명}

**실행일**: {YYYY-MM-DD HH:mm}
**환경**: {브라우저·해상도·storageState 여부}

## 초보자 페르소나

### S-B01: {시나리오명}
| 신호 | 값 |
|---|---|
| 완료 여부 | ✅ / ❌ |
| 총 소요 시간 | {N}s |
| 오류 횟수 | {N}회 |
| 최장 머뭇거림 | {N}ms @ {요소} |
| 이탈 지점 | {있으면 단계명} |
| 스크린샷 | {오류 시점 경로} |

**주요 관찰 사항**:
- {관찰 1}
- {관찰 2}

## 파워유저 페르소나
(동일 구조)

## 접근성 사용자 페르소나
(동일 구조 + ARIA 이슈 목록)

## 집계 요약

| 지표 | 초보자 | 파워유저 | 접근성 |
|---|---|---|---|
| 시나리오 완료율 | {N}% | {N}% | {N}% |
| 평균 소요 시간 | {N}s | {N}s | {N}s |
| 오류 발생 건수 | {N} | {N} | {N} |
| 이탈 지점 최다 | {단계} | {단계} | {단계} |
```

---

## Step 4: UT_FINDINGS_REPORT.md 작성 (Nielsen 휴리스틱 적용)

`specs/{NNN}/ut/UT_FINDINGS_REPORT.md` 생성.

### Nielsen 10 휴리스틱 체크리스트

| # | 휴리스틱 | 체크 포인트 |
|---|---|---|
| N1 | 시스템 상태 가시성 | 로딩·진행·완료 상태가 항상 표시되는가 |
| N2 | 실세계 대응 | 시스템 용어 대신 사용자 언어를 쓰는가 |
| N3 | 사용자 통제·자유 | 실행 취소·뒤로가기가 명확한가 |
| N4 | 일관성·표준 | 같은 기능이 일관된 UI 패턴을 쓰는가 |
| N5 | 오류 예방 | 되돌리기 어려운 행동 전 확인 절차가 있는가 |
| N6 | 기억보다 인식 | 선택지·아이콘이 외우지 않아도 이해되는가 |
| N7 | 사용 유연성·효율 | 숙련자를 위한 단축경로가 존재하는가 |
| N8 | 미적 절제 | 불필요한 정보·장식이 핵심을 가리지 않는가 |
| N9 | 오류 복구 지원 | 오류 메시지가 원인·해결책을 명확히 안내하는가 |
| N10 | 도움말·문서 | 도움이 필요한 곳에 컨텍스트 도움말이 있는가 |

### Severity 분류 (Jakob Nielsen)

| 등급 | 기준 | 처리 방침 |
|---|---|---|
| **S4 — Critical** | 사용자가 작업 완료 불가 | 즉시 수정 (배포 블로커) |
| **S3 — Major** | 작업 완료는 가능하나 큰 불편·이탈 유발 | 다음 스프린트 처리 |
| **S2 — Minor** | 불편하나 우회 가능 | 백로그 등록 |
| **S1 — Cosmetic** | 미적·UX 소소한 개선 | 여유 있을 때 처리 |

### UT_FINDINGS_REPORT.md 템플릿

```markdown
# UT_FINDINGS_REPORT — {프로젝트명}

**기반 데이터**: UT_OBSERVATION_SHEET.md  
**분석일**: {YYYY-MM-DD}

## Executive Summary

| 등급 | 건수 |
|---|---|
| S4 Critical | {N} |
| S3 Major | {N} |
| S2 Minor | {N} |
| S1 Cosmetic | {N} |

**배포 블로커**: {S4 항목 있으면 ⛔, 없으면 ✅}

## 결함 목록 (우선순위 순)

### [F-001] {결함 제목}
- **Severity**: S{N} — {Critical/Major/Minor/Cosmetic}
- **휴리스틱**: N{N} — {휴리스틱명}
- **영향 페르소나**: 초보자 / 파워유저 / 접근성
- **발생 화면·경로**: {화면 > 단계}
- **관찰된 증상**: {UT_OBSERVATION_SHEET에서 어떤 신호로 감지됐는가}
- **근본 원인**: {왜 이 문제가 발생하는가}
- **개선 방향**: {어떻게 고쳐야 하는가 — 간결하게}
- **스크린샷**: {있으면 경로}

(반복)

## 기술적 접근성 이슈 (별도 섹션)

| 이슈 | WCAG 기준 | 심각도 |
|---|---|---|
| {이슈} | {2.1.1 등} | {AA/AAA} |
```

---

## Step 5: REDESIGN_PROPOSAL.md 작성

`specs/{NNN}/ut/REDESIGN_PROPOSAL.md` 생성.

### 5-1. S4/S3 항목에 대한 개선안 발산

각 Critical/Major 결함마다 **레이아웃 안 2종** 제시:
- **안 A**: 기존 패턴 유지, 최소 변경
- **안 B**: 사용자 흐름 재설계 (권장)

### REDESIGN_PROPOSAL.md 템플릿

```markdown
# REDESIGN_PROPOSAL — {프로젝트명}

**기반**: UT_FINDINGS_REPORT.md  
**작성일**: {YYYY-MM-DD}

## F-001 개선안: {결함 제목}

**문제 요약**: {1줄}

### 안 A — 최소 변경
{ASCII 와이어프레임 또는 HTML 목업 경로}
- 변경 범위: {어떤 컴포넌트만 바뀌는가}
- 예상 효과: {어떤 오류가 줄어드는가}
- 트레이드오프: {뭘 포기하는가}

### 안 B — 흐름 재설계 (권장)
{ASCII 와이어프레임 또는 HTML 목업 경로}
- 변경 범위: {더 넓은 범위}
- 예상 효과: {더 큰 개선}
- 트레이드오프: {개발 비용 등}

**권장**: 안 {A/B} — {이유}

(결함별 반복)

## 구현 우선순위 로드맵

| 우선순위 | 결함 ID | 개선안 | 예상 공수 |
|---|---|---|---|
| P1 | F-001 | 안 B | {N}h |
| P2 | F-002 | 안 A | {N}h |
```

---

## Step 6: CI 통합 (선택 사항)

매 커밋마다 자동 실행하려면 `.github/workflows/ut.yml` 또는 Gitlab CI에 추가:

```yaml
# .github/workflows/ut.yml (GitHub Actions 예시)
name: AI Usability Test
on: [push, pull_request]
jobs:
  ut:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Playwright
        run: npx playwright install --with-deps
      - name: Run UT
        run: npx playwright test tests/ut/ --reporter=json
      - name: Upload observations
        uses: actions/upload-artifact@v3
        with:
          name: ut-observations
          path: tests/ut/raw-observations.json
```

---

## Step 7: 결과 보고 및 다음 단계

```
## AI 사용성 테스트 완료

📊 **요약**
- 테스트 화면: {N}개
- 페르소나: 초보자·파워유저·접근성 (3종 동시 실행)
- 발견 결함: S4 {N}건 / S3 {N}건 / S2 {N}건 / S1 {N}건

🚨 **배포 블로커**: {있으면 F-xxx 목록, 없으면 "없음"}

📁 **산출물 위치**: specs/{NNN}/ut/
  - UT_PLAN.md
  - UT_SCENARIOS.md
  - UT_OBSERVATION_SHEET.md
  - UT_FINDINGS_REPORT.md
  - REDESIGN_PROPOSAL.md

⚡ **권장 다음 단계**:
  - S4 결함 즉시 수정 후 재실행
  - REDESIGN_PROPOSAL.md의 P1 항목 리뷰
  - 접근성 S4/S3 이슈 있으면 → `design:accessibility-review`로 심층 리뷰 (2차 검토)
  - 인간 UT로 정성적 피드백 보완 (AI가 못 잡는 인지 노이즈)
```

---

## 타 스킬과의 역할 분담

| 스킬 | 역할 | 이 스킬과의 관계 |
|---|---|---|
| `ai-usability-test` (이 스킬) | Playwright 자동화 — 기술적·반복적 결함 1차 탐지 | — |
| `design:accessibility-review` | WCAG 기준 심층 접근성 리뷰 | **이 스킬 이후** 접근성 S4/S3 이슈가 있을 때 2차로 실행 |
| `design:design-critique` | 주관적 디자인 품질 피드백 (위계·일관성) | 병렬 실행 가능. 이 스킬은 자동화, critique는 정성 평가 |
| `1.0.0:ux-design` | 디자인 시스템 내 사용성 개선안 제안 | 이 스킬로 결함 발견 → `ux-design`으로 개선안 도출 가능 |
| `pre-launch-check` | 배포 전 체크리스트 | 접근성 검수 항목을 이 스킬 결과로 갈음 (Step 2-A/B 주석 참조) |
| `design:user-research` | 정성적 사용자 리서치 (인터뷰·설문) | 이 스킬이 먼저 → 정성 리서치가 더 깊은 문제에 집중 가능 |

### 접근성 검사 흐름 (중복 방지)

```
ai-usability-test (자동 1차)
  └─ 접근성 사용자 페르소나 → "기술적 접근성 이슈" 섹션 생성
       │
       ├─ S4/S3 이슈 없음 → pre-launch-check 접근성 항목 통과 처리
       │
       └─ S4/S3 이슈 있음 → design:accessibility-review (심층 2차)
                               └─ WCAG 기준 상세 분석 + 수정 가이드
```

---

## 한계 및 주의사항

- AI는 **피로감·주의 분산·감정적 맥락** 재현 불가 → 인간 UT 완전 대체가 아닌 1차 필터
- 페르소나 행동 패턴은 가정이며, 실제 사용자 행동과 차이 가능
- JavaScript 렌더링·인증이 복잡한 페이지는 Playwright storageState 사전 준비 필요
- 테스트 실행 환경이 프로덕션과 다르면 관찰 신호가 왜곡될 수 있음
