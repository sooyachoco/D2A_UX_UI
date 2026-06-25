#!/usr/bin/env bash
# tests/lib.sh — 보일러플레이트 hook 테스트 공용 헬퍼
#
# source 해서 사용한다. 제공 항목:
#   - TPL                 : template 루트 절대경로
#   - ok/no/summary       : assertion 카운터
#   - mk_repo <dir> [phase] [status]  : 실제 hook 을 복사한 임시 git repo 생성
#   - extract_mint <out.py>           : subagent-review.md 의 *실제* mint 파이썬 추출
#   - mkjson <cmd>                    : pre-bash-hook 입력용 JSON 생성
#   - run_gate <commit-cmd>           : pre-bash-hook 구동 → GATE_RC/GATE_OUT 설정
#   - record_review_evidence          : post-agent-hook 으로 리뷰 증거 1건 기록
#
# mint/HMAC/증거 로직을 복제하지 않고 *원본 소스*(subagent-review.md, scripts/*.sh)
# 를 그대로 구동하므로, 소스가 바뀌면 테스트가 자동으로 그 변경을 반영한다.

TPL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS + 1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
summary(){
  echo ""
  echo "  ── ${1:-result}: PASS=$PASS FAIL=$FAIL"
  [ "$FAIL" -eq 0 ]
}

# 리뷰로 분류되는 Agent 호출 입력 (post-agent-hook 의 IS_REVIEW=yes 유도)
REVIEW_JSON='{"tool_input":{"description":"Security review of auth","subagent_type":"general-purpose","prompt":"Review the code"}}'

# 실제 hook 을 복사한 임시 git repo 를 만든다. cwd 는 바뀌지 않으므로
# 호출 측에서 cd "$dir" 후 사용한다.
mk_repo(){
  local d="$1" phase="${2:-1}" status="${3:-running}"
  rm -rf "$d"
  mkdir -p "$d/scripts"
  (
    cd "$d" || exit 1
    git init -q
    git config user.email t@example.com
    git config user.name tester
    cp "$TPL/scripts/post-agent-hook.sh" "$TPL/scripts/pre-bash-hook.sh" scripts/
    printf '#!/usr/bin/env bash\nexit 0\n' > scripts/log-activity.sh
    chmod +x scripts/*.sh
    mkdir -p .claude
    printf '{"phase":%s,"status":"%s"}' "$phase" "$status" > .claude/state.json
    echo init > a.txt
    git add -A
    git commit -qm "impl T1-001"
  )
}

# subagent-review.md 의 "리뷰 토큰 생성" 섹션에서 실제 mint 파이썬을 추출한다.
extract_mint(){
  python3 - "$TPL/.claude/skills/subagent-review.md" "$1" <<'PY'
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r'리뷰 토큰 생성 \(pre-bash-hook.*?```bash\n(.*?)\n```', src, re.S)
if not m:
    sys.stderr.write('mint bash 블록을 찾지 못함\n'); sys.exit(2)
block = m.group(1)
pm = re.search(r'python3 -c "\n(.*)\n"', block, re.S)
if not pm:
    sys.stderr.write('python3 -c 래퍼 추출 실패\n'); sys.exit(2)
open(sys.argv[2], 'w', encoding='utf-8').write(pm.group(1))
PY
}

# pre-bash-hook 입력 JSON 생성 (셸 인용 회피)
mkjson(){
  python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$1"
}

# cwd 의 scripts/pre-bash-hook.sh 를 주어진 commit 명령으로 구동
run_gate(){
  GATE_OUT="$(mkjson "$1" | bash scripts/pre-bash-hook.sh 2>&1)"
  GATE_RC=$?
}

# cwd 의 scripts/post-agent-hook.sh 로 리뷰 증거 1건 기록
record_review_evidence(){
  printf '%s' "$REVIEW_JSON" | bash scripts/post-agent-hook.sh > /dev/null 2>&1 || true
}
