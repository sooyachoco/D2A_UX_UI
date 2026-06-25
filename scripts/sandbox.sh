#!/usr/bin/env bash
# 보일러플레이트 유지보수자 전용 — 파생 프로젝트에는 배포되지 않는다
# (clean-fork.sh / d2a-installer 가 설치 시 strip).
#
# 보일러플레이트의 *로컬 브랜치*(미push 포함)를 골라, 로컬 clone 으로 실제 파생 프로젝트
# 샌드박스를 한 번에 만든다. 원격(GitLab)이 아니라 로컬 repo 에서 clone 하므로 push 하지
# 않은 브랜치도 그대로 검증할 수 있다. (d2a-installer 채팅 흐름은 원격 기준이라 미push 불가)
#
# 사용법:
#   scripts/sandbox.sh new [브랜치]   # 로컬 브랜치 선택(또는 인자) → clone + clean-fork + 빌드 + VS Code 오픈
#   scripts/sandbox.sh ls             # 샌드박스 목록
#   scripts/sandbox.sh rm  <이름>     # 샌드박스 폐기
#
# 검증 흐름: new 가 만든 새 창에서 Claude Code 세션을 새로 열고
#   "boilerplate-setup 실행해줘" → create-spec → run-phase 로 변경 동작을 사람이 검증한다.
#
# 환경변수:
#   D2A_SANDBOX_ROOT  샌드박스 루트 (기본: ~/d2a-sandboxes)

set -euo pipefail

SANDBOX_ROOT="${D2A_SANDBOX_ROOT:-$HOME/d2a-sandboxes}"

# 이 스크립트가 속한 보일러플레이트 repo 루트 (로컬 clone 소스)
BP_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || true)"

die() { echo "❌ $*" >&2; exit 1; }

# 브랜치명 → 디렉터리 안전 slug (슬래시·공백 → 하이픈)
slugify() { printf '%s' "$1" | tr '/ ' '--' | tr -cd '[:alnum:]._-'; }

cmd_new() {
  [ -n "$BP_ROOT" ] || die "보일러플레이트 git repo 안에서 실행하세요."

  local branch="${1:-}"

  # 브랜치 미지정 → 로컬 브랜치 목록(최근 커밋순)에서 번호 선택
  if [ -z "$branch" ]; then
    echo "보일러플레이트 로컬 브랜치 (최근 커밋순):"
    local PS3="검증할 브랜치 번호 선택: " b
    select b in $(git -C "$BP_ROOT" for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads); do
      if [ -n "${b:-}" ]; then branch="$b"; break; fi
      echo "  유효한 번호를 입력하세요."
    done
  fi
  [ -n "$branch" ] || die "브랜치가 선택되지 않았습니다."

  # 로컬 브랜치 존재 검증 (원격이 아니라 로컬 기준 — 미push OK)
  git -C "$BP_ROOT" show-ref --verify --quiet "refs/heads/$branch" \
    || die "로컬 브랜치 없음: '$branch' (보일러플레이트 repo 기준). 'scripts/sandbox.sh new' 로 목록을 확인하세요."

  # 충돌 없는 샌드박스 디렉터리 (slug-NN)
  mkdir -p "$SANDBOX_ROOT"
  local label seq name dir
  label="$(slugify "$branch")"; [ -n "$label" ] || label="sandbox"
  seq=1
  while :; do
    name="${label}-$(printf '%02d' "$seq")"
    dir="$SANDBOX_ROOT/$name"
    [ -e "$dir" ] || break
    seq=$((seq + 1))
  done

  echo ""
  echo "📦 브랜치 '$branch' → 로컬 clone → $dir"
  git clone --quiet --branch "$branch" "$BP_ROOT" "$dir" || die "clone 실패: $branch"

  echo "🧹 clean-fork (template 추출 + 보일러플레이트 전용 파일 제거 + sandbox 도구 strip)..."
  ( cd "$dir" && bash template/scripts/clean-fork.sh ) || die "clean-fork 실패 — $dir 확인"

  # MCP 하네스 빌드 (best-effort — 실패해도 새 창에서 수동 가능)
  if command -v node >/dev/null 2>&1 && [ -d "$dir/d2a-mcp-server" ]; then
    echo "🔧 MCP 서버 빌드 중..."
    ( cd "$dir/d2a-mcp-server" && npm install --silent && npm run build --silent ) \
      && echo "  ✅ MCP 빌드 완료" \
      || echo "  ⚠️  MCP 빌드 실패 — 새 창에서 수동: cd d2a-mcp-server && npm install && npm run build"
  fi

  cat <<EOF

✅ 샌드박스 준비 완료: $dir   (브랜치: $branch)

   다음 단계 (실제 파생 프로젝트 개발자와 동일):
   1) 열린 VS Code 새 창에서 Claude Code 세션을 새로 시작
   2) "boilerplate-setup 실행해줘"
   3) 이후 create-spec → run-phase 로 변경 동작 검증

   폐기: scripts/sandbox.sh rm $name

EOF

  if command -v code >/dev/null 2>&1; then
    code "$dir" || true
  else
    echo "   (VS Code CLI 'code' 미설치 — 수동으로 폴더를 여세요: $dir)"
  fi
}

cmd_ls() {
  if [ ! -d "$SANDBOX_ROOT" ]; then
    echo "(샌드박스 없음: $SANDBOX_ROOT)"
    return 0
  fi
  echo "샌드박스 ($SANDBOX_ROOT):"
  local found=0 d name state
  for d in "$SANDBOX_ROOT"/*/; do
    [ -d "$d" ] || continue
    found=1
    name="$(basename "$d")"
    state="$([ -f "${d}CLAUDE.md" ] && echo '설치됨' || echo '미초기화')"
    printf "  %-30s %s\n" "$name" "$state"
  done
  [ "$found" = 1 ] || echo "  (없음)"
}

cmd_rm() {
  local label="${1:-}"
  [ -n "$label" ] || die "사용법: scripts/sandbox.sh rm <이름>"
  local dir="$SANDBOX_ROOT/$label"
  [ -d "$dir" ] || die "샌드박스 없음: $dir"
  # 안전장치: 삭제 대상이 반드시 SANDBOX_ROOT 하위인지 확인
  local root_abs dir_abs
  root_abs="$(cd "$SANDBOX_ROOT" && pwd -P)"
  dir_abs="$(cd "$dir" && pwd -P)"
  case "$dir_abs/" in
    "$root_abs/"?*) : ;;
    *) die "안전장치: '$dir' 는 샌드박스 루트 밖입니다 — 삭제 거부" ;;
  esac
  rm -rf "$dir_abs"
  echo "🗑️  폐기됨: $dir_abs"
}

case "${1:-}" in
  new) shift; cmd_new "${1:-}" ;;
  ls)  cmd_ls ;;
  rm)  shift; cmd_rm "${1:-}" ;;
  *)   echo "사용법: scripts/sandbox.sh {new [브랜치] | ls | rm <이름>}"; exit 1 ;;
esac
