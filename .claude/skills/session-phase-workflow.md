---
name: session-phase-workflow
description: tasks.md 기반 Phase 실행, 자율 실행 모드, 블로커 처리, 복귀 절차. CLAUDE.md의 enforce-task-completion·track-progress 규칙에서 참조.
---

# 세션·Phase 워크플로

tasks.md 기반 프로젝트에서 **작업 시작 → 자율 실행 → 블로커 처리 → 복귀**까지의 절차를 정의한다.

> **자율 실행 모드**: Phase 1 이후 구현 태스크는 사용자 개입 없이 연속 실행한다.
> Phase 경계에서 멈추지 않는다. 슬랙 알림으로 진행 상황을 보고한다.

---

## Part A: 작업 시작 절차

### A-1. integration-ready.md 게이트 확인

Phase 0.5가 있는 프로젝트에서 Phase 1 시작 전:

```
integration-ready.md 확인
  판정 "✅ AUTONOMOUS ZONE 진입 가능" → 진행
  파일 없음 또는 ✅ 아님 → 즉시 중단 (아래 블로커 처리)
```

**⛔ integration-ready.md가 없거나 ✅ 미통과인 경우 — Mock 우회 제안 금지**

다음 메시지를 출력하고 완전히 멈춘다. "Mock으로 대체", "나중에", "건너뛰기" 등
어떤 우회 선택지도 제시하지 않는다:

```
⛔ Phase 1 진입 불가 — integration-ready.md 미발급

prerequisites.md에 미수집 항목이 있습니다.
실제 값이 없으면 Phase 1을 시작할 수 없습니다.

다음 중 하나가 해결된 후 다시 시작하세요:
  1. collect-prerequisites 실행 → 값 수집 → integration-ready.md 발급
  2. 외부 자격증명 발급 대기 중이면 blockers.md에 기록하고 수신 후 재개

Mock 처리나 Phase 건너뛰기는 지원하지 않습니다.
```

```bash
./scripts/log-activity.sh BLOCKED "Phase 1 진입 불가" "integration-ready.md 미발급" || true
./scripts/notify-slack.sh "🔴 Phase 1 차단" "integration-ready.md 미발급 — collect-prerequisites 실행 필요" || true
```

### A-2. tasks.md 로드 + TodoWrite 등록

tasks.md를 읽고 해당 Phase의 미완료(☐) 태스크를 확인한다.
TodoWrite로 태스크 목록을 세션 내 추적 목록에 등록한다.

```bash
./scripts/log-activity.sh PHASE "Phase {N} 시작" "{태스크 수}개 태스크" || true
./scripts/notify-slack.sh "🚀 Phase {N} 시작" "{태스크 수}개 태스크" || true
```

### A-3. 태스크 스펙 파싱

`**read**` 필드 명시 파일만 로드한다. `**no-read**` 파일은 읽지 않는다. 스펙 외 파일이 필요하면 블로커로 처리한다.

---

## Part B: 자율 실행 (Autonomous Mode)

### B-1. 연속 실행 원칙

- 태스크 완료 → 즉시 다음 태스크 시작 (사용자 확인 불필요)
- Phase 경계 → 보고 후 즉시 다음 Phase 시작 (사용자 확인 불필요)
- 빌드 실패 1회 → 자체 수정 후 재시도 (사용자 확인 불필요)
- 슬랙 알림으로 모든 진행 상황 보고

### B-2. 태스크 실행 사이클

각 태스크에 대해 **read** 로드 → **write** 구현 → MCP `submit_task` 완료 제출 순으로 실행한다.
(`validate_task_done`은 `submit_task` 내부에서 자동 처리되므로 별도 호출하지 않는다.)
상세 MCP 호출·폴백·커밋 절차는 `/run-phase` Step 2 참조.

### B-3. 멈춰야 하는 경우 (예외)

자율 실행을 중단하고 사용자를 대기하는 경우:

| 상황 | 처리 |
|---|---|
| 연속 빌드 실패 2회 | Part C 블로커 처리 |
| tasks.md 스펙 누락 (read/done 없음) | Part C 블로커 처리 |
| decisions.md에 다음 Phase ⬜ 항목 존재 | decisions.md 해당 항목 일괄 질문 후 계속 |
| integration-ready.md 없이 Phase 1 시작 | 즉시 중단, collect-prerequisites 안내 |
| 컨텍스트 압박 감지 (아래 기준) | B-4 컨텍스트 핸드오프 실행 후 멈춤 |

