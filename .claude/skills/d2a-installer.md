---
name: d2a-installer
description: d2a-boilerplate-claude를 원격 저장소에서 다운로드하여 설치. "보일러플레이트 설치", "d2a 설치", "프로젝트 초기화" 요청 시 사용.
---

# D2A Boilerplate Installer

GitLab에서 d2a-boilerplate-claude를 다운로드하여 현재 프로젝트 디렉터리에 설치한다.

---

## 트리거

- "보일러플레이트 설치해줘"
- "d2a 설치해줘"
- "프로젝트 초기화해줘"

---

## 설정값

| 항목 | 값 |
|---|---|
| GitLab 호스트 | `gitlab.nexon.com` |
| 저장소 경로 | `frontdev/inhouse/replatform-playground/d2a-boilerplate-claude` |
| 기본 브랜치 | `main` |

---

## Step 1: 현재 디렉터리 상태 확인

설치 전에 현재 디렉터리를 확인한다:
- `CLAUDE.md`가 이미 있으면 → "이미 설치되어 있습니다. 새 채팅창을 열고 `boilerplate-setup 실행해줘`를 입력하세요."
- `.git`이 없으면 → "git 저장소가 아닙니다. git init을 먼저 실행해주세요."

> **git clone으로 직접 받은 경우**: Step 3 대신 아래 **대안 경로**를 따른다.

---

## (대안) git clone으로 직접 받은 경우

`git clone`으로 보일러플레이트를 받으면 `template/` 서브디렉토리가 존재하는 상태로 넘어온다.
아래 초기화 스크립트가 `template/` 내용을 루트로 추출하고 보일러플레이트 전용 파일을 제거한다.

> 🌿 **feature 브랜치 검증**: clone 시 `--branch <브랜치명>` 을 지정하면 해당 브랜치 상태로 받는다.
> 예: `git clone --branch feat/gamescale-docs-mcp <repo-url>` (기본은 `main`).

**1단계 — 초기화 스크립트 실행:**

```bash
bash template/scripts/clean-fork.sh
```

이 스크립트가 하는 일:
- `template/` 내용을 프로젝트 루트로 복사
- `template/`, `tests/`, `README.md`, `.gitlab-ci.yml` 등 보일러플레이트 전용 파일 제거
- 변경 사항을 자동 커밋

**2단계 — Step 3.5(MCP 서버 빌드)로 이동:**

다운로드·설치는 이미 완료된 상태이므로 Step 3을 건너뛰고 Step 3.5부터 진행한다.

---

## Step 2: 인증 정보 확인

GitLab Personal Access Token이 필요하다.

**2-1. 기존 토큰 파일 확인:**

```bash
[ -f .gitlab-token ] && grep -q '^GITLAB_TOKEN=.' .gitlab-token && echo "exists" || echo "missing"
```

`exists`이면 → Step 3으로 바로 이동.

**2-2. 토큰 파일 생성 (없는 경우):**

`.gitignore`에 항목 추가:

```bash
grep -qF '.gitlab-token' .gitignore 2>/dev/null || echo '.gitlab-token' >> .gitignore
```

Write 도구로 `.gitlab-token` 파일 생성:

```
GITLAB_TOKEN=여기에_토큰_붙여넣기
```

**2-3. 파일 오픈 및 사용자 안내:**

```bash
code .gitlab-token 2>/dev/null || true
```

```
📝 프로젝트 폴더에 .gitlab-token 파일이 생성되었습니다.

왼쪽 파일 탐색기에서 .gitlab-token 을 열어
"여기에_토큰_붙여넣기" 부분을 실제 토큰으로 교체하고 저장하세요.

  GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx

토큰 발급 위치: GitLab → Settings → Access Tokens → New token
권한: read_repository 만 체크

🌿 기본은 main 브랜치로 설치됩니다.
   feature 브랜치를 검증하는 개발자라면 "완료" 대신 "브랜치 선택할게" 라고 입력하세요.

저장 완료 후 "완료"를 입력하세요.
```

**2-4. 완료 확인:**

사용자 "완료" 입력 후 값 검증:

```bash
TOKEN_VAL=$(grep '^GITLAB_TOKEN=' .gitlab-token 2>/dev/null | cut -d= -f2-)
[ -n "$TOKEN_VAL" ] && [ "$TOKEN_VAL" != "여기에_토큰_붙여넣기" ] && echo "ok" || echo "empty"
```

