---
name: boilerplate-setup
description: 보일러플레이트 초기 세팅을 대화형 위저드로 진행. 새 프로젝트 시작, 프로젝트 초기화, 프로젝트 세팅 요청 시 사용.
---

# Boilerplate Setup Wizard

보일러플레이트 초기 세팅을 단계별 질문으로 진행한다.
각 단계에서 반드시 사용자 답변을 받은 후 다음 단계로 넘어간다.

## 트리거

다음 요청 시 이 스킬을 실행한다:
- "프로젝트를 세팅해줘"
- "프로젝트 셋팅해줘"
- "세팅 계속해줘"
- "프로젝트 초기 세팅"
- "이 PRD로 세팅해줘" (채팅에 PRD 내용 붙여넣기)

## 사전 조건: 보일러플레이트 설치 여부 확인

`.claude/` 디렉터리와 `CLAUDE.md` 파일이 **없으면** 보일러플레이트가 설치되지 않은 상태이다.

- 프로젝트 루트에 `SETUP.md`가 있으면 → 해당 파일을 읽고 Phase 1부터 실행한다.
- `SETUP.md`도 없으면 → 사용자에게 안내한다:
  ```
  보일러플레이트가 아직 설치되지 않았습니다.
  
  'd2a-installer 실행해줘' 를 입력하여 먼저 설치해주세요.
  ```

`CLAUDE.md`가 **있으면** → PROGRESS.md를 확인/생성한 뒤 Stage 0부터 시작한다.

## PROGRESS.md 생성

위저드 시작 전에 프로젝트 루트에 `PROGRESS.md`가 없으면 `specs/.template/PROGRESS.md`를 복사하여 생성한다.
이미 있으면 현재 단계를 읽어 상태를 확인한다.

위저드 진행 중 각 Stage 완료 시 PROGRESS.md의 해당 체크박스를 갱신한다.

## 진행 규칙

- 한 번에 한 단계씩 진행
- 사용자 답변 후 다음 단계로 이동
- "모르겠다" → ⬜(미결정)으로 표시하고 넘어감
- PRD가 제공되면 추출 가능한 항목은 자동 매핑하고 질문을 건너뜀
- 모든 단계 완료 후 decision-gates.md에 기록

위저드 시작 시 `TodoWrite`로 Stage 0~4 목록을 등록하고, 각 Stage 시작·완료 시 상태를 업데이트한다.

---

## Stage 0: 사전 준비 확인

위저드 시작 전에 다음 사전 준비 상태를 확인한다.

### .boilerplate-source 마커 제거 (포크 프로젝트 필수)

`.boilerplate-source` 파일은 보일러플레이트 원본 레포 전용 억제 마커다.
`log-activity.sh`가 실행 시 이 파일을 확인하여 원본 레포에서는 **활동 로그를 기록하지 않는다.**
파생 프로젝트에는 이 파일이 없어야 하며, 남아 있으면 Phase 전체 기간 동안 로그가 기록되지 않는다.

```bash
if [ -f ".boilerplate-source" ]; then
  rm -f .boilerplate-source
  echo "✅ .boilerplate-source 마커 제거 완료 — 활동 로그 기록 활성화"
fi
```

> 이 파일은 보일러플레이트 원본 레포 전용 억제 마커로, 파생 프로젝트에는 존재해서는 안 된다.
> `d2a-installer`를 거치지 않고 직접 복사한 경우 이 단계에서 자동 제거된다.

### 활동 로그 초기화

보일러플레이트 개발 이력이 담긴 기존 로그를 지우고 파생 프로젝트의 새 이력을 시작한다.

> **재실행 안전**: `## YYYY-MM-DD` 형식의 날짜 섹션이 이미 존재하면 초기화를 건너뛴다.
> 이미 기록된 프로젝트 이력이 있다는 뜻이므로 `boilerplate-setup` 재실행 시에도 로그가 보존된다.

```bash
# 날짜 섹션이 있으면 기존 프로젝트 로그가 존재 → 초기화 건너뜀
if grep -q "^## [0-9]" logs/boilerplate-activity.md 2>/dev/null; then
  echo "ℹ️  활동 로그에 기존 기록이 있어 초기화를 건너뜁니다"
else
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
  echo "✅ 활동 로그 초기화 완료"
fi
```

### D2A 특화 .gitignore 항목 추가

`.gitignore`에 D2A 하네스 전용 항목이 없으면 자동으로 추가한다:

```bash
# D2A gitignore 섹션이 없을 때만 추가
if ! grep -q "D2A harness" .gitignore 2>/dev/null; then
  cat >> .gitignore << 'EOF'

# D2A harness — MCP 상태·세션·토큰 (로컬 전용, 커밋 금지)
.claude/state.json
.claude/session-stamp
.claude/hook-errors.log
.claude/review-token-secret
.claude/review-tokens/
.claude/traces/

# D2A harness — 로컬 MCP 설정 (경로가 머신마다 다름)
.mcp.json

# D2A refs — 사내 민감 문서 (사내망 전용, 외부 유출 금지)
refs/company-policies/
refs/gamescale-docs/
EOF
  echo "✅ .gitignore에 D2A 특화 항목 추가됨"
fi
```

### Git 초기화 및 보일러플레이트 초기 커밋

```bash
# .git 디렉터리가 없으면 초기화
git rev-parse --git-dir 2>/dev/null || git init
```

초기화 후, 보일러플레이트 파일이 한 번도 커밋되지 않은 경우 즉시 초기 커밋한다:

```bash
# 이미 커밋이 있으면 건너뜀 (git log -1 으로 확인)
git log -1 --oneline 2>/dev/null || (
  git add CLAUDE.md SETUP.md README.md .gitignore .env.example \
    .claude/ refs/ specs/ scripts/ logs/ PROGRESS.md
  git commit -m "chore: d2a-base 보일러플레이트 초기 설치"
)
```

> PRD.md가 있으면 `git add -f PRD.md`도 포함한다 (`.gitignore` 대상이므로 `-f` 필요).
> `.env.local`은 절대 커밋하지 않는다 (`.gitignore` 대상).

### 참조 문서 확인

```
확인 방법: refs/company-policies/ 및 refs/gamescale-docs/ 디렉터리 존재 여부
- 둘 다 있으면 → ✅ 참조 문서 준비 완료
- 없으면 → ⚠️ 경고 표시 후 진행 (정책 자동 선택 기능이 제한됨을 안내)
  "refs/company-policies/ 또는 refs/gamescale-docs/ 디렉터리가 없습니다.
   이 디렉터리는 gitignore 처리되므로 별도 설치가 필요합니다.
   없이도 진행 가능하나, 인증·보안·인프라 결정 시 AI 제안(🤖) 항목이 늘어납니다."
   → Stage 1로 진행 (중단하지 않음)
```

---

## PRD 입력 확인

Stage 0 완료 후, PRD(기획 문서) 제공 여부를 확인한다.

다음 중 하나로 PRD가 제공될 수 있다:
1. **파일 지정** — 사용자가 파일을 첨부
2. **채팅 붙여넣기** — 사용자가 PRD 내용을 채팅에 직접 입력
3. **없음** — PRD 없이 위저드 질문으로 진행

### 디자인 시스템 키워드 감지 (DESIGN_SYSTEM)

PRD가 제공된 경우, 본문에서 **NX Basic 디자인 시스템** 키워드를 검사한다.
다음 중 하나라도 등장하면(대소문자·공백 무시) `DESIGN_SYSTEM = nxbasic` 로 판정한다:

- `NX Basic` · `nxbasic` · `NX Basic 1.0v` · `nxbasic-mcp`

```bash
# PRD 파일/붙여넣기 본문을 PRD_TEXT 로 두고 검사
if echo "$PRD_TEXT" | grep -iqE 'nx ?basic|nxbasic'; then
  DESIGN_SYSTEM="nxbasic"
  echo "✅ PRD에서 NX Basic 디자인 시스템 키워드 감지 — DESIGN_SYSTEM=nxbasic"
else
  DESIGN_SYSTEM=""   # 미지정 → 일반 디자인 리서치 흐름
fi
```

**`DESIGN_SYSTEM = nxbasic` 판정 시 효과:**
- **Stage 1.5(웹 디자인 리서치)** 는 **건너뛴다.** 시각 DNA의 출처가 NX Basic 디자인 시스템이므로 Awwwards 등 외부 레퍼런스 리서치는 수행하지 않는다.
- **Stage 1 Q5\*(디자인 샘플 생성·선택)는 건너뛰지 않는다.** 색상·타이포·컴포넌트는 NX Basic 토큰/18종을 그대로 고정하되, **레이아웃·구성(정보 배치·진입 영역·밀도)만 다른 디자인 샘플 3종**을 `design/samples.html` 로 생성하여 사용자가 비교·선택하게 한다. (상세 절차는 Stage 1 Q5\* 하단 **[NX Basic 샘플 3종]** 참조)
- 사용자가 샘플을 고르면 선택된 레이아웃 방향과 NX Basic 토큰을 `design/design-direction.md` 에 기록하고 곧장 Stage 2 로 진행한다 (UI 프로토타입은 `create-spec` Step 2.7).
- 결정을 state.json 과 활동 로그에 영구 기록한다:
  ```
  mcp__d2a-harness__update_state({ patch: { design_system: "nxbasic" } })
  ```
  ```bash
  ./scripts/log-activity.sh DECISION "[DESIGN_SYSTEM]: nxbasic" "🤖 PRD 키워드 자동 감지 — NX Basic 토큰 고정, 샘플 3종 레이아웃 비교" || true
  ```

> 참조: `refs/design-systems/nxbasic-1.0v.md` (MCP 서버·Storybook·컴포넌트 18종·토큰 144개·적용 규칙)
> 본 보일러플레이트는 `nxbasic-mcp` 를 등록하지 않고 Storybook URL 을 WebFetch 로 조회한다.

---

## Stage 1: 프로젝트 기본 정보

```bash
./scripts/notify-slack.sh "🚀 Stage 1 — 기본 정보 입력 필요" "프로젝트명·유형·대상 사용자·디자인 키워드를 채팅창에 입력해주세요." || true
```

```
🚀 D2A 보일러플레이트 셋업 — Stage 1

다음 항목을 알려주세요 (모르면 "모르겠다"로 진행합니다):

Q1. 프로젝트명은 무엇인가요?
Q2. 프로젝트 유형을 선택해주세요:
  A) 🆕 신규 개발
  B) 🔄 레거시 마이그레이션
Q3. 이 서비스의 대상 사용자는 누구인가요?
  A) 사내 직원/관리자 전용
  B) 외부 유저 (넥슨 회원)
  C) 둘 다
Q4. 이 서비스가 사용자에게 주고 싶은 첫인상을 1~3개 골라주세요:
  신뢰/공신력 · 친근함 · 전문성 · 역동성 · 세련됨/고급감 · 따뜻함 · 혁신/모던함
```

Q1~Q4 답변을 모두 받은 후 → **Q5* 디자인 샘플 선택** 절차를 진행한다.

---

## Stage 1 — Q5*: 디자인 샘플 생성 후 선택

> **반드시 `design/samples.html`을 먼저 생성한 뒤** 사용자에게 안내한다.
> 텍스트 선택지만 나열하는 방식은 금지한다.

> ### ⏭ 분기: DESIGN_SYSTEM = nxbasic 이면 NX Basic 토큰 기반으로 샘플 3종을 생성한다
>
> "PRD 입력 확인 > 디자인 시스템 키워드 감지"에서 `DESIGN_SYSTEM = nxbasic` 로 판정된 경우,
> [2단계] 웹 레퍼런스 리서치는 **생략**하되, 디자인 샘플 생성·선택([3]~[5]단계)은 **그대로 수행한다.**
> 단, 샘플은 자유 탐색이 아니라 **NX Basic 토큰/18종 컴포넌트를 고정한 채 레이아웃·구성만 3가지로 다르게**
> 제작한다. 상세 절차는 이 섹션 맨 아래의 **[NX Basic 샘플 3종]** 을 따른다.
> (Q1~Q4 기본 정보 수집은 그대로 진행)

### [1단계] 프로젝트 시각 DNA 추출

Q1~Q4 답변 + PRD(있는 경우)에서 다음을 정리한다:
- 서비스 도메인: (교육 / 게임 / 사내운영 / 커머스 / 헬스케어 / 핀테크 등)
- 핵심 인상 키워드: Q4 선택값
  - Q4가 ⬜(모르겠다)인 경우 → 서비스 도메인 기반 기본 키워드 자동 추출:
    - 사내운영: 신뢰/공신력 + 전문성
    - 교육: 친근함 + 따뜻함
    - 게임: 역동성 + 혁신/모던함
    - 커머스: 세련됨/고급감 + 신뢰/공신력
    - 기타: 신뢰/공신력 + 혁신/모던함 (기본값)
  - 자동 추출된 키워드는 검색 후 사용자에게 보고한다 ("Q4 미선택으로 도메인 기반 키워드를 적용했습니다: {키워드}")
- 대상 사용자 연령·직군: 시각적 무게감 결정에 활용
- 금지 키워드: 이 서비스에 어울리지 않는 느낌 (예: 관공서 느낌, 어두운 느낌 등)

**넥슨 GNB 사용 여부 확인 (PRD 키워드 검사):**

PRD 또는 Q1~Q5 답변에서 "GNB", "넥슨 GNB", "Global Navigation Bar" 키워드가 감지되면
`GNB_REQUIRED = true`로 표시하고 이후 단계에서 반영한다.

> NXAS SSO(사내 인증)는 GNB와 별개 시스템이므로 GNB_REQUIRED 판별에 사용하지 않는다.

- `GNB_REQUIRED = true`이면 → **[1.5단계] GNB 도메인·GID 수집 및 hosts 설정** 진행 후 [2단계]로
- `GNB_REQUIRED = false`이면 → 일반 방식으로 [2단계]로 진행

### [1.5단계] GNB 도메인·GID 수집 및 hosts 설정 (GNB_REQUIRED = true 전용)

> GNB 스크립트는 `.nexon.com` 쿠키에 의존하므로 `localhost`에서 동작하지 않는다.
> 이 단계는 **도메인·GID 수집 + hosts 설정**만 처리한다. `gnb.min.js` 스크립트 초기화는 구현 단계(Phase 1 이상)에서 별도로 수행한다.
> hosts 설정 완료 후에는 디자인 샘플에서 GNB 플레이스홀더가 올바른 로컬 도메인 경로로 렌더링된다.

#### 사전 정보 수집 (필수 — 값 없이 다음 단계 진행 불가)

사용자에게 다음 질문을 한다. 두 항목을 한 번에 물어본다:

