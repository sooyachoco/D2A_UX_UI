#!/usr/bin/env bash
# scripts/task-rollback.sh
# 태스크 실패 시 해당 태스크의 checkpoint 브랜치로 HEAD를 복원한다.
# run-phase Step 2-5 (실패 2회) 에서 호출한다.
#
# 사용법:
#   ./scripts/task-rollback.sh <task_id>
#
# 동작:
#   1. checkpoint/{task_id}-* 브랜치 중 가장 최신 것을 찾는다
#   2. git reset --hard <checkpoint> 로 복원
#   3. state.json status → "blocked" 기록
#   4. .claude/last-checkpoint 파일 삭제

set -euo pipefail

TASK_ID="${1:-}"

if [ -z "$TASK_ID" ]; then
  echo "사용법: $0 <task_id>" >&2
  exit 1
fi

# git 저장소 확인
if ! git rev-parse --git-dir &>/dev/null; then
  echo "task-rollback: git 저장소 아님" >&2
  exit 1
fi

# checkpoint/{task_id}-* 브랜치 중 최신 것 탐색
CHECKPOINT_BRANCH=$(git branch --list "checkpoint/${TASK_ID}-*" 2>/dev/null \
  | sed 's/^[* ]*//' \
  | sort \
  | tail -1)

if [ -z "$CHECKPOINT_BRANCH" ]; then
  # .claude/last-checkpoint 에서 fallback
  if [ -f ".claude/last-checkpoint" ]; then
    CHECKPOINT_BRANCH=$(cat .claude/last-checkpoint)
    echo "[rollback] last-checkpoint fallback 사용: $CHECKPOINT_BRANCH" >&2
  else
    echo "[rollback] 오류: checkpoint/${TASK_ID}-* 브랜치를 찾을 수 없습니다." >&2
    echo "  checkpoint가 생성되지 않았거나 이미 삭제되었습니다." >&2
    exit 1
  fi
fi

# 현재 브랜치 확인 (checkpoint 브랜치에 있으면 복원 불필요)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")
if [ "$CURRENT_BRANCH" = "$CHECKPOINT_BRANCH" ]; then
  echo "[rollback] 이미 checkpoint 브랜치에 있습니다: $CHECKPOINT_BRANCH"
  exit 0
fi

# 미커밋 변경사항 경고
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  echo "[rollback] 경고: 미커밋 변경사항이 있습니다. reset --hard 시 손실됩니다." >&2
fi

# reset --hard 로 checkpoint HEAD로 복원
git reset --hard "$CHECKPOINT_BRANCH"
echo "[rollback] 복원 완료: $CHECKPOINT_BRANCH (HEAD → $(git rev-parse --short HEAD))"

# state.json 업데이트
[ -f "scripts/state-manager.sh" ] && \
  bash scripts/state-manager.sh add-blocker "$TASK_ID" "rollback 실행됨" 2>/dev/null || true

# last-checkpoint 삭제
rm -f ".claude/last-checkpoint"

echo "[rollback] 완료 — 블로커 처리 후 '해결됨, 계속해줘'로 재개하세요."
