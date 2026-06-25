#!/usr/bin/env bash
# scripts/post-mcp-hook.sh
# Claude Code PostToolUse hook: D2A 하네스 MCP 도구 호출 후 로그 기록
#
# 감지 도구:
#   update_state       → PHASE (running=시작, completed=완료, blocked=차단) + MCP
#   check_phase_gate   → MCP
#   get_next_task      → MCP
#   rollback_to_checkpoint → BLOCKED + MCP

set -euo pipefail

HOOK_DATA=$(cat 2>/dev/null || echo "{}")

if ! command -v python3 &>/dev/null || [ ! -f "scripts/log-activity.sh" ]; then
  exit 0
fi

# tool_name + 입력/출력 파싱
_parsed=$(echo "$HOOK_DATA" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    tool   = d.get('tool_name', '')
    inp    = d.get('tool_input', {})
    resp   = d.get('tool_response', {})
    if isinstance(resp, str):
        try: resp = json.loads(resp)
        except: resp = {}

    phase   = str(inp.get('phase', inp.get('phase_num', '')))
    status  = inp.get('status', '')
    task_id = inp.get('task_id', inp.get('current_task', ''))
    blockers = inp.get('blockers', [])
    blockers_str = '; '.join(str(b) for b in blockers) if blockers else ''
    checkpoint = inp.get('checkpoint_id', inp.get('checkpoint', ''))

    # rollback: tool_input에 reason이 있는 경우
    reason  = inp.get('reason', '')

    # gate 결과
    gate_ok = resp.get('passed', resp.get('ok', ''))

    print(f'{tool}||{phase}||{status}||{task_id}||{blockers_str}||{checkpoint}||{reason}||{gate_ok}')
except Exception:
    print('||||||||||')
" 2>/dev/null || echo "||||||||||")

TOOL_NAME=$(   echo "$_parsed" | cut -d'|' -f1  | tr -d '|')
PHASE=$(       echo "$_parsed" | cut -d'|' -f3  | tr -d '|')
STATUS=$(      echo "$_parsed" | cut -d'|' -f5  | tr -d '|')
TASK_ID=$(     echo "$_parsed" | cut -d'|' -f7  | tr -d '|')
BLOCKERS=$(    echo "$_parsed" | cut -d'|' -f9  | tr -d '|')
CHECKPOINT=$(  echo "$_parsed" | cut -d'|' -f11 | tr -d '|')
REASON=$(      echo "$_parsed" | cut -d'|' -f13 | tr -d '|')
GATE_OK=$(     echo "$_parsed" | cut -d'|' -f15 | tr -d '|')

# 도구별 처리
case "$TOOL_NAME" in

  mcp__d2a-harness__update_state)
    PHASE_LABEL="${PHASE:+Phase ${PHASE}}"

    case "$STATUS" in
      running)
        TITLE="${PHASE_LABEL:-Phase} 시작"
        DETAIL="current_task=${TASK_ID:-없음}"
        ./scripts/log-activity.sh PHASE "$TITLE" "$DETAIL" 2>/dev/null || true
        if [ -f "scripts/notify-slack.sh" ]; then
          ./scripts/notify-slack.sh "🚀 ${TITLE}" "$DETAIL" 2>/dev/null || true
        fi
        ;;
      completed)
        TITLE="${PHASE_LABEL:-Phase} 완료"
        ./scripts/log-activity.sh PHASE "$TITLE" "" 2>/dev/null || true
        if [ -f "scripts/notify-slack.sh" ]; then
          ./scripts/notify-slack.sh "🎉 ${TITLE}" "" 2>/dev/null || true
        fi
        ;;
      blocked)
        TITLE="${PHASE_LABEL:-Phase} 차단"
        DETAIL="${BLOCKERS:-차단 원인 불명}"
        ./scripts/log-activity.sh BLOCKED "$TITLE" "$DETAIL" 2>/dev/null || true
        if [ -f "scripts/notify-slack.sh" ]; then
          ./scripts/notify-slack.sh "🔴 BLOCKED: ${TITLE}" "$DETAIL" 2>/dev/null || true
        fi
        ;;
    esac

    # MCP 감사 로그 (항상)
    MCP_DETAIL="phase=${PHASE} status=${STATUS}"
    [ -n "$TASK_ID" ] && MCP_DETAIL="${MCP_DETAIL} current_task=${TASK_ID}"
    ./scripts/log-activity.sh MCP "update_state" "$MCP_DETAIL" 2>/dev/null || true
    ;;

  mcp__d2a-harness__check_phase_gate)
    GATE_RESULT="${GATE_OK:-?}"
    DETAIL="phase=${PHASE} → $([ "$GATE_RESULT" = "True" ] || [ "$GATE_RESULT" = "true" ] && echo "통과" || echo "결과=${GATE_RESULT}")"
    ./scripts/log-activity.sh MCP "check_phase_gate" "$DETAIL" 2>/dev/null || true
    ;;

  mcp__d2a-harness__get_next_task)
    DETAIL="phase=${PHASE}"
    [ -n "$TASK_ID" ] && DETAIL="${DETAIL} → next=${TASK_ID}"
    ./scripts/log-activity.sh MCP "get_next_task" "$DETAIL" 2>/dev/null || true
    ;;

  mcp__d2a-harness__rollback_to_checkpoint)
    REASON_TEXT="${REASON:-원인 미상}"
    CHECKPOINT_TEXT="${CHECKPOINT:-checkpoint 미상}"
    ./scripts/log-activity.sh BLOCKED \
      "rollback_to_checkpoint 실행" \
      "checkpoint=${CHECKPOINT_TEXT} | reason=${REASON_TEXT}" 2>/dev/null || true
    ./scripts/log-activity.sh MCP \
      "rollback_to_checkpoint" \
      "checkpoint=${CHECKPOINT_TEXT}" 2>/dev/null || true
    if [ -f "scripts/notify-slack.sh" ]; then
      ./scripts/notify-slack.sh "🔄 ROLLBACK" \
        "checkpoint=${CHECKPOINT_TEXT} | ${REASON_TEXT}" 2>/dev/null || true
    fi
    ;;

esac
