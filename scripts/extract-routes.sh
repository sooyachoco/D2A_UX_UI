#!/bin/bash
# spec.md / PRD.md / api-spec.yaml 에서 공개 라우트를 추출하여
# tests/e2e/runtime-health.spec.ts 의 ROUTES 배열을 갱신한다.
#
# 사용법:
#   ./scripts/extract-routes.sh              # 자동 추출 + 갱신
#   ./scripts/extract-routes.sh --dry-run    # 추출 결과만 출력 (파일 변경 없음)
#
# 호출 시점:
#   - boilerplate-setup Stage 2-E (Playwright 셋업 시 - 초기 채움)
#   - subagent-review Step 2-0 (Phase 경계마다 - spec 변경 반영)
#   - run-phase Step 0 (Phase 진입 시 - 선택적)
#
# 인증 라우트 제외 휴리스틱:
#   login / signin / auth / callback / dashboard / mypage / profile / settings
#   (보호 라우트는 보호 라우트 e2e 에서 fixtures/auth-mock.ts 와 함께 검증)

set -e

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPEC_FILE="$PROJECT_ROOT/tests/e2e/runtime-health.spec.ts"

# spec 파일이 없으면 (Stage 2-E 미실행) 종료 — 자동 호출에서는 noop
if [[ ! -f "$SPEC_FILE" ]] && [[ "$DRY_RUN" == "false" ]]; then
  echo "[extract-routes] $SPEC_FILE 없음 — Stage 2-E 미실행. 갱신 생략."
  exit 0
fi

# Python 으로 라우트 추출
EXTRACTED_ROUTES=$(cd "$PROJECT_ROOT" && python3 - <<'PYEOF'
import re, pathlib, json

candidates = []

# 검색 대상: specs/ 하위, PRD.md, docs/ 하위
for src in ['specs', 'PRD.md', 'docs']:
    p = pathlib.Path(src)
    if not p.exists():
        continue
    if p.is_file():
        files = [p]
    else:
        files = list(p.rglob('*.md')) + list(p.rglob('*.yaml')) + list(p.rglob('*.yml'))
    for f in files:
        try:
            text = f.read_text(encoding='utf-8', errors='ignore')
        except Exception:
            continue
        # 패턴 1: 백틱 안의 절대 경로 - chr(96) 으로 backtick 표현
        BT = chr(96)
        for m in re.findall(BT + r'(/[a-zA-Z0-9][a-zA-Z0-9/_-]*)' + BT, text):
            candidates.append(m)
        # 패턴 2: openapi paths: 들여쓰기 + /route:
        for m in re.findall(r'^\s+(/[a-zA-Z][a-zA-Z0-9/_-]*):', text, re.MULTILINE):
            candidates.append(m)
        # 패턴 3: route|path|url: /something  (따옴표 유무 모두)
        for m in re.findall(r'(?:route|path|url)\s*[:=]\s*"?(/[a-zA-Z][a-zA-Z0-9/_-]*)', text, re.IGNORECASE):
            candidates.append(m)
        for m in re.findall(r"(?:route|path|url)\s*[:=]\s*'?(/[a-zA-Z][a-zA-Z0-9/_-]*)", text, re.IGNORECASE):
            candidates.append(m)

# 인증 필요 라우트 제외 (휴리스틱)
excluded_keywords = ['login', 'logout', 'signin', 'signout', 'auth', 'callback', 'oauth',
                     'admin', 'dashboard', 'mypage', 'profile', 'settings', 'account']

seen = set()
result = ['/']
for r in candidates:
    if r in seen:
        continue
    seen.add(r)
    # API 경로 제외 (페이지 라우트만)
    if r.startswith('/api') or r.startswith('/_next'):
        continue
    # 동적 세그먼트(:id, [id]) 제외
    if ':' in r or '[' in r:
        continue
    # 인증 키워드 포함 제외
    if any(k in r.lower() for k in excluded_keywords):
        continue
    result.append(r)

# 최대 5개
print(json.dumps(result[:5], ensure_ascii=False))
PYEOF
)

[[ -z "$EXTRACTED_ROUTES" ]] && EXTRACTED_ROUTES='["/"]'

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[extract-routes] 추출 결과 (dry-run):"
  echo "$EXTRACTED_ROUTES"
  exit 0
fi

# spec 파일의 ROUTES 라인 갱신 — python 으로 안전하게 처리
# (awk -v 인자에 JSON 의 따옴표가 들어가면 셸 파싱이 깨짐)
RESULT=$(SPEC_FILE="$SPEC_FILE" NEW_ROUTES="$EXTRACTED_ROUTES" python3 - <<'PYEOF'
import os, re, sys

spec = os.environ['SPEC_FILE']
new_routes = os.environ['NEW_ROUTES']

with open(spec, 'r', encoding='utf-8') as f:
    text = f.read()

# 'const ROUTES = ...;' 라인 한 줄 교체 (배열 또는 다중 라인 모두 한 줄로 통일)
new_line = f'const ROUTES = {new_routes};'
new_text, n = re.subn(r'^const ROUTES = .*;\s*$', new_line, text, count=1, flags=re.MULTILINE)

if n == 0:
    print("NOT_FOUND")
    sys.exit(0)

if new_text == text:
    print("UNCHANGED")
else:
    with open(spec, 'w', encoding='utf-8') as f:
        f.write(new_text)
    print("UPDATED")
PYEOF
)

case "$RESULT" in
  UPDATED)
    echo "[extract-routes] 갱신: ROUTES = $EXTRACTED_ROUTES"
    ;;
  UNCHANGED)
    echo "[extract-routes] 변경 없음: $EXTRACTED_ROUTES"
    ;;
  NOT_FOUND)
    echo "[extract-routes] WARNING: $SPEC_FILE 에서 ROUTES 라인을 찾지 못함 — 수동 점검 필요"
    ;;
  *)
    echo "[extract-routes] python 실행 실패" >&2
    exit 1
    ;;
esac
