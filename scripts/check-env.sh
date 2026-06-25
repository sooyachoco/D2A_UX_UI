#!/usr/bin/env bash
# .env.example에서 # required 주석이 달린 변수가 .env.local(또는 .env)에 설정되어 있는지 검사한다.
#
# 사용:
#   bash scripts/check-env.sh              # 기본 실행
#   bash scripts/check-env.sh --quiet      # 통과 메시지 억제 (CI용)
#
# 종료 코드:
#   0 — 모든 required 변수 설정됨
#   1 — 미설정 변수 있음 (목록 출력)
#
# .env.example 주석 컨벤션:
#   KEY=        # required  → 이 변수는 반드시 .env.local에 설정되어야 한다
#   KEY=value   # optional  → 기본값으로 동작 가능, 필요 시 덮어씌움
#   KEY=value   # (주석 없음) → 검사 대상 아님

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
QUIET="${1:-}"

ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"

# .env.example이 없으면 검사 불필요
if [ ! -f "$ENV_EXAMPLE" ]; then
  [ "$QUIET" != "--quiet" ] && echo "ℹ️  .env.example 없음 — 환경변수 검사 생략"
  exit 0
fi

# .env.local → .env 순서로 탐색
ENV_FILE=""
for candidate in \
  "${PROJECT_ROOT}/.env.local" \
  "${PROJECT_ROOT}/backend/.env.local" \
  "${PROJECT_ROOT}/.env"; do
  if [ -f "$candidate" ]; then
    ENV_FILE="$candidate"
    break
  fi
done

# .env.example에서 # required 변수 추출 (KEY= ... # required)
REQUIRED_VARS=()
while IFS= read -r line; do
  # 빈 줄·주석 줄 건너뜀
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  # KEY=...  # required  패턴
  if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=.*#[[:space:]]*required([[:space:]]|$) ]]; then
    REQUIRED_VARS+=("${BASH_REMATCH[1]}")
  fi
done < "$ENV_EXAMPLE"

if [ ${#REQUIRED_VARS[@]} -eq 0 ]; then
  [ "$QUIET" != "--quiet" ] && echo "✅ .env.example에 # required 항목 없음 — 검사 생략"
  exit 0
fi

# 각 required 변수의 값이 실제로 채워져 있는지 확인
MISSING=()
for var in "${REQUIRED_VARS[@]}"; do
  value=""

  # 1순위: 이미 export된 환경변수
  if [ -n "${!var:-}" ]; then
    value="${!var}"
  fi

  # 2순위: .env.local 파일에서 읽기 (KEY=VALUE 형식, 공백·따옴표 처리)
  if [ -z "$value" ] && [ -n "$ENV_FILE" ]; then
    raw=$(grep -E "^${var}=" "$ENV_FILE" 2>/dev/null | tail -1 || true)
    if [ -n "$raw" ]; then
      value="${raw#*=}"           # KEY= 이후 부분
      value="${value%%#*}"        # 인라인 주석 제거
      value="${value%"${value##*[! ]}"}"  # 후행 공백 제거
      # 따옴표 제거
      value="${value#\"}" && value="${value%\"}"
      value="${value#\'}" && value="${value%\'}"
    fi
  fi

  [ -z "$value" ] && MISSING+=("$var")
done

if [ ${#MISSING[@]} -eq 0 ]; then
  [ "$QUIET" != "--quiet" ] && \
    echo "✅ required 환경변수 ${#REQUIRED_VARS[@]}개 모두 설정됨 (${ENV_FILE:-환경변수 직접 주입})"
  exit 0
fi

# 미설정 변수 보고
echo "" >&2
echo "⛔ [check-env] 다음 환경변수가 설정되지 않았습니다:" >&2
echo "" >&2
for var in "${MISSING[@]}"; do
  # .env.example에서 해당 줄의 주석을 힌트로 출력
  hint=$(grep -E "^${var}=" "$ENV_EXAMPLE" | head -1 || true)
  echo "   ✗ ${var}  →  ${hint}" >&2
done
echo "" >&2
echo "   설정 방법:" >&2
if [ -n "$ENV_FILE" ]; then
  echo "   1) ${ENV_FILE} 파일을 열어 위 변수에 실제 값을 입력하세요." >&2
else
  echo "   1) 프로젝트 루트에 .env.local 파일을 생성하고 위 변수를 설정하세요." >&2
fi
echo "   2) 값 발급 방법은 prerequisites.md를 참조하세요." >&2
echo "   3) 설정 후 다시 실행: bash scripts/check-env.sh" >&2
echo "" >&2
exit 1
