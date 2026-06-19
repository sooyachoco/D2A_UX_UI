---
name: run-phase
description: tasks.md의 특정 Phase를 자율 실행. 각 태스크를 명시된 read/done 스펙 기반으로 순차 실행하고 완료 시 커밋. "run-phase N", "Phase N 실행해줘" 요청 시 사용.
---

# Run Phase — 자율 실행 스킬

tasks.md의 특정 Phase를 사용자 개입 없이 자동으로 실행한다.
각 태스크는 `**read**`에 명시된 파일만 로드하고, `**done**` 기준으로 완료를 검증한다.

> **⚠️ `Skill()` 호출 제약**: Claude Code의 `Skill()` 도구는 사용자가 `/skill-name`을 직접 타이핑할 때만 동작한다.
> AI가 `Skill("run-phase", "N")`을 자율 호출하면 "Unknown skill" 오류가 발생할 수 있다.
> **오류 발생 시 올바른 폴백**: 이 파일을 Read로 읽고 각 Step을 직접 실행한다.
> **단, Step 3(subagent-review)은 절대 스킵하지 않는다.**
> `Skill("subagent-review")` 호출도 실패하는 경우:
> → `.claude/skills/subagent-review.md`를 Read로 읽고 각 Step을 인라인 실행한다.

## 트리거

- "run-phase N" (N = Phase 번호)
- "Phase N 실행해줘" / "Phase N 시작해줘"
- session-phase-workflow Part B에서 자동 연속 실행 시

---

## Step 0: 사전 게이트 확인

### Step 0-A: state.json 초기화 (MCP 필수) — 0-B보다 먼저 실행

초기화 전에 **미해결 블로커·인증 프로필 변경 마커**를 먼저 확인한다. 세션 복귀 시 이전 블로커나 `change-auth-profile.sh` 가 남긴 마커가 state.json 에 남아 있을 수 있다.

```
# 1) .claude/state.json 존재하면 Read로 내용 확인
#    a) auth_profile_pending 키 존재 → change-auth-profile.sh 후 boilerplate-setup 재실행 미완료
#       → 사용자에게 차단 메시지 보고 후 즉시 중단:
#          "❌ 인증 프로필 변경 후 셋업 미완료 — boilerplate-setup 실행 필요
#           대기 중 프로필: ${auth_profile_pending}"
#       → boilerplate-setup 호출 후 재진입 안내
#    b) blockers 배열에 항목이 있고 status가 "blocked"이면:
#       → 사용자에게 블로커 목록 보고 후 중단
#       → "해결됨" 확인 받은 후에만 아래 초기화 진행
# 2) 블로커 없음 + 마커 없음 인 경우에만 초기화
```

**`auth_profile_pending` 마커 처리 (run-phase 자체 차단):**

```bash
PENDING=$(STATE_FILE=.claude/state.json python3 -c "
import json, os, pathlib
p = pathlib.Path(os.environ['STATE_FILE'])
if p.exists():
    d = json.loads(p.read_text())
    print(d.get('auth_profile_pending', ''))
" 2>/dev/null)

if [ -n "$PENDING" ]; then
  cat <<EOF >&2

❌ 인증 프로필 변경 후 셋업 미완료
   대기 중 프로필: $PENDING

조치: boilerplate-setup 을 다시 실행하여 Stage 1.6-A → Stage 2-E 까지 완료하고,
      create-spec Step 2.7 (UI + 실제 로그인 + storageState 통합 검증)을 1회 수행하세요.
      Stage 1.6-A 의 AskUserQuestion 에서 '$PENDING' 를 선택해야 합니다.
      셋업 완료 후 마커가 자동 제거됩니다.
EOF
  ./scripts/log-activity.sh BLOCKED "auth_profile_pending=$PENDING" "boilerplate-setup 재실행 대기" || true
  exit 1
fi
```

> 마커 제거: Stage 1.6-A 가 `auth_profile` 을 새로 저장할 때 `auth_profile_pending` 도 함께 제거해야 한다 (boilerplate-setup.md Stage 1.6-A 의 update_state 호출에 포함).

```
mcp__d2a-harness__update_state({
  patch: { phase: N, status: "running", current_task: null, blockers: [] }
})
```