```bash
./scripts/notify-slack.sh "🌐 GNB 도메인·GID 입력 필요" "넥슨 GNB 사용 프로젝트입니다.\n서비스 예상 도메인과 GID(4자리)를 채팅창에 입력해주세요." || true
```

```
🌐 넥슨 GNB 사전 설정 — 디자인 샘플 생성 전 필수 정보

이 서비스는 넥슨 GNB를 사용합니다.
아래 두 항목은 로컬 hosts 설정과 GNB 스크립트에 직접 사용되므로
반드시 입력해야 다음 단계로 진행됩니다.

Q_GNB_1. 서비스 예상 도메인을 알려주세요.
  (예: mygame.nexon.com, gamehub.nexon.com)

Q_GNB_2. GID (게임 식별자, 4자리 숫자)를 알려주세요.
```

**답변 유효성 검사 — 아래 조건 중 하나라도 해당하면 재질문한다. [2단계]로 넘어가지 않는다:**
- Q_GNB_1이 비어 있거나 도메인 형식이 아님 (`.`이 없거나 공백 포함)
- Q_GNB_2가 비어 있거나 4자리 숫자가 아님

재질문 형식:
```
⛔ 다음 항목이 입력되지 않았습니다. 확인 후 다시 입력해주세요:
  • {미입력 항목 목록}

도메인과 GID는 hosts 설정·GNB 스크립트에 필수이므로 건너뛸 수 없습니다.
```

유효한 답변 수신 후 변수 저장:
- `GNB_DOMAIN = {Q_GNB_1 답변}`
- `GNB_GID = {Q_GNB_2 답변}`

#### hosts 설정 안내 및 확인

> ⚠ **이 단계는 자율 실행 금지 — `AskUserQuestion` 도구로 반드시 사용자 입력 대기**
> `enforce-task-completion`의 "사용자 확인 없이 연속 진행" 규칙의 **명시적 예외**다.
> GNB 및 INSIGN은 `.nexon.com` 쿠키에 의존하므로 hosts 미설정 시 로컬 개발 자체가 불가능하다.
> "완료" 입력 없이 [2단계]로 넘어가는 것은 규칙 위반이며, AI 임의로 "나중에 하셔도 됩니다" 처리 금지.

설정 가이드를 출력하고 완료 확인을 기다린다:

```bash
./scripts/notify-slack.sh "🖥️ hosts 설정 필요 — 입력 대기 중" "로컬 GNB 개발을 위해 /etc/hosts에 도메인을 추가해야 합니다.\n설정 완료 후 채팅창에 '완료'를 입력해주세요." || true
```

```
🖥️ 로컬 hosts 설정 안내

로컬 개발 호스트: local-{GNB_DOMAIN}

─── Mac / Linux ───────────────────────────────────────
sudo sh -c 'echo "127.0.0.1  local-{GNB_DOMAIN}" >> /etc/hosts'
sudo dscacheutil -flushcache   # Mac DNS 캐시 초기화

─── Windows ───────────────────────────────────────────
메모장(관리자 권한)으로 C:\Windows\System32\drivers\etc\hosts 편집:
  127.0.0.1  local-{GNB_DOMAIN}
관리자 권한 CMD: ipconfig /flushdns

─── 설정 확인 ─────────────────────────────────────────
ping -c 1 local-{GNB_DOMAIN}
→ 127.0.0.1 응답이 나오면 성공

⚠️ GNB 및 INSIGN 사용 시 .nexon.com 쿠키에 의존하므로 localhost에서는 동작하지 않습니다.
hosts 설정 없이는 로컬 개발이 불가합니다.

설정 완료 후 "완료"를 입력해주세요.
```

사용자가 "완료" 외 다른 입력을 하면 위 안내를 반복한다. [2단계]로 넘어가지 않는다.

사용자 "완료" 입력 후:
- `GNB_HOSTS_READY = true` 저장
- `GNB_LOCAL_HOST = local-{GNB_DOMAIN}` 저장
- **state.json에 gnb_required 영구 저장 (MCP 필수)**:
  ```
  mcp__d2a-harness__update_state({
    patch: { gnb_required: true }
  })
  ```
  > 이 호출이 없으면 세션 재시작·컨텍스트 압축 시 GNB_REQUIRED 플래그가 소실되어
  > Phase 1 게이트에서 GNB 스크립트 검증이 작동하지 않는다.
  > MCP 호출 실패 시: `scripts/state-manager.sh patch gnb_required true` 폴백 실행

- 아래 확인 메시지 출력 후 [1.6단계]로 진행:

```
✅ hosts 설정 확인
  local-{GNB_DOMAIN} → 127.0.0.1
  state.json.gnb_required = true (Phase 게이트 GNB 스크립트 검증 활성화)
```

### [1.6단계] HTTPS + Caddy 게이트키퍼 구축 (모든 프로젝트 무조건 실행)

> **목적**: 모든 파생 프로젝트의 로컬 개발 환경을 **HTTPS 표준**으로 통일한다.
> Caddy 단일 데몬이 443 포트를 점유하고 SNI 분기로 N개 프로젝트를 동시 운영한다.
> dev 서버는 평문 HTTP 고포트(8010+)에서 동작 → **sudo 영구 회피**.
>
> 적용 대상:
>   - GNB/INSIGN/NXAS 프로젝트: `_ifwt`/`Bearer` 쿠키가 HTTPS 필수 → 무조건 HTTPS
>   - 일반 프로젝트: 라이브 환경과 동일한 HTTPS 흐름으로 검증 → 인증·쿠키·CSP 회귀를 로컬에서 1차 차단

> ⚠️ **이 단계는 자율 실행 금지 — `AskUserQuestion` 도구로 반드시 사용자 입력 대기**
> mkcert 키체인 등록·`/etc/hosts` 수정·Caddy 시스템 데몬 시작에 sudo 가 1회 필요하다.
> AI 가 대신 실행할 수 없다.

#### [1.6-A] 인증 프로필 결정 (호스트명 결정의 사전 조건)

> 호스트명·NCSR 등록·storageState·fixture 모드가 모두 인증 프로필에서 파생되므로
> 이 단계가 누락되면 INSIGN/NXAS 프로젝트도 잘못된 도메인(`.test`)으로 셋업된다.

`AskUserQuestion` 도구로 사용자에게 인증 프로필을 묻는다. 질문/선택지:

```
질문: 이 프로젝트의 인증 방식을 선택하세요.

선택지:
  A) insign            — 외부 유저 (GameScale Web SDK / _ifwt 쿠키)
                          호스트: local-{프로젝트}.nexon.com
  B) nxas              — 사내 SSO (NXAS / Bearer 토큰)
                          호스트: local-{프로젝트}.nxgd.io
  C) insign-with-nxas  — 외부+사내 모두 사용
                          호스트: local-{프로젝트}.nexon.com (INSIGN 정책 우선)
  D) custom            — 자체 인증 (JWT/세션/NextAuth/Passport/Firebase 등)
                          호스트: local-{프로젝트}.nxgd.io
  E) none              — 인증 없음 (공개 도구·데모·내부 위키 등)
                          호스트: local-{프로젝트}.test
```

`AskUserQuestion` 호출 시 `header: "인증 프로필"`, `multiSelect: false`. 사용자가 "Other"로 직접 입력하면 5가지 정식 키워드 외 값은 거부 후 재질문.

**결과 변수 할당:**

```bash
# AskUserQuestion 응답을 정식 키워드로 매핑 (대소문자·공백·옵션 라벨 정규화)
case "$USER_AUTH_ANSWER" in
  *insign-with-nxas*|*"외부+사내"*) AUTH_PROFILE="insign-with-nxas" ;;
  *insign*|*"외부 유저"*)            AUTH_PROFILE="insign" ;;
  *nxas*|*"사내 SSO"*)               AUTH_PROFILE="nxas" ;;
  *custom*|*"자체"*|*JWT*|*NextAuth*) AUTH_PROFILE="custom" ;;
  *none*|*"인증 없음"*|*"공개"*)       AUTH_PROFILE="none" ;;
  *) echo "ERROR: 알 수 없는 응답 — 5가지 중 선택해주세요"; AUTH_PROFILE=""; ;;
esac

# 빈 값이면 재질문 (보일러플레이트 흐름 정지 방지)
[ -z "$AUTH_PROFILE" ] && {
  echo "AUTH_PROFILE 미결정 — AskUserQuestion 재호출"
  exit 1  # 또는 위 AskUserQuestion 호출로 되돌아감
}

echo "✅ 인증 프로필 확정: $AUTH_PROFILE"
```

**즉시 state.json 영구 저장** (다음 [1.6-B] case 분기 전에):

`auth_profile_pending` 마커가 있다면 함께 제거 (`change-auth-profile.sh` 가 남긴 재셋업 표지):

```
mcp__d2a-harness__update_state({
  patch: { auth_profile: "${AUTH_PROFILE}", auth_profile_pending: null }
})
```

> MCP 호출 실패 시 폴백 — 환경변수 전달로 셸 보간 안전화:
> ```bash
> AUTH_PROFILE_VAL="$AUTH_PROFILE" python3 -c "
> import json, os, pathlib
> p = pathlib.Path('.claude/state.json')
> d = json.loads(p.read_text()) if p.exists() else {}
> d['auth_profile'] = os.environ['AUTH_PROFILE_VAL']
> d.pop('auth_profile_pending', None)  # 재셋업 마커 제거
> p.write_text(json.dumps(d, indent=2, ensure_ascii=False))
> "
> ```

> **변경 시점**: 인증 프로필을 잘못 선택했거나 프로젝트 진행 중 변경이 필요한 경우
> 부록 A (인증 프로필 변경 절차) 를 참조한다.

#### [1.6-B] 호스트명 결정 — 인증 프로필 기반 자동 분기

```bash
# AUTH_PROFILE 은 [1.6-A] 에서 결정된 값을 재사용
# 모든 로컬 개발 환경 도메인은 'local-' 프리픽스 사용 (정책 문서의 'dev-' 는
# Dev EC2 서버를 가리키므로, 로컬 머신과 명확히 구분하기 위함)
case "$AUTH_PROFILE" in
  insign|insign-with-nxas)
    # INSIGN _ifwt 쿠키 정책상 .nexon.com 도메인 강제
    LOCAL_DEV_HOST="local-${PROJECT_SLUG}.nexon.com"
    POLICY_NOTE="INSIGN _ifwt 쿠키 정책 — .nexon.com 강제 (refs/policies/authentication-external.md A-2d)"
    ;;
  nxas)
    # NXAS 단독: 개발 환경 권장 도메인 = .nxgd.io
    # (nexon.com 은 DNS 정식 신청 시 반려 — refs/policies/authentication-nxas.md A-3c)
    LOCAL_DEV_HOST="local-${PROJECT_SLUG}.nxgd.io"
    POLICY_NOTE="NXAS 개발 권장 도메인 (.nxgd.io 는 NCSR DNS 등록 가능)"
    ;;
  custom)
    # 사내 자체 인증: NXAS 와 동일 도메인 카테고리 권장
    LOCAL_DEV_HOST="local-${PROJECT_SLUG}.nxgd.io"
    POLICY_NOTE="자체 인증 — nxgd.io 권장 (라이브 도메인은 별도 결정)"
    ;;
  none|*)
    # 인증 없음: RFC 6761 예약 TLD 로 안전한 격리
    LOCAL_DEV_HOST="local-${PROJECT_SLUG}.test"
    POLICY_NOTE="인증 없음 — RFC 6761 예약 TLD (외부 등록 불가)"
    ;;
esac
```

| 인증 프로필 | 도메인 default | 근거 |
|---|---|---|
| **insign** / **insign-with-nxas** | `local-{프로젝트}.nexon.com` | INSIGN `_ifwt` 쿠키 정책상 `.nexon.com` 강제 |
| **nxas** (사내 단독) | `local-{프로젝트}.nxgd.io` | NXAS 개발 환경 권장 — `.nexon.com` 은 DNS 신청 반려 |
| **custom** (자체 인증) | `local-{프로젝트}.nxgd.io` | 사내 도메인 카테고리 — 라이브 마이그레이션 자유 |
| **none** (인증 없음) | `local-{프로젝트}.test` | RFC 6761 예약 TLD — 외부 격리 |

> **프리픽스 규칙**: 정책 문서의 `dev-{서비스}.{도메인}` 은 Dev EC2 서버(원격 개발 환경)를 의미한다.
> 보일러플레이트는 로컬 개발자 머신을 명확히 구분하기 위해 **`local-` 프리픽스**를 사용한다.
> NCSR Callback URL 등록 시에도 `https://local-{프로젝트}.{nexon.com|nxgd.io}/auth/callback` 로 등록한다.

#### LOCAL_DEV_HOST 영구 저장 (state.json)

호스트명 결정 직후 `local_dev_host` 를 state.json 에 영구 저장한다.
(`auth_profile` 은 [1.6-A] 에서 이미 저장됨 — 중복 저장 방지)

```
mcp__d2a-harness__update_state({
  patch: { local_dev_host: "${LOCAL_DEV_HOST}" }
})
```

> MCP 호출 실패 시 폴백:
> ```bash
> python3 -c "
> import json, pathlib
> p = pathlib.Path('.claude/state.json')
> d = json.loads(p.read_text()) if p.exists() else {}
> d['local_dev_host'] = '${LOCAL_DEV_HOST}'
> p.write_text(json.dumps(d, indent=2, ensure_ascii=False))
> "
> ```

> **`.dev` TLD 사용 금지**: Google 운영 실제 TLD + HSTS preload 등록되어 있어
> 모바일·CI·게스트 머신에서 mkcert root CA 부재 시 영구 차단된다.

#### 셋업 안내 출력

```bash
./scripts/notify-slack.sh "🔐 HTTPS + Caddy 셋업 필요 — 입력 대기 중" "mkcert + Caddy 게이트키퍼를 셋업합니다.\n아래 명령을 터미널에서 직접 실행한 뒤 '완료'를 입력해주세요." || true
```

