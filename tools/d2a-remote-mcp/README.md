# d2a-remote-mcp

D2A 공개(authless) 원격 MCP 서버 — Cloudflare Workers + `agents` SDK(`McpAgent`).

## 엔드포인트

| 경로 | 용도 |
|---|---|
| `/mcp` | MCP Streamable HTTP transport (권장) |
| `/sse` | 레거시 SSE transport (구형 클라이언트) |
| `/health` | 평문 헬스 체크 |

## 제공 툴

| 툴 | 설명 |
|---|---|
| `ping` | 서버 생존 확인 |
| `ut_severity_gate` | UT_FINDINGS_REPORT 본문 + 규칙(`S4=0,S3<=2`)으로 Severity 게이트 판정 |

## 로컬 개발

```bash
npm install
npm run dev          # http://localhost:8787
npm run typecheck    # 타입 검사
npm run dry-run      # 인증 없이 번들 검증
```

## 배포 (Cloudflare 로그인 필요 — 사용자가 직접)

```bash
npx wrangler login           # 브라우저 OAuth (1회)
npx wrangler deploy          # → https://d2a-remote-mcp.<subdomain>.workers.dev
```

> 계정이 여러 개면 `CLOUDFLARE_ACCOUNT_ID=a82e5be0a8064fadca42ee9101aaa8ff` 를
> 환경변수로 지정하거나 `wrangler.jsonc` 에 `"account_id"` 를 추가한다.

## MCP 클라이언트 연결

배포 후 URL `https://d2a-remote-mcp.<subdomain>.workers.dev/mcp` 를 등록한다.

### Claude Code (.mcp.json 또는 settings)

```json
{
  "mcpServers": {
    "d2a-remote": {
      "type": "http",
      "url": "https://d2a-remote-mcp.<subdomain>.workers.dev/mcp"
    }
  }
}
```

### MCP Inspector 로 점검

```bash
npx @modelcontextprotocol/inspector
# Transport: Streamable HTTP, URL: .../mcp
```

## 툴 추가 방법

`src/index.ts` 의 `init()` 안에서:

```ts
this.server.tool("툴이름", "설명", { 인자: z.string() }, async ({ 인자 }) => ({
  content: [{ type: "text", text: "결과" }],
}));
```

> 주의: Workers 런타임에는 파일시스템·`child_process` 가 없다.
> 파일/셸 의존 로직은 KV·R2·D1·외부 API 로 대체해야 한다.