`empty`이면 → "파일을 저장했는지 확인하고 다시 '완료'를 입력해주세요." 반복.

---

## Step 2.5: 설치 브랜치 결정 (대부분 건너뜀)

> ⚠️ **대다수 개발자는 이 단계를 건너뛴다.** 사용자가 Step 2-3에서 그냥 "완료"를
> 입력했으면 `D2A_REF=main`으로 두고 **바로 Step 3으로 진행**한다.
> 아래 절차는 사용자가 "브랜치 선택"(`브랜치`/`branch`/`feature`/`피처` 등 의도가
>담긴 입력)을 요청한 경우에만 수행한다.

**2.5-1. 원격 브랜치 목록 조회** (토큰은 Step 2에서 이미 확보):

```bash
GITLAB_TOKEN=$(grep '^GITLAB_TOKEN=' .gitlab-token | cut -d= -f2-)
PROJECT="frontdev%2Finhouse%2Freplatform-playground%2Fd2a-boilerplate-claude"
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.nexon.com/api/v4/projects/$PROJECT/repository/branches?per_page=100" \
  | python3 -c "import sys,json; bs=json.load(sys.stdin); [print(b['name'], '\t', b['commit']['committed_date'][:10]) for b in sorted(bs, key=lambda x: x['commit']['committed_date'], reverse=True)]"
```

**2.5-2. `AskUserQuestion`으로 브랜치 선택**:
- 조회 결과로 선택지를 구성한다. `main`을 첫 번째(권장)로, 나머지는 **최근 커밋순 feature 브랜치**를 최대 3개까지 선택지로 제시한다.
- 브랜치가 4개를 넘으면 사용자가 "Other(직접 입력)"로 임의 브랜치명을 입력할 수 있게 한다.
- 사용자가 직접 입력한 브랜치명은 **2.5-1 목록에 존재하는지 검증**한다. 목록에 없으면 다시 묻는다.

**2.5-3. 선택 결과를 `D2A_REF`로 확정** → Step 3의 git clone `--branch` 값에 그대로 사용한다.
사용자가 브랜치 선택을 요청하지 않았으면 `D2A_REF=main`이다.

---

## Step 3: 다운로드 및 설치

> 다운로드(git clone)와 설치를 하나의 스크립트로 수행한다.
> `curl` archive 방식은 내부 GitLab에서 동작하지 않으므로 `git clone --branch` 를 사용한다 (SETUP.md와 동일 방식).

**3-1. 설치 스크립트 생성** (Write 도구로 `scripts/d2a-install-tmp.sh` 작성):

```bash
#!/usr/bin/env bash
set -e
D2A_REF="${D2A_REF:-main}"   # 설치 브랜치 — Step 2.5에서 선택한 값(없으면 main)
D2A_TMP="${TMPDIR:-${TEMP:-/tmp}}/d2a-install"
rm -rf "$D2A_TMP"; mkdir -p "$D2A_TMP"

# 1) git clone 으로 다운로드 (--branch 로 선택 브랜치 설치)
GITLAB_TOKEN=$(grep '^GITLAB_TOKEN=' .gitlab-token | cut -d= -f2-)
echo "📦 설치 브랜치: $D2A_REF"
git clone --depth=1 --branch "$D2A_REF" \
  "https://oauth2:${GITLAB_TOKEN}@gitlab.nexon.com/frontdev/inhouse/replatform-playground/d2a-boilerplate-claude.git" \
  "$D2A_TMP/extract" \
  || { echo "❌ clone 실패 — 브랜치명 '$D2A_REF' 이 원격에 존재하는지 확인하세요"; exit 1; }

# 2) template/ 내용만 복사 (.git 은 extract/ 안에만 존재하므로 루트로 복사되지 않음)
# Windows Git Bash 호환 (rsync 미사용)
cp -R "$D2A_TMP/extract/template/." .

# 2-B) 유지보수자 전용 파일 strip (sandbox 도구는 보일러플레이트 repo 전용, 파생 프로젝트 미배포)
rm -f scripts/sandbox.sh .claude/skills/sandbox.md

# 활동 로그 초기화 — 헤더 포함하여 즉시 생성
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

# 첫 SETUP entry — 활동 로그가 의미 있는 SETUP 으로 시작되도록.
# 다음 세션에서 "어떤 보일러플레이트 버전으로 초기화됐는지" 즉시 파악 가능.
if [ -f scripts/log-activity.sh ]; then
  HOST_INFO="$(uname -s) $(uname -r 2>/dev/null || echo '')"
  bash scripts/log-activity.sh SETUP \
    "d2a-boilerplate-claude 초기 설치 (clone)" \
    "source=gitlab.nexon.com:${D2A_REF} | host=${HOST_INFO}" 2>/dev/null || true
fi

# 프로젝트 .gitignore에 참조 문서 제외 항목 추가
GITIGNORE=".gitignore"
for entry in "refs/company-policies/" "refs/gamescale-docs/"; do
  grep -qF "$entry" "$GITIGNORE" 2>/dev/null || printf '\n%s\n' "$entry" >> "$GITIGNORE"
done

# 임시 파일 정리
rm -rf "$D2A_TMP"
rm -f scripts/d2a-install-tmp.sh

# 토큰 파일 삭제 (1회용)
rm -f .gitlab-token

echo "설치 완료 (브랜치: $D2A_REF)"
```

