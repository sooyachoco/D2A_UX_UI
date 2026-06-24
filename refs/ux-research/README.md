# UX Research — AI 네이티브 리서치 지식 베이스

> **출처 개념**: [AI 네이티브 방식의 UX 리서치와 데이터 분석](https://brunch.co.kr/@ghidesigner/493)
> 형제 글: [AI 네이티브 사용성 테스트](https://brunch.co.kr/@ghidesigner/492) → `.claude/skills/ai-usability-test.md`

UX 리서치 산출물을 **HTML이 아닌 MD 파일**로 관리하는 지식 자산 체계.
(토큰 68~87%↓ · RAG 탐색 정확도 35%↑ · git 변경 추적 · 스크립트 실행 위험 0)

---

## 단일 SOURCE 규약 (drift 방지 — 가장 중요)

페르소나와 사용자 여정은 **이 디렉터리에서만 정의**한다.
`ai-usability-test`, `1.0.0:ux-design`, `design:design-critique` 등 하위 스킬은
아래 두 파일을 **읽기만** 하고 자체적으로 재정의하지 않는다.

| 단일 source 파일 | 소비하는 곳 | 소비 방식 |
|---|---|---|
| `PERSONA.md` | `ai-usability-test` Step 1-2 (페르소나 3종) | 읽어서 시뮬레이션 행동에 매핑 |
| `USER_JOURNEY_MAP.md` | `ai-usability-test` Step 2 (UT_SCENARIOS) | 터치포인트 → 검증 시나리오 도출 |

> 하위 스킬이 페르소나/여정을 직접 새로 만들고 있으면 **규약 위반** —
> 이 파일들로 통합한 뒤 링크로 참조하게 고친다.

---

## 산출물 7종

| 파일 | 역할 | 단계 |
|---|---|---|
| `USER_RESEARCH.md` | 가설·방법론·마일스톤 (전략 이정표) | 1. 설계 |
| `INTERVIEW_GUIDE.md` | AI 에이전트 작동 경계 (CAR: 맥락·지시·규칙) | 1. 설계 |
| `INTERVIEW_NOTES.md` | 전사본 + 자동요약 + 원천 발화 타임코드 | 2. 수집 |
| `SURVEY_ANALYSIS.md` | 정량 설문 + 주관식 패턴 융합 | 3. 분석 |
| `EMPATHY_MAP.md` | 감정·환경·이득·곤경 다차원 구조화 | 3. 분석 |
| **`PERSONA.md`** ⭐ | 페르소나 + 신뢰도 점수 + 실증 링크 | 3. 분석 · **단일 source** |
| **`USER_JOURNEY_MAP.md`** ⭐ | 유입~이탈 터치포인트·결정 순간 | 3. 분석 · **단일 source** |

---

## 데이터 신뢰도 표기 (필수)

"상상한 것"과 "데이터로 검증된 것"을 분리한다.

| 표기 | 의미 |
|---|---|
| 🟢 검증 | 인터뷰/설문/트래킹 데이터로 뒷받침 (실증 링크 필수) |
| 🔵 가설 | 아직 데이터 없는 추정 — `collaboration-tracker.md`에 등록 |

가설(🔵)이 데이터로 확인되면 🟢로 승격하고 실증 링크를 단다.
