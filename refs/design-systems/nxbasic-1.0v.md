# NX Basic 1.0v 디자인 시스템

> 넥슨 사내 디자인 시스템. 컴포넌트/디자인 토큰을 AI 코딩 도구에서 조회할 수 있도록
> **Remote MCP 서버 + Storybook** 으로 제공된다.
> 출처: Notion "🦍 NX Basic 1.0v MCP 가이드" (플랫폼파운데이션그룹 / Re:Platform팀 / R&D 프로젝트)

---

## 개요

| 항목 | 내용 |
|---|---|
| 시스템명 | NX Basic 1.0v |
| MCP 서버명 | `nxbasic-mcp` (Cloudflare Workers, **authless**) |
| MCP 엔드포인트 | `https://nxbasic-mcp.sooyachoco.workers.dev/mcp` |
| Storybook | https://sooyachoco.github.io/NXbasic1.0v/?path=/docs/introduction--docs |
| 컴포넌트 Repo | https://github.com/sooyachoco/NXbasic1.0v |
| 컴포넌트 수 | 18종 |
| 디자인 토큰 수 | 144개 (CSS 변수 70 + type scale 13 + nxbasic-system 61) |
| 컴포넌트 import | `import { Button } from 'nxbasic'` |

## 지원 컴포넌트 (18종)

Badge · Button · Card · Checkbox · Dialog · Dropdown · Icon · Link · Notification ·
Pagination · Radio · Search · Tab · Table · Tag · TextField · Toggle · Tooltip

---

## 본 보일러플레이트의 연동 방식 — 텍스트 안내(Storybook 조회)

> **이 보일러플레이트는 `nxbasic-mcp` MCP 서버를 등록하지 않는다.**
> 컴포넌트/토큰 정보는 아래 Storybook URL 을 **WebFetch** 로 조회하여 참조한다.
> (MCP 직접 연결을 원하면 맨 아래 "MCP 서버 직접 연결(선택)" 참조)

- **Introduction**: `https://sooyachoco.github.io/NXbasic1.0v/?path=/docs/introduction--docs`
- **컴포넌트 문서 URL 패턴**:
  `https://sooyachoco.github.io/NXbasic1.0v/?path=/docs/components-{이름소문자}--docs`
  - 예: Button → `.../components-button--docs`
  - 예: TextField → `.../components-textfield--docs`
- **토큰 SSOT (GitHub)**: `src/tokens/colors.css`, `src/tokens/typography.css`, `src/tokens/tokens.ts`

### 디자인 토큰 분류

| 카테고리 | 예시 키워드 | 설명 |
|---|---|---|
| colors | `primary`, `pc-500`, `--color-pc-*`, `--color-bc-*`, `--semantic-*` | Primitive/Brand 컬러, semantic 토큰 |
| typography | `type-default-16` (13단계 type scale), `w-light` · `w-medium` (font weight), `--font-family-base` | 타입 스케일·굵기 클래스 |
| spacing | spacing 토큰 | 여백 스케일 |
| radius | radius 토큰 | 모서리 반경 |
| semantic | `semantic.color.text.primary` 등 | 의미 기반 토큰 |

---

## 보일러플레이트 적용 규칙

이 디자인 시스템을 사용할지 여부는 두 경로로 결정된다.

### 1. PRD 키워드 자동 감지 → 웹 리서치만 생략, 샘플 3종은 NX Basic 토큰으로 생성

PRD(기획 문서) 본문에 다음 키워드 중 하나가 등장하면 `DESIGN_SYSTEM = nxbasic` 로 판정한다
(대소문자·공백 무시):

- `NX Basic`
- `nxbasic`
- `NX Basic 1.0v`
- `nxbasic-mcp`

