import { McpAgent } from "agents/mcp";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { evaluateUtGate } from "./ut-gate.js";

/**
 * D2A 공개 원격 MCP (Cloudflare Workers, authless).
 *
 * 엔드포인트:
 *   /mcp  — Streamable HTTP transport (권장)
 *   /sse  — 레거시 SSE transport (구형 클라이언트 호환)
 *
 * 툴 추가 방법: init() 안에서 this.server.tool(name, schema, handler) 를 호출.
 */
export class D2AMcp extends McpAgent {
  server = new McpServer({
    name: "d2a-remote-mcp",
    version: "0.1.0",
  });

  async init() {
    // 헬스 체크용 — 연결 검증.
    this.server.tool(
      "ping",
      "서버 생존 확인. pong 과 현재 툴 목록 요약을 반환한다.",
      {},
      async () => ({
        content: [{ type: "text", text: "pong — d2a-remote-mcp v0.1.0 (tools: ping, ut_severity_gate)" }],
      })
    );

    // UT Severity 게이트 — d2a-harness 의 ut: done 기준 로직을 원격으로 노출.
    this.server.tool(
      "ut_severity_gate",
      "AI 사용성 테스트 리포트(UT_FINDINGS_REPORT) 본문에서 S1~S4 카운트를 추출하고, 임계 규칙(예: S4=0,S3<=2) 충족 여부를 판정한다.",
      {
        report: z.string().describe("UT_FINDINGS_REPORT.md 의 본문 텍스트 (Executive Summary 표 포함)"),
        criteria: z.string().describe('Severity 임계 규칙. 콤마 구분. 예: "S4=0,S3<=2"'),
      },
      async ({ report, criteria }) => {
        const result = evaluateUtGate(report, criteria);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  passed: result.passed,
                  reason: result.reason,
                  counts: result.counts,
                  checked: result.checked,
                },
                null,
                2
              ),
            },
          ],
        };
      }
    );
  }
}

export default {
  fetch(request: Request, env: unknown, ctx: ExecutionContext): Response | Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/mcp") {
      return D2AMcp.serve("/mcp").fetch(request, env as never, ctx);
    }
    if (url.pathname === "/sse" || url.pathname === "/sse/message") {
      return D2AMcp.serveSSE("/sse").fetch(request, env as never, ctx);
    }
    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response(
        "d2a-remote-mcp is running.\nMCP endpoint: /mcp (Streamable HTTP) or /sse (legacy)\n",
        { headers: { "content-type": "text/plain; charset=utf-8" } }
      );
    }
    return new Response("Not found", { status: 404 });
  },
};
