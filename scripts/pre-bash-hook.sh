#!/usr/bin/env bash
# scripts/pre-bash-hook.sh
# Claude Code PreToolUse hook: Bash 도구 실행 전 위험 명령 차단
# - git push --force / -f → 항상 차단 (D2A_ALLOW_FORCE_PUSH=1 으로 긴급 우회)
# - git commit (Phase N 완료) → review token 없이 차단 (D2A_ALLOW_REVIEW_SKIP=1 으로 긴급 우회)
# - git commit → validate token 없이 차단 (D2A_ALLOW_COMMIT=1 으로 긴급 우회)
# stdin으로 전달되는 JSON에서 command를 파싱하여 판단

set -euo pipefail

HOOK_DATA=$(cat 2>/dev/null || echo "{}")
ERRORS_LOG=".claude/hook-errors.log"
VALIDATE_TOKEN=".claude/last-validate-result"

_log_error() {
  mkdir -p .claude
  echo "[$(date -u +%H:%M:%S)] pre-bash-hook: $*" >> "$ERRORS_LOG"
}

COMMAND=""
if command -v python3 &>/dev/null; then
  COMMAND=$(echo "$HOOK_DATA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
fi

if [ -z "$COMMAND" ]; then
  exit 0
fi

# ── 게이트 1: git push --force 차단 ─────────────────────────────────────────
FORCE_PUSH=$(echo "$COMMAND" | python3 -c "
import sys, re
cmd = sys.stdin.read()
if re.search(r'git\s+push\b.*\s(--force|-f\b|--force-with-lease)', cmd):
    print('yes')
else:
    print('no')
" 2>/dev/null || echo "no")

if [ "$FORCE_PUSH" = "yes" ] && [ "${D2A_ALLOW_FORCE_PUSH:-0}" != "1" ]; then
  echo "" >&2
  echo "╔══════════════════════════════════════════════════════╗" >&2
  echo "║  🚫 차단: git push --force 는 허용되지 않습니다.     ║" >&2
  echo "║  공유 히스토리를 파괴할 수 있는 명령입니다.           ║" >&2
  echo "║  정말 필요하다면:                                    ║" >&2
  echo "║    export D2A_ALLOW_FORCE_PUSH=1                    ║" >&2
  echo "║  위 명령 실행 후 다시 시도하세요.                     ║" >&2
  echo "╚══════════════════════════════════════════════════════╝" >&2
  echo "" >&2
  _log_error "git push --force 차단"
  exit 1
fi

# ── 게이트 3: "Phase N 완료" 커밋 — 서브에이전트 리뷰 토큰 확인 ───────────────
# 정수 Phase(1 이상) 완료 커밋에만 적용. Phase 0.5 등 소수점 Phase는 제외.
# 리뷰 토큰 확인됨 → validate token도 함께 기록(Gate 2 자동 통과).
# 우회: export D2A_ALLOW_REVIEW_SKIP=1
#
# [HEREDOC 파싱 수정] AI는 HEREDOC 형식으로 커밋하므로 따옴표 추출 대신
# 전체 명령 문자열에서 직접 패턴을 검색한다.
# - HEREDOC: 메시지 내용이 cmd 문자열에 줄바꿈으로 포함됨 → 직접 검색 가능
# - 일반 따옴표: -m "Phase N 완료" 형식도 cmd에 포함되므로 동일하게 동작
PHASE_NUM=$(echo "$COMMAND" | python3 -c "
import sys, re
cmd = sys.stdin.read()
if not re.search(r'\bgit\s+commit\b', cmd):
    sys.exit(0)
# HEREDOC(\$(cat <<...)) 및 일반 따옴표 형식 모두 처리:
# 전체 명령 문자열에서 직접 검색 (두 형식 모두 'Phase N 완료'가 cmd에 포함됨)
pm = re.search(r'Phase\s+(\d+)\s+완료', cmd)
if pm and int(pm.group(1)) >= 1:
    print(pm.group(1))
" 2>/dev/null || echo "")

if [ -n "$PHASE_NUM" ] && [ "${D2A_ALLOW_REVIEW_SKIP:-0}" != "1" ]; then
  REVIEW_TOKEN=".claude/review-tokens/phase-${PHASE_NUM}.token"
  if [ ! -f "$REVIEW_TOKEN" ]; then
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════╗" >&2
    echo "║  🚫 차단: Phase ${PHASE_NUM} 완료 커밋 — 리뷰 토큰 없음             ║" >&2
    echo "║                                                          ║" >&2
    echo "║  Phase 완료 전 서브에이전트 리뷰가 필수입니다.           ║" >&2
    echo "║  실행: subagent-review                                   ║" >&2
    echo "║                                                          ║" >&2
    echo "║  리뷰 완료 시 토큰이 자동 생성되어 커밋이 허용됩니다.    ║" >&2
    echo "║  토큰 경로: .claude/review-tokens/phase-${PHASE_NUM}.token       ║" >&2
    echo "║                                                          ║" >&2
    echo "║  긴급 우회: export D2A_ALLOW_REVIEW_SKIP=1              ║" >&2
    echo "╚══════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    _log_error "Phase ${PHASE_NUM} review token 없이 Phase 완료 커밋 차단"
    exit 1
  fi

  # ── HMAC 서명 + 리뷰 증거 검증 (토큰 위조·리뷰 스킵 방지) ─────────────────────
  # .claude/review-token-secret 이 없으면 검증을 건너뛴다 (CI/구버전 토큰 호환).
  # 시크릿이 있으면 토큰 sig 를 재계산하고, evidence_digest 가 있는 강한 토큰은
  # phase-N.evidence 의 digest 일치 + 현재 commit 결합 dispatch 증거까지 검증한다.
  # 출력 형식: '<status>|<detail>' — status ∈ {ok, skip, legacy, invalid, evidence_fail}
  HMAC_OUT=$(python3 -c "
import sys, os, hmac, hashlib

secret_path = '.claude/review-token-secret'
token_path = '$REVIEW_TOKEN'

def out(s, d=''):
    print(f'{s}|{d}')

try:
    with open(secret_path) as sf:
        secret = sf.read().strip()
except FileNotFoundError:
    out('skip'); sys.exit(0)  # 시크릿 없음 — CI/레거시, 검증 생략

token_data = {}
try:
    with open(token_path) as tf:
        for line in tf:
            if '=' in line:
                k, v = line.strip().split('=', 1)
                token_data[k] = v
except Exception:
    out('skip'); sys.exit(0)

phase = token_data.get('phase', '')
commit = token_data.get('commit', '')
timestamp = token_data.get('timestamp', '')
stored_sig = token_data.get('sig', '')
ev_count = token_data.get('evidence_count', '')
ev_digest = token_data.get('evidence_digest', '')

if not stored_sig:
    out('skip'); sys.exit(0)  # sig 없음 — 구버전 토큰

has_evidence = bool(ev_digest)
if has_evidence:
    payload = f'{phase}:{commit}:{timestamp}:{ev_count}:{ev_digest}'
else:
    payload = f'{phase}:{commit}:{timestamp}'

expected = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
if not hmac.compare_digest(expected, stored_sig):
    out('invalid'); sys.exit(0)

if not has_evidence:
    # 서명 OK 이나 증거 미결합 (inline/구버전) — 통과시키되 상위에서 경고
    out('legacy', token_data.get('review_mode', '')); sys.exit(0)

# 강한 토큰: 증거 파일 digest 일치 + 현재 commit 결합 dispatch 검증
ev_path = f'.claude/review-tokens/phase-{phase}.evidence'
if not os.path.exists(ev_path):
    out('evidence_fail', 'evidence 파일 없음'); sys.exit(0)
with open(ev_path, 'rb') as ef:
    raw = ef.read()
if hashlib.sha256(raw).hexdigest() != ev_digest:
    out('evidence_fail', 'evidence digest 불일치(추가/변조)'); sys.exit(0)
bound = sum(1 for ln in raw.decode('utf-8', 'replace').splitlines()
            if len(ln.split('\t')) >= 2 and ln.split('\t')[1].strip() == commit)
if bound < 1:
    out('evidence_fail', f'commit {commit[:7]} 결합 리뷰 증거 0건'); sys.exit(0)

out('ok', f'evidence={ev_count}, bound={bound}')
" 2>/dev/null || echo "skip|")

  HMAC_RESULT="${HMAC_OUT%%|*}"
  HMAC_DETAIL="${HMAC_OUT#*|}"

  if [ "$HMAC_RESULT" = "invalid" ]; then
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════╗" >&2
    echo "║  🚫 차단: Phase ${PHASE_NUM} 리뷰 토큰 서명 불일치               ║" >&2
    echo "║                                                          ║" >&2
    echo "║  토큰 파일이 위조되었거나 수동으로 복사된 것으로          ║" >&2
    echo "║  판단됩니다. subagent-review 를 재실행하세요.             ║" >&2
    echo "║                                                          ║" >&2
    echo "║  긴급 우회: export D2A_ALLOW_REVIEW_SKIP=1              ║" >&2
    echo "╚══════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    _log_error "Phase ${PHASE_NUM} review token HMAC 서명 불일치 — 커밋 차단"
    exit 1
  fi

  if [ "$HMAC_RESULT" = "evidence_fail" ]; then
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════╗" >&2
    echo "║  🚫 차단: Phase ${PHASE_NUM} 리뷰 증거 검증 실패                 ║" >&2
    echo "║                                                          ║" >&2
    echo "║  토큰 서명은 유효하나, 현재 코드에 결합된 리뷰 실행       ║" >&2
    echo "║  증거가 없습니다. ($HMAC_DETAIL)" >&2
    echo "║  → 리뷰 토큰만 발급하고 리뷰는 건너뛴 것으로 판단됩니다.  ║" >&2
    echo "║  subagent-review 리뷰어를 Agent 도구로 재실행하세요.     ║" >&2
    echo "║                                                          ║" >&2
    echo "║  긴급 우회: export D2A_ALLOW_REVIEW_SKIP=1              ║" >&2
    echo "╚══════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    _log_error "Phase ${PHASE_NUM} 리뷰 증거 검증 실패($HMAC_DETAIL) — 커밋 차단"
    exit 1
  fi

  if [ "$HMAC_RESULT" = "legacy" ]; then
    # 증거 미결합(inline/구버전) 토큰 — 통과시키되 경고를 남긴다 (하위호환)
    echo "ℹ️  Phase ${PHASE_NUM} 리뷰 토큰: 증거 미결합(${HMAC_DETAIL:-legacy}) — Agent fan-out 리뷰 권장" >&2
    _log_error "Phase ${PHASE_NUM} 리뷰 토큰 증거 미결합(${HMAC_DETAIL:-legacy}) — 통과(경고)"
  fi

  # 리뷰 토큰 확인됨 — Phase 완료 PROGRESS.md 커밋은 MCP submit_task 없이도 허용
  # validate token을 기록하여 Gate 2를 통과시킨다
  mkdir -p "$(dirname "$VALIDATE_TOKEN")"
  echo "passed" > "$VALIDATE_TOKEN"
fi

# ── 게이트 2: git commit — validate token 확인 ───────────────────────────────
# Phase 실행 중(state.json status=running)에만 강제. 일반 커밋은 통과.
IS_COMMIT=$(echo "$COMMAND" | python3 -c "
import sys, re
cmd = sys.stdin.read()
# 'git commit' 이 포함된 명령 감지 (--amend 포함)
if re.search(r'\bgit\s+commit\b', cmd):
    print('yes')
else:
    print('no')
" 2>/dev/null || echo "no")

if [ "$IS_COMMIT" = "yes" ] && [ "${D2A_ALLOW_COMMIT:-0}" != "1" ]; then
  STATE_FILE=".claude/state.json"
  STATUS=""
  if [ -f "$STATE_FILE" ] && command -v python3 &>/dev/null; then
    STATUS=$(python3 -c "
import json
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    print(d.get('status', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
  fi

  # Phase 실행 중일 때만 validate token 요구
  if [ "$STATUS" = "running" ]; then
    if [ ! -f "$VALIDATE_TOKEN" ] || [ "$(cat "$VALIDATE_TOKEN" 2>/dev/null)" != "passed" ]; then
      echo "" >&2
      echo "╔══════════════════════════════════════════════════════════╗" >&2
      echo "║  🚫 차단: validate_task_done passed:true 없이 커밋 불가  ║" >&2
      echo "║                                                          ║" >&2
      echo "║  먼저 MCP submit_task 또는 validate_task_done를 호출하세요." >&2
      echo "║  통과 후 자동으로 커밋이 허용됩니다.                     ║" >&2
      echo "║                                                          ║" >&2
      echo "║  긴급 우회: export D2A_ALLOW_COMMIT=1                   ║" >&2
      echo "╚══════════════════════════════════════════════════════════╝" >&2
      echo "" >&2
      _log_error "validate token 없이 git commit 시도 차단"
      exit 1
    fi
    # 일회용 토큰 소비 — 다음 커밋에서 재검증 필요
    rm -f "$VALIDATE_TOKEN"
  fi
fi

exit 0