### B-4. 컨텍스트 압박 감지 및 핸드오프

**감지 기준 (아래 중 하나라도 해당되면 핸드오프 실행):**
- 현재 태스크에서 Read한 파일 누적 합계가 500KB 이상 (대형 파일 다수 로드)
- Phase 내 완료된 태스크 수가 10개 이상이고 아직 미완료 태스크가 남아 있는 경우
- AI 자신이 응답 생성 중 "이전 내용이 기억나지 않는다" 또는 "앞서 작성한 코드를 재확인해야 한다"는 신호를 감지한 경우

**핸드오프 실행 절차:**

1. 현재 태스크를 `tasks.md`에서 ☐ 상태로 유지한다 (완료 처리하지 않음).
2. `.claude/context-handoff.md`를 생성 또는 갱신한다:

```markdown
# 컨텍스트 핸드오프

생성일: {YYYY-MM-DD HH:MM}
Phase: {N} | 태스크: {task_id}

## 현재 진행 상태
- 완료된 태스크: {완료 태스크 ID 목록}
- 중단된 태스크: {task_id} — {태스크 제목}
- 중단 위치: {파일명:줄 또는 "태스크 시작 전"}

## 중단된 태스크 컨텍스트
- read 파일: {로드했던 파일 목록}
- 완료된 작업: {구현한 내용 요약 — 1~3줄}
- 남은 작업: {아직 하지 않은 작업 — 1~3줄}
- 주의 사항: {다음 세션이 반드시 알아야 할 것}

## 핵심 인터페이스 (다음 세션 참조용)
{이번 Phase에서 작성된 주요 함수·타입·API 경로}
```

3. 슬랙 알림 발송 후 멈춤:
```bash
./scripts/log-activity.sh BLOCKED "컨텍스트 압박 핸드오프" "Phase ${N} ${task_id} 중단" || true
./scripts/notify-slack.sh "⚡ 컨텍스트 핸드오프" "새 채팅 → '이어서 해줘' 입력하면 ${task_id}부터 재개" || true
```

**새 세션 복귀 시**: Part E 절차 진입 → `.claude/context-handoff.md` 확인 → 중단된 태스크부터 재개.

---

## Part C: 블로커 처리

### C-1. 블로커 발생 시 절차

```
1. blockers.md 생성/갱신 (블로커 내용, 발생 태스크, 필요 정보)
2. tasks.md 해당 태스크를 ☐ 유지 (완료 처리하지 않음)
3. PROGRESS.md 갱신: 🔴 블로커 대기
4. 슬랙 알림
5. 멈춤 — 사용자 개입 대기
```

```bash
./scripts/log-activity.sh BLOCKED "{태스크ID} 블로커" "{블로커 내용}" || true
./scripts/notify-slack.sh "🔴 블로커: {태스크ID}" "{내용}\n해결 후 '해결됨, 계속해줘' 입력" || true
```

### C-2. blockers.md 형식

```markdown
## 블로커 목록

### {태스크ID}: {제목}
**발생일**: {YYYY-MM-DD HH:MM}
**블로커 내용**: {무엇이 없는지/무엇이 실패했는지}
**필요 정보**: {사용자가 제공해야 할 것}
**상태**: 🔴 미해결 / ✅ 해결됨
```

### C-3. 블로커 해결 후 재개

**롤백(recovery 브랜치) 생성 시 해결 방법:**

```
1. recovery/{task_id}-{timestamp} 브랜치에서 코드 수정
2. 원래 브랜치에 merge: git checkout main && git merge recovery/{task_id}-...
3. recovery 브랜치 삭제: git branch -d recovery/{task_id}-...
   → MCP get_next_task 호출 시 autoResolveBlockers가 브랜치 소멸을 감지
   → state.json.blockers에서 해당 항목 자동 제거
4. "해결됨, 계속해줘" 입력
```

**일반 블로커(외부 의존성 등) 해결 시:**

```
1. 필요 정보/자격증명을 확보
2. blockers.md 해당 항목을 ✅로 갱신
3. "해결됨, 계속해줘" 입력
```

**재개 진입점:**

사용자가 해결 입력 시 → **Part E 복귀 절차로 진입** — B-2를 직접 재시작하지 않는다.

---

## Part D: Phase 완료 처리

Phase 내 모든 태스크 ☑ 완료 후:

```bash
./scripts/log-activity.sh PHASE "Phase {N} 완료" || true
./scripts/notify-slack.sh "✅ Phase {N} 완료" "다음: Phase {N+1}" || true
```

소스 코드(`.py`/`.ts`/`.tsx`/`.js`/`.jsx`) 변경이 있으면 subagent-review를 실행한다.
`Skill("subagent-review")` 시도 → 실패 시 `.claude/skills/subagent-review.md`를 Read로 읽고 인라인 실행.
Critical 0건 확인 후 즉시 Phase N+1 시작. 상세 조건은 `/run-phase` Step 3 참조.

**subagent-review 누락 감지 (수동 실행 경로 방어)**:

Phase 완료 시 아래를 확인한다 (PROGRESS.md + 토큰 파일 기반):

```
[1단계] PROGRESS.md의 review_status 확인:
  → "Phase {N}: ✅ ..." : 정상 (run-phase T{N}-review가 처리함)
  → "Phase {N}: ⏳ pending" 또는 필드 없음: 리뷰 미완료

[2단계] 리뷰 미완료 + 소스 파일 수정 있음:
  → .claude/review-tokens/phase-{N}.token 존재 확인
     - 토큰 있음: 리뷰 완료 (PROGRESS.md만 누락), review_status 갱신 후 진행
     - 토큰 없음: subagent-review 실행
       Skill("subagent-review") 시도 → 실패 시 subagent-review.md Read 후 인라인 실행
```

decisions.md에 다음 Phase ⬜ 항목이 있으면 일괄 질문 → 답변 후 decisions.md 갱신 → 즉시 시작.

---

## Part E: 복귀 처리

**"이어서 해줘", "계속해줘", "어디까지 했어?"** 입력 시:

### E-1. 상태 파악

1. `.claude/state.json` 존재 여부 확인
   - 있으면: phase / current_task / blockers 읽기
   - 없으면: state.json 미생성 → **E-2로 이동 (run-phase 재진입)**
2. `Read("PROGRESS.md")` — 사람이 읽을 수 있는 진행 상태 확인 (state.json과 불일치 시 tasks.md 기준)
3. `Read("tasks.md")` — 미완료(☐) 태스크 확인
4. `blockers.md`가 있으면 읽고 미해결 블로커 확인
5. **직전 완료 Phase의 subagent-review 실행 여부 확인** (수동 실행 방어):

   PROGRESS.md + 토큰 파일 이중 검증 방식을 사용한다 (로그 파일 기반은 순환 실패 가능성 있음):

   ```
   [1단계] PROGRESS.md의 review_status 필드 읽기:
     → "Phase {N}: ✅ ..." : 리뷰 완료 → E-2 진행
     → "Phase {N}: ⏳ pending" 또는 필드 없음 : 리뷰 미완료 의심

   [2단계] 리뷰 미완료 의심 시 보조 검증 — 토큰 파일 존재 확인:
     → `.claude/review-tokens/phase-{N}.token` 존재하면: 리뷰 완료 (PROGRESS.md 업데이트 누락)
        → PROGRESS.md review_status를 "Phase {N}: ✅ (복구됨)" 으로 수동 갱신 후 E-2 진행
     → 파일 없고 소스 파일 수정 이력 있음: 리뷰 미완료 확정
        → run-phase 재진입 전에 먼저 subagent-review 실행
           (`Skill("subagent-review")` 시도 → 실패 시 subagent-review.md Read 후 인라인 실행)
        → 리뷰 완료(token 생성) 후 E-2 진행
     → 파일 없고 소스 변경 없음(N/A): 정상, E-2 진행
   ```

   소스 파일 수정 이력 판별:
   ```bash
   # 직전 Phase 커밋 이후 소스 파일 변경 여부 확인
   git diff --name-only HEAD~5 HEAD 2>/dev/null \
     | grep -E '\.(py|ts|tsx|js|jsx)$' | head -1
   # 결과 있으면 소스 변경 있음
   ```

### E-2. run-phase 재진입 결정

아래 조건 중 하나라도 해당하면 run-phase를 실행한다.
PROGRESS.md를 읽고 직접 구현을 시작하는 것은 **금지**이다.

**run-phase 실행 방법** (우선순위 순):
1. `Skill("run-phase", "N")` 호출 시도
2. "Unknown skill" 오류 발생 시: `.claude/skills/run-phase.md`를 Read로 읽고 각 Step 직접 실행