- 호출 성공 → `.claude/state.json` 파일 존재 확인 (Glob으로 검증)
  - 파일 확인됨 → Step 0-B 진행
  - 파일 없음 (MCP 반환 ok이나 파일 미생성) → `scripts/state-manager.sh init` 실행 후 재확인
- MCP 호출 실패 → `scripts/state-manager.sh set-phase N` 실행 → 파일 생성 후 Step 0-B 진행

```bash
./scripts/log-activity.sh MCP "Phase ${N} state.json 초기화" "update_state 호출" || true
```

### Step 0-B: Phase 게이트 검증 (MCP 필수)

**[우회 변수 점검] Gate 3 비활성 상태 경고:**

```bash
if [ "${D2A_ALLOW_REVIEW_SKIP:-0}" = "1" ]; then
  echo "⚠️  경고: D2A_ALLOW_REVIEW_SKIP=1 설정 감지 — Gate 3(리뷰 토큰 강제) 비활성 상태입니다."
  echo "   긴급 상황이 아니라면: unset D2A_ALLOW_REVIEW_SKIP"
fi
```

이 경고는 Phase 실행을 차단하지 않는다. 단, 변수가 설정된 상태로 Phase를 완료하면
Gate 3가 우회되어 리뷰 없이 "Phase N 완료" 커밋이 허용됨을 인지해야 한다.

**MCP 도구로 코드 수준 검증을 실행한다 (Claude 텍스트 판단 대신):**

```
mcp__d2a-harness__check_phase_gate({ phase: N })
```

- `ok: true` → `unresolved_decisions` 배열도 함께 확인:
  - 비어 있으면: 실행 시작 (Step 0-C 건너뜀)
  - 비어 있지 않으면: **Step 0-C 진행** (정책 자동 선택 시도 — `ok: true`여도 decisions 미해결이면 실행 전 처리 필수)
- `ok: false` → blockers / unresolved_decisions 목록을 사용자에게 보고 후 **즉시 중단**

```bash
./scripts/log-activity.sh MCP "Phase ${N} gate 확인" "check_phase_gate 결과: ok=true" || true
```

MCP 도구 실패(서버 미기동 등) 시 폴백:
```
1. tasks.md 읽기 — 해당 Phase 태스크 목록 확인
2. Phase 1 이상이면 integration-ready.md 확인:
   판정 "✅ AUTONOMOUS ZONE 진입 가능" → 진행
   그 외 → 즉시 중단 (아래 메시지 출력, Mock 우회 제안 금지):

   ⛔ Phase {N} 진입 불가 — integration-ready.md 미발급

   prerequisites.md에 미수집 항목이 있습니다.
   실제 값이 없으면 Phase {N}을 시작할 수 없습니다.

   해결 방법:
     collect-prerequisites 실행 → 값 수집 → integration-ready.md 발급

   Mock 처리나 Phase 건너뛰기는 지원하지 않습니다.

3. decisions.md 읽기 — 해당 Phase의 ⬜ 항목 확인
   → Step 0-C 정책 자동 선택 시도
   → 자동 선택 불가 항목만 일괄 질문
```

### Step 0-C: decisions.md 정책 기반 자동 선택

⬜ 항목이 발견되면 **사용자에게 묻기 전에** 정책에서 자동 선택을 시도한다.

```
각 ⬜ 항목에 대해:

1. refs/INDEX.md "빠른 결정 가이드" 표에서 해당 항목 키워드 검색
   → 정책이 선택지를 명확히 지정하면:
      decisions.md 해당 항목을 ✅로 갱신
      결정 내용 + "🤖 정책 자동 선택" 표시
      사용자에게 보고: "G-00X [{항목}]을(를) 정책 기반으로 [{값}]로 자동 선택했습니다."
      → 다음 항목으로 계속

2. refs/policies/ 해당 파일에서 추가 검색
   → 동일 조건이면 자동 선택

3. 정책에 선택지가 없거나 충돌이 있으면:
   해당 항목을 "자동 선택 불가" 목록에 추가

자동 선택 불가 목록이 비어 있으면 → 즉시 실행 시작
자동 선택 불가 항목이 있으면 → 일괄 질문 (session-phase-workflow Part D 방식)
```

