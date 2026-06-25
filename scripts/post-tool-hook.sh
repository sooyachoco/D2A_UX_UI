#!/usr/bin/env bash
# scripts/post-tool-hook.sh
# Claude Code PostToolUse hook: Write/Edit/MultiEdit 후 소스 파일 변경 로깅
# stdin으로 전달되는 JSON에서 file_path를 파싱하여 log-activity.sh 호출

set -euo pipefail

ERRORS_LOG=".claude/hook-errors.log"
_log_error() {
  mkdir -p .claude
  echo "[$(date -u +%H:%M:%S)] post-tool-hook: $*" >> "$ERRORS_LOG"
}

# stdin 전체를 읽어서 변수에 저장 (stdin은 한 번만 읽을 수 있음)
HOOK_DATA=$(cat 2>/dev/null || echo "{}")

# python3로 tool_name / file_path / 변경 유형 파싱
FP=""
TOOL_NAME="Edit"
CHANGE_TYPE="수정"
if command -v python3 &>/dev/null; then
  _parsed=$(echo "$HOOK_DATA" | python3 -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    fp = inp.get('file_path', '')
    tool = d.get('tool_name', 'Edit')
    if tool == 'Write':
        change = '신규 생성' if not os.path.exists(fp) else '전체 덮어쓰기'
    elif tool == 'MultiEdit':
        change = '다중 수정'
    else:
        change = '부분 수정'
    print(fp + '||' + tool + '||' + change)
except Exception:
    print('||Edit||수정')
" 2>/dev/null || echo "||Edit||수정")
  FP=$(echo "$_parsed" | cut -d'|' -f1 | tr -d '|')
  TOOL_NAME=$(echo "$_parsed" | cut -d'|' -f3)
  CHANGE_TYPE=$(echo "$_parsed" | cut -d'|' -f5)
fi

# 파일 경로가 없으면 종료 (문서 변경이거나 파싱 실패)
if [ -z "$FP" ]; then
  exit 0
fi

# R2: d2a-mcp-server/src/ 파일 수정 감지 → dist/ 재빌드 안내
# src를 수정하면 dist/가 stale해지므로 즉시 경고한다.
case "$FP" in
  d2a-mcp-server/src/*|*/d2a-mcp-server/src/*)
    echo "⚠️  d2a-mcp-server/src/ 파일이 수정되었습니다: ${FP}" >&2
    echo "   MCP 서버 변경을 반영하려면 반드시 빌드하세요:" >&2
    echo "   cd d2a-mcp-server && npm run build" >&2
    ;;
esac

# .env 계열 파일 수정 감지 → stderr 경고 (Claude Code가 사용자에게 표시)
case "$FP" in
  *.env|.env|.env.local|.env.production|.env.staging|.env.development)
    echo "⚠️  경고: 실제 비밀값이 포함된 .env 파일이 수정되었습니다: ${FP}" >&2
    echo "   이 파일이 .gitignore에 포함되어 있는지 확인하세요." >&2
    echo "   키 목록만 .env.example에 커밋하고, 실제 값은 절대 커밋하지 마세요." >&2
    ;;
esac

# lock·txt·자동생성 파일 로깅 생략 / .md는 tasks.md만 허용
case "$FP" in
  *.lock|*.txt|*package-lock.json|*yarn.lock|*pnpm-lock.yaml)
    exit 0
    ;;
  *.md)
    case "$FP" in
      *tasks.md) ;;   # tasks.md는 아래 체크박스 감지로 진행
      *) exit 0 ;;    # 나머지 .md 건너뜀
    esac
    ;;
esac

BASENAME="${FP##*/}"

# tasks.md 체크박스 변경 감지 → TASK 로깅 + state.json 업데이트
case "$FP" in
  *tasks.md)
    if command -v python3 &>/dev/null; then
      # ☑ 된 태스크 ID 추출 (T\d+ 패턴) → state.json 업데이트
      # TASK 카테고리 로그는 MCP submit_task 경유 시에만 기록 (CLAUDE.md 규칙 5)
      # 직접 Edit으로 체크박스를 변경한 경우 state.json만 갱신한다
      TASK_IDS=$(echo "$HOOK_DATA" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    old = inp.get('old_string', '')
    new = inp.get('new_string', '')
    if not old or not new:
        sys.exit(0)
    if '☐' in old and '☑' in new:
        for line in new.split('\n'):
            m = re.match(r'.*\*\*status\*\*.*☑.*', line) or re.search(r'☑\s*(T[\d\-]+)', line)
            if m:
                tid = re.search(r'(T[\d][\w\-]*)', line)
                if tid:
                    print(tid.group(1))
except Exception:
    pass
" 2>/dev/null || echo "")

      # state.json: 완료된 태스크 ID 기록
      if [ -n "$TASK_IDS" ] && [ -f "scripts/state-manager.sh" ]; then
        while IFS= read -r task_id; do
          [ -n "$task_id" ] && \
            { bash scripts/state-manager.sh complete-task "$task_id" 2>/dev/null || _log_error "state-manager complete-task 실패: $task_id"; }
        done <<< "$TASK_IDS"
      fi
    fi
    exit 0
    ;;
esac

# 소스 파일 변경 로깅 (도구 유형·변경 유형 포함)
if [ -f "scripts/log-activity.sh" ]; then
  ./scripts/log-activity.sh SOURCE "[${TOOL_NAME}] ${CHANGE_TYPE}: ${BASENAME}" "${FP}" 2>/dev/null || \
    _log_error "log-activity SOURCE 실패: $FP"
fi
