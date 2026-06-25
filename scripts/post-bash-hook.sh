#!/usr/bin/env bash
# scripts/post-bash-hook.sh
# Claude Code PostToolUse hook: Bash 도구 실행 후 git commit / 빌드·테스트 명령 감지 및 로깅

set -euo pipefail

HOOK_DATA=$(cat 2>/dev/null || echo "{}")

COMMAND=""
if command -v python3 &>/dev/null; then
  COMMAND=$(echo "$HOOK_DATA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
fi

# ── git commit 감지 ──────────────────────────────────────────────────────────
if echo "$COMMAND" | grep -q "git commit"; then
  MSG=$(echo "$COMMAND" | python3 -c "
import sys, re
cmd = sys.stdin.read()
# 단순 따옴표/큰따옴표 메시지: git commit -m 'msg' 또는 git commit -m \"msg\"
m = re.search(r'-m\s+[\"\']((?:[^\"\'\\\\]|\\\\.)+)[\"\']\s*$', cmd.strip())
if m:
    print(m.group(1).strip()); sys.exit(0)
# HEREDOC 메시지: git commit -m \"\$(cat <<'EOF'\n...\nEOF\n)\"
m = re.search(r\"<<['\\\"]?EOF['\\\"]?\\s*\\n(.*?)(?=\\n\\s*(?:Co-Authored|EOF))\", cmd, re.DOTALL)
if m:
    print(m.group(1).strip().split('\\n')[0].strip()); sys.exit(0)
print('')
" 2>/dev/null || echo "")

  # 커밋 해시 + 변경 파일 통계
  COMMIT_HASH=$(git log -1 --format="%h" 2>/dev/null || echo "")
  COMMIT_STATS=$(git show --stat HEAD --format="" 2>/dev/null | tail -1 | sed 's/^ //' || echo "")

  DETAIL=""
  [ -n "$COMMIT_HASH" ]  && DETAIL="${COMMIT_HASH}"
  [ -n "$COMMIT_STATS" ] && DETAIL="${DETAIL:+${DETAIL} | }${COMMIT_STATS}"

  if [ -f "scripts/log-activity.sh" ]; then
    TITLE="${MSG:-git commit 실행}"
    ./scripts/log-activity.sh COMMIT "git commit: ${TITLE}" "${DETAIL}" 2>/dev/null || true
  fi
  exit 0
fi

# ── 빌드·테스트 명령 감지 ────────────────────────────────────────────────────
# 지원 스택: pytest / npm / yarn / pnpm / vitest / tsc / go / cargo / mvn / gradle
BUILD_MATCHED=false
BUILD_CMD="build/test"

case "$COMMAND" in
  # Python
  *pytest*)                BUILD_MATCHED=true; BUILD_CMD="pytest" ;;
  # Node.js
  *"npm run build"*)       BUILD_MATCHED=true; BUILD_CMD="npm run build" ;;
  *"npm run test"*)        BUILD_MATCHED=true; BUILD_CMD="npm run test" ;;
  *"npm test"*)            BUILD_MATCHED=true; BUILD_CMD="npm test" ;;
  *"yarn build"*)          BUILD_MATCHED=true; BUILD_CMD="yarn build" ;;
  *"yarn test"*)           BUILD_MATCHED=true; BUILD_CMD="yarn test" ;;
  *"pnpm build"*)          BUILD_MATCHED=true; BUILD_CMD="pnpm build" ;;
  *"pnpm test"*)           BUILD_MATCHED=true; BUILD_CMD="pnpm test" ;;
  *vitest*)                BUILD_MATCHED=true; BUILD_CMD="vitest" ;;
  *"tsc --"*|*"tsc -p"*|*"tsc -b"*) BUILD_MATCHED=true; BUILD_CMD="tsc" ;;
  # Go
  *"go build"*)            BUILD_MATCHED=true; BUILD_CMD="go build" ;;
  *"go test"*)             BUILD_MATCHED=true; BUILD_CMD="go test" ;;
  # Rust
  *"cargo build"*)         BUILD_MATCHED=true; BUILD_CMD="cargo build" ;;
  *"cargo test"*)          BUILD_MATCHED=true; BUILD_CMD="cargo test" ;;
  # Java / JVM
  *"mvn test"*|*"mvn package"*|*"mvn install"*|*"mvn verify"*)
                           BUILD_MATCHED=true; BUILD_CMD="mvn" ;;
  *"gradle test"*|*"gradle build"*|*"./gradlew"*)
                           BUILD_MATCHED=true; BUILD_CMD="gradle" ;;
