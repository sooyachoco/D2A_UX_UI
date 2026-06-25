# D2A 보일러플레이트 셋업

> **전제**: 이 보일러플레이트는 **Claude Code (CLI / IDE 확장)** 로 운영된다.
> 사용자와 AI가 모두 Claude Code를 통해 대화하며 프로젝트를 개발한다.

> **주 동작 방식**: 터미널을 직접 열지 않아도 된다.
> **Claude Code 채팅 인터페이스만으로** 설치부터 전체 개발 워크플로가 실행된다.

---

## 사전 요구사항

| 항목                                  | 최소 버전 | 확인 방법             | 비고                 |
| ------------------------------------- | --------- | --------------------- | -------------------- |
| [Claude Code](https://claude.ai/code) | 최신      | `claude --version`    | 필수                 |
| Node.js                               | v20 이상  | `node --version`      | 필수 (MCP 서버 실행) |
| Git                                   | 2.x 이상  | `git --version`       | 필수                 |
| GitLab Personal Access Token          | —         | 저장소 read 권한 필요 | 필수                 |

> Claude Code CLI: `npm install -g @anthropic-ai/claude-code`
> Claude Code IDE 확장: VS Code / JetBrains 마켓플레이스에서 설치

---

## 설치 절차

### Phase 1: 보일러플레이트 설치

#### 1-1. 설치 여부 확인

`CLAUDE.md`와 `.claude/skills/` 디렉터리가 있으면 이미 설치됨 → Phase 2로 이동.

#### 1-2. GitLab 인증 정보 확인

Claude가 `.gitlab-token` 파일을 프로젝트 폴더에 자동 생성합니다.  
파일 탐색기에서 파일을 열어 토큰 값만 교체하고 저장하면 됩니다.

```
📝 프로젝트 폴더에 .gitlab-token 파일이 생성되었습니다.

왼쪽 파일 탐색기에서 .gitlab-token 을 열어
"여기에_토큰_붙여넣기" 부분을 실제 토큰으로 교체하고 저장하세요.

  GITLAB_TOKEN=xxxxxxxxxxxxxxxxxxxx

저장 완료 후 "완료"를 입력하세요.
```

> ⚠️ **스코프 주의**: 토큰 발급 화면에서 기본 선택된 스코프(`read_user`, `ai_workflows`, `api` 등)를 **모두 해제**하고, **`read_repository`만 체크**하세요.
> 불필요한 권한이 포함된 토큰을 발급하면 보안 정책에 위반될 수 있습니다.

> **토큰 발급 위치**: GitLab → 아바타 → Edit profile → Access Tokens → New token  
> Token name: `d2a-claude` / Scopes: `read_repository` 만 체크

> **보안**: `.gitlab-token`은 `.gitignore`에 자동 추가되며, 설치 완료 후 자동 삭제됩니다.  
> 채팅 히스토리에 토큰이 남지 않습니다.

> **🌿 브랜치 선택 (대부분 건너뜀)**: 기본은 `main` 브랜치로 설치됩니다.
> **feature 브랜치를 검증하는 개발자**라면 "완료" 대신 **"브랜치 선택할게"** 라고 입력하세요.
> 일반 개발자는 그냥 **"완료"** 를 입력하면 `main`으로 진행합니다.

#### 1-2-B. (선택) feature 브랜치 선택

> ⚠️ **대부분의 개발자는 이 단계를 건너뜁니다.** 사용자가 1-2에서 "완료"를 입력했으면
> `D2A_REF=main`으로 두고 **바로 1-3으로 진행**한다. 아래 절차는 사용자가 "브랜치 선택"
> (`브랜치`/`branch`/`feature`/`피처` 등 의도가 담긴 입력)을 요청한 경우에만 수행한다.

**B-1. 원격 브랜치 목록 조회** (토큰은 1-2에서 이미 확보):

```bash
GITLAB_TOKEN=$(grep '^GITLAB_TOKEN=' .gitlab-token | cut -d= -f2-)
PROJECT="frontdev%2Finhouse%2Freplatform-playground%2Fd2a-boilerplate-claude"
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.nexon.com/api/v4/projects/$PROJECT/repository/branches?per_page=100" \
  | python3 -c "import sys,json; bs=json.load(sys.stdin); [print(b['name'], '\t', b['commit']['committed_date'][:10]) for b in sorted(bs, key=lambda x: x['commit']['committed_date'], reverse=True)]"
```

**B-2. `AskUserQuestion`으로 브랜치 선택**:
- 조회 결과로 선택지를 구성한다. `main`을 첫 번째(권장)로, 나머지는 **최근 커밋순 feature 브랜치**를 최대 3개까지 선택지로 제시한다.
- 브랜치가 4개를 넘으면 사용자가 "Other(직접 입력)"로 임의 브랜치명을 입력할 수 있게 한다.
- 사용자가 직접 입력한 브랜치명은 **B-1 목록에 존재하는지 검증**한다. 목록에 없으면 다시 묻는다.

**B-3. 선택 결과를 `D2A_REF`로 확정** → 1-3 다운로드 스크립트의 `D2A_REF` 값에 그대로 사용한다.

#### 1-3. 다운로드 및 설치

Claude가 `.gitlab-token`에서 토큰을 읽어 설치를 자동 진행합니다.

```bash
GITLAB_TOKEN=$(grep '^GITLAB_TOKEN=' .gitlab-token | cut -d= -f2-)
D2A_TMP="${TMPDIR:-/tmp}/d2a-install"
# 설치할 브랜치 — 기본 main. 1-2-B에서 feature 브랜치를 선택한 경우 그 브랜치명으로 교체.
D2A_REF="${D2A_REF:-main}"

# 1) 토큰 유효성 사전 검증
TOKEN_INFO=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.nexon.com/api/v4/personal_access_tokens/self")
python3 -c "
import sys, json
try:
    d = json.loads('''$TOKEN_INFO''')
except Exception:
    print('❌ 응답 파싱 실패 — 네트워크 또는 토큰 오류')
    sys.exit(1)
if d.get('active'):
    print('✅ 토큰 유효:', d['name'], '/ 만료:', d.get('expires_at', '없음'))
else:
    print('❌ 토큰 오류:', d.get('message') or d.get('error_description') or d)
    sys.exit(1)
" || { echo "토큰 검증 실패 — 아래 실패 처리 표를 확인하세요"; exit 1; }

# 2) git clone으로 다운로드 (curl archive 방식은 내부 GitLab에서 동작하지 않음)
#    --branch "$D2A_REF" 로 선택한 브랜치를 설치 (기본 main)
mkdir -p "$D2A_TMP"
echo "📦 설치 브랜치: $D2A_REF"
git clone --depth=1 --branch "$D2A_REF" \
  "https://oauth2:${GITLAB_TOKEN}@gitlab.nexon.com/frontdev/inhouse/replatform-playground/d2a-boilerplate-claude.git" \
  "$D2A_TMP/extract" \
  || { echo "❌ clone 실패 — 브랜치명 '$D2A_REF' 이 원격에 존재하는지 확인하세요"; exit 1; }

# rsync: template/ 내용만 복사 (tests/, README.md, .gitlab-ci.yml 등 보일러플레이트 전용 파일 제외)
#        --exclude='.git' 로 원본 .git/(토큰 포함 remote URL) 복사 방지
#        --ignore-existing 으로 이미 존재하는 파일(PRD.md 등) 덮어쓰기 방지
#        sandbox 도구는 유지보수자 전용 — 파생 프로젝트에 배포하지 않음
rsync -a --exclude='.git' --exclude='scripts/sandbox.sh' --exclude='.claude/skills/sandbox.md' \
  --ignore-existing "$D2A_TMP/extract/template/" ./
rm -rf "$D2A_TMP"

# 활동 로그 초기화 — 보일러플레이트 개발 기록을 제거하고 빈 헤더로 시작
# (rsync --ignore-existing은 기존 파일을 덮어쓰지 않으므로 별도 초기화 필요)
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

# 2-B) 설치 브랜치를 SETUP 항목으로 기록 (다음 세션에서 어떤 브랜치로 설치됐는지 추적)
if [ -f scripts/log-activity.sh ]; then
  bash scripts/log-activity.sh SETUP \
    "d2a-boilerplate-claude 초기 설치 (clone)" \
    "source=gitlab.nexon.com:${D2A_REF} | host=$(uname -s) $(uname -r 2>/dev/null || echo '')" 2>/dev/null || true
fi

# 3) 프로젝트 .gitignore에 참조 문서 제외 항목 추가
GITIGNORE_PATH="$(pwd)/.gitignore"
for entry in "refs/company-policies/" "refs/gamescale-docs/"; do
  grep -qF "$entry" "$GITIGNORE_PATH" 2>/dev/null || printf '\n%s\n' "$entry" >> "$GITIGNORE_PATH"
done

# 4) D2A 하네스 MCP 서버 빌드
if command -v node >/dev/null 2>&1 && [ -d d2a-mcp-server ]; then
  echo "MCP 서버 빌드 중..."
  (cd d2a-mcp-server && npm install --silent && npm run build --silent) \
    && echo "✅ MCP 서버 빌드 완료" \
    || echo "⚠️  MCP 서버 빌드 실패 — 나중에 수동으로 실행: cd d2a-mcp-server && npm install && npm run build"
fi
```

실패 처리:
| 상황 | 안내 |
|---|---|
| 401 / 403 | 토큰이 올바르지 않거나 저장소 접근 권한이 없습니다 |
| `insufficient_scope` | 토큰 스코프에 `read_repository`가 없습니다 — 재발급 필요 |
| `Token is expired` | 토큰이 만료되었습니다 — GitLab에서 재발급 후 재시도 |
| tar 오류 / HTML 수신 | `curl` archive 방식 미지원 — 위 스크립트의 `git clone` 방식을 사용하세요 |
| 302 → sign_in 리다이렉트 | 내부 GitLab에서 `curl` archive 방식 미지원 — `git clone` 방식으로 전환 필요 |
| `rsync: command not found` | `brew install rsync` (macOS) 또는 `apt install rsync` (Ubuntu) |
| `Remote branch ... not found` / clone 실패 | 선택한 브랜치명이 원격에 없습니다 — 1-2-B의 브랜치 목록 조회로 정확한 이름을 확인 후 재시도 |
| 네트워크 오류 | gitlab.nexon.com에 연결할 수 없습니다. 네트워크를 확인해주세요 |

#### 1-4. 설치 검증

다음 파일이 모두 존재하는지 확인한다:

| 항목                            | 기대                                                                       |
| ------------------------------- | -------------------------------------------------------------------------- |
| `CLAUDE.md`                     | 존재                                                                       |
| `.claude/skills/`               | 스킬 파일 18개                                                             |
| `.claude/settings.json`         | `enableAllProjectMcpServers: true` + hooks 포함                            |
| `.mcp.json`                     | `d2a-harness` MCP 서버 등록                                                |
| `d2a-mcp-server/dist/index.js`  | 존재 (MCP 서버 빌드 결과물)                                                |
| `refs/INDEX.md`                 | 존재                                                                       |
| `refs/collaboration-tracker.md` | 존재                                                                       |
| `specs/.template/`              | .md 파일 6개 이상                                                          |
| `.env.example`                  | 존재                                                                       |
| `scripts/`                      | log-activity.sh, notify-slack.sh, pre-write-hook.sh, pre-bash-hook.sh 포함 |

---

### Phase 2: Slack 알림 설정 (선택)

슬랙 알림을 사용하려면 `.env.local` 파일을 생성하고 Webhook URL을 설정한다:

```bash
# .env.local (gitignore 대상 — 절대 커밋하지 않는다)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

설정하지 않으면 알림 없이 로컬 로그만 기록된다 (`logs/boilerplate-activity.md`).

---

### Phase 3: 프로젝트 세팅 위저드

> 💡 **스킬 실행 방식**: `.claude/skills/`의 스킬은 슬래시 커맨드(`/command`)가 아닙니다.
> Claude Code 채팅창에 자연어로 요청하면 Claude가 내부적으로 `Skill()` 도구를 호출합니다.

**새 채팅창**을 열고 아래와 같이 입력한다.

**PRD(기획 문서)가 있는 경우 (권장):**

새 채팅창을 열 때 PRD 파일을 컨텍스트로 추가한 뒤 입력한다:

```
boilerplate-setup 실행해줘
```

Claude가 PRD에서 프로젝트 정보를 자동 추출하여 중복 질문을 건너뛴다.

**PRD가 없는 경우:**

```
boilerplate-setup 실행해줘
```

위저드가 질문으로 프로젝트 정보를 직접 수집한다.

**위저드 단계:**

- **Stage 0**: 참조 문서 확인 (`refs/company-policies/`, `refs/gamescale-docs/`)
- **Stage 1**: 프로젝트 기본 정보 수집 (PRD가 있으면 자동 추출)
- **Stage 1.5**: Phase 0 UI 프로토타입 구현 (더미 데이터 기반)
- **Stage 2**: 기술 스택 확정 (`backend/CLAUDE.md`, `frontend/CLAUDE.md` 자동 생성)
- **Stage 3~4**: 인프라 / 인증 설정

---

### Phase 4: Git 초기화 (선택)

프로젝트에 `.git/` 디렉터리가 없으면 Claude Code 채팅에서 입력한다:

```
git 초기화하고 보일러플레이트 파일들을 첫 커밋으로 만들어줘
```

AI가 아래를 자동으로 실행한다:

```bash
git init
git add CLAUDE.md .claude/ refs/ specs/ docs/ scripts/ logs/ .env.example .gitignore README.md SETUP.md
# PRD.md가 있으면 추가 (.gitignore 대상이므로 -f 필요)
[ -f PRD.md ] && git add -f PRD.md
git commit -m "chore: d2a-base 보일러플레이트 초기 설치"
```

> ⚠️ **PRD.md 주의**: `.gitignore`에 `PRD.md`가 포함되어 있습니다 (보일러플레이트 소스 레포 전용 설정).
> 파생 프로젝트에서 PRD.md를 추적하려면 반드시 `git add -f PRD.md`를 사용하세요.

---

## 이후 워크플로

Claude Code 채팅창에 아래 자연어 트리거를 입력한다.
(스킬 이름은 슬래시 없이 자연어로 호출한다 — `.claude/skills/{name}.md` 평탄 구조라 `/name` 자동완성은 노출되지 않는다.)

### 기능 개발 흐름

```
1. "create-spec 실행해줘"          → spec.md → plan.md → tasks.md 생성
2. "check-decision-gates 실행해줘" → 미결정 사항 확인 (구현 시작 전)
3. "구현을 시작해줘" / "Phase 1 시작해줘" → tasks.md 기반 순차 구현 (TodoWrite 추적)
4. (자동) Phase 완료 시 subagent-review 병렬 리뷰 실행
5. "pre-launch-check 실행해줘" / "배포 전 체크해줘" → 배포 전 검증
```

### 외부 시스템 연동 흐름

```
1. "analyze-integrations 실행해줘"     → 외부 시스템 분석 (integration-registry.md 생성)
2. "collect-prerequisites 실행해줘"    → 실제 값 수집 · 연결 테스트
3. "integrate-external-system 실행해줘" → Real-first 연동 구현
```

### 세션 관리

```
"이어서 해줘" / "계속해줘"  → session-phase-workflow 자동 실행 (복귀 처리)
"어디까지 했지?"            → PROGRESS.md + tasks.md (+ blockers.md) 읽기
```

---

## Claude Code 설정 확인

`.claude/settings.json`이 올바르게 설정되었는지 확인한다:

```json
{
  "enableAllProjectMcpServers": true,
  "permissions": {
    "allow": ["Bash(*)"],
    "additionalDirectories": [".claude"]
  },
  "hooks": {
    "Stop": [...],          ← 세션 종료 시 타임스탬프 기록
    "PreToolUse": [...],    ← .env.production 쓰기 차단, git push --force 차단
    "PostToolUse": [...]    ← tasks.md 체크박스 전환 감지, 활동 로깅
  }
}
```

`enableAllProjectMcpServers: true` 설정으로 `.mcp.json`에 등록된 `d2a-harness` MCP 서버가 자동 연결된다.
이 서버는 Phase 게이트 검증·done 기준 실행·체크포인트/롤백을 코드로 강제한다.

**긴급 우회 (필요 시에만):**

- 프로덕션 파일 쓰기: `export D2A_ALLOW_SECRET_WRITE=1`
- Force push: `export D2A_ALLOW_FORCE_PUSH=1`

---

---

## 트러블슈팅

### 스킬이 동작하지 않는 경우

**1단계 — 파일 존재 확인**

```bash
ls .claude/skills/*.md | wc -l   # 18이어야 함
```

파일이 없으면 `d2a-installer 다시 실행해줘`를 입력한다.

**2단계 — 새 채팅창에서 재시도**

현재 채팅은 설치 이전에 열린 것이므로 `CLAUDE.md`를 로딩하지 못한 상태일 수 있다.
**새 채팅창을 열고** `boilerplate-setup 실행해줘`를 다시 입력한다.

**3단계 — VS Code 워크스페이스 확인**

프로젝트 루트(`CLAUDE.md`가 있는 디렉토리)가 VS Code 워크스페이스 루트인지 확인한다.
하위 폴더만 열려 있으면 `.claude/`를 인식하지 못한다.

- **폴더로 열기**: `파일 → 폴더 열기` → 프로젝트 루트 선택
- **워크스페이스 파일 사용 시**: `.code-workspace`의 `folders[0].path`가 프로젝트 루트를 가리키는지 확인

**4단계 — VS Code 완전 재시작**

단순히 창을 닫았다가 여는 것으로는 재스캔되지 않는다. **앱 자체를 종료**해야 한다.

- macOS: `Cmd+Q` → VS Code 재실행
- Windows/Linux: 작업표시줄에서 앱 완전 종료 → 재실행

재시작 후 새 채팅창에서 `boilerplate-setup 실행해줘`를 입력하여 동작을 확인한다.