```
🔐 HTTPS + Caddy 게이트키퍼 셋업 (모든 프로젝트 표준)

아래 명령을 터미널에서 직접 실행해주세요:

  ./scripts/setup-https.sh ${LOCAL_DEV_HOST} frontend

스크립트가 자동 처리하는 것:
  ① mkcert + Caddy 설치 (없으면 brew install)
  ② mkcert 로컬 CA 시스템 키체인 등록 (sudo 1회)
  ③ ${LOCAL_DEV_HOST} 도메인 인증서 발급 (frontend/${LOCAL_DEV_HOST}.pem)
  ④ /etc/hosts 등록 — 127.0.0.1  ${LOCAL_DEV_HOST}  (sudo 1회)
  ⑤ Caddy 시스템 서비스 시작 — 443 점유 (sudo 1회)
  ⑥ dev 서버 포트 자동 할당 (8010 부터 충돌 없는 포트)
  ⑦ Caddy 사이트 등록 — https://${LOCAL_DEV_HOST} → http://localhost:{dev_포트}
  ⑧ frontend/.env.example 갱신 — LOCAL_DEV_HOST, LOCAL_DEV_PORT 자동 추가

⚠️ sudo 가 등장하는 시점은 위 ②④⑤ 뿐이며, 이후 dev 서버 시작에는 sudo 가 필요 없습니다.
   여러 파생 프로젝트가 같은 머신에서 충돌 없이 동시 실행됩니다 (Caddy SNI 분기).

발급 완료 후 "완료"를 입력해주세요.
```

사용자 "완료" 외 다른 입력 시 위 안내 반복. [2단계]로 넘어가지 않는다.

#### 셋업 완료 후 변수 저장

사용자 "완료" 입력 후 아래 변수들을 저장하고 state.json 에 영구 기록:

- `HTTPS_READY = true`
- `LOCAL_DEV_HOST = ${LOCAL_DEV_HOST}`
- `LOCAL_DEV_PORT = {.env.example 의 LOCAL_DEV_PORT 값을 읽어 저장}`
- `HTTPS_CERT_PATH = frontend/${LOCAL_DEV_HOST}.pem`

```
mcp__d2a-harness__update_state({
  patch: {
    https_ready: true,
    local_dev_host: "${LOCAL_DEV_HOST}",
    local_dev_port: {LOCAL_DEV_PORT}
  }
})
```

> MCP 호출 실패 시 폴백: `scripts/state-manager.sh patch https_ready true`

#### 확인 메시지

```
✅ HTTPS + Caddy 셋업 확인

  도메인:  https://${LOCAL_DEV_HOST}     (포트 명시 없음 = 443, Caddy 가 처리)
  dev 서버: http://localhost:${LOCAL_DEV_PORT}  (평문 HTTP — 프론트 dev 서버)
  인증서:  frontend/${LOCAL_DEV_HOST}.pem
  Caddy:   sudo brew services list 로 실행 확인

  state.json.https_ready = true (Phase 게이트 HTTPS 검증 활성화)
```

> **로그인 연동 검증 단계는 `create-spec` Step 2.7 로 통합**되었습니다.
> Stage 1.7 / Stage 2-F 는 모두 폐지되었습니다. 사전조건(frontend/, UI 라우트, 로그인 버튼)이
> `create-spec` Step 2.7 에서 생성되기 때문에, 보일러플레이트 셋업 안에서 실제 로그인 검증을
> 시도하면 검증할 대상이 없습니다.
>
> 실제 로그인 1회 수동 검증 + Playwright storageState 저장은 Step 2.7 의 단일
> Playwright 헤드풀 세션(`./scripts/save-auth-state.sh https://${LOCAL_DEV_HOST}`)에서
> UI 확인과 함께 한 번에 처리됩니다.

### [2단계] 레퍼런스 리서치 (WebSearch 3회 이상)

고정 템플릿을 쓰지 않는다. **실제 레퍼런스를 검색하고 그 결과에서 디자인 방향을 도출한다.**

```
검색 키워드 예시 (프로젝트 도메인에 맞게 조합):
  "{도메인} web design award 2024"
  "best {도메인} UI design inspiration"
  "{핵심 키워드} website design trend 2024"
  "awwwards {도메인} site of the year"
```

검색 결과에서 **시각 밀도·독창성이 높은 사례 5개 이상** 분석 후:
- 각 사례에서 레이아웃 구조, 컬러 전략, 장식 기법 1가지씩 추출
- 추출된 요소들을 프로젝트 성격에 맞게 **3가지 독립적인 방향**으로 조합

→ 결과를 `design/design-direction.md` 레퍼런스 섹션에 먼저 기록

### [3단계] `design/samples.html` 생성

`mkdir -p design` 후 `specs/.template/design/samples-guide.md`를 참조하여
**[2단계]에서 도출한 방향을 그대로 구현**한다.

```
파일: design/samples.html
─────────────────────────────────────────────────────────────
[ 절대 금지 패턴 ]
• Navbar → Hero → Cards 단순 수직 스택
• 3개 샘플이 동일한 레이아웃 구조를 반복
• 모든 섹션 동일 max-width 컨테이너 반복
• 화면 상단 중앙 히어로 영역 — 형태 불문 전면 금지
  (배경+텍스트 오버레이, 중앙정렬 제목+부제+버튼, 풀스크린 랜딩 등 모든 변형)
• 3개 샘플 모두 첫 진입 영역을 서로 다른 레이아웃 대안으로 구성
  (벤토 그리드 / 분할 스크린 / 사이드바+콘텐츠 / 대각선 클리핑 / 매거진 / 타이포 블록 등)
• 카드: grid-cols-3 gap-6 단순 반복
• Primary 단색 + 회색만 사용
• 외부 UI 라이브러리 CDN (Bootstrap, Tailwind CDN 등)
• 트랜지션·애니메이션이 전혀 없는 정적 UI
• max-width 컨테이너에 calc((100vw - 1440px)/2 + Xpx) 패딩 혼용
  (뷰포트 > 1440px 환경에서 내부 콘텐츠가 찌그러짐 — 위 "두 패턴 혼용 절대 금지" 참조)

[ AI 클리셰 금지 — specs/.template/design/samples-guide.md "AI 클리셰" 섹션 필독 ]
• 컬러: #6366f1(Tailwind Indigo) · #8b5cf6(Violet) · #3b82f6(Blue) · Purple→Blue 그래디언트
• 폰트: Poppins+Inter 조합, Inter 단독
• 장식: Glassmorphism 카드 남용, 전체 border-radius 통일, 이모지 아이콘(🚀 ✨ 💡)
• 콘텐츠: Lorem ipsum, "제목 텍스트", 의미 없는 더미 — 실제 서비스 데이터 구조로 대체

[ 3개 샘플 설계 원칙 ]
• 레퍼런스 리서치 결과에서 도출된 방향을 각 샘플에 구현
• 레이아웃 구조 자체가 샘플마다 달라야 함
  (예: 하나는 그리드 모자이크, 하나는 레이어 깊이, 하나는 색 블록 등)
• 각 샘플의 Primary 컬러가 다름
• 도메인 아이콘 4~6개를 inline SVG로 직접 작성하여 배경·카드에 활용

[ 기술 요구사항 ]
• 단일 HTML — CSS·JS 모두 인라인
• Google Fonts @import만 허용
• 상단 고정 탭 바 (A/B/C 전환)
• prefers-reduced-motion 분기
• WCAG AA: 텍스트-배경 대비 4.5:1 이상
• 와이어프레임 수준 금지 — 실제 서비스처럼 렌더링
• 콘텐츠 가로 폭 1440px 제한 — `specs/.template/design/samples-guide.md`의 "콘텐츠 가로 폭 제한" 섹션(패턴 A·B·C)을 반드시 읽고 적용한다.
  ⚠ 핵심 금지 ①: `max-width`가 있는 요소에 `calc((100vw - 1440px)/2 + Xpx)` 패딩을 동시에 사용하면 2K·4K에서 내부 너비 0 수렴.
  ⚠ 핵심 금지 ②: 색 블록 분할·대각선 클리핑 등 배경 전체 너비 내용 섹션(패턴 C)과 `max-width: 1440px` 섹션(패턴 B)을 한 샘플 안에서 혼용하면 wide viewport에서 섹션 간 정렬이 깨진다.

• 상단 오프셋 (필수):
  #tab-bar가 position: fixed이므로 각 .sample 요소에 명시적 padding-top 지정 필수.
  디자인 샘플에는 실제 GNB 스크립트 없음 → body.paddingTop 자동 주입 없음 → CSS에서 직접 지정.
  GNB_REQUIRED = false: padding-top = tab-bar 렌더링 높이 (약 56px)
  GNB_REQUIRED = true:  padding-top = tab-bar 높이 + GNB 플레이스홀더 높이 (약 56 + 60 = 116px)
  ※ create-spec Step 2.7 prototype의 "padding-top 제거 규칙"과 충돌하지 않음 — 적용 대상이 다름

[ GNB_REQUIRED = true 일 때 추가 처리 ]
• 각 샘플 최상단에 GNB 플레이스홀더 바 삽입 (실제 GNB 높이 60px 기준)
• 플레이스홀더는 넥슨 GNB 실제 스타일을 모사 (다크 배경, 넥슨 로고 텍스트, 메뉴·로그인 영역)
• 플레이스홀더: position: fixed; top: {tab-bar높이}px; z-index: 9000 (tab-bar보다 낮게)
• 각 .sample 요소의 padding-top = tab-bar 높이 + GNB 플레이스홀더 높이 (약 116px)
  body.paddingTop 자동 주입 없음 — 플레이스홀더는 스크립트가 아니므로 CSS에서 직접 지정
• 모든 고정(fixed/sticky) 요소의 top 값에 GNB 높이 오프셋 반영 (tab-bar + GNB 합산)
• 샘플 내 자체 Navbar가 있다면 GNB 플레이스홀더 아래에 위치
• 플레이스홀더 우측 하단에 안내 뱃지 표시:
  "⚠ 넥슨 GNB 영역 — 도메인 설정 후 실제 스크립트로 교체됩니다"
─────────────────────────────────────────────────────────────
```

### [4단계] 사용자 안내

파일 생성 완료 후 커밋하고, 브라우저에서 자동으로 연다:

```bash
# design/는 보일러플레이트 .gitignore 대상이므로 파생 프로젝트에서 -f 필요
git add -f design/samples.html design/design-direction.md
git commit -m "feat: design samples generated — stage 1"

# 브라우저 자동 열기 (macOS: open, Linux: xdg-open)
open design/samples.html 2>/dev/null || xdg-open design/samples.html 2>/dev/null || true
./scripts/notify-slack.sh "🎨 디자인 샘플 생성 완료 — 선택 대기 중" "브라우저에서 design/samples.html의 샘플 3종을 확인한 뒤\n채팅창에 A / B / C / D / N 을 입력해주세요." || true
```

그 다음 형식으로 출력한다:

```
🎨 디자인 샘플 3종을 생성했습니다.

참고한 레퍼런스:
  • {레퍼런스 1 — 사이트명 + 차용 포인트}
  • {레퍼런스 2 — 사이트명 + 차용 포인트}
  • {레퍼런스 3 — 사이트명 + 차용 포인트}

브라우저에서 직접 확인해주세요:
→ design/samples.html

┌───────────────────────────────────────────────────────────┐
│ 샘플 A: {방향 — 레퍼런스 기반 한 줄 설명}                │
│ 샘플 B: {방향 — 레퍼런스 기반 한 줄 설명}                │
│ 샘플 C: {방향 — 레퍼런스 기반 한 줄 설명}                │
│ N: NX Basic 1.0v 디자인 시스템 적용 (넥슨 사내 디자인 시스템) │
│ D: 직접 지정 (원하는 방향을 말씀해주세요)                 │
└───────────────────────────────────────────────────────────┘

브라우저에서 샘플을 확인한 뒤 A / B / C / N / D 를 입력해주세요.
```

> **N 선택지(NX Basic) 노출 규칙**: 위 선택지 박스에는 항상 NX Basic 을 함께 제시한다.
> 이는 사용자가 웹 리서치 기반 샘플(A/B/C)과 넥슨 사내 디자인 시스템을 같은 자리에서 비교·선택하게
> 하기 위함이다. NX Basic 개요는 한 줄로 함께 안내한다:
> "N) NX Basic 1.0v — 넥슨 사내 디자인 시스템(컴포넌트 18종·토큰 144개). 선택 시 웹 리서치 없이 NX Basic 토큰을 고정한 채 레이아웃만 다른 샘플 3종을 다시 제시해 비교·선택합니다. (참조: refs/design-systems/nxbasic-1.0v.md)"

### [5단계] 선택 결과 처리

- **A / B / C 선택** → 선택된 샘플의 컬러·폰트·레이아웃 특성을 `design/design-direction.md`에 기록 → Stage 1.5 진행
- **D (직접 지정)** → 사용자 설명을 바탕으로 커스텀 샘플 HTML을 `design/samples.html`에 추가 → 재확인 후 진행
- **N (NX Basic 1.0v)** → `DESIGN_SYSTEM = nxbasic` 로 설정하고 아래 **[NX Basic 샘플 3종]** 절차로 진행 (Stage 1.5 웹 리서치 생략). PRD 키워드 감지로 진입한 경우와 동일하게 처리한다.

### [NX Basic 샘플 3종] DESIGN_SYSTEM = nxbasic 처리

> 진입 경로: ① PRD 키워드 감지(`DESIGN_SYSTEM=nxbasic`), 또는 ② Q5\* [5단계]에서 **N** 선택.
> Stage 1.5 웹 리서치는 생략하되, **NX Basic 토큰을 고정한 채 레이아웃만 다른 디자인 샘플 3종을 생성**하여
> 사용자가 비교·선택하게 한다.

1. **상태·로그 기록** (Q5\* [5단계] N 선택으로 처음 진입한 경우):
   ```
   mcp__d2a-harness__update_state({ patch: { design_system: "nxbasic" } })
   ```
   ```bash
   ./scripts/log-activity.sh DECISION "[DESIGN_SYSTEM]: nxbasic" "👤 Q5* N 선택 — NX Basic 토큰 고정, 샘플 3종 레이아웃 비교" || true
   ./scripts/log-activity.sh POLICY "refs/design-systems/nxbasic-1.0v.md: NX Basic 1.0v 적용 결정" "" || true
   ```

2. **NX Basic 토큰/컴포넌트 조회** — `refs/design-systems/nxbasic-1.0v.md` 를 읽고, Storybook 을 WebFetch 로 조회한다 (MCP 미등록):
   - Introduction: `https://sooyachoco.github.io/NXbasic1.0v/?path=/docs/introduction--docs`
   - 컬러/타이포 토큰: GitHub `src/tokens/colors.css`, `typography.css`, `tokens.ts`
   - 필요한 컴포넌트 문서: `.../components-{이름소문자}--docs`