**자동 선택 가능 항목 예시** (정책에 명확한 기준 있음):
- DB 엔진 → 정책에 PostgreSQL 지정 시 자동 선택
- 인증 방식 → refs/policies/authentication.md에서 프로젝트 유형별 결정
- 코드 컨벤션 → 기술 스택 확정 시 표준 린터 자동 적용

**자동 선택 불가 항목 예시** (비즈니스 판단 필요):
- 기능 우선순위 변경
- 외부 서비스 연동 여부
- 데이터 보관 기간

각 결정 완료 시 (자동선택 또는 사용자 확인 직후) DECISION 로그를 남긴다:
```bash
# 정책 자동선택 시
./scripts/log-activity.sh DECISION "[{항목}]: {값}" "🤖 refs 자동선택" || true

# 사용자 확인 시
./scripts/log-activity.sh DECISION "[{항목}]: {값}" "👤 사용자 확인" || true
```

---

## Step 1: Phase 태스크 로드

> **참고**: 태스크 선택·deps 확인·완료 판단은 Step 2의 `get_next_task`가 담당한다.
> 여기서는 Phase 전체 구조를 파악하여 TodoWrite에 등록하는 용도로만 사용한다.

tasks.md에서 해당 Phase의 태스크 목록을 확인한다:
- `**status**: ☐` — 실행 대상
- `**status**: ☑` — 이미 완료 (건너뜀)

TodoWrite로 실행 대상 태스크 목록을 순서대로 등록한다.
(실제 실행 순서와 deps 확인은 `get_next_task`가 결정한다.)

**스프린트 컨트랙트 생성 (Phase 1 이상, 소스 변경 수반 시 필수):**

`.claude/review-contracts/phase-{N}.md`를 아래 형식으로 생성한다.
이 파일은 T{N}-review 실행 시 리뷰어가 판정 기준으로 사용한다.

```markdown
# Phase {N} 리뷰 컨트랙트

생성일: {YYYY-MM-DD HH:MM}
Phase: {N}

## 이번 Phase 구현 범위
{tasks.md의 해당 Phase 태스크 제목 목록}

## 완료 기준 (리뷰어 판정 기준)
{spec.md 또는 tasks.md의 done 기준에서 추출}
- [ ] {구현해야 할 기능 1}
- [ ] {구현해야 할 기능 2}
...

## 이번 Phase에서 의도적으로 포함하지 않는 범위
{다음 Phase로 미룬 기능 — 리뷰어의 오탐 방지용}
- {기능 A}는 Phase {N+1}에서 구현 예정
...

## 리뷰어 포커스
- Security: {이번 Phase의 인증·권한 관련 주요 변경}
- Architecture: {이번 Phase의 레이어 경계 변경}
- Feature Behavior: {이번 Phase의 핵심 사용자 시나리오}
```

파일이 이미 존재하면 (복귀 실행 시) 건너뛴다.

**UI-heavy Phase 흐림 방지 체크 (.tsx/.jsx 파일 포함 Phase에만 적용):**

스프린트 컨트랙트의 "리뷰어 포커스" 섹션에 아래 항목을 추가한다.
Phase 실행 중 이 규칙을 위반하는 구현을 발견하면 즉시 수정 후 진행한다.

```markdown
## 흐림(drift) 방지 규칙 (UI Phase)
- [ ] 토큰 단일 출처: CSS 변수(`--color-*`, `--spacing-*`) 사용 — 매직넘버 px 값 금지
- [ ] 반복 UI 컴포넌트화: 동일 UI가 2회 이상 등장하면 공통 컴포넌트로 즉시 승격
- [ ] 상태 variant는 플래그 분기: 같은 컴포넌트의 상태별 렌더를 별 파일 복붙 금지
- [ ] 레이아웃 폭 토큰화: 패널/콘텐츠 폭을 인라인 px 대신 CSS 변수로
- [ ] 상태 커버리지: 각 인터랙티브 컴포넌트의 빈/로딩/에러 상태 모두 구현
```

참조: `.claude/skills/ui-design-workflow.md` §6 흐림 방지

