#!/bin/bash
# 보일러플레이트 활동 로그에 항목을 추가한다.
#
# 사용: ./scripts/log-activity.sh <카테고리> <제목> [상세내용]
#
# 카테고리:
#   SETUP    — 프로젝트 세팅, 보일러플레이트 설치, 의존성
#   PHASE    — Phase 시작/완료
#   TASK     — 태스크 완료
#   REVIEW   — 서브에이전트 리뷰 실행/결과
#   SLACK    — 슬랙 알림 발송
#   SOURCE   — Write/Edit 도구로 소스 파일 수정 (hook 자동 기록)
#   COMMIT   — Git 커밋 생성
#   DECISION — 결정 게이트 해결
#   POLICY   — 정책 참조/갱신
#   SKILL    — 스킬 실행
#   COLLAB   — collaboration-tracker 갱신
#   BUILD    — 빌드/테스트 성공·실패
#   BLOCKED  — 차단 항목 발생·해제
#   MCP      — D2A 하네스 MCP 도구 호출 감사 로그 (check_phase_gate, create_checkpoint, validate_task_done, update_state, rollback_to_checkpoint)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/logs/boilerplate-activity.md"

# 보일러플레이트 원본 레포(.boilerplate-source 마커 존재)에서는 로그를 기록하지 않는다
if [ -f "${PROJECT_ROOT}/.boilerplate-source" ]; then
  exit 0
fi

CATEGORY="${1:-MISC}"
TITLE="${2:-}"
DETAIL="${3:-}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_HEADER=$(date '+%Y-%m-%d')

if [ -z "$TITLE" ]; then
  echo "사용법: $0 <카테고리> <제목> [상세내용]" >&2
  exit 1
fi

# 유효 카테고리 검증 (미정의 카테고리는 경고 후 MISC로 기록)
VALID_CATEGORIES="SETUP PHASE TASK REVIEW SLACK COMMIT SOURCE DECISION POLICY SKILL COLLAB BUILD BLOCKED MCP"
if ! echo " ${VALID_CATEGORIES} " | grep -q " ${CATEGORY} "; then
  echo "⚠️  log-activity: 미정의 카테고리 '${CATEGORY}' — MISC로 기록 (유효: ${VALID_CATEGORIES})" >&2
  CATEGORY="MISC"
fi

mkdir -p "$(dirname "$LOG_FILE")"

# 파일이 없거나 빈 파일이면 헤더 생성 (`: >` 초기화 직후 복구)
if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<'HEADER'
# 보일러플레이트 활동 로그

> d2a-base 보일러플레이트가 프로젝트 개발에 관여한 모든 활동을 기록합니다.
> `scripts/log-activity.sh`와 AI 에이전트 규칙(`log-boilerplate-activity.mdc`)에 의해 자동 갱신됩니다.

| 카테고리 | 설명 |
|---|---|
| SETUP | 프로젝트 세팅, 보일러플레이트 설치, 의존성 |
| PHASE | Phase 시작/완료 (update_state hook 자동 기록) |
| TASK | MCP submit_task 완료 (hook 자동 기록) |
| REVIEW | 서브에이전트 리뷰 실행/결과 (Agent hook 자동 기록) |
| SLACK | 슬랙 알림 발송 (notify-slack.sh 자동 기록) |
| COMMIT | Git 커밋 생성 (Bash hook 자동 기록) |
| SOURCE | Write/Edit 도구로 소스 파일 수정 (hook 자동 기록) |
| DECISION | 결정 게이트 해결 (AI 직접 호출) |
| POLICY | 정책 참조/갱신 (AI 직접 호출) |
| SKILL | 스킬 실행 (Skill hook 자동 기록) |
| COLLAB | collaboration-tracker 갱신 (AI 직접 호출) |
| BUILD | 빌드/테스트 성공·실패 (Bash hook 자동 기록) |
| BLOCKED | 차단 항목 발생·해제 (AI 직접 호출 또는 rollback hook) |
| MCP | D2A 하네스 MCP 도구 호출 감사 로그 (hook 자동 기록) |
| MISC | 미정의 카테고리 (자동 변환) |

---

HEADER
fi

LAST_DATE=$(grep '^## [0-9]' "$LOG_FILE" | tail -1 | sed 's/^## //' || true)

if [ "$LAST_DATE" != "$DATE_HEADER" ]; then
  echo "## ${DATE_HEADER}" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
fi

{
  echo "- \`${TIMESTAMP}\` **[${CATEGORY}]** ${TITLE}"
  if [ -n "$DETAIL" ]; then
    echo "$DETAIL" | while IFS= read -r line; do
      echo "  - ${line}"
    done
  fi
} >> "$LOG_FILE"