| 조건 | 처리 |
|---|---|
| `.claude/state.json` 없음 | Phase 번호를 PROGRESS.md에서 파악 후 run-phase 실행 |
| `state.json.current_task`가 null 또는 비어 있음 | 동일 |
| 미해결 블로커 있음 | 블로커 보고 → 사용자 해결 대기 → 해결 확인 후 아래 알림 발송 → run-phase 실행 |
| state.json 있고 current_task 정상 | E-3 복귀 보고 후 run-phase 실행 |

**state.json 신규 키 (HTTPS + 인증 셋업 — 보일러플레이트 v2 이후):**

| 키 | 의미 | 누락 시 |
|---|---|---|
| `auth_profile` | 인증 프로필 (insign / nxas / insign-with-nxas / custom / none) | Stage 1.6-A 미실행 — `boilerplate-setup 실행해줘` 재입력 |
| `local_dev_host` | 로컬 dev 호스트명 (예: `local-myproject.nxgd.io`) | Stage 1.6-B 미실행 |
| `local_dev_port` | 프론트 dev 포트 (8010+) | Stage 1.6-B 미실행 |
| `local_backend_port` | 백엔드 dev 포트 (보통 LOCAL_DEV_PORT + 10000) | Stage 1.6-B 미실행 |
| `https_ready` | Stage 1.6 완료 여부 | Stage 1.6 미실행 |
| `auth_storage_ready` | create-spec Step 2.7 통합 검증 완료 여부 (storageState 저장됨) | Step 2.7 미실행 또는 storageState 30일 만료 — `save-auth-state.sh` 재실행 |
| `auth_storage_saved_at` | storageState 저장 시각 (30일 만료 기준) | 만료 검증 시 사용 |

> 이 키들이 모두 부재한 상태로 복귀하면 "`boilerplate-setup 실행해줘`를 입력하세요"로 사용자에게 안내한다.

> **모든 복귀 경로는 run-phase 실행으로 끝난다.**
> run-phase의 Step 0-A가 state.json을 재초기화하고 MCP 게이트를 통과시킨다.

**블로커 해제 확인 후 알림 (미해결 블로커 있음 경로):**

```bash
./scripts/log-activity.sh BLOCKED "{태스크ID} 블로커 해제" "" || true
./scripts/notify-slack.sh "🟢 블로커 해제: {태스크ID}" "재개 중..." || true
```

### E-3. 복귀 보고 후 run-phase 재진입

사용자에게 현황을 보고한 뒤 즉시 `Skill("run-phase", "N")`을 호출한다.
run-phase의 Step 0-A~0-C가 state.json 재초기화, 블로커 확인, decisions.md 검토를 담당하므로
여기서 TodoWrite 재등록이나 게이트 확인을 별도로 수행하지 않는다.

```
## 복귀 완료

현재 Phase: {N} | 완료: {완료수}/{전체수} 태스크
미해결 블로커: {없음 / 있음 → 내용}
다음 태스크: {태스크ID} — {설명}

run-phase {N} 재진입 → MCP 게이트 확인 후 자율 실행 재개합니다.
```

---

## Part F: PROGRESS.md 갱신

다음 이벤트 발생 시 PROGRESS.md를 갱신한다:
- Phase 전환 (새 Phase 시작 / 완료)
- 사용자 확인 대기 (AI가 멈추고 입력을 기다릴 때)
- UI 확인 요청 (Phase 0 완료 후 브라우저 확인 요청 시)
- 구현 중단 (블로커 발생 / decisions.md 미결정 항목)
- 블로커 해결 (자율 실행 재개 전)
- 전체 완료

```markdown
## 현재 상태
**Phase**: {N} | **상태**: {🔄 진행 중 / ✅ 완료 / 🔴 블로커 대기}
**마지막 업데이트**: {YYYY-MM-DD HH:MM}

## 진행률
- Phase 0: ☑ 완료
- Phase 0.5: ☑ 완료 (integration-ready.md 발급)
- Phase 1: 🔄 {N}/{M} 태스크
```

---

## Part G: 상태 파일 안전 기록

- tasks.md 체크박스 갱신은 **Edit 도구**로 해당 줄만 수정한다: `**status**: ☐` → `**status**: ☑`. Write로 전체 재작성 금지.
- tasks.md ☑ 수와 PROGRESS.md 진행률 불일치 시: tasks.md 기준으로 PROGRESS.md 재계산