**Phase 시작 로그 (Step 1 완료 후 필수):**

```bash
# 현재 Phase {N}의 미완료 태스크만 카운트 (전체 tasks.md가 아닌 해당 Phase만)
TASK_COUNT=$(python3 -c "
import re
try:
    content = open('tasks.md').read()
    lines = content.split('\n')
    in_phase = False
    count = 0
    for line in lines:
        ph = re.match(r'^##\s+Phase\s+([\d.]+)', line)
        if ph:
            in_phase = (float(ph.group(1)) == {N})
        if in_phase and re.match(r'^\*\*status\*\*:\s*☐', line):
            count += 1
    print(count)
except Exception:
    print('?')
" 2>/dev/null || echo "?")
./scripts/log-activity.sh PHASE "Phase {N} 시작" "태스크 ${TASK_COUNT}개" || true
./scripts/notify-slack.sh "🚀 Phase {N} 시작" "태스크 ${TASK_COUNT}개 자율 실행 시작" || true
```

---

## Step 2: 태스크 실행 루프

### 2-1. 다음 태스크 요청 (MCP)

```
mcp__d2a-harness__get_next_task({ phase: N })
```

MCP가 내부적으로 처리하는 것:
- tasks.md + state.json 교차 확인으로 deps 충족된 첫 태스크 선택
- `create_checkpoint` 자동 호출 (write hook 게이트 활성화)
- `state.json.current_task` 갱신

반환값에 따른 처리:

| 반환 | 처리 |
|---|---|
| `all_done: true` | Phase 완료 → Step 3으로 이동 |
| `ok: false` | error 메시지 보고 → 블로커 처리 → 멈춤 |
| `ok: true`, `task_id` 있음 | 아래 2-2 진행 |

```bash
./scripts/log-activity.sh MCP "{task_id} 시작" "get_next_task 반환" || true
```

### 2-2. 구현

**[컨텍스트 압박 사전 점검]** 태스크 구현 시작 전:
- 이번 Phase에서 완료한 태스크가 10개 이상이거나
- 이전 태스크들에서 대형 파일(각 50KB+)을 3개 이상 Read한 경우
→ `/session-phase-workflow` Part B-4 핸드오프 절차를 실행한다.

`read_files` 목록의 파일을 Read한다 (MCP가 결정한 목록만).
`write_files` 파일을 생성/수정한다.

**`skill` 필드 처리** (`get_next_task` 반환값의 `skill` 필드 확인):

| skill 값 | 처리 |
|---|---|
| `"subagent-review"` | **아래 인라인 실행 절차를 따른다** (Skill() 호출 금지) |
| 기타 | `.claude/skills/{skill명}.md` Read 후 인라인 실행 |

**`skill: subagent-review` 인라인 실행 절차 (T{N}-review 태스크):**

1. `.claude/skills/subagent-review.md` 파일을 Read로 읽는다
2. 파일의 Step 1~5를 메인 에이전트가 순차적으로 직접 실행한다
   - Step 1: 모드 결정 및 리뷰 범위·파일 분류 확인 (`--full` 기본)
   - Step 2-0: 통합 테스트 실행 (pytest tests/integration/ 또는 test:e2e)
   - Step 2-1: Agent 도구로 서브에이전트 병렬 실행 (6명)
   - Step 3: 결과 취합 (통합 테스트 결과 + 에이전트 결과 통합, Critical/Warning/Info 분류)
   - Step 4: Critical 수정 (메인 에이전트 직접 수행)
   - Step 5: 완료 처리 — **review token 반드시 생성** (`.claude/review-tokens/phase-{N}.token`)
3. `write_files`의 token 파일이 존재해야 `submit_task`의 `done` 기준 통과

### 2-3. 제출 및 액션 수행 (MCP)

구현 완료 후:

```
mcp__d2a-harness__submit_task({ task_id: "{task_id}", attempt: 1 })
```

MCP가 내부적으로 처리하는 것:
- `validate_task_done` 실행 (done 기준 전체 검증)
- validate token 파일 생성 (pre-bash-hook의 커밋 허용 조건)
- state.json 갱신

**action별 처리:**

**`action: "next"` (통과)**:

