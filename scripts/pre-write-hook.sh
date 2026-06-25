#!/usr/bin/env bash
# scripts/pre-write-hook.sh
# Claude Code PreToolUse hook: Write/Edit 실행 전 게이트 검사
# 1) Phase 실행 중(status=running) 소스 파일 수정 시 checkpoint 없으면 차단
# 2) 프로덕션·스테이징 시크릿 파일 하드 차단
# 3) 개발용 .env 경고

set -euo pipefail

HOOK_DATA=$(cat 2>/dev/null || echo "{}")
ERRORS_LOG=".claude/hook-errors.log"

_log_error() {
  mkdir -p .claude
  echo "[$(date -u +%H:%M:%S)] pre-write-hook: $*" >> "$ERRORS_LOG"
}

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

if [ -z "$FP" ]; then
  exit 0
fi

# ── 게이트 1: Phase 실행 중 checkpoint 없이 소스 파일 수정 차단 ──────────────
# 소스 파일 여부 판단 (운영 문서·설정 제외)
_is_source_file() {
  local f="$1"
  case "$f" in
    # 운영 파일 — 항상 허용
    *tasks.md|*PROGRESS.md|*blockers.md|*decisions.md|*CLAUDE.md) return 1 ;;
    *.md|*.txt) return 1 ;;
    # 소스 파일
    *.py|*.ts|*.tsx|*.js|*.jsx|*.go|*.rs|*.java|*.rb|*.php|*.swift|*.kt) return 0 ;;
    *.sh|*.bash) return 0 ;;
    *.html|*.css|*.scss|*.sass|*.less) return 0 ;;
    # 설정 파일 — 허용
    *.json|*.yaml|*.yml|*.toml|*.ini|*.conf) return 1 ;;
    *) return 1 ;;
  esac
}

STATE_FILE=".claude/state.json"
CHECKPOINT_FILE=".claude/last-checkpoint"

if _is_source_file "$FP" && command -v python3 &>/dev/null; then
  STATUS=$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    print(d.get('status', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

  if [ "$STATUS" = "running" ]; then
    if [ ! -f "$CHECKPOINT_FILE" ] || [ ! -s "$CHECKPOINT_FILE" ]; then
      echo "" >&2
      echo "╔══════════════════════════════════════════════════════════╗" >&2
      echo "║  🚫 차단: checkpoint 없이 소스 파일 수정 불가            ║" >&2
      echo "║                                                          ║" >&2
      echo "║  파일: ${FP}" >&2
      echo "║                                                          ║" >&2
      echo "║  먼저 MCP create_checkpoint를 호출하세요:                ║" >&2
      echo "║    mcp__d2a-harness__create_checkpoint({ task_id: '...' })" >&2
      echo "║                                                          ║" >&2
      echo "║  또는 Phase 실행 중이 아닌 경우 state.json을 확인하세요. ║" >&2
      echo "╚══════════════════════════════════════════════════════════╝" >&2
      echo "" >&2
      _log_error "checkpoint 없이 소스 파일 수정 시도 차단: $FP"
      exit 1
    fi
  fi
fi

# 프로덕션·스테이징 시크릿 파일 → 하드 차단 (exit 1)
# D2A_ALLOW_SECRET_WRITE=1 환경변수로 긴급 우회 가능
case "$FP" in
  *.env.production|.env.production|*.env.staging|.env.staging)
    if [ "${D2A_ALLOW_SECRET_WRITE:-0}" != "1" ]; then
      echo "" >&2
      echo "╔══════════════════════════════════════════════════════╗" >&2
      echo "║  🚫 차단: 프로덕션/스테이징 시크릿 파일 수정 금지    ║" >&2
      echo "║  파일: ${FP}" >&2
      echo "║  실제 시크릿이 포함된 파일은 직접 수정할 수 없습니다. ║" >&2
      echo "║  키 목록만 .env.example에 관리하세요.                ║" >&2
      echo "║  긴급 우회: D2A_ALLOW_SECRET_WRITE=1 설정 후 재시도 ║" >&2
      echo "╚══════════════════════════════════════════════════════╝" >&2
      echo "" >&2
      exit 1
    fi
    ;;
esac

# 개발용 .env 계열 파일 → 경고만 (차단하지 않음)
case "$FP" in
  *.env|.env|.env.local|.env.development)
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════╗" >&2
    echo "║  ⚠️  민감 파일 수정 감지: ${FP}" >&2
    echo "║  실제 시크릿 값이 포함된 파일입니다." >&2
    echo "║  .gitignore 등록 여부를 확인하세요." >&2
    echo "║  키 이름만 .env.example에 커밋하세요." >&2
    echo "╚══════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    ;;
esac

# ── 게이트: GNB --gnb-h 이중 적용 안티패턴 차단 ─────────────────────────
# var(--gnb-h) 는 .site-header 등 fixed/sticky 요소의 top 오프셋 전용.
# 페이지 요소(<main>, <section>) 또는 컨테이너의 padding-top 에 사용하면
# GNB 스크립트가 자동 주입하는 body.paddingTop 과 합산되어 헤더 높이가 두 배 적용된다.
# 우회: D2A_ALLOW_GNB_PADDING=1 (정상적인 use case 없음 — 거의 항상 안티패턴)
case "$FP" in
  *.tsx|*.ts|*.jsx|*.js|*.css|*.scss|*.sass|*.less)
    if command -v python3 &>/dev/null && [ "${D2A_ALLOW_GNB_PADDING:-0}" != "1" ]; then
      CONTENT=$(echo "$HOOK_DATA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('new_string', '') or ti.get('content', '') or ti.get('new_source', ''))
except Exception:
    pass
" 2>/dev/null || echo "")

      if [ -n "$CONTENT" ] \
         && echo "$CONTENT" | grep -qE '(padding-top|paddingTop|paddingBlockStart)[^;,]*var\(\s*--gnb-h\s*\)'; then
        echo "" >&2
        echo "╔══════════════════════════════════════════════════════════╗" >&2
        echo "║  🚫 차단: GNB --gnb-h 이중 적용 안티패턴                 ║" >&2
        echo "║                                                          ║" >&2
        echo "║  파일: ${FP}" >&2
        echo "║                                                          ║" >&2
        echo "║  --gnb-h 는 .site-header 등 fixed/sticky 요소의          ║" >&2
        echo "║  top 오프셋 전용입니다. padding-top 에 사용하면 GNB가    ║" >&2
        echo "║  자동 주입하는 body.paddingTop 과 합산되어 헤더 높이가   ║" >&2
        echo "║  두 배(≈232px)로 적용됩니다.                             ║" >&2
        echo "║                                                          ║" >&2
        echo "║  ❌ paddingTop: 'var(--gnb-h)'                           ║" >&2
        echo "║  ❌ padding-top: calc(var(--gnb-h) + var(--space-12))    ║" >&2
        echo "║  ✅ paddingTop: 'var(--space-12)'   (디자인 토큰 사용)   ║" >&2
        echo "║                                                          ║" >&2
        echo "║  세부 규칙: frontend/CLAUDE.md 'GNB 컴플라이언스'        ║" >&2
        echo "║  긴급 우회: D2A_ALLOW_GNB_PADDING=1 (정당한 use case     ║" >&2
        echo "║             거의 없음 — 사용 전 규칙 재확인 권장)        ║" >&2
        echo "╚══════════════════════════════════════════════════════════╝" >&2
        echo "" >&2
        _log_error "GNB --gnb-h 이중 적용 차단: $FP"
        exit 1
      fi
    fi
    ;;
esac

exit 0
