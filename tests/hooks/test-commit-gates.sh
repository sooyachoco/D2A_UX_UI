#!/usr/bin/env bash
# tests/hooks/test-commit-gates.sh
# pre-bash-hook 회귀 테스트 — Gate 1(force push 차단) + Gate 2(validate token).
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
. "$DIR/../lib.sh"

WORK="${TMPDIR:-/tmp}/d2a-test-commit-gates.$$"

echo "▶ commit-gates (Gate 1 force-push / Gate 2 validate-token)"
mk_repo "$WORK"
cd "$WORK" || exit 1

# ── Gate 1: git push --force 차단 ──────────────────────────────────
run_gate "git push --force origin main"
if [ "$GATE_RC" -ne 0 ] && echo "$GATE_OUT" | grep -qi "force"; then
  ok "G1 force push 차단"
else
  no "G1 force push 차단 실패 (rc=$GATE_RC)"
fi

# Gate 1 우회 (D2A_ALLOW_FORCE_PUSH=1)
GATE_OUT="$(mkjson "git push -f origin main" | D2A_ALLOW_FORCE_PUSH=1 bash scripts/pre-bash-hook.sh 2>&1)"
GATE_RC=$?
if [ "$GATE_RC" -eq 0 ]; then
  ok "G1 명시 우회(D2A_ALLOW_FORCE_PUSH=1) 통과"
else
  no "G1 우회 실패 (rc=$GATE_RC)"
fi

# ── Gate 2: running 상태 commit — validate token 요구 ──────────────
rm -f .claude/last-validate-result
run_gate 'git commit -m "chore: x"'
if [ "$GATE_RC" -ne 0 ] && echo "$GATE_OUT" | grep -q "validate_task_done"; then
  ok "G2 validate token 없이 commit 차단"
else
  no "G2 차단 실패 (rc=$GATE_RC)"
fi

# validate token 있으면 통과 + 일회용 소비
echo passed > .claude/last-validate-result
run_gate 'git commit -m "chore: x"'
if [ "$GATE_RC" -eq 0 ] && [ ! -f .claude/last-validate-result ]; then
  ok "G2 validate token 통과 후 소비(일회용)"
else
  no "G2 통과/소비 실패 (rc=$GATE_RC)"
fi

# status != running 이면 강제하지 않음
printf '{"phase":1,"status":"idle"}' > .claude/state.json
rm -f .claude/last-validate-result
run_gate 'git commit -m "chore: x"'
if [ "$GATE_RC" -eq 0 ]; then
  ok "G2 비-running 상태 일반 커밋 통과"
else
  no "G2 비-running 막힘 (rc=$GATE_RC): $GATE_OUT"
fi

cd "$DIR" > /dev/null || true
rm -rf "$WORK"
summary "commit-gates"