3. **`design/samples.html` 생성 — NX Basic 토큰 고정, 레이아웃 3종** — `mkdir -p design` 후
   `specs/.template/design/samples-guide.md` 의 **"NX Basic 모드"** 규칙에 따라 샘플 3종을 만든다:
   - 색상·타이포·컴포넌트는 NX Basic 토큰/18종을 그대로 사용한다 (자유 색상·폰트 탐색 금지 — `samples-guide.md` 의 AI 클리셰 색상/폰트 금지 규칙은 **NX Basic 토큰 준수로 갈음**).
   - 3종은 **레이아웃·구성(진입 영역·정보 밀도·배치)만** 서로 다르게 설계한다 (예: 사이드바+콘텐츠 / 벤토 그리드 / 매거진 레이아웃). 레이아웃 다양성·절대 금지 패턴 규칙은 그대로 적용한다.
   - 상단 고정 탭 바(A/B/C 전환), 가로폭 1440px 제한, 마이크로 인터랙션, 접근성 기준은 일반 샘플과 동일하게 충족한다.

4. **사용자 안내·선택** — Q5\* [4단계]·[5단계] 와 동일하게 브라우저로 열고 A/B/C 선택을 받는다.
   안내 박스의 선택지는 NX Basic 레이아웃 방향 3종으로 구성한다 (N 옵션은 이미 NX Basic 확정 상태이므로 제외):
   ```
   ┌───────────────────────────────────────────────────────────┐
   │ 샘플 A: {NX Basic 토큰 + 레이아웃 방향 1 한 줄 설명}      │
   │ 샘플 B: {NX Basic 토큰 + 레이아웃 방향 2 한 줄 설명}      │
   │ 샘플 C: {NX Basic 토큰 + 레이아웃 방향 3 한 줄 설명}      │
   │ D: 직접 지정 (원하는 레이아웃 방향을 말씀해주세요)        │
   └───────────────────────────────────────────────────────────┘
   ```

5. **`design/design-direction.md` 작성** — `specs/.template/design-direction.md` 기반으로,
   색상 시스템·타이포그래피·여백·컴포넌트 스타일을 **NX Basic 토큰 값으로 채우고**, 선택된 샘플의
   **레이아웃 방향**을 함께 기록한다.
   - 맨 위 "디자인 시스템" 항목에 `NX Basic 1.0v (DESIGN_SYSTEM=nxbasic)` 명시.
   - 웹 레퍼런스 섹션은 "NX Basic 디자인 시스템 적용 — 외부 레퍼런스 리서치 생략" 으로 기록.
   - "선택된 디자인 샘플" 항목에 선택된 A/B/C 레이아웃 방향을 기록한다.

6. **커밋 후 Stage 2 로 진행** (Stage 1.5 는 건너뛴다):
   ```bash
   git add -f design/samples.html design/design-direction.md
   git commit -m "feat: NX Basic design samples (3 layouts) generated — stage 1"
   ```

---

## Stage 1.5: 디자인 방향 확정

> ### ⏭ 분기: DESIGN_SYSTEM = nxbasic 이면 이 Stage 1.5 를 건너뛴다
>
> NX Basic 경로에서는 Q5\* [NX Basic 샘플 3종] 절차에서 `design/samples.html`(레이아웃 3종) 선택과
> `design/design-direction.md`(NX Basic 토큰 + 선택된 레이아웃) 기록이 이미 끝났으므로,
> 웹 디자인 리서치(`design-research` 스킬)를 수행하지 않고 곧장 Stage 2 로 진행한다.

Stage 1 Q5* 완료 후, **선택된 디자인 방향을 최종 문서화한다**.
UI 프로토타입은 이 단계에서 구현하지 않는다 — `create-spec` Step 2.7에서 spec.md 확정 후 생성한다.

이 단계는 `/design-research` 스킬로 레퍼런스 조사 및 `design/design-direction.md` 보완만 수행한다.

### 처리 절차

1. `Skill("design-research")` 실행 → `design/design-direction.md` 보완 완료
2. 커밋:
   ```bash
   git add -f design/design-direction.md  # design/는 .gitignore 대상 — -f 필요
   git commit -m "docs: design direction confirmed — {디자인방향명} (stage 1.5)"
   ```
3. Stage 2로 진행

> **프로토타입 생성은 `create-spec` Step 2.7에서 spec.md 기반으로 수행한다.**
> 이 시점에 `prototype/index.html`이 없어도 Stage 2~4 진행에 영향이 없다.

---

## Stage 2: 기술 스택 확정

사용자 UI 확인 완료 후, 백엔드/인프라 기술 스택을 결정한다.

> Stage 2 시작 전 `design/design-direction.md`를 읽어 UI 복잡도·인터랙션 수준을 파악하고,
> 프론트엔드 스택 제안 시 반영한다 (예: 복잡한 상태관리 → 상태관리 라이브러리 포함 여부 판단).

```bash
./scripts/notify-slack.sh "⚙️ Stage 2 — 기술 스택 선택 필요" "AI 제안 기술 스택을 확인하고 채팅창에 수락 또는 변경 사항을 입력해주세요." || true
```

```
⚙️ Stage 2 — 기술 스택

디자인 방향이 확정되었습니다. 이제 기술 스택을 선택합니다.

AI 제안 기술 스택 (프로젝트 특성 + UI 복잡도 기반):
{프로젝트 유형·규모·design-direction.md UI 복잡도에 맞는 최신 안정 버전 제안}

이대로 진행할까요? 다른 스택이 있으시면 말씀해주세요.
```

### Stage 2 완료 후: 계층형 CLAUDE.md 분리 (필수)

**분리 실행 (사용자 확인 없이 자동 진행):**

```bash
# backend/CLAUDE.md 생성
mkdir -p backend
cp specs/.template/backend/CLAUDE.md backend/CLAUDE.md

# frontend/CLAUDE.md 생성
mkdir -p frontend
cp specs/.template/frontend/CLAUDE.md frontend/CLAUDE.md

# GNB 미사용 프로젝트: 넥슨 GNB 컴플라이언스 섹션 제거
# GNB_REQUIRED = true 이면 섹션을 그대로 유지한다
if [ "${GNB_REQUIRED:-false}" = "false" ]; then
  python3 - <<'PY'
import re, pathlib
p = pathlib.Path("frontend/CLAUDE.md")
text = p.read_text()
text = re.sub(r'\n## 넥슨 GNB 컴플라이언스\n.*?\n---\n', '\n---\n', text, flags=re.DOTALL)
p.write_text(text)
print("GNB 섹션 제거 완료")
PY
fi

# React가 아닌 프론트엔드: 컴포넌트 작성 규칙 섹션 제거 (React 전용 파일 구조)
# FRONTEND_FRAMEWORK = react 이면 그대로 유지한다
if [ "${FRONTEND_FRAMEWORK:-react}" != "react" ]; then
  python3 - <<'PY'
import re, pathlib
p = pathlib.Path("frontend/CLAUDE.md")
text = p.read_text()
text = re.sub(r'\n## 컴포넌트 작성 규칙\n.*?\n---\n', '\n---\n', text, flags=re.DOTALL)
p.write_text(text)
print("컴포넌트 작성 규칙 섹션 제거 완료")
PY
fi

# Python이 아닌 백엔드: conftest.py 픽스처 섹션 제거
# BACKEND_LANG = python 이면 그대로 유지한다
if [ "${BACKEND_LANG:-python}" != "python" ]; then
  python3 - <<'PY'
import re, pathlib
p = pathlib.Path("backend/CLAUDE.md")
text = p.read_text()
text = re.sub(r'\n### 테스트 픽스처 공통화.*', '', text, flags=re.DOTALL)
p.write_text(text)
print("conftest.py 섹션 제거 완료")
PY
fi

# Python이 아닌 백엔드: PROGRESS.md "코드 패턴 메모" 섹션을 Node/Express 변형으로 교체
# - 템플릿 기본값은 Python/FastAPI 가정이므로 Node 프로젝트에서는 부적합 placeholder 가 남는다
# - run-phase Step 3-1 ③ 시점에 사용자가 직접 채우지만, 첫 시점부터 올바른 예시가 있어야 가이드 가능
if [ "${BACKEND_LANG:-python}" != "python" ]; then
  python3 - <<'PY'
import pathlib
p = pathlib.Path("PROGRESS.md")
if not p.exists():
    print("PROGRESS.md 없음 — 코드 패턴 메모 교체 생략")
    raise SystemExit(0)
text = p.read_text()

# ① 디렉터리 구조 예시 (FastAPI → Express/Prisma)
old_dir = """예:
backend/
  app/
    api/v1/        ← 라우터
    services/      ← 비즈니스 로직
    models/        ← DB 모델
    schemas/       ← 요청/응답 스키마
  tests/
frontend/
  src/
    components/    ← 공통 컴포넌트
    pages/         ← 페이지 컴포넌트
    hooks/         ← 커스텀 훅"""
new_dir = """예 (Node/Express):
backend/
  src/
    api/v1/        ← 라우터
    services/      ← 비즈니스 로직
    repository/    ← DB 액세스 (Prisma 등)
    middleware/    ← 인증·검증 미들웨어
    lib/           ← Prisma client 싱글톤 등
    utils/         ← sanitize·검증 헬퍼
  tests/
frontend/
  src/
    components/    ← 공통 컴포넌트
    pages/         ← 페이지 컴포넌트
    hooks/         ← 커스텀 훅
    lib/           ← apiClient 등"""
text = text.replace(old_dir, new_dir)

# ② 공통 패턴 표 (FastAPI Depends → Express middleware)
text = text.replace(
    '| 에러 응답 | {예: `{"detail": str, "code": str}`} |',
    '| 에러 응답 | {예: `{ "code": string, "message": string }`} |'
)
text = text.replace(
    '| 인증 주입 | {예: `Depends(require_auth)`} |',
    '| 인증 주입 | {예: `authMiddleware` 라우터 일괄 적용} |'
)
text = text.replace(
    '| DB 세션 | {예: `Depends(get_db)`} |',
    '| DB 세션 | {예: `prisma` 싱글톤 import} |'
)

# ③ 핵심 인터페이스 예시 (Python 파일 → TypeScript 파일)
text = text.replace(
    '| {예: backend/app/middleware/auth.py} | {require_auth} | {Depends 주입, request.state.user 설정} |',
    '| {예: backend/src/middleware/auth.ts} | {authMiddleware} | {Express Request.user 설정} |'
)
text = text.replace(
    '| {예: backend/app/schemas/user.py} | {UserPayload} | {id: int, email: str, role: str} |',
    '| {예: backend/src/types/user.ts} | {UserPayload} | {id: string, email: string, role: string} |'
)

p.write_text(text)
print("PROGRESS.md 코드 패턴 메모 Node/Express 변형 적용 완료")
PY
fi
```

**참고 — 계층형 CLAUDE.md 규칙 구조:**

`specs/.template/frontend/CLAUDE.md`에는 frontend 전용 규칙(design-quality-guard, nexon-gnb-guard)이,
`specs/.template/backend/CLAUDE.md`에는 backend 전용 규칙(ensure-test-coverage, env-management)이 정의되어 있다.
이 규칙들은 루트 CLAUDE.md에 존재하지 않으므로 루트에서 삭제할 내용이 없다 — 템플릿 파일을 복사하는 것으로 분리가 완료된다.

분리 후 루트 CLAUDE.md가 200줄 이하인지 확인한다:
```bash
wc -l CLAUDE.md
# 200줄 초과 시: 추가로 이동 가능한 규칙을 검토하고 사용자에게 보고한다
```

분리 완료를 로그에 기록하고 커밋한다:
```bash
./scripts/log-activity.sh SETUP "CLAUDE.md 계층 분리 완료" "frontend/ + backend/ CLAUDE.md 생성" || true
git add frontend/CLAUDE.md backend/CLAUDE.md CLAUDE.md
git commit -m "chore: split CLAUDE.md into frontend/ and backend/ — stage 2"
```

---

## Stage 2-E: E2E 테스트 설정 (프론트엔드 선택 시 자동 진행)

> **조건**: Stage 2에서 프론트엔드 스택이 확정된 경우에만 진행한다.
> 백엔드 전용 프로젝트(API 서버, CLI 등)이면 이 Stage를 건너뛴다.

```bash
./scripts/notify-slack.sh "🧪 Stage 2-E — E2E 설정 선택 필요" "E2E 테스트 프레임워크를 선택해주세요.\nA) Playwright  B) Cypress  C) 설정 안 함" || true
```

```
🧪 Stage 2-E — E2E 테스트 설정

프론트엔드 프로젝트에 E2E 테스트를 설정합니다.
E2E 통과를 태스크 done 기준으로 연결하면 AI 자율 실행 중
회귀를 자동으로 감지할 수 있습니다.

선택지:
  A) Playwright (권장) — Playwright MCP와 통합, ARIA 기반으로 셀렉터 깨짐 없음
  B) Cypress — 시각 회귀 테스트에 강점, 대규모 스위트에 적합
  C) 설정 안 함 — subagent-review에서 REQUIRED 경고 발생 (나중에 추가 가능)

권장: A (Playwright MCP가 이미 보일러플레이트에 통합되어 있습니다)
```

사용자 답변에 따라 처리:

### A 선택: Playwright 설정

```bash
# 1. Playwright 설치
cd frontend && npx playwright install --with-deps chromium 2>&1 | tail -20

# 2. playwright.config.ts 생성 — HTTPS + Caddy 표준 (모든 프로젝트)
#    .env.example 의 LOCAL_DEV_HOST / LOCAL_DEV_PORT 를 런타임에 읽음
#    CI 환경에서는 Caddy 가 없으므로 평문 localhost:LOCAL_DEV_PORT 로 분기
#    백엔드 dev 서버는 감지된 스택 명령으로 webServer 배열에 자동 추가
BACKEND_DETECT=$(
  if [ -f ../backend/pyproject.toml ] || [ -f ../backend/requirements.txt ]; then
    if grep -qE 'fastapi|uvicorn' ../backend/pyproject.toml ../backend/requirements.txt 2>/dev/null; then
      echo 'fastapi'
    elif grep -qE 'django' ../backend/pyproject.toml ../backend/requirements.txt 2>/dev/null; then
      echo 'django'
    fi
  elif [ -f ../backend/package.json ]; then
    if grep -qE '@nestjs/core' ../backend/package.json 2>/dev/null; then
      echo 'nestjs'
    elif grep -qE '"express"' ../backend/package.json 2>/dev/null; then
      echo 'express'
    fi
  fi
)
case "$BACKEND_DETECT" in
  fastapi) BE_CMD='cd ../backend && uvicorn app.main:app --port ${BE_PORT}'; BE_HEALTH='/health' ;;
  django)  BE_CMD='cd ../backend && python manage.py runserver ${BE_PORT}'; BE_HEALTH='/health/' ;;
  nestjs)  BE_CMD='cd ../backend && npm run start:dev';                       BE_HEALTH='/health' ;;
  express) BE_CMD='cd ../backend && npm run dev';                             BE_HEALTH='/health' ;;
  *)       BE_CMD=''; BE_HEALTH='' ;;
esac

cat > playwright.config.ts << 'EOF'
import { defineConfig, devices } from '@playwright/test';

const HOST = process.env.LOCAL_DEV_HOST ?? 'localhost';
const FE_PORT = process.env.LOCAL_DEV_PORT ?? '8010';
const BE_PORT = process.env.LOCAL_BACKEND_PORT ?? '18010';

// CI 에는 Caddy 가 없으므로 평문 HTTP localhost 로 분기
// 로컬에서는 Caddy 가 SNI 분기로 https://{HOST}:443 → localhost:{FE_PORT}
const BASE_URL = process.env.CI
  ? `http://localhost:${FE_PORT}`
  : `https://${HOST}`;