**3-2. 스크립트 실행:**

> Step 2.5에서 feature 브랜치를 선택했으면 `D2A_REF=<브랜치명>` 을 앞에 붙여 실행한다.
> 선택하지 않았으면(대부분) 그냥 실행하면 `main`으로 설치된다.

```bash
# 기본 (main):
bash scripts/d2a-install-tmp.sh

# feature 브랜치 선택 시 (예: feat/gamescale-docs-mcp):
# D2A_REF="feat/gamescale-docs-mcp" bash scripts/d2a-install-tmp.sh
```

---

## Step 3.5: MCP 서버 빌드

D2A 하네스 MCP 서버(`d2a-mcp-server/`)를 빌드한다.
이 서버는 Phase 게이트 검증, done 기준 실행, 체크포인트 관리를 코드로 강제한다.

```bash
# node/npm 설치 여부 확인
command -v node >/dev/null 2>&1 || { echo "⚠️ node 미설치 — MCP 서버 빌드 건너뜀"; exit 0; }

# 의존성 설치 및 빌드
cd d2a-mcp-server && npm install && npm run build && cd ..
```

빌드 결과: `d2a-mcp-server/dist/index.js` 생성 확인.
실패 시 → "⚠️ MCP 서버 빌드 실패. 수동으로 `cd d2a-mcp-server && npm install && npm run build` 실행" 안내 후 계속 진행.

---

## Step 4: 설치 검증

설치 완료 후 필수 파일이 있는지 확인한다:

```bash
# 필수 파일 체크
for f in CLAUDE.md .claude/skills .claude/settings.json refs/INDEX.md specs/.template .mcp.json d2a-mcp-server/dist/index.js; do
  [ -e "$f" ] && echo "✅ $f" || echo "❌ $f — 누락"
done
```

---

## Step 5: 완료 안내

```
✅ D2A 보일러플레이트 설치 완료!

설치된 구성:
- CLAUDE.md (프로젝트 지침서)
- .claude/skills/ (18개 스킬)
- .mcp.json (D2A 하네스 MCP 서버 등록)
- d2a-mcp-server/ (Phase 게이트·done 검증·체크포인트 MCP 서버)
- refs/ (정책 레퍼런스)
- specs/.template/ (스펙 템플릿)

다음 단계:
1. **새 채팅창을 연다** (이 채팅은 설치 전에 열렸으므로 새 채팅 필요)
2. **PRD(기획 문서)가 있으면** 새 채팅창에 PRD 파일을 컨텍스트로 추가한 뒤 입력:
   ```
   boilerplate-setup 실행해줘
   ```
   PRD 없이 시작하는 경우도 동일하게 입력하면 위저드가 질문으로 정보를 수집합니다.

> 스킬이 동작하지 않으면 `SETUP.md`의 트러블슈팅 섹션을 참조하세요.

- refs/company-policies/ (사내 정책 문서)
- refs/gamescale-docs/ (GameScale 문서)

※ 두 폴더는 이 프로젝트의 .gitignore에 자동 추가됩니다.
  내용은 포함되지만 커밋 대상에서 제외됩니다.
```
