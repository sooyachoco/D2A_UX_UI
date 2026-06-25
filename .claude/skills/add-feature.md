---
name: add-feature
description: Phase 완료 후 추가 개발 표준 진입점. 스코프 정의 → 구현 → 변경 규모 기반 subagent-review → 커밋을 자율 실행. 기능 추가·버그 수정·리팩터링 시 사용.
---

# add-feature — 추가 기능 개발 스킬

초기 Phase 완료 후 기능 추가·수정·리팩터링을 위한 표준 진입점.
`/run-phase`의 Phase 단위 리뷰 강제를 상속하되 경량화된 스코프로 운영한다.
CLAUDE.md의 모든 행동 규칙(1–9번)이 이 스킬 내에서도 그대로 적용된다.

## 트리거

- "add-feature {기능명}"
- "X 기능 추가해줘" / "Y 변경해줘" / "Z 리팩터링해줘" (Phase 완료 이후)
- "버그 고쳐줘" (단일 변경)

---

## Step 1: 스코프 명확화

### 1-1. 기존 상태 확인

```
1. tasks.md가 있으면 현재 완료 Phase와 미완료 ☐ 태스크를 확인한다.
   → 스펙에 이미 포함된 ☐ 태스크이면: "run-phase N 으로 진행하세요" 안내 후 종료.
   → 스펙에 없는 신규 작업이면: 아래 1-2로 진행.

2. spec.md가 있으면 요청 기능이 스펙 범위 내인지 확인한다.
```

### 1-2. Mini-Spec 작성 (ask-before-decide 준수)

요청이 모호하거나 영향 파일이 불명확하면 아래 형식으로 확인 후 진행한다.
요청이 충분히 명확하면 mini-spec을 직접 작성하고 사용자 승인을 구한다.

```
📋 구현 범위 확인: {기능명}

**구현 내용**:
- {변경 또는 추가할 내용}

**영향 파일 (예상)**:
- {변경 예정 파일 목록}

**주의사항**:
- {spec.md / decisions.md / data-model.md 변경 필요 여부}
- {API 변경 여부 → api-spec.yaml 갱신 필요}

계속 진행할까요?
```

### 1-3. 리뷰 모드 사전 결정

영향 파일 목록 기준으로 리뷰 모드를 결정한다 (Step 3에서 사용).

| 조건 | 리뷰 모드 |
|---|---|
| 1–2파일, Critical Path 아님 | `skip` |
| 3–9파일 또는 `spec.md`·`decisions.md` 변경 | `--fast` |
| 10+ 파일 또는 Critical Path 파일 포함 | `--full` |

**Critical Path 파일 판별**:
- `contracts/`, `data-model.md`, `api-spec.yaml` 경로 포함
- 파일 경로에 `auth`, `login`, `session`, `middleware` 포함
- 라우터·컨트롤러 파일 (`route`, `controller`, `handler`, `api` 포함)

---

## Step 2: 구현

1. 영향 파일이 3개 이상이면 `TodoWrite`로 구현 단계를 먼저 등록한다.
2. 각 파일을 순차적으로 구현한다.
   - `decisions.md` ⬜ 발견 시: `refs/INDEX.md` 기반 자동 선택을 먼저 시도한다.
   - 정책 근거 없는 항목만 사용자에게 질문한다.
3. 빌드 검사:
   - 백엔드: `pytest` 실행
   - 프론트엔드: `npm run build` 실행
   - 연속 2회 실패 → 블로커 처리 (Step 2 마지막 항목 참조)
4. spec-doc-sync: 코드 변경이 문서에 영향을 주면 같은 턴에서 갱신 (CLAUDE.md 규칙 9번).

```bash
./scripts/log-activity.sh SKILL "{기능명} 구현 완료" || true
```

**블로커 발생 시 (연속 2회 빌드 실패 또는 decisions.md 자동 선택 불가)**:

```bash
./scripts/log-activity.sh BLOCKED "{기능명} 구현 블로커" "{이유}" || true
./scripts/notify-slack.sh "🔴 블로커: {기능명}" "{이유}\n해결 후 '해결됨, 계속해줘'" || true
```

PROGRESS.md 🔴 갱신 → **멈춤**.

---

## Step 3: 규모 기반 서브에이전트 리뷰

Step 1-3에서 결정한 모드를 실행한다.

### `skip` — 리뷰 생략

변경 파일 목록을 출력하고 로그를 남긴다.

```bash
./scripts/log-activity.sh REVIEW "{기능명} 리뷰 생략 (소규모 변경)" || true
```

Step 4로 이동.

### `--fast` / `--full` — 리뷰 실행

`.claude/skills/subagent-review.md`를 Read한 뒤 Step 1–5 (Step 3.5 포함)를 인라인 실행한다.

**리뷰 대상 파일 결정 (subagent-review Step 1-2 대체)**:

Phase 경계 커밋 기준이 아닌 이번 add-feature 변경 파일을 기준으로 사용한다.

```bash
# 커밋 전 변경 파일 (staged + unstaged 소스 파일)
git diff --name-only HEAD
git diff --cached --name-only
```

리뷰어 구성:
- `--fast`: Security + Architecture (2명)
- `--full`: Security + Performance + Architecture + Spec Fidelity + Accessibility + Feature Behavior (6명)

**Critical 0건** → Step 4로 이동.
**Critical 있음** → subagent-review Step 4 수정 절차 완료 후 Step 4로 이동.
**동일 Critical 반복 / 2회 연속 신규 Critical** → 블로커 처리 후 멈춤.

**feature 리뷰 토큰 생성**:

```bash
FEATURE_SLUG=$(echo "{기능명}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | cut -c1-40)
python3 -c "
import os, datetime
slug = '${FEATURE_SLUG}'
os.makedirs('.claude/review-tokens', exist_ok=True)
ts = datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')
token_path = f'.claude/review-tokens/feature-{slug}-{ts}.token'
with open(token_path, 'w') as f:
    f.write(datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))
print(f'리뷰 토큰 생성: {token_path}')
" || true
./scripts/log-activity.sh REVIEW "{기능명} 리뷰 완료" "${MODE} 모드 / Critical: 0" || true
./scripts/notify-slack.sh "✅ {기능명} 리뷰 완료" "Critical: 0" || true
```

---

## Step 4: 커밋

```bash
git add {변경 파일 목록}
git commit -m "{type}: {기능명 요약}"
./scripts/log-activity.sh COMMIT "{기능명}" || true
```

커밋 타입 (Conventional Commits):

| 작업 유형 | 타입 |
|---|---|
| 신규 기능 추가 | `feat:` |
| 버그 수정 | `fix:` |
| 리팩터링 | `refactor:` |
| 문서·스펙만 변경 | `docs:` |
| 설정·환경 변경 | `chore:` |

---

## 블로커 처리 요약

| 상황 | 처리 |
|---|---|
| tasks.md에 ☐ 태스크 발견 | `/run-phase N` 안내 후 종료 |
| 연속 2회 빌드 실패 | PROGRESS.md 🔴 갱신 + 슬랙 알림 + 멈춤 |
| 동일 Critical 반복 또는 2회 연속 신규 Critical | blockers.md 기록 + 슬랙 알림 + 멈춤 |
| decisions.md ⬜ 자동 선택 불가 | 일괄 질문 후 재개 |

블로커 해결 후 "해결됨, 계속해줘" 입력 시 → `Skill("session-phase-workflow")` Part E 절차로 복귀.