export default defineConfig({
  testDir: '../tests/e2e',
  // create-spec Step 2.7 통합 검증이 저장한 storageState 디렉터리는 테스트 대상에서 제외 (개인 인증 정보)
  testIgnore: ['**/.auth/**'],
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: [['line'], ['html', { open: 'never' }]],
  use: {
    baseURL: BASE_URL,
    ignoreHTTPSErrors: true,  // mkcert root CA 가 CI 머신에 없을 수 있음
    trace: 'on-first-retry',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  webServer: [
    {
      // 프론트엔드 — 평문 HTTP, Caddy 가 앞단에서 TLS 종단
      command: `npm run dev -- --port ${FE_PORT}`,
      url: `http://localhost:${FE_PORT}`,
      ignoreHTTPSErrors: true,
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
    // {{BACKEND_WEBSERVER_BLOCK}}
  ],
});
EOF

# 백엔드 webServer 블록을 감지된 스택에 따라 치환
# awk 의 -v 인자는 백슬래시 escape 를 자체 해석하므로, 임시파일 r 로 안전하게 삽입
if [ -n "$BE_CMD" ]; then
  BE_BLOCK_FILE=$(mktemp)
  cat > "$BE_BLOCK_FILE" <<BE_EOF
    {
      // 백엔드 — HTTP, 같은 origin 으로 proxy 처리
      command: '${BE_CMD}',
      url: \`http://localhost:\${BE_PORT}${BE_HEALTH}\`,
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
BE_EOF
  awk -v blockfile="$BE_BLOCK_FILE" '
    /{{BACKEND_WEBSERVER_BLOCK}}/ {
      while ((getline line < blockfile) > 0) print line
      close(blockfile)
      next
    }
    { print }
  ' playwright.config.ts > playwright.config.ts.tmp
  mv playwright.config.ts.tmp playwright.config.ts
  rm -f "$BE_BLOCK_FILE"
else
  # 백엔드 미감지 → 주석 라인만 유지 (사용자가 추후 수동 추가)
  awk '/{{BACKEND_WEBSERVER_BLOCK}}/{print "    // 백엔드 미감지 — 필요 시 webServer 배열에 직접 추가"; next}1' playwright.config.ts > playwright.config.ts.tmp
  mv playwright.config.ts.tmp playwright.config.ts
fi

# 3. tests/e2e/ 디렉터리 + smoke 테스트 생성
mkdir -p ../tests/e2e
cat > ../tests/e2e/smoke.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test('메인 화면이 정상 렌더링된다', async ({ page }) => {
  await page.goto('/');
  await expect(page).not.toHaveTitle('Error');
  // TODO: 서비스별 실제 검증 조건으로 교체
  await expect(page.locator('body')).toBeVisible();
});
EOF

# 3-A. 런타임 헬스체크 spec 생성
#   목적: Phase 완료 직전 dev 서버를 띄운 채 핵심 라우트를 방문해
#         콘솔 에러·미처리 Promise rejection·네트워크 4xx/5xx 가 없는지 자동 검증한다.
#         (빌드 통과 ≠ 런타임 통과 갭을 메우는 가드 — subagent-review Step 2-0이 강제)
#
# ROUTES 는 일단 ['/']로 초기 채움. spec.md/PRD 가 작성된 이후
# subagent-review Step 2-0 이 매 Phase 경계마다 scripts/extract-routes.sh 를
# 호출하여 자동 갱신한다.
cat > ../tests/e2e/runtime-health.spec.ts << 'EOF_TPL'
import { test, expect } from '@playwright/test';

// 공개 라우트 — scripts/extract-routes.sh 가 spec.md/PRD 에서 자동 갱신한다.
// 인증이 필요한 라우트는 보호 라우트 e2e 에서 fixtures/auth-mock.ts 의
// authenticatedPage fixture 와 함께 별도 spec 으로 검증한다.
// 사용자가 직접 수정해도 되지만, subagent-review 가 다시 덮어쓸 수 있다.
const ROUTES = ["/"];
EOF_TPL

# spec.md/PRD 가 이 시점에 이미 있으면 즉시 1회 갱신 시도 (없으면 noop)
( cd .. && [ -x scripts/extract-routes.sh ] && ./scripts/extract-routes.sh 2>&1 | tail -1 ) || true

# 다음 부분(EOF로 끝나는 spec 본문)은 변수 치환 없이 그대로 둔다
cat >> ../tests/e2e/runtime-health.spec.ts << 'EOF'

// favicon, sourcemap 등 무시할 패턴
const IGNORED_URL = /favicon\.ico$|\.map($|\?)/;
// 외부 광고/분석 스크립트의 경고 등 노이즈 필터링이 필요하면 여기에 추가한다.
const IGNORED_CONSOLE = /\[HMR\]|DevTools/;

test('런타임 헬스체크 — 콘솔 에러·네트워크 실패 없음', async ({ page }) => {
  const consoleErrors: string[] = [];
  const failedRequests: string[] = [];

  page.on('console', msg => {
    if (msg.type() === 'error' && !IGNORED_CONSOLE.test(msg.text())) {
      consoleErrors.push(msg.text());
    }
  });
  page.on('pageerror', err => consoleErrors.push(`pageerror: ${err.message}`));
  page.on('requestfailed', req => {
    if (!IGNORED_URL.test(req.url())) {
      failedRequests.push(`${req.method()} ${req.url()} — ${req.failure()?.errorText}`);
    }
  });
  page.on('response', res => {
    if (res.status() >= 400 && !IGNORED_URL.test(res.url())) {
      failedRequests.push(`${res.status()} ${res.url()}`);
    }
  });

  for (const route of ROUTES) {
    await page.goto(route, { waitUntil: 'networkidle' });
  }

  expect(consoleErrors, `콘솔 에러:\n${consoleErrors.join('\n')}`).toEqual([]);
  expect(failedRequests, `네트워크 실패:\n${failedRequests.join('\n')}`).toEqual([]);
});
EOF

# 3-B. 로그인이 필요한 프로젝트 감지 → auth-mock fixture 자동 생성
#   인증 시그널을 .env / 코드 / 의존성에서 탐지해 모드(insign/nxas/custom)를 판별한다.
#   3가지 모드를 모두 지원하는 통합 fixture 를 생성하고 감지된 모드를 기본값으로 설정한다.
#   인증 시그널이 전혀 없으면(완전 공개 사이트) 이 단계는 생략된다.
#
#   refs/policies/authentication*.md 인증 정책 매핑:
#     insign  — refs/policies/authentication-external.md (GameScale Web SDK / _ifwt)
#     nxas    — refs/policies/authentication-nxas.md (사내 SSO / Bearer)
#     custom  — JWT/세션/NextAuth/Passport 등 자체 구현
AUTH_MODE="none"
ENV_FILES="../frontend/.env.example ../frontend/.env.local ../.env.example ../.env.local ../backend/.env.example"
SRC_DIRS="../frontend/src ../src ../app ../backend"

# INSIGN/외부 유저 (GameScale Web SDK)
if (grep -lhE '^(NEXT_PUBLIC_GID|NEXT_PUBLIC_LOCAL_DEV_HOST|VITE_GNB_GAME_CODE|NEXT_PUBLIC_INFACE_|VITE_INFACE_)' $ENV_FILES 2>/dev/null | head -1 | grep -q .) \
   || grep -rqE 'inface\.js|signin\.nexon\.com|getUserProfile|_ifwt' $SRC_DIRS 2>/dev/null; then
  AUTH_MODE="insign"
fi

# NXAS (사내 SSO)
if [ "$AUTH_MODE" = "none" ]; then
  if (grep -lhE '^(NEXT_PUBLIC_NXAS|NXAS_CLIENT|NXAS_REDIRECT)|^EMPNO=' $ENV_FILES 2>/dev/null | head -1 | grep -q .) \
     || grep -rqE 'nxas\.nexon\.com|\bEMPNO\b|\bDEPTCode\b' $SRC_DIRS 2>/dev/null; then
    AUTH_MODE="nxas"
  fi
fi

# 자체 인증 (JWT / 세션 / NextAuth / Passport / Clerk / Supabase / Firebase / Auth0 / MSAL / SAML 등)
if [ "$AUTH_MODE" = "none" ]; then
  AUTH_DEPS=$(jq -s -r '[.[].dependencies // {}, .[].devDependencies // {}] | add | keys[]' \
    ../frontend/package.json ../package.json ../backend/package.json 2>/dev/null \
    | grep -E '^(jsonwebtoken|next-auth|@auth/|passport(-[a-z-]+)?|bcrypt(js)?|@nestjs/jwt|@nestjs/passport|iron-session|lucia|@clerk/|@supabase/auth-helpers|firebase(-admin)?|@firebase/auth|@auth0/|^auth0$|@azure/msal|oidc-client-ts|react-oidc-context|samlify)' \
    | head -1)
  AUTH_ENV=$(grep -lhE '^(JWT_SECRET|SESSION_SECRET|NEXTAUTH_SECRET|AUTH_SECRET|COOKIE_SECRET|REFRESH_TOKEN_SECRET|CLERK_SECRET|SUPABASE_JWT|FIREBASE_PRIVATE_KEY|AUTH0_SECRET|AZURE_AD_CLIENT_SECRET|SAML_CERT)=' $ENV_FILES 2>/dev/null | head -1)
  AUTH_DIR=$(find $SRC_DIRS -type d \( -name "auth" -o -name "authentication" \) 2>/dev/null | head -1)
  if [ -n "$AUTH_DEPS$AUTH_ENV$AUTH_DIR" ]; then
    AUTH_MODE="custom"
  fi
fi

# 화이트리스트 — AUTH_MODE 가 의도하지 않은 값으로 오염되는 것을 차단
case "$AUTH_MODE" in
  insign|nxas|custom|none) ;;
  *) AUTH_MODE="none" ;;
esac

echo "감지된 인증 모드: $AUTH_MODE"

if [ "$AUTH_MODE" != "none" ]; then
  mkdir -p ../tests/e2e/fixtures
  cat > ../tests/e2e/fixtures/auth-mock.ts << EOF
/**
 * 로그인이 필요한 프로젝트의 e2e 인증 fixture.
 *
 * 자동 감지된 인증 모드: ${AUTH_MODE}
 *   - insign : INSIGN/외부 유저 (GameScale Web SDK / _ifwt 쿠키)
 *   - nxas   : 사내 SSO (NXAS / Bearer 토큰)
 *   - custom : 자체 인증 (JWT / 세션 / NextAuth / Passport / Clerk 등)
 *
 * ⚠️ 동작 방식 (환경별 자동 분기):
 *   - 로컬 (process.env.CI 미설정):
 *       create-spec Step 2.7 통합 검증의 save-auth-state.sh 가 저장한 tests/e2e/.auth/user.json
 *       (실제 로그인 storageState) 을 재사용한다.
 *       → 실제 인증 흐름이 매 e2e 마다 검증된다.
 *   - CI (process.env.CI=true):
 *       위 storageState 가 없으므로 모드별 모킹(injectInsignMock 등) 으로 대체.
 *       → 빠르고 secret 노출 없이 보호 라우트 검증 가능.
 *
 * 사용 예시:
 *   import { test, expect } from '../fixtures/auth-mock';
 *   test('보호 라우트', async ({ authenticatedPage: page }) => {
 *     await page.goto('/dashboard');
 *     await expect(page.getByText('환영합니다')).toBeVisible();
 *   });
 *
 * 모드 변경:
 *   - 전역: 아래 DEFAULT_AUTH_MODE 상수 수정
 *   - 개별 spec: test.use({ authMode: 'custom' });
 *
 * ⚠️ 이 fixture 는 로컬·CI e2e 전용. 스테이지/라이브 환경에서는 절대 사용하지 않는다.
 */
import { test as base, expect, type Page, type BrowserContext } from '@playwright/test';
import * as fs from 'node:fs';
import * as path from 'node:path';

export type AuthMode = 'insign' | 'nxas' | 'custom';
export const DEFAULT_AUTH_MODE: AuthMode = '${AUTH_MODE}' as AuthMode;

// HTTPS 표준(Stage 1.6 셋업) 기준 — Caddy 가 https://\${LOCAL_DEV_HOST} 로 종단 처리
// 쿠키 주입 시 도메인을 동적으로 사용하여 실서비스 도메인 오염 위험을 차단
const LOCAL_DEV_HOST: string = process.env.LOCAL_DEV_HOST ?? 'localhost';

// 보안 가드 — fixture 는 로컬 개발 도메인에서만 동작해야 한다.
// 실서비스 환경 변수가 오염되어 production 도메인에 mock 쿠키가 주입되는 것을 차단한다.
// 허용 패턴 (Stage 1.6 정책):
//   - localhost                              (CI 평문 fallback)
//   - local-*.test                           (인증 없는 프로젝트, RFC 6761)
//   - local-*.nxgd.io                        (NXAS 단독·custom 사내 인증)
//   - local-*.nexon.com                      (INSIGN/혼합 — 정책 강제)
const ALLOWED_DOMAIN_RE =
  /^(localhost|local-[a-z0-9-]+\\.(test|nxgd\\.io|nexon\\.com))$/;
if (!ALLOWED_DOMAIN_RE.test(LOCAL_DEV_HOST)) {
  throw new Error(
    \`auth-mock fixture 는 로컬 개발 도메인에서만 사용 가능합니다 — LOCAL_DEV_HOST=\${LOCAL_DEV_HOST}\`
  );
}

// CI 환경에서는 평문 HTTP localhost 로 동작 (playwright.config.ts 의 baseURL 분기와 일치)
// 따라서 secure 쿠키는 CI 가 아닌 로컬 HTTPS 환경에서만 활성화한다.
const COOKIE_SECURE: boolean = !process.env.CI && LOCAL_DEV_HOST !== 'localhost';

// ───────── 1) INSIGN 모드 (GameScale Web SDK) ─────────
export interface InsignMockUser {
  uid: string;
  platform_type: 'krpc' | 'jppc' | 'arena_west' | 'arena_th' | 'arena_tw' | 'arena_sea';
  platform_user_id: string;
  is_guest?: boolean;
}

export const DEFAULT_INSIGN_USER: InsignMockUser = {
  uid: 'e2e-test-uid-001',
  platform_type: 'krpc',
  platform_user_id: 'TEST-MEMBER-001',
  is_guest: false,
};

export async function injectInsignMock(page: Page, user: InsignMockUser = DEFAULT_INSIGN_USER) {
  await page.route('**/sdk/inface.js', route =>
    route.fulfill({
      body: '/* inface.js mocked for e2e */',
      headers: { 'content-type': 'application/javascript' },
    })
  );
  await page.addInitScript((mockUser) => {
    (window as unknown as { inface: unknown }).inface = {
      auth: {
        isSignedIn: () => true,
        gotoSignIn: () => {},
        gotoSignOut: () => {},
        getUserProfile: async () => ({ data: mockUser, error: null }),
        webToken: 'e2e-mock-web-token',
      },
    };
  }, user);
}

// ───────── 2) NXAS 모드 (사내 SSO) ─────────
export interface NxasMockUser {
  uid: string;
  empno: string;
  deptCode: string;
  email?: string;
  displayName?: string;
}

export const DEFAULT_NXAS_USER: NxasMockUser = {
  uid: 'e2e-test-empno',
  empno: 'E12345',
  deptCode: 'D001',
  email: 'test@nexon.co.kr',
  displayName: 'E2E Test User',
};

export interface NxasMockOptions {
  /** Bearer 토큰 쿠키 이름 (기본: 'NXAS_TOKEN') */
  tokenCookieName?: string;
  /** 사용자 정보 엔드포인트 glob 패턴 (기본은 모든 origin 의 /api/me) */
  userInfoUrl?: string;
}

export async function injectNxasMock(
  context: BrowserContext,
  user: NxasMockUser = DEFAULT_NXAS_USER,
  options: NxasMockOptions = {}
) {
  const { tokenCookieName = 'NXAS_TOKEN', userInfoUrl = '**/api/me' } = options;

  await context.addCookies([{
    name: tokenCookieName,
    value: 'e2e-mock-nxas-bearer-token',
    domain: LOCAL_DEV_HOST,
    path: '/',
    httpOnly: false,
    secure: COOKIE_SECURE,
    sameSite: 'Lax',
  }]);

  await context.route(userInfoUrl, route =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(user),
    })
  );
}

// ───────── 3) 자체 인증 모드 (JWT / 세션 / NextAuth 등) ─────────
export interface CustomMockUser {
  uid: string;
  email?: string;
  displayName?: string;
  roles?: string[];
}

export const DEFAULT_CUSTOM_USER: CustomMockUser = {
  uid: 'e2e-test-user-001',
  email: 'test@example.com',
  displayName: 'E2E Test User',
  roles: ['user'],
};

export interface CustomAuthMockOptions {
  /** localStorage 키 (예: 'access_token'). null 이면 localStorage 주입 생략 */
  tokenStorageKey?: string | null;
  /** 토큰 값 */
  tokenValue?: string;
  /** 사용자 정보 엔드포인트 glob 패턴 (기본은 모든 origin 의 /api/auth/me) */
  userInfoUrl?: string;
  /** 추가 쿠키 (NextAuth 의 'next-auth.session-token' 등) */
  cookies?: Array<{ name: string; value: string }>;
}

export async function injectCustomAuthMock(
  context: BrowserContext,
  user: CustomMockUser = DEFAULT_CUSTOM_USER,
  options: CustomAuthMockOptions = {}
) {
  const {
    tokenStorageKey = 'access_token',
    tokenValue = 'e2e-mock-jwt-token',
    userInfoUrl = '**/api/auth/me',
    cookies = [],
  } = options;

  if (tokenStorageKey) {
    await context.addInitScript(([key, val]) => {
      window.localStorage.setItem(key as string, val as string);
    }, [tokenStorageKey, tokenValue] as const);
  }

  if (cookies.length > 0) {
    await context.addCookies(
      cookies.map(c => ({
        ...c,
        domain: LOCAL_DEV_HOST,
        path: '/',
        httpOnly: false,
        secure: COOKIE_SECURE,
        sameSite: 'Lax' as const,
      }))
    );
  }

  await context.route(userInfoUrl, route =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(user),
    })
  );
}

// ───────── 통합 fixture (CI/로컬 자동 분기) ─────────
const STORAGE_STATE_PATH = path.resolve(__dirname, '../.auth/user.json');
const STORAGE_MAX_AGE_DAYS = 30;

interface StoredOrigin {
  origin: string;
  localStorage: Array<{ name: string; value: string }>;
}
interface StoredCookie {
  name: string; value: string; domain: string; path: string;
  expires?: number; httpOnly?: boolean; secure?: boolean;
  sameSite?: 'Strict' | 'Lax' | 'None';
}
interface StorageState {
  cookies?: StoredCookie[];
  origins?: StoredOrigin[];
}

// 정책(authentication-external.md A-4b): INSIGN/GNB 세션 만료는 서버 측 관리.
// 따라서 파일 mtime 이 아니라 storageState 안의 인증 쿠키 `expires` 가 단일 신뢰원.
// mtime STORAGE_MAX_AGE_DAYS 는 보조 안전망으로만 사용한다.
const AUTH_COOKIE_NAMES = ['_ifwt', 'NXAS_TOKEN', 'access_token', 'authToken', 'next-auth.session-token'];

function isStorageStateUsable(): boolean {
  if (!fs.existsSync(STORAGE_STATE_PATH)) return false;
  let state: StorageState;
  try {
    state = JSON.parse(fs.readFileSync(STORAGE_STATE_PATH, 'utf8')) as StorageState;
  } catch {
    console.warn('⚠️  storageState 파싱 실패 — auth-mock fallback');
    return false;
  }

  const auth = (state.cookies ?? []).filter(c =>
    AUTH_COOKIE_NAMES.some(n => c.name?.toLowerCase().includes(n.toLowerCase()))
  );
  if (auth.length === 0) {
    console.warn('⚠️  storageState 에 인증 쿠키 없음 — auth-mock fallback');
    return false;
  }

  // Playwright 는 세션 쿠키를 expires 없음/-1/0 으로 직렬화한다 → 브라우저 종료 시 만료 = stale
  const persistent = auth.filter(c => typeof c.expires === 'number' && c.expires > 0);
  if (persistent.length === 0) {
    console.warn('⚠️  storageState 인증 쿠키가 모두 세션 쿠키 (정책상 만료 처리) — auth-mock fallback');
    return false;
  }

  const now = Math.floor(Date.now() / 1000);
  const maxExp = Math.max(...persistent.map(c => c.expires as number));
  if (maxExp < now) {
    console.warn(`⚠️  storageState 인증 쿠키 만료: ${Math.floor((now - maxExp) / 86400)}일 경과 — auth-mock fallback`);
    return false;
  }

  // 안전망 — 서버 만료 캡처 누락 가능성 대비
  const ageDays = (Date.now() - fs.statSync(STORAGE_STATE_PATH).mtimeMs) / 86_400_000;
  if (ageDays > STORAGE_MAX_AGE_DAYS) {
    console.warn(`⚠️  storageState 파일 ${Math.floor(ageDays)}일 경과 (한도 ${STORAGE_MAX_AGE_DAYS}일) — auth-mock fallback`);
    return false;
  }

  return true;
}

async function applyStorageState(context: BrowserContext): Promise<void> {
  // 기존 context 에 storageState 를 적용해 test.use({...}) 옵션을 보존한다.
  const state: StorageState = JSON.parse(fs.readFileSync(STORAGE_STATE_PATH, 'utf8'));
  if (state.cookies?.length) {
    await context.addCookies(state.cookies);
  }
  if (state.origins?.length) {
    // localStorage 는 페이지 초기화 시점에 주입되어야 하므로 addInitScript 사용
    await context.addInitScript((origins: StoredOrigin[]) => {
      const current = origins.find(o => o.origin === location.origin);
      if (current) {
        for (const item of current.localStorage) {
          window.localStorage.setItem(item.name, item.value);
        }
      }
    }, state.origins);
  }
}

type AuthFixtures = {
  authenticatedPage: Page;
  authMode: AuthMode;
};

export const test = base.extend<AuthFixtures>({
  authMode: [DEFAULT_AUTH_MODE, { option: true }],
  authenticatedPage: async ({ page, context, authMode }, use) => {
    const useStorageState = !process.env.CI && isStorageStateUsable();

    if (useStorageState) {
      // 로컬: create-spec Step 2.7 통합 검증에서 저장한 실제 로그인 storageState 를 기존 context 에 적용
      // (test.use 옵션·viewport·locale 등 호출자 설정을 그대로 보존)
      await applyStorageState(context);
    } else {
      // CI 또는 storageState 없음/만료 → 모드별 모킹
      if (!process.env.CI && !fs.existsSync(STORAGE_STATE_PATH)) {
        const host = process.env.LOCAL_DEV_HOST || '<LOCAL_DEV_HOST>';
        console.warn(
          '⚠️  tests/e2e/.auth/user.json 없음 — auth-mock 모킹으로 fallback. ' +
          `실제 로그인 검증을 위해 ./scripts/save-auth-state.sh https://${host} 실행 권장.`
        );
      }
      switch (authMode) {
        case 'insign':
          await injectInsignMock(page);
          break;
        case 'nxas':
          await injectNxasMock(context);
          break;
        case 'custom':
          await injectCustomAuthMock(context);
          break;
      }
    }
    await use(page);
  },
});

