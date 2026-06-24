# work-analysis/ — D2A 보일러플레이트 3층 구조의 근거층

> 선행 작업에서 처음 만들어진 메타 인프라를 D2A 표준으로 도입.
> 디폴트(template/skills)를 *어떻게 고쳤는지* 의 단일 근거 역할.

## 3층 구조

```
[근거층] work-analysis/                              ← 이 디렉토리
  │   "무엇을 왜 고쳤나" (증거·매핑·실측 데이터)
  │
  │ 역류 (피드백 — 인사이트 → 디폴트 개선)
  ▼
[디폴트층] specs/.template/ + .claude/skills/        ← ★ 진짜 개선 대상
  │   양식(.template) + 방법(skills) — 새 프로젝트가 그대로 복사
  │
  │ 복사·적용
  ▼
[인스턴스층] specs/{NNN}-{feature}/                 ← 실제 프로젝트 산출물
      디폴트를 한 번 적용한 결과 (선행 작업·NEXON STREAM 등)
```

**핵심**: 인스턴스(specs/{NNN}/)는 *시험대*이고, 진짜 개선 대상은 **디폴트(.template + skills)** 다.

## 디렉토리 구성

```
work-analysis/
├── README.md                                  # 이 파일
├── DESIGN-FLOW-COMPARISON.md                  # 디폴트 vs 실제 갭 분석 + 매핑표
├── baseline-defaults/                         # 개선 *전* 동결 스냅샷
│   ├── ui-design-workflow.DEFAULT.md          # before 보존
│   ├── create-spec.DEFAULT.md                 # before 보존
│   └── ai-usability-test.DEFAULT.md           # before 보존
├── REPORT-{topic}.md                          # 단계별 dogfooding 결과 보고
└── insights/                                  # 단편 인사이트 (승격 후보 풀)
    └── {YYYY-MM-DD}-{topic}.md
```

## 사용 흐름

### 1. 인사이트 발견 (인스턴스 작업 중)
- 어떤 마찰을 잡고 싶을 때마다 `insights/{날짜}-{주제}.md` 단편으로 기록
- 1회성이면 그대로 인스턴스에서 처리, 2회 반복되면 승격 후보

### 2. 갭 분석 (`DESIGN-FLOW-COMPARISON.md`)
- 디폴트 흐름 vs 실제 작업 흐름을 11개 항목 표로 비교
- "그래서 얻은 것" 컬럼에 정량 효과 기록 (예: 핑퐁 5라운드 → 0라운드)

### 3. 동결 스냅샷 (`baseline-defaults/*.DEFAULT.md`)
- 디폴트 개선 *전* 원본을 영구 보존
- 개선본과 diff하여 before/after 변화를 영구히 추적 가능

### 4. 디폴트 승격 (근거 → 디폴트층)
- 인사이트가 **2회 반복 + 일반화 검증** 통과하면 `.template/` 또는 `.claude/skills/` 에 흡수
- 승격 시 `specs/.template/VERSION` 의 변경 이력에 매핑 (`work-analysis/{문서}` 참조)

## 효과 측정 (§5 지표 — 다음 단계 작업)

| 지표 | 측정 방법 | 통제군 |
|---|---|---|
| 핑퐁 라운드 수 | 시안 → 사용자 OK까지 라운드 카운트 | "스킬 끄고 같은 화면 1개" |
| DS 가정 오류 | swap-pass-log.md 에 기록된 mismatch 건수 | swap pass 비활성화 vs 활성화 |
| Phase 0 시간 | 시작~승인까지 분 단위 | v1.5 vs v1.6+ 흐름 |
| UT 결함 검출률 | S4/S3 발견 건수 | 인간 UT vs AI UT |

## 일반화 검증 게이트 (§6)

특정 프로젝트(예: 선행 작업)에만 의미 있는 인사이트가 디폴트에 잘못 박히면 다른 archetype(백오피스·CLI·API)에서 마찰 유발.
**디폴트 승격 전 2개 이상 archetype에서 재현 확인 필수.**

## 승격 규칙 (§7)

```
인사이트 (insights/) → 2회 반복 마찰
    ↓
일반화 테스트 (2개 archetype 통과)
    ↓
디폴트 승격 (.template/ 또는 .claude/skills/)
    ↓
VERSION 변경 이력에 매핑 기록
```

## 관련 정책
- `CLAUDE.md` 제3장 "결정 전 반드시 확인 (ask-before-decide)" — 인사이트 발견 시 ① 카테고리 D 구조 변경에 해당하는지 점검
- `refs/collaboration-tracker.md` — 디폴트 변경이 다른 부서 산출물에 영향 주면 자동 등록
- `specs/.template/VERSION` — 모든 디폴트 변경의 단일 변경 이력
