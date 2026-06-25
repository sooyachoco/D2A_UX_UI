#!/usr/bin/env bash
# Mock 아티팩트 + Rough 타입 제거 검증 스크립트
#
# 호출 시점:
#   - tasks.md의 "Mock → 실제 백엔드 API 교체" 태스크 done: cmd
#   - Phase 2 진입 전 check_phase_gate (MCP gate 조건)
#
# 통과 조건:
#   [1] frontend/src/mocks/ 디렉터리 없음
#   [2] services/ 내 USE_MOCK/VITE_USE_MOCK 참조 없음
#   [3] 프로덕션 env 파일에 VITE_USE_MOCK=true 없음
#   [4] types/ 내 rough type placeholder([key: string]: unknown/any) 없음

set -euo pipefail

ERRORS=0
FRONTEND="${FRONTEND_SRC:-frontend/src}"

echo "────────────────────────────────────────────────"
echo " Mock 아티팩트 + Rough 타입 제거 검증"
echo "────────────────────────────────────────────────"

# 1. src/mocks 디렉터리 존재 여부
if [ -d "${FRONTEND}/mocks" ]; then
  echo "❌ [1] ${FRONTEND}/mocks/ 가 아직 존재합니다 — Mock 미제거"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ [1] mocks 디렉터리 없음"
fi

# 2. services/ 내 USE_MOCK 참조 잔존 여부
if [ -d "${FRONTEND}/services" ]; then
  MOCK_REFS=$(grep -rn "USE_MOCK\|VITE_USE_MOCK" "${FRONTEND}/services/" 2>/dev/null \
    | grep -v "^Binary" || true)
  if [ -n "$MOCK_REFS" ]; then
    echo "❌ [2] services/ 에 USE_MOCK 참조가 남아 있습니다:"
    echo "$MOCK_REFS" | head -5
    ERRORS=$((ERRORS + 1))
  else
    echo "✅ [2] services/ 에 USE_MOCK 참조 없음"
  fi
else
  echo "ℹ️  [2] ${FRONTEND}/services/ 없음 — 건너뜀"
fi

# 3. 프로덕션 env 파일에 VITE_USE_MOCK=true 잔존 여부
PROD_ERR=0
for envfile in frontend/.env frontend/.env.production frontend/.env.staging; do
  if [ -f "$envfile" ] && grep -q "VITE_USE_MOCK=true" "$envfile"; then
    echo "❌ [3] $envfile 에 VITE_USE_MOCK=true 가 남아 있습니다"
    PROD_ERR=$((PROD_ERR + 1))
  fi
done
if [ $PROD_ERR -eq 0 ]; then
  echo "✅ [3] 프로덕션 env에 VITE_USE_MOCK=true 없음"
else
  ERRORS=$((ERRORS + PROD_ERR))
fi

# 4. rough type placeholder 잔존 여부 (types/ 디렉터리)
if [ -d "${FRONTEND}/types" ]; then
  ROUGH=$(grep -rn "\[key: string\]: unknown\|\[key: string\]: any" \
    "${FRONTEND}/types/" 2>/dev/null | grep -v "^Binary" || true)
  if [ -n "$ROUGH" ]; then
    echo "❌ [4] types/ 에 rough type placeholder 가 남아 있습니다:"
    echo "$ROUGH" | head -5
    echo "   → Step 2.8 타입 확정 또는 해당 필드를 구체 타입으로 대체하세요"
    ERRORS=$((ERRORS + 1))
  else
    echo "✅ [4] types/ 에 rough placeholder 없음"
  fi
else
  echo "ℹ️  [4] ${FRONTEND}/types/ 없음 — 건너뜀"
fi

echo "────────────────────────────────────────────────"

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "⛔ $ERRORS 건의 Mock/Rough 타입 잔존이 감지되었습니다."
  echo ""
  echo "   완료 필요 태스크:"
  echo "   • T{N}: Mock → 실제 백엔드 API 교체 + Mock 코드 제거"
  echo "     - src/mocks/ 디렉터리 삭제"
  echo "     - services/ 에서 USE_MOCK 분기 제거"
  echo "     - .env.production에서 VITE_USE_MOCK 제거"
  echo "   • TypeScript 타입 확정 (create-spec Step 2.8 기준)"
  echo "     - types/ 내 [key: string]: unknown 플레이스홀더 제거"
  echo ""
  exit 1
fi

echo ""
echo "✅ 모든 검증 통과 — Phase 2 진입 가능"
exit 0