tasks.md ☑ 갱신 → 커밋 순서 (커밋 타입은 Conventional Commits 형식):

```
1. tasks.md 해당 태스크 **status**: ☑ 로 갱신 (Edit 도구)
```

```bash
git add {write 파일 목록} tasks.md
git commit -m "{type}: {task_id} {태스크 제목}"
./scripts/log-activity.sh TASK "{task_id}: {제목}" "Phase {N} — 통과 (attempt {attempt})" || true
./scripts/notify-slack.sh "✅ {task_id} 완료" "다음: {next_task_id}" || true
```

TodoWrite 해당 태스크 completed 마킹 → **즉시 2-1로 돌아가 다음 태스크 요청**.

---

**`action: "retry"` (1차 실패)**:

reason 메시지를 읽고 수정한 뒤 attempt=2로 재제출:

```
mcp__d2a-harness__submit_task({ task_id: "{task_id}", attempt: 2 })
```

- `action: "next"` → 위 통과 처리로 진행
- `action: "rollback"` → 아래 롤백 처리로 진행

---

**`action: "rollback"` (2회 실패, 자동 롤백 완료)**:

MCP가 내부적으로 `rollback_to_checkpoint`를 실행하여 recovery 브랜치를 생성한 상태.
원래 브랜치(main 등)는 변경되지 않음.

```bash
./scripts/log-activity.sh BLOCKED "{task_id} validate 2회 실패" "{reason 요약}" || true
./scripts/notify-slack.sh "🔴 블로커: {task_id}" "{reason}\n해결 후 '해결됨, 계속해줘'" || true
```

blockers.md 기록 → PROGRESS.md 갱신(🔴) → **멈춤**.

**블로커 해결 후 재개 절차:**

1. `recovery/{task_id}-{timestamp}` 브랜치에서 코드를 수정한다
2. 수정이 만족스러우면 해당 브랜치를 원래 브랜치(main 등)에 merge한다:
   ```bash
   git checkout main
   git merge recovery/{task_id}-{timestamp}
   ```
3. recovery 브랜치를 삭제하면 MCP(`get_next_task`)가 다음 호출 시 자동으로 blocker를 해제한다
   - 삭제: `git branch -d recovery/{task_id}-{timestamp}`
   - MCP `autoResolveBlockers`가 브랜치 소멸을 감지하여 `state.json.blockers`에서 해당 항목을 제거
4. 사용자가 "해결됨, 계속해줘"를 입력하면 아래 알림 발송 후 Part E 복귀 절차로 진입
   ```bash
   ./scripts/log-activity.sh BLOCKED "{task_id} 블로커 해제" "" || true
   ./scripts/notify-slack.sh "🟢 블로커 해제: {task_id}" "재개 중..." || true
   ```

---

## Step 3: Phase 완료 처리

모든 태스크 ☑ 완료 후, 아래 순서로 실행한다:

**3-0. tasks.md 상태 최종 검증 + Blocker(즉시수정) 잔존 확인 (Phase 완료 전 필수)**

```
[1] Grep으로 tasks.md에서 해당 Phase의 **status**: ☐ 가 0건인지 확인.
☐ 잔존 시 → 강제 ☑ 처리 금지.
            미완료 태스크를 ☑ 로 강제 갱신하면 실제 결함이 숨겨진다.
            → blockers.md에 "Phase N 완료 시 미완료 태스크: {태스크ID목록}" 기록
            → PROGRESS.md 🔴 갱신
            → 슬랙 알림 후 멈춤 (아래 3-1 이후 진행하지 않음)
☐ 0건 확인됨 → [2]로 진행

[2] docs/technical-debt.md 존재 시, Phase {N} 항목에 "Blocker(즉시수정)" 잔존 여부 확인.
    (subagent-review Step 5에서 미수정 즉시수정 항목이 이 파일에 기록됨)

    잔존 시 → Phase 완료 차단:
      ./scripts/log-activity.sh BLOCKED "Phase {N} Blocker(즉시수정) 잔존" "technical-debt.md 확인" || true
      ./scripts/notify-slack.sh "🔴 Phase {N} 완료 차단" "Blocker(즉시수정) 미수정\n해결 후 계속해줘" || true
      → PROGRESS.md 🔴 갱신 → 멈춤

    없음 또는 파일 없음 → 3-1로 진행
```

