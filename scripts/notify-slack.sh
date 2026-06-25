#!/bin/bash
# Slack 채널로 알림을 발송한다.
# Webhook URL은 환경변수 SLACK_WEBHOOK_URL 로 주입한다 (시크릿 하드코딩 금지).
#
# 사용: SLACK_WEBHOOK_URL=... ./scripts/notify-slack.sh "제목" "본문"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TITLE="${1:-알림}"
BODY="${2:-}"

# Webhook URL은 환경변수로 주입 (시크릿 하드코딩 금지 — GitHub 푸시 보호)
WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# SLACK_NOTIFY_ENABLED=false 이면 건너뜀
if [ "${SLACK_NOTIFY_ENABLED:-}" = "false" ]; then
  "${SCRIPT_DIR}/log-activity.sh" SLACK "${TITLE}" "발송 건너뜀 (SLACK_NOTIFY_ENABLED=false)" || true
  exit 0
fi

# Webhook 미설정 시 조용히 건너뜀 (best-effort)
if [ -z "${WEBHOOK_URL}" ]; then
  "${SCRIPT_DIR}/log-activity.sh" SLACK "${TITLE}" "발송 건너뜀 (SLACK_WEBHOOK_URL 미설정)" || true
  exit 0
fi

ESCAPED_TITLE=$(echo "$TITLE" | sed 's/"/\\"/g')
ESCAPED_BODY=$(echo "$BODY" | sed 's/"/\\"/g')

PAYLOAD=$(cat <<EOF
{
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "${ESCAPED_TITLE}",
        "emoji": true
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "${ESCAPED_BODY}"
      }
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "📁 $(basename "${PROJECT_ROOT}") | $(date '+%Y-%m-%d %H:%M')"
        }
      ]
    }
  ]
}
EOF
)

# best-effort: 실패해도 빌드/Phase 전환을 차단하지 않는다
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "${WEBHOOK_URL}" \
  -H 'Content-type: application/json' \
  -d "${PAYLOAD}" \
  --max-time 5 \
  || echo "000")

"${SCRIPT_DIR}/log-activity.sh" SLACK "${TITLE}" "HTTP ${HTTP_STATUS}" || true
