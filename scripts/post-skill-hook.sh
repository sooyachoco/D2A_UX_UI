#!/usr/bin/env bash
# scripts/post-skill-hook.sh
# Claude Code PostToolUse hook: Skill 도구 실행 후 SKILL 카테고리로 자동 로깅
# stdin으로 전달되는 JSON에서 skill 이름을 파싱하여 log-activity.sh 호출

set -euo pipefail

HOOK_DATA=$(cat 2>/dev/null || echo "{}")

SKILL_NAME=""
if command -v python3 &>/dev/null; then
  SKILL_NAME=$(echo "$HOOK_DATA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    name = inp.get('skill', '')
    args = inp.get('args', '')
    if args:
        print(f'{name} {args}'.strip())
    else:
        print(name)
except Exception:
    print('')
" 2>/dev/null || echo "")
fi

if [ -z "$SKILL_NAME" ]; then
  exit 0
fi

if [ -f "scripts/log-activity.sh" ]; then
  ./scripts/log-activity.sh SKILL "${SKILL_NAME} 스킬 실행" "" 2>/dev/null || true
fi