**3-1. PROGRESS.md 갱신 (Phase 전환 시 필수)**

PROGRESS.md에서 다음 세 항목을 반드시 갱신한다:

```
① "Phase 체크리스트" 섹션: 완료된 Phase 항목을 [x]로 변경
② "review_status" 행:
   - 소스 파일(.py/.ts/.tsx/.js/.jsx) 변경 있었음 → "Phase {N}: ⏳ pending" 으로 설정
     (subagent-review 완료 후 Step 5에서 "Phase {N}: ✅ {YYYY-MM-DD}" 로 갱신됨)
   - 소스 변경 없음(문서·설정만 변경) → "Phase {N}: N/A" 로 설정
③ "코드 패턴 메모" 섹션 (placeholder 치환 필수):
   - 헤더를 "Phase {N} 완료 기준"으로 업데이트
   - 이 Phase에서 추가된 API 경로, 파일, 핵심 함수를 반영
   - "다음 세션 사전 메모"에 다음 Phase 시작 전 확인 사항 기록
   - **반드시 다음 placeholder 토큰을 모두 실제 값으로 치환**:
     · `{실제 프로젝트 구조 …}` → 실제 디렉터리 트리
     · `{예: …}` → 실제 파일 경로 / 함수명 / 패턴
   - 잔존 시 다음 Phase 진입 시 `check_phase_gate` 에서 blocker 로 차단됨 (검사 6).
```

**검증 명령 (Phase 완료 직전 반드시 실행):**

```bash
# "코드 패턴 메모" 섹션에 placeholder 토큰 잔존 검사
if awk '/^##\s*코드 패턴 메모/{flag=1} flag' PROGRESS.md | grep -qE '\{실제 프로젝트 구조|\{예:'; then
  echo "ERROR: PROGRESS.md 코드 패턴 메모 placeholder 잔존 — 실제 값으로 치환 후 재실행"
  exit 1
fi
```

```bash
./scripts/log-activity.sh PHASE "Phase {N} 완료" || true
./scripts/notify-slack.sh "✅ Phase {N} 완료" "다음: Phase {N+1} 자동 시작" || true
```

**[방안 B] Phase 완료 커밋 — pre-bash-hook Gate 3 트리거 (필수)**

review token이 없으면 이 커밋이 Gate 3에 의해 차단된다 — review 강제 실행의 최후 방어선.

```bash
git add PROGRESS.md tasks.md
git commit -m "$(cat <<'EOF'
chore: Phase N 완료 — {요약}
EOF
)"
```

> ⚠️ **커밋 메시지 필수 패턴**: 메시지에 반드시 `Phase N 완료` (N은 정수 1 이상)를 포함해야 Gate 3가 작동한다.
> 다음 형식은 Gate 3를 **미작동**시킨다 — 사용 금지:
> - `"Phase 1 구현 완료"` (완료 앞에 숫자 없음)
> - `"Phase 1 done"` (영어)
> - `"1단계 완료"` (Phase 키워드 없음)
>
> `pre-bash-hook.sh` Gate 3: 커밋 메시지에 `Phase\s+(\d+)\s+완료` 패턴 감지 시
> `.claude/review-tokens/phase-N.token` 없으면 **커밋 차단** + 리뷰 실행 요구.
> review가 완료되어 token이 생성된 후에만 이 커밋이 허용된다.

**subagent-review 실행 경로 (Layer 2+3 이중 강제)**

> **Primary (Layer 3 — MCP 강제)**: tasks.md에 `T{N}-review` 태스크가 있으면
> Step 2 태스크 루프에서 `get_next_task`가 자동으로 반환 → Step 2-2의 `skill: subagent-review`
> 인라인 실행 절차로 처리 → 토큰 생성 → `submit_task` 통과 → Phase 완료.
> **이 경로에서는 아래 Fallback 실행 불필요** — Step 2-2가 이미 처리했음.

