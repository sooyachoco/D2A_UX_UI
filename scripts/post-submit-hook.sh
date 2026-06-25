#!/usr/bin/env bash
# scripts/post-submit-hook.sh
# PostToolUse hook: mcp__d2a-harness__submit_task 완료 후 실행
# submit_task 결과가 action=next + next_task_id=null(Phase 완료 예정)이면
# review token 존재 여부를 확인하고 없으면 Claude 컨텍스트에 경고를 주입한다.
#
# Claude Code PostToolUse hook: stdout → Claude 컨텍스트에 주입됨
# 2>/dev/null은 settings.json에서 사용하지 않음 (stdout이 중요)

set -euo pipefail

HOOK_DATA=$(cat 2>/dev/null || echo "{}")

# state.json에서 현재 Phase 번호 확인
STATE_FILE=".claude/state.json"
PHASE_NUM=""
if [ -f "$STATE_FILE" ] && command -v python3 &>/dev/null; then
  PHASE_NUM=$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    phase = int(d.get('phase', 0))
    if phase >= 1:
        print(phase)
except Exception:
    pass
" 2>/dev/null || echo "")
fi

[ -z "$PHASE_NUM" ] && exit 0

# submit_task 입력에서 task_id / attempt 추출, 결과에서 validation 상태 파싱
if command -v python3 &>/dev/null; then
  _submit_info=$(echo "$HOOK_DATA" | python3 -c "
import json, sys, re
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    task_id = inp.get('task_id', '')
    attempt = str(inp.get('attempt', 1))

    resp = d.get('tool_response', d.get('response', {}))
    if isinstance(resp, str):
        try: resp = json.loads(resp)
        except: resp = {}

    # validation_passed: True/False 또는 문자열
    passed = resp.get('validation_passed', resp.get('passed', None))
    if passed is True:
        result = '통과'
    elif passed is False:
        result = '재시도'
    else:
        result = '완료'

    action   = resp.get('action', '')
    next_id  = str(resp.get('next_task_id', 'UNKNOWN'))
    print(f'{task_id}||{attempt}||{result}||{action}||{next_id}')
except Exception:
    print('||1||완료||UNKNOWN||UNKNOWN')
" 2>/dev/null || echo "||1||완료||UNKNOWN||UNKNOWN")

  TASK_ID=$(echo "$_submit_info"  | cut -d'|' -f1  | tr -d '|')
  ATTEMPT=$(echo "$_submit_info"  | cut -d'|' -f3  | tr -d '|')
  TASK_RESULT=$(echo "$_submit_info" | cut -d'|' -f5  | tr -d '|')
  ACTION=$(echo "$_submit_info"   | cut -d'|' -f7  | tr -d '|')
  NEXT_TASK_ID=$(echo "$_submit_info" | cut -d'|' -f9 | tr -d '|')
else
  TASK_ID=""
  ATTEMPT="1"
  TASK_RESULT="완료"
  ACTION=""
  NEXT_TASK_ID="UNKNOWN"
fi

# tasks.md에서 태스크 제목 조회 (있으면 포함)
TASK_TITLE="$TASK_ID"
if [ -n "$TASK_ID" ] && command -v python3 &>/dev/null; then
  _title=$(python3 -c "
import re, sys
task_id = '${TASK_ID}'
for candidate in ['tasks.md', 'specs/tasks.md']:
    try:
        content = open(candidate).read()
        m = re.search(r'###\s+' + re.escape(task_id) + r'\s*:\s*(.+)', content, re.IGNORECASE)
        if m:
            print(m.group(1).strip()); sys.exit(0)
    except Exception:
        pass
print('')
" 2>/dev/null || echo "")
  [ -n "$_title" ] && TASK_TITLE="${TASK_ID}: ${_title}"
fi

# TASK 카테고리 로그 기록 (CLAUDE.md 규칙 5: MCP submit_task 경유 시에만)
if [ -n "$TASK_ID" ] && [ -f "scripts/log-activity.sh" ]; then
  ./scripts/log-activity.sh TASK "${TASK_TITLE}" \
    "Phase ${PHASE_NUM} — ${TASK_RESULT} (attempt ${ATTEMPT})" 2>/dev/null || true

  # 슬랙 알림 — SLACK_TASK_GRANULARITY 환경변수로 단위 선택:
  #   task   — 모든 태스크 완료 시 알림 (기존 동작, 노이즈 많음)
  #   phase  — Phase 시작/완료 + 재시도(attempt>1) + 실패만 알림 (기본값 — 권장)
  #   blocker — BUILD FAIL / BLOCKED 만 알림 (조용한 모드)
  #
  # .env.local 또는 셸에서 export SLACK_TASK_GRANULARITY=task 로 변경 가능.
  SLACK_GRAN="${SLACK_TASK_GRANULARITY:-phase}"

  _should_slack=false
  case "$SLACK_GRAN" in
    task)
      _should_slack=true
      ;;
    phase)
      # 재시도 또는 실패만 — 일반 성공은 Phase 시작/완료에서 알림
      if [ "$ATTEMPT" != "1" ] || [ "$TASK_RESULT" = "재시도" ]; then
        _should_slack=true
      fi
      ;;
    blocker)
      # 실패 시점만
      [ "$TASK_RESULT" = "재시도" ] && _should_slack=true
      ;;
  esac

  if [ "$_should_slack" = "true" ] && [ -f "scripts/notify-slack.sh" ]; then
    _emoji="✅"
    [ "$TASK_RESULT" = "재시도" ] && _emoji="⚠️"
    ./scripts/notify-slack.sh \
      "${_emoji} TASK ${TASK_RESULT}: ${TASK_TITLE}" \
      "Phase ${PHASE_NUM} — attempt ${ATTEMPT}" 2>/dev/null || true
  fi
fi

# action=next AND next_task_id=null 이면 Phase 내 구현 태스크가 모두 완료된 시점
# (T{N}-review 태스크가 없는 경우 또는 review 직후)
if [ "$ACTION" != "next" ] || [ "$NEXT_TASK_ID" != "null" ] && [ "$NEXT_TASK_ID" != "None" ] && [ "$NEXT_TASK_ID" != "" ] && [ "$NEXT_TASK_ID" != "UNKNOWN" ]; then
  exit 0
fi

# review token 확인
REVIEW_TOKEN=".claude/review-tokens/phase-${PHASE_NUM}.token"
if [ -f "$REVIEW_TOKEN" ]; then
  exit 0  # 토큰 있음 — 정상
fi

# token 없음 → Claude 컨텍스트에 경고 주입 (stdout)
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⛔ [REVIEW GATE] Phase ${PHASE_NUM} 구현 완료 — review token 없음

  tasks.md에 T${PHASE_NUM}-review 태스크가 없거나 아직 실행 안 됨.
  Phase ${PHASE_NUM} 완료 처리 전 즉시 subagent-review를 실행하세요:

  1. Read('.claude/skills/subagent-review.md')
  2. Step 1~5 인라인 실행 (Agent로 서브에이전트 병렬 실행)
  3. token 파일 생성 확인: .claude/review-tokens/phase-${PHASE_NUM}.token

  리뷰 없이 'chore: Phase ${PHASE_NUM} 완료' 커밋 시도 → Gate 3 차단.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
