#!/bin/bash
# Stop hook: Claude 응답 종료 시마다 실행
# .claude/session-stamp에 타임스탬프를 기록하여 세션 단절 감지에 활용
# 새 세션에서 AI가 이 파일을 확인해 컨텍스트 복원 필요 여부를 판단한다

mkdir -p .claude
date -u +"%Y-%m-%dT%H:%M:%SZ" > .claude/session-stamp 2>/dev/null || true

# state.json의 last_updated도 갱신 (세션 단절 감지에 활용)
[ -f scripts/state-manager.sh ] && bash scripts/state-manager.sh touch 2>/dev/null || true

# 진행상태 HTML 대시보드 갱신 (.claude/status.html — 읽기 전용 산출물)
# last_updated 갱신 직후에 호출해 최신 상태를 반영한다. best-effort.
[ -f scripts/status-html.py ] && command -v python3 &>/dev/null \
  && python3 scripts/status-html.py >/dev/null 2>&1 || true

# ── Review Gate 감지 (stdout → Claude 컨텍스트에 주입됨) ────────────────────
# Phase 실행 중이고 구현 태스크가 모두 완료됐는데 review token이 없으면 경고.
# 이 경고는 Claude의 다음 턴 컨텍스트에 자동으로 포함된다.
STATE_FILE=".claude/state.json"
if [ -f "$STATE_FILE" ] && command -v python3 &>/dev/null; then
  PHASE_NUM=$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    if d.get('status') == 'running' and int(d.get('phase', 0)) >= 1:
        print(int(d.get('phase', 0)))
except Exception:
    pass
" 2>/dev/null || echo "")

  if [ -n "$PHASE_NUM" ]; then
    REVIEW_TOKEN=".claude/review-tokens/phase-${PHASE_NUM}.token"

    # tasks.md에서 해당 Phase의 미완료 구현 태스크 수 확인 (review 제외)
    TASKS_FILE=""
    for candidate in tasks.md specs/tasks.md; do
      [ -f "$candidate" ] && TASKS_FILE="$candidate" && break
    done
    if [ -z "$TASKS_FILE" ]; then
      for candidate in specs/*/tasks.md; do
        [ -f "$candidate" ] && TASKS_FILE="$candidate" && break
      done
    fi

    INCOMPLETE_IMPL=0
    if [ -n "$TASKS_FILE" ] && command -v python3 &>/dev/null; then
      INCOMPLETE_IMPL=$(python3 -c "
import re, sys
phase = $PHASE_NUM
try:
    content = open('$TASKS_FILE').read()
    lines = content.split('\n')
    in_phase = False
    count = 0
    for i, line in enumerate(lines):
        ph = re.match(r'^##\s+Phase\s+([\d.]+)', line)
        if ph:
            cur = float(ph.group(1))
            in_phase = (cur == phase)
        if not in_phase:
            continue
        task = re.match(r'^###\s+(T\S+)\s*:', line)
        if task and 'review' not in task.group(1).lower():
            # 이 태스크의 status 확인
            for j in range(i+1, min(i+25, len(lines))):
                if re.match(r'^\*\*status\*\*', lines[j]):
                    if '☐' in lines[j]:
                        count += 1
                    break
    print(count)
except Exception:
    print(1)  # 확인 불가 시 경고 억제
" 2>/dev/null || echo "1")
    fi

    # 구현 태스크 모두 완료(0) + review token 없음 → 경고 주입
    if [ "$INCOMPLETE_IMPL" = "0" ] && [ ! -f "$REVIEW_TOKEN" ]; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "⛔ [STOP GATE] Phase ${PHASE_NUM} 구현 완료 — review token 없음"
      echo ""
      echo "  subagent-review를 지금 즉시 실행해야 합니다:"
      echo "  1. Read('.claude/skills/subagent-review.md')"
      echo "  2. Step 1~5 인라인 실행 (Agent로 서브에이전트 병렬 실행)"
      echo "  3. token 확인: .claude/review-tokens/phase-${PHASE_NUM}.token"
      echo ""
      echo "  이후 run-phase.md Step 3-1의 Phase 완료 커밋을 진행하세요."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
    fi
  fi
fi

# ── fork-clean 감지 (파생 프로젝트에서 docs/ 등이 tracked 상태로 남아있는 경우) ─
# .boilerplate-source 없음 = 파생 프로젝트. docs/·design/·PRD.md 가 tracked면 경고.
if [ ! -f ".boilerplate-source" ] && git rev-parse --git-dir &>/dev/null; then
  DIRTY_TRACKED=$(git ls-files docs/ design/ PRD.md 2>/dev/null | head -1)
  if [ -n "$DIRTY_TRACKED" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  [FORK-CLEAN] 보일러플레이트 전용 파일이 git에 추적 중입니다"
    echo ""
    echo "  원인: d2a-installer 대신 git clone으로 설치했을 가능성"
    echo "  조치: bash scripts/clean-fork.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
fi

# 미푸시 커밋 자동 push (Claude 응답 종료 시 1회)
if git rev-parse --git-dir >/dev/null 2>&1; then
  git push --quiet 2>/dev/null || true
fi

# hook-errors.log가 있으면 Claude가 볼 수 있도록 stderr에 출력 후 초기화
# Claude Code는 Stop hook의 stderr를 사용자에게 표시한다
ERRORS_LOG=".claude/hook-errors.log"
if [ -s "$ERRORS_LOG" ]; then
  echo "" >&2
  echo "┌─────────────────────────────────────────────────┐" >&2
  echo "│  ⚠️  이번 세션에서 hook 오류가 발생했습니다      │" >&2
  echo "├─────────────────────────────────────────────────┤" >&2
  while IFS= read -r line; do
    echo "│  $line" >&2
  done < "$ERRORS_LOG"
  echo "└─────────────────────────────────────────────────┘" >&2
  echo "" >&2
  > "$ERRORS_LOG"  # 표시 후 초기화
fi