esac

if [ "$BUILD_MATCHED" = "true" ]; then
  # 성공/실패 판별 + 테스트 수·소요 시간 파싱
  BUILD_DETAIL=$(echo "$HOOK_DATA" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    resp = d.get('tool_response', '')

    # ① 메타데이터 우선 — Claude Code Bash hook 의 tool_response 가 제공하는
    #    종료 신호를 신뢰. 키 이름은 환경에 따라 다르므로 다중 키 시도.
    #    (단순 키워드 휴리스틱은 vitest/jest 의 exit 1 무메시지 케이스를 놓침)
    status_meta = None
    if isinstance(resp, dict):
        if 'is_error' in resp:
            status_meta = 'FAIL' if resp['is_error'] else 'SUCCESS'
        elif 'success' in resp:
            status_meta = 'SUCCESS' if resp['success'] else 'FAIL'
        elif 'exit_code' in resp:
            try:
                status_meta = 'SUCCESS' if int(resp['exit_code']) == 0 else 'FAIL'
            except (TypeError, ValueError):
                status_meta = None
        elif 'interrupted' in resp and resp.get('interrupted'):
            status_meta = 'FAIL'

    # 출력 본문 추출 (수치 파싱용)
    if isinstance(resp, dict):
        s = str(resp.get('content', resp.get('output', resp.get('stdout', ''))))
        if not s:
            s = json.dumps(resp, ensure_ascii=False)
    else:
        s = str(resp)
    sl = s.lower()

    # ② 메타데이터로 결정 못한 경우만 키워드 휴리스틱 폴백
    if status_meta is not None:
        status = status_meta
    elif any(p in sl for p in ['failed', 'exit code 1', 'exit code: 1', 'traceback',
                                'syntaxerror', 'typeerror', 'build failed',
                                'compilation error', 'test result: failed',
                                'fail_under', 'tests failed']):
        # FAIL 키워드를 SUCCESS 보다 먼저 검사 — '1 passed, 2 failed' 같은 혼합 출력에서
        # 'passed' 만 보고 SUCCESS 처리되던 기존 버그 차단
        status = 'FAIL'
    elif any(p in sl for p in ['passed', 'built in', 'successfully compiled',
                                'compiled successfully', 'build succeeded',
                                'test result: ok']):
        status = 'SUCCESS'
    else:
        status = 'DONE'

    # 통과/실패 수 (pytest, jest, vitest, cargo 공통 패턴)
    passed = re.search(r'(\d+)\s+passed', s) or re.search(r'(\d+) passed;', s)
    failed = re.search(r'(\d+)\s+failed', s) or re.search(r'(\d+) failed;', s)

    # failed > 0 인데 status 가 SUCCESS 로 잡혔으면 FAIL 로 보정 (안전망)
    if status == 'SUCCESS' and failed:
        try:
            if int(failed.group(1)) > 0:
                status = 'FAIL'
        except ValueError:
            pass

    # 소요 시간
    duration = re.search(r' in ([\d.]+)s', s) or re.search(r'([\d.]+)s\b', s)

    parts = [status]
    if passed or failed:
        t = []
        if passed: t.append(passed.group(1) + ' passed')
        if failed: t.append(failed.group(1) + ' failed')
        parts.append(', '.join(t))
    if duration:
        parts.append(duration.group(1) + 's')
    print(' | '.join(parts))
except Exception:
    print('DONE')
" 2>/dev/null || echo "DONE")

  if [ -f "scripts/log-activity.sh" ]; then
    ./scripts/log-activity.sh BUILD "${BUILD_CMD}" "${BUILD_DETAIL}" 2>/dev/null || true
  fi

  # FAIL 시 슬랙 알림
  if echo "$BUILD_DETAIL" | grep -q "^FAIL" && [ -f "scripts/notify-slack.sh" ]; then
    ./scripts/notify-slack.sh "🔴 빌드/테스트 실패: ${BUILD_CMD}" "${BUILD_DETAIL}" 2>/dev/null || true
  fi
fi

exit 0