판정 시:
- **Stage 1.5(웹 디자인 리서치)** 는 **건너뛴다.** 시각 DNA의 출처가 NX Basic 디자인 시스템이므로 외부 레퍼런스 리서치는 수행하지 않는다.
- **Stage 1 Q5\*(디자인 샘플 생성·선택)는 건너뛰지 않는다.** 색상·타이포·컴포넌트는 NX Basic 토큰/18종을 그대로 고정하되, **레이아웃·구성(진입 영역·정보 밀도·배치)만 다른 디자인 샘플 3종**을 `design/samples.html` 로 생성하여 사용자가 비교·선택한다. (`ui-design-workflow` §3 "레이아웃 안 3개 발산"과 동일 취지 — NX Basic 토큰으로 발산)
- 선택된 레이아웃 방향과 NX Basic 토큰을 `design/design-direction.md` 에 채운 뒤 곧장
  `create-spec` Step 2.7(UI 프로토타입)으로 향한다.
- 결정은 `decisions.md` `DESIGN_SYSTEM` 항목 + `state.json.design_system` 에 기록한다.

### 2. 디자인 리서치 진행 시 → 선택지로 제안

PRD 에 키워드가 없어 일반 디자인 리서치를 진행하는 경우,
`boilerplate-setup` Q5\* 샘플 선택지와 `design-research` 스킬에서
**웹 리서치 결과와 함께 NX Basic 1.0v 적용**을 하나의 선택지로 제시한다.
사용자가 NX Basic 을 고르면 위 1번과 동일하게 처리한다.

---

## UI 프로토타입(create-spec Step 2.7)에서의 사용

`DESIGN_SYSTEM = nxbasic` 일 때:

- 컬러·타이포·여백은 NX Basic 토큰을 기준으로 `design/design-direction.md` 에 매핑한다
  (Storybook `colors.css` / `typography.css` / `tokens.ts` WebFetch 조회).
- 컴포넌트는 가능한 한 NX Basic 18종(Button, TextField, Table, Dialog 등)에 매핑하여 구현한다.
  - `nxbasic` 패키지가 설치 가능하면 `import { Button } from 'nxbasic'` 사용을 우선한다.
  - 패키지 미설치/사내망 제약 시: Storybook 문서의 props·스타일을 참조하여 동등 컴포넌트를 직접 구현한다.
- `design-quality-guard` 의 "기본 테마 그대로 사용 금지" 규칙은 NX Basic 토큰 준수로 갈음한다
  (디자인 시스템을 그대로 따르는 것이 목표이므로 임의 변주를 추가하지 않는다).

---

## MCP 서버 직접 연결 (선택 — 본 보일러플레이트 기본 비활성)

`nxbasic-mcp` 를 직접 연결하면 `get_component_docs` / `search_design_tokens` / `list_components`
도구를 쓸 수 있다. Notion 가이드 기준 설치 방법:

**Claude Code** — `~/.claude.json` 의 `mcpServers` 에 추가 (기존 내용 보존):
```json
{
  "mcpServers": {
    "nxbasic-mcp": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "mcp-remote", "https://nxbasic-mcp.sooyachoco.workers.dev/mcp"],
      "env": { "NODE_TLS_REJECT_UNAUTHORIZED": "0" }
    }
  }
}
```
> macOS/Linux 는 `"command": "npx"`, `"args": ["-y", "mcp-remote", "<엔드포인트>"]` 형태로 둔다.

**권한** — `~/.claude/settings.json`:
```json
{ "permissions": { "allow": ["mcp__nxbasic-mcp__*"] } }
```

**제공 도구:**

| 도구 | 용도 | 주요 파라미터 |
|---|---|---|
| `get_component_docs` | 컴포넌트 상세 문서(props·예제·Storybook 링크) | `component`, `locale`(ko/en), `includeExamples` |
| `search_design_tokens` | 디자인 토큰 키워드 검색 | `query`, `category`, `limit` |
| `list_components` | 컴포넌트 전체 목록 | `category`(Components/Foundation) |

> ⚠️ 회사 프록시/SSL 환경에서는 `NODE_TLS_REJECT_UNAUTHORIZED=0` 이 필요할 수 있다.
> 🔒 현재 서버는 인증 없이 공개 URL 로 운영된다 — 민감 정보 전송 금지.