> **Fallback (Layer 2 — 게이트 강제)**: tasks.md에 `T{N}-review` 태스크가 **없는** 경우
> (레거시 프로젝트 또는 수동 작성 tasks.md)에만 아래를 실행한다.
> tasks.md에 `skip-review: true` 주석이 있으면 건너뛴다.

Fallback 실행 — **조건 확인 없이 무조건 실행**:

```
Grep("T{N}-review", "tasks.md 해당 Phase 섹션")
  → 존재 → Primary에서 이미 처리됨, 아래 생략
  → 없음 → 아래 인라인 실행
```

`.claude/skills/subagent-review.md`를 Read 후 Step 1~5 인라인 실행 (Step 2-2의 subagent-review 절차와 동일).

- Critical 0건 → 즉시 다음 Phase 자동 시작
- Critical 있음 → 수정 후 해당 리뷰어만 재실행, Critical 0건 확인 후 진행

PROGRESS.md 갱신 → **Phase N+1에 대해 Step 0부터 재실행** (사용자 확인 없이).

---

## Step 4: 전체 완료

모든 Phase의 모든 태스크 ☑ 완료 시:

```bash
./scripts/notify-slack.sh "🎉 전체 구현 완료" "모든 Phase 완료\n채팅창에 \"pre-launch-check 실행해줘\" 입력 권장" || true
```

PROGRESS.md 최종 상태 갱신.

### Step 4-1: 로컬 실행 안내 (⛔ 사용자 확인 대기)

Phase G/H 진행 전 반드시 아래 안내를 출력하고 **사용자 확인을 기다린다.**
(사용자가 "확인했어" / "됐어" / "테스트 완료" 등 확인 응답을 줄 때까지 Phase G/H로 넘어가지 않는다)

```
✅ 구현이 완료되었습니다! 보안 점검(Phase G)으로 넘어가기 전에
로컬에서 직접 실행해보고 주요 기능을 확인해 주세요.

──────────────────────────────────────────
🚀 실행 방법
──────────────────────────────────────────
{프로젝트 루트의 README.md 또는 backend/CLAUDE.md · frontend/CLAUDE.md에
 명시된 실행 명령을 여기에 출력. 없으면 아래 기본값 사용}

  예) 백엔드:   cd backend && uvicorn app.main:app --reload
      프론트:   cd frontend && npm run dev

──────────────────────────────────────────
✔️ 확인 체크리스트
──────────────────────────────────────────
  □ 브라우저에서 메인 화면이 정상 표시된다
  □ 로그인 / 핵심 기능 1~2개를 직접 조작해봤다
  □ 콘솔·터미널에 예상치 못한 에러가 없다

──────────────────────────────────────────
확인이 끝나면 "테스트 완료" 또는 "이상 없어" 라고 입력해 주세요.
이슈가 있으면 내용을 알려주시면 함께 수정합니다.
```

**실행 명령 자동 추출 규칙 (위 출력 전 Claude가 수행):**

**HTTPS 표준 안내 (모든 파생 프로젝트 공통):**

