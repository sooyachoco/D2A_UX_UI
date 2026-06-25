#!/usr/bin/env bash
# git clone으로 보일러플레이트를 받은 경우 template/ 내용을 루트로 추출하고
# 보일러플레이트 전용 파일을 제거합니다.
#
# 사용법: bash template/scripts/clean-fork.sh
#        (반드시 레포 루트에서 실행)

set -e

# ── 실행 위치 확인 ────────────────────────────────────────────────────────────
if ! git rev-parse --git-dir &>/dev/null; then
  echo "❌ git 저장소가 아닙니다."
  exit 1
fi

# ── template/ 존재 확인 ───────────────────────────────────────────────────────
if [ ! -d "template" ]; then
  echo "❌ template/ 디렉토리가 없습니다."
  echo "   이미 초기화되었거나, d2a-installer를 통해 설치된 경우입니다."
  echo "   → 'boilerplate-setup 실행해줘' 로 프로젝트 세팅을 시작하세요."
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  D2A 보일러플레이트 초기화 (git clone 경로)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 1. template/ 내용을 루트로 복사 (기존 파일 덮어쓰지 않음) ────────────────
echo "  [1/4] template/ 내용 추출 중..."
# macOS BSD cp 는 -n(no-clobber)로 기존 파일(.gitignore 등)을 스킵하면 비0 종료한다 (GNU cp 는 0).
# set -e 와 충돌해 중단되므로 || true 로 흡수하고, 실제 추출 성공은 아래 sentinel 로 검증한다.
cp -Rn template/. . || true
if [ ! -f "CLAUDE.md" ] || [ ! -d ".claude/skills" ]; then
  echo "  ❌ 추출 실패 — CLAUDE.md / .claude/skills 가 복사되지 않았습니다"
  exit 1
fi
echo "  ✅ 추출 완료"

# ── 2. 보일러플레이트 전용 디렉토리·파일 제거 ────────────────────────────────
echo ""
echo "  [2/4] 보일러플레이트 전용 파일 제거 중..."

REMOVE_DIRS=("template" "tests")
# 유지보수자 전용 파일은 파생 프로젝트에 배포하지 않는다 (sandbox 도구는 보일러플레이트 repo 전용)
REMOVE_FILES=("README.md" ".gitlab-ci.yml" "MIGRATION.md" "d2a.code-workspace" "scripts/sandbox.sh" ".claude/skills/sandbox.md")

for d in "${REMOVE_DIRS[@]}"; do
  if [ -n "$(git ls-files "$d")" ]; then
    git rm -rf "$d" --quiet 2>/dev/null || true
  fi
  rm -rf "$d" 2>/dev/null || true
  echo "  ✅ $d/ 제거"
done

for f in "${REMOVE_FILES[@]}"; do
  if git ls-files --error-unmatch "$f" &>/dev/null 2>&1; then
    git rm -f "$f" --quiet 2>/dev/null || true
  fi
  rm -f "$f" 2>/dev/null || true
  echo "  ✅ $f 제거"
done

# ── 3. 활동 로그 초기화 (헤더 포함 즉시 생성) ───────────────────────────────
echo ""
echo "  [3/4] 활동 로그 초기화..."
mkdir -p logs
cat > logs/boilerplate-activity.md << 'LOG_HEADER'
# 보일러플레이트 활동 로그

> d2a-base 보일러플레이트가 프로젝트 개발에 관여한 모든 활동을 기록합니다.
> `scripts/log-activity.sh`와 AI 에이전트 규칙에 의해 자동 갱신됩니다.

| 카테고리 | 설명 | 기록 방식 |
|---|---|---|
| SETUP    | 프로젝트 세팅, 보일러플레이트 설치, 의존성 | AI 직접 호출 |
| PHASE    | Phase 시작/완료 | update_state hook 자동 |
| TASK     | MCP submit_task 완료 | submit_task hook 자동 |
| REVIEW   | 서브에이전트 리뷰 시작/완료 | Agent hook 자동 + AI 완료 기록 |
| SLACK    | 슬랙 알림 발송 | notify-slack.sh 자동 |
| COMMIT   | Git 커밋 생성 (해시·변경 파일 통계 포함) | Bash hook 자동 |
| SOURCE   | 소스 파일 수정 (도구 유형·변경 유형 포함) | Write/Edit hook 자동 |
| DECISION | decisions.md 항목 결정 | AI 직접 호출 필수 |
| POLICY   | 정책 파일 참조/갱신 | AI 직접 호출 필수 |
| SKILL    | 스킬 및 서브에이전트 실행 | Skill/Agent hook 자동 |
| COLLAB   | collaboration-tracker 갱신 | AI 직접 호출 필수 |
| BUILD    | 빌드/테스트 성공·실패 (통과 수·소요 시간 포함) | Bash hook 자동 |
| BLOCKED  | 차단 항목 발생·해제 | rollback hook + AI 직접 호출 필수 |
| MCP      | D2A 하네스 MCP 도구 호출 감사 로그 | post-mcp-hook 자동 |

---

LOG_HEADER
echo "  ✅ logs/boilerplate-activity.md 초기화 (헤더 포함)"

# ── 3-B. 첫 SETUP entry — 보일러플레이트 설치 기록 ────────────────────────────
# 활동 로그가 의미 있는 SETUP entry로 시작되도록 (이전: 첫 entry가 COMMIT 이라 추적 어려움).
# 이 entry 가 있어야 다음 세션에서 "어떤 보일러플레이트 버전으로 초기화됐는지" 즉시 파악 가능.
if [ -f scripts/log-activity.sh ]; then
  BP_COMMIT=$(git log -1 --format='%h' 2>/dev/null || echo "unknown")
  BP_DATE=$(git log -1 --format='%ai' 2>/dev/null | cut -d' ' -f1 || echo "unknown")
  HOST_INFO="$(uname -s) $(uname -r 2>/dev/null || echo '')"
  bash scripts/log-activity.sh SETUP \
    "d2a-boilerplate-claude 초기 설치 (clone 경로)" \
    "template commit=${BP_COMMIT} (${BP_DATE}) | host=${HOST_INFO}" 2>/dev/null || true
fi

# ── 4. 새 파일 스테이징 및 커밋 ──────────────────────────────────────────────
echo ""
echo "  [4/4] 커밋 중..."
git add .
git commit -m "chore: 보일러플레이트 초기화 (template 추출)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ 초기화 완료"
echo ""
echo "  다음 단계:"
echo "  1. MCP 서버 빌드:"
echo "     cd d2a-mcp-server && npm install && npm run build && cd .."
echo "  2. 새 채팅창에서 'boilerplate-setup 실행해줘' 입력"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
