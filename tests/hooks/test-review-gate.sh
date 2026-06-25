#!/usr/bin/env bash
# tests/hooks/test-review-gate.sh
# pre-bash-hook Gate 3 회귀 테스트 — 리뷰 토큰 HMAC + proof-of-work(증거) 결합.
#
# 실제 scripts/post-agent-hook.sh, scripts/pre-bash-hook.sh 와
# .claude/skills/subagent-review.md 의 *실제* mint 파이썬을 그대로 구동한다.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
. "$DIR/../lib.sh"

WORK="${TMPDIR:-/tmp}/d2a-test-review-gate.$$"
MINT="$WORK/mint_extracted.py"
DONE='git commit -m "Phase 1 완료"'
PLAIN='git commit -m "chore: tidy"'

echo "▶ review-gate (HMAC + evidence proof-of-work)"
mk_repo "$WORK"
if ! extract_mint "$MINT"; then
  no "subagent-review.md 에서 mint 추출 실패"
  rm -rf "$WORK"
  summary "review-gate"
  exit 1
fi
cd "$WORK" || exit 1
HEAD="$(git rev-parse HEAD)"

# C1 — 리뷰 스킵: 증거 없음 + inline 아님 → mint 거부
python3 "$MINT" > /dev/null 2>&1
if [ $? -ne 0 ] && [ ! -f .claude/review-tokens/phase-1.token ]; then
  ok "C1 증거 없으면 mint 거부 (사일런트 스킵 차단)"
else
  no "C1 mint 가 거부되지 않음"
fi

# C2 — inline 폴백: 명시 우회 → 레거시 토큰 + Gate 통과(경고)
D2A_ALLOW_INLINE_REVIEW=1 python3 "$MINT" > /dev/null 2>&1
if grep -q "review_mode=inline" .claude/review-tokens/phase-1.token 2>/dev/null; then
  ok "C2 inline 토큰 생성 (명시 우회)"
else
  no "C2 inline 토큰 미생성"
fi
run_gate "$DONE"
if [ "$GATE_RC" -eq 0 ] && echo "$GATE_OUT" | grep -q "증거 미결합"; then
  ok "C2 Gate 통과 + 레거시 경고 (하위호환)"
else
  no "C2 Gate 처리 실패 (rc=$GATE_RC)"
fi
rm -f .claude/review-tokens/phase-1.token .claude/last-validate-result

# C3 — 실제 리뷰: 증거 기록 → strong 토큰 → Gate ok
record_review_evidence
if [ -f .claude/review-tokens/phase-1.evidence ] && grep -q "$HEAD" .claude/review-tokens/phase-1.evidence; then
  ok "C3 증거 기록 (현재 HEAD 결합)"
else
  no "C3 증거 미기록"
fi
python3 "$MINT" > /dev/null 2>&1
if grep -q "evidence_digest=" .claude/review-tokens/phase-1.token 2>/dev/null; then
  ok "C3 strong 토큰 생성 (증거 결합)"
else
  no "C3 strong 토큰 미생성"
fi
run_gate "$DONE"
if [ "$GATE_RC" -eq 0 ]; then
  ok "C3 Gate 통과 (strong 토큰 — mint·Gate payload 일치 교차검증)"
else
  no "C3 Gate 차단됨 (rc=$GATE_RC): $GATE_OUT"
fi

# C4 — 증거 변조(라인 추가 → digest 불일치) → 차단
printf '2099-01-01T00:00:00Z\tdeadbeef\tfake\n' >> .claude/review-tokens/phase-1.evidence
run_gate "$DONE"
if [ "$GATE_RC" -ne 0 ] && echo "$GATE_OUT" | grep -q "리뷰 증거 검증 실패"; then
  ok "C4 증거 변조 감지 차단"
else
  no "C4 변조 차단 실패 (rc=$GATE_RC)"
fi

# C5 — 토큰 sig 변조 → invalid 차단 (증거/토큰 재구성)
rm -f .claude/review-tokens/phase-1.evidence .claude/review-tokens/phase-1.token
record_review_evidence
python3 "$MINT" > /dev/null 2>&1
python3 - <<'PY'
import re
p = '.claude/review-tokens/phase-1.token'
s = open(p).read()
s = re.sub(r'sig=([0-9a-f])', lambda m: 'sig=' + ('0' if m.group(1) != '0' else '1'), s, count=1)
open(p, 'w').write(s)
PY
run_gate "$DONE"
if [ "$GATE_RC" -ne 0 ] && echo "$GATE_OUT" | grep -q "서명 불일치"; then
  ok "C5 sig 변조 감지 차단"
else
  no "C5 sig 변조 차단 실패 (rc=$GATE_RC)"
fi

# C6 — 비-Phase 일반 커밋 → Gate 3 무관 통과 (Gate 2 통과용 validate token 부여)
echo passed > .claude/last-validate-result
run_gate "$PLAIN"
if [ "$GATE_RC" -eq 0 ]; then
  ok "C6 비-Phase 일반 커밋 통과 (Gate 3 무관)"
else
  no "C6 일반 커밋 막힘 (rc=$GATE_RC): $GATE_OUT"
fi

cd "$DIR" > /dev/null || true
rm -rf "$WORK"
summary "review-gate"
