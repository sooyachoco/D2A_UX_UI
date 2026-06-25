#!/usr/bin/env bash
# scripts/task-checkpoint.sh
# 태스크 실행 전 현재 HEAD에 checkpoint 브랜치를 생성하여 롤백 기준점을 만든다.
# run-phase Step 2 시작 전 각 태스크마다 호출한다.
#
# 사용법:
#   ./scripts/task-checkpoint.sh <task_id>
#
# 생성 브랜치: checkpoint/{task_id}-{YYYYMMDDTHHMMSSZ}
# 기록 파일:  .claude/last-checkpoint  (가장 최근 checkpoint 브랜치명)

set -euo pipefail

TASK_ID="${1:-unknown}"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ" 2>/dev/null || date +"%Y%m%dT%H%M%SZ")
BRANCH="checkpoint/${TASK_ID}-${TIMESTAMP}"
RECORD_FILE=".claude/last-checkpoint"

# git 저장소 확인
if ! git rev-parse --git-dir &>/dev/null; then
  echo "task-checkpoint: git 저장소 아님, 건너뜀" >&2
  exit 0
fi

# HEAD가 없는 초기 상태(empty repo)이면 건너뜀
if ! git rev-parse HEAD &>/dev/null; then
  echo "task-checkpoint: 커밋 없음, 건너뜀" >&2
  exit 0
fi

# checkpoint 브랜치 생성
if git branch "$BRANCH" HEAD 2>/dev/null; then
  mkdir -p .claude
  echo "$BRANCH" > "$RECORD_FILE"
  echo "[checkpoint] 생성: $BRANCH"
else
  echo "[checkpoint] 경고: $BRANCH 브랜치 생성 실패 (이미 존재하거나 권한 없음)" >&2
fi