export { expect };
EOF
fi

# 4. package.json에 test:e2e 스크립트 추가 (framework 설치 후에만 실행)
cd .. && if [ -f frontend/package.json ]; then
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('frontend/package.json', 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts['test:e2e'] = 'playwright test';
pkg.scripts['test:e2e:ui'] = 'playwright test --ui';
pkg.scripts['test:e2e:health'] = 'playwright test tests/e2e/runtime-health.spec.ts';
fs.writeFileSync('frontend/package.json', JSON.stringify(pkg, null, 2) + '\n');
console.log('test:e2e 스크립트 추가 완료');
"
else
  echo "⚠️  frontend/package.json 없음 — 프레임워크 설치 후 아래를 수동으로 추가하세요:"
  echo '   "test:e2e": "playwright test"'
  echo '   "test:e2e:ui": "playwright test --ui"'
  echo '   "test:e2e:health": "playwright test tests/e2e/runtime-health.spec.ts"'
fi
```

완료 후:
```bash
git add frontend/playwright.config.ts tests/e2e/
[ -f frontend/package.json ] && git add frontend/package.json
git commit -m "chore: playwright e2e 설정 + smoke/runtime-health test — stage 2-E"
AUTH_NOTE=""
[ -f tests/e2e/fixtures/auth-mock.ts ] && AUTH_NOTE=" + auth-mock fixture (mode=${AUTH_MODE})"
./scripts/log-activity.sh SETUP "E2E 설정 완료 (Playwright)" "smoke.spec.ts + runtime-health.spec.ts 생성${AUTH_NOTE}" || true
```

출력:
```
✅ Playwright E2E 설정 완료

생성된 파일:
  • frontend/playwright.config.ts        — Playwright 설정 (webServer + trace/video/screenshot)
  • tests/e2e/smoke.spec.ts              — 메인 화면 smoke 테스트
  • tests/e2e/runtime-health.spec.ts     — 콘솔 에러·네트워크 실패 자동 검증 (Phase 완료 게이트)
  • tests/e2e/fixtures/auth-mock.ts      — 로그인 필요 프로젝트 감지 시 생성 (인증 모킹 fixture)
                                          감지된 모드: ${AUTH_MODE} (insign / nxas / custom / none)
  • frontend/package.json                — test:e2e / test:e2e:ui / test:e2e:health 스크립트

다음 단계:
  tasks.md 작성 시 프론트엔드 기능 태스크에 아래 done 기준을 추가하면
  AI가 직접 회귀를 감지합니다:
    done:
      - cmd: cd frontend && npm run build
      - cmd: npx playwright test tests/e2e/{feature}.spec.ts --reporter=line

  Phase 완료 직전 subagent-review Step 2-0 이 자동으로 다음을 실행합니다:
      - cmd: npx playwright test tests/e2e/runtime-health.spec.ts
    → 사용자 핸드오프 전 JS 런타임 에러를 1차 차단합니다.

  로그인이 필요한 프로젝트는 보호 라우트 e2e 작성 시 다음 패턴을 사용합니다:
      import { test, expect } from '../fixtures/auth-mock';
      test('보호 라우트 동작', async ({ authenticatedPage: page }) => { ... });
    감지된 인증 모드(insign/nxas/custom)에 맞는 모킹이 자동 적용됩니다.
    개별 spec 에서 모드 오버라이드: test.use({ authMode: 'custom' });

⚠️  fixture 의 production 유입 차단 (권장):
    tests/e2e/ 는 일반적으로 빌드 대상 외이지만, 안전을 위해 다음을 추가하세요:
      • frontend/tsconfig.json :  "exclude": ["tests/**"]
      • frontend/.eslintrc     :  no-restricted-imports → patterns: ["**/tests/e2e/**"]
    fixture 자체는 토큰 값이 'e2e-mock-*' 고정이고 domain='localhost' 한정이라
    실수로 import 되어도 실서비스 도메인에 영향을 줄 수 없습니다.

⚠️  Stage 2-E는 create-spec Step 2.7 이전(frontend/ 초기화 전)에도 실행 가능하다.
   create-spec Step 2.7에서 React 앱을 초기화한 뒤
   playwright.config.ts의 webServer 설정이 실제 dev 명령과 일치하는지 확인하고,
   필요 시 Stage 2-E를 다시 실행하여 smoke 테스트를 업데이트한다.
```

### B 선택: Cypress 설정

```bash
# 1. Cypress 설치
cd frontend && npm install --save-dev cypress

# 2. cypress.config.ts 생성
cat > cypress.config.ts << 'EOF'
import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3000',
    specPattern: '../tests/e2e/**/*.cy.ts',
    supportFile: false,
  },
});
EOF

