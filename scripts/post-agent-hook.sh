#!/usr/bin/env bash
# scripts/post-agent-hook.sh
# Claude Code PostToolUse hook: Agent 도구 실행 후 REVIEW / SKILL 로깅
# - subagent_type 또는 description에 review 키워드 → REVIEW 카테고리
# - 그 외 Agent 호출 → SKILL 카테고리 (CLAUDE.md: Agent는 리뷰 전용)

set -euo pipefail

HOOK_DATA=$(cat 2>/dev/null || echo "{}")

if ! command -v python3 &>/dev/null; then
  exit 0
fi

# tool_input에서 description / subagent_type / prompt 첫 줄 추출
# IFS=$'\t' 로 탭만 구분자로 사용 — description 내부 공백이 fields 를 쪼개는 버그 차단
IFS=$'\t' read -r DESCRIPTION SUBAGENT_TYPE PROMPT_FIRST <<< "$(echo "$HOOK_DATA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    desc = inp.get('description', '').strip()
    stype = inp.get('subagent_type', '').strip()
    prompt_first = inp.get('prompt', '').strip().split('\n')[0][:80]
    # 탭 구분으로 한 줄 출력 — description 에 공백이 있어도 안전
    print(f'{desc}\t{stype}\t{prompt_first}')
except Exception:
    print('\t\t')
" 2>/dev/null || echo -e "\t\t")"

# 모두 비어있으면 종료
if [ -z "$DESCRIPTION" ] && [ -z "$SUBAGENT_TYPE" ] && [ -z "$PROMPT_FIRST" ]; then
  exit 0
fi

if [ ! -f "scripts/log-activity.sh" ]; then
  exit 0
fi

# REVIEW 판별: subagent_type / description / prompt 첫 줄에 리뷰 관련 키워드
# - subagent-review.md 의 6명 리뷰어가 일관되지 않은 description/subagent_type 으로 호출되어도
#   모두 REVIEW 카테고리로 통일되도록 6명 영역 이름을 키워드에 포함.
IS_REVIEW=$(echo "${SUBAGENT_TYPE} ${DESCRIPTION} ${PROMPT_FIRST}" | python3 -c "
import sys
text = sys.stdin.read().lower()
keywords = [
    'review', '리뷰', 'code-reviewer', 'code_reviewer', 'subagent-review',
    # subagent-review.md 의 6명 리뷰어 영역 이름 (description 단독 호출 방어)
    'security review', 'performance review', 'architecture review',
    'accessibility review', 'spec fidelity', 'feature behavior',
    # subagent_type 으로 영역 이름만 들어오는 경우 (security/performance/...)
    # — 단독 키워드는 false positive 위험이 있어 'review' 와 함께 쓸 때만 매칭
]
print('yes' if any(k in text for k in keywords) else 'no')
" 2>/dev/null || echo "no")

LABEL="${DESCRIPTION:-${PROMPT_FIRST:-서브에이전트 실행}}"
TYPE_TAG=""
[ -n "$SUBAGENT_TYPE" ] && TYPE_TAG=" [${SUBAGENT_TYPE}]"

if [ "$IS_REVIEW" = "yes" ]; then
  # REVIEW: 리뷰 시작 기록 (완료 후 상세 결과는 AI가 REVIEW 카테고리로 직접 기록)
  ./scripts/log-activity.sh REVIEW "서브에이전트 리뷰 시작: ${LABEL}" "subagent_type=${SUBAGENT_TYPE:-general-purpose}" 2>/dev/null || true

  # ── 리뷰 증거 기록 (proof-of-work 결합용) ─────────────────────────────────
  # state.json phase + 현재 HEAD + 라벨을 append-only 로 .claude/review-tokens/
  # phase-N.evidence 에 기록한다. 이 hook 은 하네스가 Agent 도구를 *실제로 호출*
  # 했을 때만 발화하므로, 에이전트의 서술/날조로는 만들 수 없는 "리뷰 fan-out 실행"
  # 의 관측 증거가 된다. subagent-review 의 토큰 mint 와 pre-bash-hook Gate 3 가
  # 이 파일을 현재 commit 에 결합하여, "리뷰 토큰만 발급하고 리뷰는 건너뛰는"
  # 사일런트 우회를 차단한다. (라벨은 환경변수로 전달해 셸 인젝션을 피한다.)
  D2A_EV_LABEL="$LABEL" python3 -c "
import json, os, subprocess, datetime, sys
try:
    with open('.claude/state.json') as f:
        d = json.load(f)
    phase = int(d.get('phase', 0))
    if phase < 1:
        sys.exit(0)  # 정수 Phase(1+) 가 아니면 토큰/증거 대상 아님
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True,
                                   stderr=subprocess.DEVNULL).strip()
    ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    label = os.environ.get('D2A_EV_LABEL', '')[:80].replace('\t', ' ').replace('\n', ' ')
    os.makedirs('.claude/review-tokens', exist_ok=True)
    with open(f'.claude/review-tokens/phase-{phase}.evidence', 'a') as ef:
        ef.write(f'{ts}\t{head}\t{label}\n')
except Exception:
    pass  # 증거 기록 실패가 리뷰 흐름을 막지 않는다 (best-effort)
" 2>/dev/null || true
else
  # CLAUDE.md 규칙: Agent는 /subagent-review 전용 — 그 외 호출은 SKILL로 기록
  ./scripts/log-activity.sh SKILL "서브에이전트 실행: ${LABEL}${TYPE_TAG}" "" 2>/dev/null || true
fi
