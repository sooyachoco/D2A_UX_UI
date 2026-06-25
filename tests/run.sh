#!/usr/bin/env bash
# tests/run.sh — D2A 보일러플레이트 마스터 테스트 러너
#
# 변경 유형에 맞춰 티어를 선택 실행한다. 인자 없으면 전체.
#   bash tests/run.sh            # Tier 0 + 1 (+ 2 placeholder)
#   bash tests/run.sh static     # Tier 0 만 (정적/구조)
#   bash tests/run.sh hooks      # shell hook 하네스만
#   bash tests/run.sh mcp        # MCP vitest 만
#
# 종료 코드: 0 전체 통과 / 1 실패 항목 존재.
# 주의: 이 디렉터리(tests/)는 clean-fork 시 제거되어 파생 프로젝트로 출하되지 않는다.
set -u
TPL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TPL" || exit 1
RC=0
hr(){ echo ""; echo "═══ $1 ═══"; }
fail(){ echo "  ✖ $1"; RC=1; }

tier0(){
  hr "Tier 0 · 정적/구조 검사"

  echo "• bash -n (scripts/*.sh, tests/**/*.sh)"
  local f
  for f in scripts/*.sh tests/*.sh tests/hooks/*.sh; do
    [ -f "$f" ] || continue
    bash -n "$f" 2>/dev/null || fail "셸 구문 오류: $f"
  done

  echo "• python 컴파일 (scripts/*.py)"
  for f in scripts/*.py; do
    [ -f "$f" ] || continue
    python3 -m py_compile "$f" 2>/dev/null || fail "python 컴파일 오류: $f"
  done

  if command -v shellcheck > /dev/null 2>&1; then
    echo "• shellcheck (error 레벨)"
    shellcheck -S error scripts/*.sh tests/*.sh tests/hooks/*.sh 2>/dev/null || fail "shellcheck error"
  else
    echo "• shellcheck (미설치 — skip)"
  fi

  echo "• lint-claude-md.py (C1~C6: 스킬/경로/규칙번호/settings 훅/교차참조/중복)"
  if [ -f scripts/lint-claude-md.py ]; then
    python3 scripts/lint-claude-md.py > /tmp/d2a-lint.out 2>&1 || fail "lint-claude-md 위반"
    grep -E "FAIL|❌|✖" /tmp/d2a-lint.out 2>/dev/null | head -20
    rm -f /tmp/d2a-lint.out
  else
    echo "  (없음 — skip)"
  fi
}

mcp(){
  hr "Tier 1 · MCP vitest"
  if [ -d d2a-mcp-server/node_modules ]; then
    ( cd d2a-mcp-server && npm test --silent ) || fail "MCP vitest 실패"
  else
    echo "  (d2a-mcp-server/node_modules 없음 — 'cd d2a-mcp-server && npm ci' 후 재실행. skip)"
  fi
}

hooks(){
  hr "Tier 1 · shell hook 하네스"
  local t
  for t in tests/hooks/test-*.sh; do
    [ -f "$t" ] || continue
    bash "$t" || fail "hook 테스트 실패: $t"
  done
}

tier2(){
  hr "Tier 2 · 워크플로 통합 smoke"
  if ls tests/integration/*.sh > /dev/null 2>&1; then
    local t
    for t in tests/integration/*.sh; do bash "$t" || fail "integration 실패: $t"; done
  else
    echo "  ⏳ 미구현 — 고정 fixture spec/tasks → MCP 도구 직접 구동 단계(다음). 건너뜀."
  fi
}

case "${1:-all}" in
  static|tier0) tier0 ;;
  mcp) mcp ;;
  hooks) hooks ;;
  tier1) mcp; hooks ;;
  all) tier0; mcp; hooks; tier2 ;;
  *) echo "사용법: bash tests/run.sh [static|hooks|mcp|tier1|all]"; exit 2 ;;
esac

hr "결과"
if [ "$RC" -eq 0 ]; then
  echo "  ✅ 전체 통과"
else
  echo "  ❌ 실패 항목 있음 (위 ✖ 참조)"
fi
exit $RC