# 3. tests/e2e/ 디렉터리 + smoke 테스트 생성
mkdir -p ../tests/e2e
cat > ../tests/e2e/smoke.cy.ts << 'EOF'
describe('smoke', () => {
  it('메인 화면이 정상 렌더링된다', () => {
    cy.visit('/');
    cy.get('body').should('be.visible');
    // TODO: 서비스별 실제 검증 조건으로 교체
  });
});
EOF

# 4. package.json에 test:e2e 스크립트 추가 (framework 설치 후에만 실행)
cd .. && if [ -f frontend/package.json ]; then
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('frontend/package.json', 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts['test:e2e'] = 'cypress run';
pkg.scripts['test:e2e:open'] = 'cypress open';
fs.writeFileSync('frontend/package.json', JSON.stringify(pkg, null, 2) + '\n');
console.log('test:e2e 스크립트 추가 완료');
"
else
  echo "⚠️  frontend/package.json 없음 — 프레임워크 설치 후 아래를 수동으로 추가하세요:"
  echo '   "test:e2e": "cypress run"'
  echo '   "test:e2e:open": "cypress open"'
fi
```

완료 후:
```bash
git add frontend/cypress.config.ts tests/e2e/
[ -f frontend/package.json ] && git add frontend/package.json
git commit -m "chore: cypress e2e 설정 + smoke test — stage 2-E"
./scripts/log-activity.sh SETUP "E2E 설정 완료 (Cypress)" "tests/e2e/smoke.cy.ts 생성" || true
```

### C 선택: 설정 안 함

```bash
./scripts/log-activity.sh SETUP "E2E 설정 건너뜀" "subagent-review에서 FE 변경 시 REQUIRED 경고 발생" || true
```

출력:
```
⚠️ E2E 설정을 건너뜁니다.

나중에 추가하려면:
  Playwright: cd frontend && npx playwright init
  Cypress:    cd frontend && npm install --save-dev cypress

프론트엔드 파일을 변경하는 Phase의 subagent-review(Step 2-0)에서
[REQUIRED] E2E 미설정 경고가 발생합니다.
```

---

## Stage 2-F: ⚠️ 폐지됨 — create-spec Step 2.7 로 통합

> **이 Stage 는 더 이상 별도 실행되지 않는다.**
>
> 원래 Stage 2-F 가 수행하던 "실제 로그인 1회 수동 검증 + storageState 저장" 은
> `create-spec` Step 2.7 (UI 프로토타입 빌드 + HTTPS 통합 검증) 에 흡수되었다.
>
> **변경 이유**:
>   - Stage 2-F 의 사전조건(frontend/ + UI 라우트 + 로그인 버튼) 은 `create-spec` Step 2.7
>     에서 생성되므로, Stage 2-F 가 `boilerplate-setup` 안에서 실행되면 검증할 대상이 없었다.
>   - 사용자 입장에서 UI 확인과 실제 로그인 검증이 같은 브라우저 세션에서 동시에 끝나는 것이
>     단순하고, 두 단계를 분리할 실익이 없다.
>
> **통합 후 흐름** (AUTH_PROFILE != 'none' 인 경우):
>
> ```
> boilerplate-setup
>   └ Stage 1.6-A   인증 프로필 결정 (AskUserQuestion)
>   └ Stage 1.6-B   HTTPS + Caddy 셋업 (setup-https.sh)
>   └ Stage 2-E     Playwright config 셋업 (frontend 없어도 선행 실행 가능)
>   └ Stage 3~4     인프라/인증 설정
> create-spec
>   └ Step 2.7      UI 프로토타입 빌드
>                   + save-auth-state.sh 단일 Playwright 세션
>                     → UI 확인 + 실제 로그인 + storageState 자동 저장
>                   + state.json.auth_storage_ready = true 갱신
> ```
>
> **AUTH_PROFILE = 'none' 인 경우**: 로그인 자체가 없으므로 storageState 단계는 항상 건너뜀.
>
> 만료/재발급 정책은 변경되지 않았다 — 30일 만료 시 `save-auth-state.sh https://${LOCAL_DEV_HOST}`
> 를 재실행하면 갱신되며, `subagent-review` Step 2-0 이 만료를 감지해 Blocker 로 알린다.

---

## Stage 3~4: 인프라 / 인증 설정 (+ GNB 환경변수)

CLAUDE.md의 `check-policy-refs` 규칙에 따라 `refs/policies/` 문서를 먼저 참조한 뒤 질문한다.

```bash
./scripts/notify-slack.sh "⚙️ Stage 3~4 — 인프라·인증 입력 필요" "클라우드 환경·인증 방식·DB 선호를 채팅창에 입력해주세요." || true
```

```
⚙️ Stage 3~4 — 인프라 / 인증

Q6. 클라우드 환경을 알려주세요:
  A) AWS (ap-northeast-2 — 서울)
  B) AWS (기타 리전)
  C) 사내 IDC / 온프레미스
  D) 미정 (AI 제안 받겠습니다)

Q7. 인증 방식을 선택해주세요:
  A) 사내 직원만 (NXAS SSO)
  B) 외부 넥슨 유저 (GameScale Web SDK / INSIGN)
  C) 둘 다 (사내 + 외부)
  D) 인증 없음 (공개 서비스)

Q8. DB / 캐시 선호가 있나요?
  A) AI 제안에 맡기겠습니다
  B) 직접 지정: (입력)
```

Q6~Q8 답변 수신 후:
- Q6가 D이면 → refs/INDEX.md B-1 기준으로 AI 제안
- Q7에 따라 → 아래 "인증 처리 로직" 실행
- Q8이 A이면 → refs/INDEX.md B-4 기준으로 AI 제안 → 사용자 확인

---

### 인증 처리 로직 (Q6 기준)

#### Q7-A: 사내 직원만 (NXAS SSO)

`refs/policies/authentication-nxas.md`를 읽고 아래를 처리한다.

**사전 발급 게이트 안내 (필수):**
```
🔐 NXAS SSO 연동 사전 준비

아래 항목을 NCSR에서 신청해야 개발을 시작할 수 있습니다.

[1] 클라이언트 등록 (client_id 발급)
  → https://ncsr.nexon.com/CSR/Write/23/161
  → 필요 정보: 클라이언트 이름, 인증 유형, Callback URL, Logout URL

[2] 네트워크 ACL (Dev/Stage 환경 접근)
  → https://ncsr.nexon.com/CSR/Write/16/327

  ⚠ localhost·*.test 는 NXAS Callback URL 허용 카테고리가 아닙니다.
    Stage 1.6 의 setup-https.sh 가 hosts 등록·인증서 발급·Caddy 사이트 등록을 자동 처리합니다.
    NXAS Callback URL 패턴: https://local-{서비스}.nxgd.io/auth/callback
    (.nxgd.io 는 NCSR DNS 정식 등록도 가능 — refs/policies/authentication-nxas.md A-3c)

client_id가 발급되면 알려주세요 (또는 추후 수집으로 건너뛰기: "나중에").
```

```bash
./scripts/notify-slack.sh "🔐 NXAS client_id 신청 필요 — 입력 대기 중" "NCSR에서 client_id를 신청해야 합니다.\nhttps://ncsr.nexon.com/CSR/Write/23/161\n발급 완료 후 채팅창에 client_id를 입력하거나 '나중에'를 입력하세요." || true
```

**사용자 응답 처리:**
- client_id 입력 시 → `.env.example`에 바로 기록
- "나중에" 입력 시 → `prerequisites.md`에 ⬜ 미수집으로 기록, 계속 진행

**.env.example 추가:**
```
NXAS_CLIENT_ID=                                                      # required
NXAS_CLIENT_SECRET=                                                  # required
NXAS_CALLBACK_URL=https://local-{서비스}.nxgd.io/auth/callback        # required (로컬 — Stage 1.6)
NXAS_ENV=dev                                                         # optional (dev | stage | live)
```

**CLAUDE.md에서 INFACE 섹션 제거 (NXAS는 INFACE Gateway 미사용):**
```bash
python3 - <<'PY'
import re, pathlib

# frontend: INFACE API 호출 패턴 섹션 제거
fe = pathlib.Path("frontend/CLAUDE.md")
if fe.exists():
    text = fe.read_text()
    text = re.sub(r'\n## API 호출 패턴.*', '', text, flags=re.DOTALL)
    fe.write_text(text)
    print("frontend INFACE 섹션 제거 완료")

# backend: INFACE API Gateway 인증 섹션 제거
be = pathlib.Path("backend/CLAUDE.md")
if be.exists():
    text = be.read_text()
    text = re.sub(r'\n## INFACE API Gateway 인증\n.*', '', text, flags=re.DOTALL)
    be.write_text(text)
    print("backend INFACE 섹션 제거 완료")
PY
```

---

#### Q7-B: 외부 넥슨 유저 (INSIGN) — **INSIGN 필수 연동**

> **INSIGN은 외부 유저 대상 넥슨 서비스의 표준 인증 방식이다. 선택이 아닌 필수다.**
> `refs/policies/authentication-external.md` A-1b · A-2d · A-7 · A-9를 읽고 처리한다.

**Step 1 — GID 확인:**
- `GNB_GID`가 이미 수집됐으면 재사용 (Stage 1 [1.5단계] 수집값)
- 미수집이면 수집:
  ```
  🎮 GID(게임 식별자) 확인
  INSIGN + INFACE API Gateway에 필수입니다.
  GID (4자리 숫자)를 알려주세요.
  ```

**Step 2 — 서비스 도메인 확인:**
- `GNB_DOMAIN`이 이미 수집됐으면 재사용
- 미수집이면 수집:
  ```
  🌐 서비스 도메인 확인
  INSIGN 쿠키(_ifwt)는 .nexon.com 도메인에만 발급됩니다.
  서비스 예상 도메인을 알려주세요 (예: mygame.nexon.com)
  ```

**Step 3 — 도메인 판별 및 `/insign` 페이지 필요 여부 결정:**

| 도메인 | `/insign` 페이지 | 도메인 허용 요청 |
|---|---|---|
| `*.nexon.com` | ❌ 불필요 | ❌ 불필요 |
| 그 외 | ✅ **필수 구현** | ✅ **insign@nexon.co.kr 이메일 필수** |

- `*.nexon.com` 도메인 → Step 4로 이동
- 그 외 도메인:
  ```
  ⚠ nexon.com 외 도메인입니다.
  아래 두 가지가 추가로 필요합니다:
  1. /insign 페이지 구현 (inface.js 로드)
  2. insign@nexon.co.kr로 도메인 허용 요청 이메일 발송
  → 제목: [INSIGN] 도메인 허용 요청 — {서비스명}
    본문: 서비스명, 허용 요청 도메인, 사용 환경, GID
  ```

**Step 4 — INFACE API Gateway 사전 발급 게이트 안내:**

> **로컬 개발 환경에서는 GID만 필수 차단 항목이다.**
> 나머지 항목(Console 계정, API Key, ACL 등)은 스테이지·라이브 배포 전까지 준비하면 된다.
> uid Passthrough 전략으로 Gateway 없이 로컬 개발이 가능하기 때문이다.

> **[AI 처리 지침]** `GNB_HOSTS_READY = true`이면 (Stage 1 [1.5단계]에서 이미 설정 완료)
> 아래 가이드 메시지에서 `━━ 로컬 개발 hosts 설정 ━━` 항목을 **제외**하고 출력한다.
> 중복 설정을 방지하기 위해 "Stage 1에서 설정한 `local-{GNB_DOMAIN}`을 그대로 사용합니다"로 대체한다.

```
🔐 INSIGN + INFACE API Gateway 사전 준비

━━ 로컬 개발 필수 (없으면 개발 시작 불가) ━━

[필수] GID (게임 식별자) — INSIGN 초기화에 필요
  → 담당 기술PM에게 요청

━━ 스테이지·라이브 배포 전 필수 (지금 없어도 개발 가능) ━━

[준비] INFACE Console 계정 활성화
  → NCSR: https://ncsr.nexon.com/CSR/Write/7/1232

[준비] API Key (x-inface-api-key)
  → INFACE Gateway 콘솔 생성 + insign@nexon.co.kr 요청

[준비] 네트워크 ACL
  → NCSR: https://ncsr.nexon.com/CSR/Write/16/327
  → 허용 NAT IP 목록은 authentication-external.md A-7 참조

━━ 로컬 개발 hosts 설정 (INSIGN 쿠키는 localhost 불가) ━━

  sudo sh -c 'echo "127.0.0.1  local-{GNB_DOMAIN 또는 수집된 도메인}" >> /etc/hosts'
  sudo dscacheutil -flushcache

  → HTTPS 로컬 개발 서버 스크립트(dev:local / dev:local:cert)는
    Q7 처리 완료 후 Next.js 프론트엔드에 자동 추가됩니다.
    Vite 프로젝트는 create-spec Step 2.7 React 앱 초기화 시 dev:https 스크립트가 추가됩니다.

━━ 로컬 개발 전략: uid Passthrough (Gateway 우회) ━━

  로컬: 브라우저 → 로컬 백엔드 직접 호출
        프론트가 inface.auth.getUserProfile()로 uid 추출
        → x-inface-user-uid 헤더 직접 주입
  스테이지·라이브: Gateway가 토큰 검증 후 헤더 자동 주입
  상세: refs/policies/authentication-external.md A-9

GID를 알려주세요 (없으면 "나중에").
```

```bash
./scripts/notify-slack.sh "🔐 INSIGN GID 확인 필요 — 입력 대기 중" "INSIGN 초기화에 필요한 GID(4자리 게임 식별자)를 담당 기술PM에게 요청하세요.\n확인 후 채팅창에 GID를 입력하거나 '나중에'를 입력하세요." || true
```

**사용자 응답 수집 후:**
- GID 입력 시 → `.env.example`에 즉시 기록
- "나중에" 입력 시 → `prerequisites.md`에 ⬜ GID 미수집으로 기록 (개발 차단 항목)
- 나머지 준비 항목 → `prerequisites.md`에 ⬜ 스테이지 배포 전 완료 필요로 기록

**`.env.example` 추가:**

> **주석 컨벤션** — `check-env.sh`가 이 주석을 파싱하여 Phase 진입 전 환경변수 설정 여부를 검사한다:
> - `# required` → `.env.local`에 실제 값 필수. 미설정 시 Phase 게이트 차단.
> - `# optional` → 기본값으로 동작 가능. 미설정 시 경고 없음.
> - 주석 없음 → 검사 대상 아님.

```
# INSIGN / INFACE Gateway
NEXT_PUBLIC_SERVICE_DOMAIN={GNB_DOMAIN 또는 수집된 도메인}  # required
NEXT_PUBLIC_GID={GID}                                        # required
NEXT_PUBLIC_LOCAL_DEV_HOST=local-{GNB_DOMAIN 또는 수집된 도메인}  # required (로컬 HTTPS 서버 호스트명)
INFACE_API_KEY=                                              # optional
NEXT_PUBLIC_USE_GATEWAY=false                                # optional
# ⚠️ HTTPS 로컬 환경에서 http:// 백엔드를 NEXT_PUBLIC_API_BASE_URL로 직접 지정하면
#    브라우저 Mixed Content 차단 발생 — BACKEND_URL + rewrites() 프록시를 사용한다
BACKEND_URL=http://localhost:8000                            # optional (next.config.ts rewrites 대상, server-side 전용)
# NEXT_PUBLIC_API_BASE_URL 미설정 시 api-client.ts API_BASE='' → rewrites()가 /api/v1/* 프록시 처리
# NEXT_PUBLIC_API_BASE_URL=https://public.api.nexon.com/{서비스}  # 스테이지·라이브

# Backend CORS (백엔드 .env.example에도 동일하게 추가)
# 백엔드는 HTTP 유지 — Mixed Content는 Next.js rewrites()가 해결하므로 백엔드 HTTPS 불필요
CORS_ORIGINS=https://local-{GNB_DOMAIN 또는 수집된 도메인}  # required (포트 443 — URL에서 생략)
# 스테이지·라이브: CORS_ORIGINS=https://{서비스 도메인}
```

---

#### Q7-C: 사내 + 외부 (둘 다)

Q7-A 처리 후 Q7-B 처리를 순서대로 진행한다.
두 인증 시스템의 사전 준비 항목이 모두 수집될 때까지 진행한다.

---

#### Q7-D: 인증 없음 (공개 서비스)

인증 관련 환경변수·사전 준비 항목이 없으므로 수집 단계를 건너뛴다.

**CLAUDE.md에서 INFACE 섹션 제거 (인증 없음 프로젝트는 INFACE Gateway 미사용):**
```bash
python3 - <<'PY'
import re, pathlib

# frontend: INFACE API 호출 패턴 섹션 제거
fe = pathlib.Path("frontend/CLAUDE.md")
if fe.exists():
    text = fe.read_text()
    text = re.sub(r'\n## API 호출 패턴.*', '', text, flags=re.DOTALL)
    fe.write_text(text)
    print("frontend INFACE 섹션 제거 완료")

# backend: INFACE API Gateway 인증 섹션 제거
be = pathlib.Path("backend/CLAUDE.md")
if be.exists():
    text = be.read_text()
    text = re.sub(r'\n## INFACE API Gateway 인증\n.*', '', text, flags=re.DOTALL)
    be.write_text(text)
    print("backend INFACE 섹션 제거 완료")
PY
```

---

### 공통: 프론트엔드 HTTPS 로컬 개발 환경 설정

> **프론트엔드가 있는 모든 프로젝트에 적용** (`frontend/package.json` 존재 시). Q7 선택과 무관하게 실행한다.
> 로컬 HTTPS 호스트명은 **Stage 1.6 의 LOCAL_DEV_HOST 를 그대로 재사용**한다 (case 분기 결과):
> - insign / insign-with-nxas : `local-{프로젝트}.nexon.com` (INSIGN `_ifwt` 정책)
> - nxas / custom            : `local-{프로젝트}.nxgd.io`   (NXAS 개발 권장)
> - none                     : `local-{프로젝트}.test`     (RFC 6761)
>
> 모두 `local-` 프리픽스. 정책 문서의 `dev-` 는 Dev EC2 원격 서버를 의미하므로 구분.
> Stage 1.6 의 setup-https.sh 가 이미 인증서·hosts·Caddy 사이트를 셋업했으므로
> 이 단계는 .env 변수 갱신과 dev 스크립트 등록만 담당한다.

**[AI 처리 지침]** 위 우선순위에 따라 `localHost` 값을 결정한 후 아래를 실행한다.

**`frontend/package.json` HTTPS 스크립트 자동 추가:**

```bash
if [ -f frontend/package.json ]; then
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('frontend/package.json', 'utf8'));
const localHost = '{위 우선순위로 결정한 호스트명}';
pkg.scripts = pkg.scripts || {};
// dev:local — Next.js 자동 자체 서명 인증서 (추가 설치 없음, 브라우저 경고 있음)
// Unix에서 443은 root 권한 필요 → sudo npm run dev:local
pkg.scripts['dev:local'] = 'next dev --experimental-https --hostname ' + localHost + ' --port 443';
// dev:local:cert — mkcert 인증서 사용 (브라우저 경고 없음, mkcert 설치 후 인증서 생성 필요)
// Unix에서 443은 root 권한 필요 → sudo npm run dev:local:cert
pkg.scripts['dev:local:cert'] = 'next dev --experimental-https --experimental-https-cert ' + localHost + '.pem --experimental-https-key ' + localHost + '-key.pem --hostname ' + localHost + ' --port 443';
fs.writeFileSync('frontend/package.json', JSON.stringify(pkg, null, 2) + '\n');
console.log('dev:local / dev:local:cert 스크립트 추가 완료');
"
fi
```

**.gitignore에 인증서 파일 추가:**

```bash
grep -q "*.pem" .gitignore 2>/dev/null || echo -e "\n# 로컬 개발 mkcert 인증서 (커밋 금지)\n*.pem\n*-key.pem" >> .gitignore
```

사용자에게 아래 안내를 출력한다 (프론트엔드 존재 시):

```
✅ 로컬 HTTPS 개발 서버 스크립트 추가 완료

  접속 URL: https://{localHost}  (포트 443 — 브라우저 주소창에 포트 생략)

┌─ 바로 사용 (추가 설치 없음, 브라우저 경고 있음) ──────────────
│  sudo npm run dev:local
│  → Unix에서 443 포트는 root 권한 필요 (sudo 필수)
│  → 최초 실행 시 브라우저 경고: "고급 → 계속" 클릭
│  → _ifwt / GNB / INSIGN 쿠키 정상 동작
└────────────────────────────────────────────────────────────

┌─ 브라우저 경고 없이 사용 (mkcert 설치 필요) ───────────────────
│  [전역 — 머신 당 1회] CA 등록
│  which mkcert || brew install mkcert  # Mac
│  mkcert -install
│  → 이후 이 머신의 모든 mkcert 인증서가 브라우저에서 신뢰됨
│
│  [프로젝트별] 인증서 생성 (이 프로젝트 frontend/ 에서 1회)
│  cd frontend && mkcert {localHost}
│  → frontend/{localHost}.pem, frontend/{localHost}-key.pem 생성
│  → 다른 프로젝트는 해당 프로젝트 frontend/ 에서 별도 실행
│
│  이후: sudo npm run dev:local:cert
└────────────────────────────────────────────────────────────
```

```bash
git add frontend/package.json .gitignore
git commit -m "chore: add HTTPS local dev scripts — stage 3"
./scripts/log-activity.sh SETUP "HTTPS 로컬 개발 스크립트 추가" "dev:local / dev:local:cert" || true
```

---

**GNB 사용 프로젝트 추가 확인 (`GNB_REQUIRED = true` 시):**

> Stage 1 [1.5단계]에서 GNB_DOMAIN·GNB_GID·GNB_HOSTS_READY 값이 반드시 수집 완료된 상태로 진입한다.
> (미수집 시 [1.5단계]를 통과할 수 없으므로 이 단계에서 재수집 로직은 불필요하다.)

1. GNB 환경변수를 `.env.example`에 추가한다 (수집된 값으로 채운다):
   ```
   NEXT_PUBLIC_GNB_LOGIN_ENV=test     # required (test | live)
   NEXT_PUBLIC_GNB_GAME_CODE={GNB_GID}  # required
   NEXT_PUBLIC_GNB_LOCAL_HOST=local-{GNB_DOMAIN}  # required
   ```
2. Phase 0 플레이스홀더를 실제 GNB 스크립트로 교체할 시점을 안내한다:
   → "GNB_HOSTS_READY = true + SSO prerequisites 완료 후 실제 스크립트 교체"

---

## Stage 완료: CLAUDE.md 갱신

모든 Stage 완료 후 CLAUDE.md 하단에 다음 섹션을 append한다.
이 섹션이 이미 있으면 확정된 값으로 업데이트한다.

```markdown
## 확정된 기술 스택 (변경 불가)

> Stage 2~4 완료 시 자동 기록 — 임의 변경 금지

| 항목 | 확정 값 |
|---|---|
| 프론트엔드 | {확정값} |
| 백엔드 | {확정값} |
| DB | {확정값} |
| 캐시 | {확정값 또는 해당 없음} |
| 클라우드 | {확정값} |
| 인증 (사내) | {확정값 또는 해당 없음} |
| 인증 (유저) | {확정값 또는 해당 없음} |
| GNB | {사용 / 미사용} |
| E2E 테스트 | {Playwright / Cypress / 미설정} |
```

`.env.example`에 아래 항목이 모두 포함되어 있는지 확인하고 누락된 항목을 추가한다:

```bash
# 확인 목록 (누락 시 추가)
# - CORS_ORIGINS (백엔드 CORS 허용 도메인 — allow_origins=["*"] 하드코딩 금지)
grep -q "CORS_ORIGINS" .env.example || \
  echo -e "\n# Backend CORS\nCORS_ORIGINS=https://localhost" >> .env.example
```

```bash
git add CLAUDE.md .env.example
git commit -m "chore: finalize project setup — stack and env confirmed"
./scripts/log-activity.sh SETUP "보일러플레이트 셋업 완료" "Stage 0~4" || true
./scripts/notify-slack.sh "✅ 프로젝트 셋업 완료" "기술 스택 확정\n다음 단계: 'create-spec 실행해줘'를 입력하여 spec.md → plan.md → tasks.md 문서를 생성하세요." || true
```

이후 `create-spec` 스킬을 자동 호출한다:

```
Skill("create-spec")
```

---

## 부록 A: 인증 프로필 변경 절차

프로젝트 진행 중 인증 방식을 변경(예: `none` → `nxas`, `nxas` → `insign`)해야 하는 경우 자동화 스크립트를 사용하세요:

```bash
./scripts/change-auth-profile.sh <새 프로필>

# 예시
./scripts/change-auth-profile.sh nxas
./scripts/change-auth-profile.sh insign-with-nxas
```

**자동 처리 항목** (6단계):

1. tests/e2e/.auth/user.json 삭제 (storageState — 재로그인 필요)
2. tests/e2e/fixtures/auth-mock.ts 삭제 (Stage 2-E 가 새 모드로 재생성)
3. Caddy 사이트 파일 삭제 + reload
4. state.json 의 `auth_profile / local_dev_host / https_ready / auth_storage_ready` 초기화
5. .env.example 의 `LOCAL_DEV_HOST / LOCAL_DEV_PORT / LOCAL_BACKEND_PORT` 제거
6. 다음 단계 안내 출력

스크립트 실행 후 `boilerplate-setup 실행해줘`를 다시 입력하면 Stage 1.6-A → Stage 1.6-B → Stage 2-E 가 새 인증 프로필로 재구성됩니다. 실제 로그인 + storageState 저장은 이후 `create-spec` Step 2.7 의 통합 검증에서 1회 처리됩니다.

> **주의**: 인증 프로필 변경은 Phase 진행 중에 수행하면 기존 e2e 가 깨질 수 있습니다.
> Phase 경계에서 수행하는 것을 권장합니다.

---

## 부록 B: Caddy 다중 사용자 머신에서의 한계

`brew services start caddy` 로 등록한 Caddy 데몬은 **시스템 전역**으로 동작합니다.
같은 머신을 여러 macOS 사용자 계정이 공유하는 경우:

- `/opt/homebrew/etc/d2a-sites/*.caddy` 는 시스템 전역 → 한 사용자가 등록한 사이트가
  다른 사용자 계정에도 동일하게 보입니다.
- 사용자별 격리가 필요하면 `brew services` 대신 사용자별 Caddy 인스턴스를 별도 포트
  (예: 8443)로 실행하고, `LOCAL_DEV_HOST:8443` 으로 접근하는 패턴 권장.

대부분의 개발자는 머신 1개를 단독 사용하므로 이 한계는 일반적으로 발생하지 않습니다.

---

## 부록 C: Caddy 운영 명령 가이드

Stage 1.6 셋업 후 Caddy 운영에 필요한 명령:

| 작업 | 명령 (macOS) |
|---|---|
| **상태 확인** | `sudo brew services list \| grep caddy` |
| **설정 reload** (사이트 추가/삭제 후) | `sudo brew services reload caddy` |
| **재시작** | `sudo brew services restart caddy` |
| **중지** | `sudo brew services stop caddy` |
| **시작** | `sudo brew services start caddy` |
| **Caddyfile 검증** | `caddy validate --config $(brew --prefix)/etc/Caddyfile` |
| **현재 등록된 사이트 목록** | `ls $(brew --prefix)/etc/d2a-sites/` |
| **개별 사이트 삭제** | `rm $(brew --prefix)/etc/d2a-sites/{도메인}.caddy && sudo brew services reload caddy` |
| **로그 (액세스)** | `tail -f $(brew --prefix)/var/log/caddy/access.log` |
| **로그 (에러)** | `tail -f $(brew --prefix)/var/log/caddy/error.log` |

### 흔한 트러블슈팅

| 증상 | 원인 / 조치 |
|---|---|
| `brew services start caddy` 가 즉시 종료됨 | 443 포트 점유 — `sudo lsof -nP -iTCP:443 -sTCP:LISTEN` 으로 점유 프로세스 확인 후 종료 |
| 브라우저에서 "사이트에 연결할 수 없음" | hosts 미등록 — `cat /etc/hosts \| grep {도메인}` 확인 |
| 브라우저에서 자체 서명 경고 | mkcert root CA 미등록 — `mkcert -install` 재실행 |
| Caddy 가 시작되었으나 502 응답 | dev 서버 미기동 — 별도 터미널에서 `cd frontend && npm run dev` |
| `caddy validate` 가 실패 | Caddyfile 구문 오류 — `$(brew --prefix)/etc/Caddyfile` 직접 점검 |
| Reload 후에도 변경 미반영 | restart 시도 — `sudo brew services restart caddy` |

### Caddyfile 위치 (참고)

- macOS Apple Silicon: `/opt/homebrew/etc/Caddyfile`
- macOS Intel: `/usr/local/etc/Caddyfile`
- Linux: `/etc/caddy/Caddyfile`

D2A 보일러플레이트가 추가한 사이트는 `{prefix}/etc/d2a-sites/*.caddy` 에 격리되어 있어
사용자가 추가한 다른 Caddy 설정과 충돌하지 않습니다.
