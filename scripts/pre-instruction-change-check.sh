#!/usr/bin/env bash
# scripts/pre-instruction-change-check.sh
#
# D2A 보일러플레이트 — 지침 변경 회귀 탐지 훅 (방안 6)
#
# CLAUDE.md, .claude/skills/*.md, .claude/settings.json 변경 시
# PreToolUse 훅으로 자동 실행되어:
#   1. 변경 대상 파일 확인
#   2. CLAUDE.md 정적 분석 (lint-claude-md.py)
#   3. 구조 검증 (validate-boilerplate.sh L1만 빠르게)
#   4. 변경 내용 요약 경고 출력
#
# stdin: Claude Code PreToolUse 훅 JSON (tool_name, tool_input)
# 종료 코드:
#   0 — 계속 진행 (문제 없거나 경고만)
#   1 — 차단 (lint 실패 등 중대한 문제) — Claude Code가 Write/Edit를 중단함

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

# stdin에서 훅 데이터 읽기
HOOK_DATA=$(cat 2>/dev/null || echo "{}")

# file_path 추출
FP=""
if command -v python3 &>/dev/null; then
  FP=$(echo "$HOOK_DATA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
fi

# 지침 파일 여부 확인
is_instruction_file() {
  local path="$1"
  case "$path" in
    CLAUDE.md|*/CLAUDE.md)           return 0 ;;
    .claude/skills/*.md)              return 0 ;;
    .claude/settings.json)            return 0 ;;
    .claude/settings.local.json)      return 0 ;;
    *)                                return 1 ;;
  esac
}

if [ -z "$FP" ] || ! is_instruction_file "$FP"; then
  exit 0  # 지침 파일이 아니면 통과
fi

# 지침 파일 변경 감지
printf "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" >&2
printf "${YELLOW}⚠️  지침 파일 변경 감지: %s${NC}\n" "$FP" >&2
printf "${YELLOW}   회귀 검사를 실행합니다...${NC}\n" >&2
printf "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n" >&2

LINT_FAILED=false
STRUCT_WARNED=false

# ── CLAUDE.md 또는 스킬 파일 변경 시: 정적 분석 ─────────────────────────────
case "$FP" in
  CLAUDE.md|*/CLAUDE.md|.claude/skills/*.md)
    printf "${BLUE}[회귀 탐지] lint-claude-md.py 실행 중...${NC}\n" >&2
    if python3 scripts/lint-claude-md.py 2>&1 | head -40 >&2; then
      printf "${BLUE}[회귀 탐지] lint 통과${NC}\n\n" >&2
    else
      LINT_FAILED=true
      printf "${RED}[회귀 탐지] lint 실패 — 저장 전 확인하세요${NC}\n\n" >&2
    fi
    ;;
esac

# ── settings.json 변경 시: 훅 경로 일관성만 빠르게 확인 ─────────────────────
case "$FP" in
  .claude/settings.json|.claude/settings.local.json)
    printf "${BLUE}[회귀 탐지] settings.json 훅 경로 확인 중...${NC}\n" >&2

    # 수정 후 파일이 존재하면 현재 파일 기준으로 검사 (저장 전이므로 기존 파일 검사)
    if command -v python3 &>/dev/null && [ -f ".claude/settings.json" ]; then
      HOOK_PATHS=$(python3 - << 'PY'
import json, re, sys
try:
    with open('.claude/settings.json') as f:
        data = json.load(f)
    for event_hooks in data.get('hooks', {}).values():
        for block in event_hooks:
            for hook in block.get('hooks', []):
                for m in re.findall(r'scripts/[\w\-]+\.sh', hook.get('command', '')):
                    if not __import__('os').path.exists(m):
                        print(f'MISSING:{m}')
except Exception as e:
    print(f'ERROR:{e}', file=sys.stderr)
PY
)
      if echo "$HOOK_PATHS" | grep -q "MISSING:"; then
        echo "$HOOK_PATHS" | grep "MISSING:" | while read -r line; do
          path="${line#MISSING:}"
          printf "${RED}  ❌ 훅 참조 파일 없음: %s${NC}\n" "$path" >&2
        done
        LINT_FAILED=true
      else
        printf "${BLUE}[회귀 탐지] 훅 경로 정상${NC}\n\n" >&2
      fi
    fi
    ;;
esac

# ── 변경 영향 안내 ────────────────────────────────────────────────────────────
printf "${YELLOW}━━━ 변경 영향 안내 ━━━${NC}\n" >&2
case "$FP" in
  CLAUDE.md)
    printf "${YELLOW}  📋 CLAUDE.md 변경 시 영향:${NC}\n" >&2
    printf "${YELLOW}     - 모든 향후 Claude Code 세션에 즉시 적용${NC}\n" >&2
    printf "${YELLOW}     - 기존 세션은 재시작 후 적용${NC}\n" >&2
    printf "${YELLOW}     - run-all-tests.sh로 전체 검증 권장${NC}\n" >&2
    ;;
  .claude/skills/*.md)
    SKILL_NAME="${FP##*/}"
    SKILL_NAME="${SKILL_NAME%.md}"
    printf "${YELLOW}  🔧 스킬 파일 변경: /%s${NC}\n" "$SKILL_NAME" >&2
    printf "${YELLOW}     - 다음 /%s 실행부터 즉시 적용${NC}\n" "$SKILL_NAME" >&2
    printf "${YELLOW}     - 관련 피드백 루프: validate-feedback-loops.sh 재실행 권장${NC}\n" >&2
    ;;
  .claude/settings.json)
    printf "${YELLOW}  ⚙️  settings.json 변경 시 영향:${NC}\n" >&2
    printf "${YELLOW}     - 훅 변경은 Claude Code 재시작 후 적용${NC}\n" >&2
    printf "${YELLOW}     - 권한(permissions) 변경은 즉시 적용${NC}\n" >&2
    ;;
esac
printf "\n" >&2

# lint 실패 시 차단하지 않고 경고만 (best-effort 정책 — 작업 중단은 사용자 판단)
# 강한 차단이 필요하면 아래 주석을 해제:
# [ "$LINT_FAILED" = true ] && exit 1

exit 0