[boilerplate-setup Stage 1.6](../skills/boilerplate-setup.md#L350) 정책에 따라 모든 프로젝트는 Caddy 게이트키퍼 + mkcert HTTPS 셋업이 사전에 완료되어 있다. 다음 형식으로 출력한다:

```bash
# .env.example 에서 LOCAL_DEV_HOST / LOCAL_DEV_PORT 추출
LOCAL_DEV_HOST=$(grep -E '^LOCAL_DEV_HOST=' frontend/.env.example .env.example 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' | tr -d "'")
LOCAL_DEV_PORT=$(grep -E '^LOCAL_DEV_PORT=' frontend/.env.example .env.example 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' | tr -d "'")
LOCAL_BACKEND_PORT=$(grep -E '^LOCAL_BACKEND_PORT=' frontend/.env.example .env.example backend/.env.example 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' | tr -d "'")
LOCAL_DEV_HOST=${LOCAL_DEV_HOST:-localhost}
LOCAL_DEV_PORT=${LOCAL_DEV_PORT:-8010}
LOCAL_BACKEND_PORT=${LOCAL_BACKEND_PORT:-18010}
```

```
🌐 로컬 실행 안내 (HTTPS 표준 + Caddy 게이트키퍼)

🔑 호스트:    ${LOCAL_DEV_HOST}                  (.env.example 의 LOCAL_DEV_HOST)
📍 dev 포트:  ${LOCAL_DEV_PORT}                  (sudo 회피 — Caddy 가 443 처리)
🌍 접속 URL:  https://${LOCAL_DEV_HOST}          (포트 명시 없음)

프론트:   cd frontend && npm run dev              # http://localhost:${LOCAL_DEV_PORT} (평문)
백엔드:   {감지된 백엔드 명령}                     # http://localhost:${LOCAL_BACKEND_PORT}

⚠️  HTTPS 인증서·Caddy·hosts 가 셋업되지 않은 상태이면:
    ./scripts/setup-https.sh ${LOCAL_DEV_HOST} frontend
    (이 명령은 sudo 가 1~2회 필요 — mkcert 키체인 등록·hosts 등록·Caddy 데몬 시작.
     이후 dev 서버 시작에는 sudo 가 필요 없습니다.)
```

**백엔드 명령 자동 추출 (`LOCAL_BACKEND_PORT` 적용 보장):**

```bash
# 백엔드 디렉터리 존재 여부 + 스택 감지
BE_CMD=""
BE_HEALTH=""
if [ -d backend ]; then
  if [ -f backend/pyproject.toml ] || [ -f backend/requirements.txt ]; then
    if grep -qE 'fastapi|uvicorn' backend/pyproject.toml backend/requirements.txt 2>/dev/null; then
      BE_CMD="cd backend && uvicorn app.main:app --port ${LOCAL_BACKEND_PORT} --reload"
      BE_HEALTH="/health"
    elif grep -qE 'django' backend/pyproject.toml backend/requirements.txt 2>/dev/null; then
      BE_CMD="cd backend && python manage.py runserver ${LOCAL_BACKEND_PORT}"
      BE_HEALTH="/health/"
    fi
  elif [ -f backend/package.json ]; then
    if grep -qE '@nestjs/core' backend/package.json; then
      BE_CMD="cd backend && PORT=${LOCAL_BACKEND_PORT} npm run start:dev"
      BE_HEALTH="/health"
    elif grep -qE '"express"' backend/package.json; then
      BE_CMD="cd backend && PORT=${LOCAL_BACKEND_PORT} npm run dev"
      BE_HEALTH="/health"
    fi
  fi

  # 위에서 못 찾았으면 backend/CLAUDE.md / README.md 에서 추출 (사용자 정의)
  if [ -z "$BE_CMD" ]; then
    BE_CMD=$(grep -oE '`[^`]*\b(uvicorn|gunicorn|python.*manage\.py.*runserver|npm run start:dev|npm run dev)\b[^`]*`' \
      backend/CLAUDE.md backend/README.md 2>/dev/null | head -1 | tr -d '`')
  fi
fi

# 출력
if [ -n "$BE_CMD" ]; then
  echo "백엔드:   $BE_CMD"
  echo "         (health: http://localhost:${LOCAL_BACKEND_PORT}${BE_HEALTH:-/})"
elif [ -d backend ]; then
  echo "백엔드:   ⚠️ 자동 감지 실패 — backend/README.md 또는 backend/CLAUDE.md 의 dev 명령 참조"
else
  echo "백엔드:   (없음 — 프론트엔드 전용 프로젝트)"
fi
```

### Step 4-2: Phase G/H 선택 안내

사용자 확인 응답 수신 후 출력:

```
다음 단계를 선택해 주세요:

  G) 보안·품질 점검 (Phase G) — 배포 전 보안 리뷰 및 사내 보안 진단
  H) 배포 준비 (Phase H)      — 배포 체크리스트 + 실행

어느 것을 먼저 진행할까요?
```

---

## 실행 중 사용자 개입이 필요한 경우

| 상황 | 처리 |
|---|---|
| 블로커 발생 | 슬랙 알림 + 멈춤 |
| decisions.md ⬜ 발견 | 일괄 질문 후 답변 받으면 자동 재개 |
| integration-ready.md 없음 | 즉시 중단, 안내 |
| 사용자가 채팅에 "멈춰" 입력 | 현재 태스크 완료 후 중단 |
