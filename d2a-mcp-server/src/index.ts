import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

import { checkPhaseGate } from "./tools/phase-gate.js";
import { validateTaskDone } from "./tools/task-validator.js";
import { updateState, getState } from "./tools/state-tool.js";
import { createCheckpoint, rollbackToCheckpoint } from "./tools/checkpoint.js";
import { getNextTask, submitTask } from "./tools/phase-runner.js";
import { checkPrerequisitesGrounded } from "./tools/prerequisites-grounded.js";
import { recordTrace } from "./tracer.js";

// ─── 입력 스키마 (Zod) ─────────────────────────────────────────────────────
const CheckPhaseGateInput = z.object({
  phase: z.number().describe("검증할 Phase 번호 (0, 0.5, 1, 2, ...)"),
});

const ValidateTaskDoneInput = z.object({
  task_id: z.string().describe("검증할 태스크 ID (예: T1-001)"),
});

const UpdateStateInput = z.object({
  patch: z.record(z.unknown()).describe("state.json에 병합할 필드 (부분 업데이트)"),
});

const CheckpointInput = z.object({
  task_id: z.string().describe("checkpoint를 생성할 태스크 ID"),
});

const RollbackInput = z.object({
  task_id: z.string().describe("rollback 대상 태스크 ID"),
});

const GetNextTaskInput = z.object({
  phase: z.number().describe("실행할 Phase 번호"),
});

const SubmitTaskInput = z.object({
  task_id: z.string().describe("제출할 태스크 ID"),
  attempt: z.union([z.literal(1), z.literal(2)]).describe("시도 횟수 (1=첫 시도, 2=수정 후 재시도)"),
});

// ─── MCP 서버 도구 정의 ────────────────────────────────────────────────────
const TOOLS = [
  {
    name: "check_phase_gate",
    description:
      "Phase 전환 가능 여부를 코드로 검증한다. " +
      "integration-ready.md 존재·판정 확인, state.json 미해결 블로커, decisions.md ⬜ 항목을 체크한다. " +
      "run-phase Step 0에서 호출하여 Claude의 텍스트 판단 대신 코드 판단을 사용한다.",
    inputSchema: {
      type: "object" as const,
      properties: {
        phase: { type: "number", description: "검증할 Phase 번호" },
      },
      required: ["phase"],
    },
  },
  {
    name: "validate_task_done",
    description:
      "tasks.md의 done 기준을 독립적으로 재실행하여 태스크 완료를 검증한다. " +
      "file:/contains:/regex:/json:/cmd:/coverage: 6가지 타입을 지원한다. " +
      "run-phase Step 2-3 완료 검증에서 Claude 판단 대신 코드 검증을 사용한다.",
    inputSchema: {
      type: "object" as const,
      properties: {
        task_id: { type: "string", description: "검증할 태스크 ID" },
      },
      required: ["task_id"],
    },
  },
  {
    name: "update_state",
    description:
      ".claude/state.json을 atomic write로 부분 업데이트한다. " +
      "phase, status, current_task, integration_ready, blockers 등 원하는 필드만 전달하면 된다.",
    inputSchema: {
      type: "object" as const,
      properties: {
        patch: {
          type: "object",
          description: "state.json에 병합할 필드 객체",
        },
      },
      required: ["patch"],
    },
  },
  {
    name: "create_checkpoint",
    description:
      "태스크 실행 전 현재 HEAD에 checkpoint 브랜치를 생성한다. " +
      "형식: checkpoint/{task_id}-{timestamp}. " +
      ".claude/last-checkpoint 에도 브랜치명을 기록한다.",
    inputSchema: {
      type: "object" as const,
      properties: {
        task_id: { type: "string", description: "checkpoint를 생성할 태스크 ID" },
      },
      required: ["task_id"],
    },
  },
  {
    name: "rollback_to_checkpoint",
    description:
      "태스크 실패(done 기준 2회 실패) 시 checkpoint 시점으로 recovery 브랜치를 생성하여 복원한다. " +
      "원래 브랜치(main 등)는 변경되지 않으며 state.json에 블로커를 기록한다. " +
      "submit_task가 내부적으로 호출하므로 Claude가 직접 호출할 필요가 없다.",
    inputSchema: {
      type: "object" as const,
      properties: {
        task_id: { type: "string", description: "rollback 대상 태스크 ID" },
      },
      required: ["task_id"],
    },
  },
  {
    name: "get_next_task",
    description:
      "지정된 Phase에서 다음에 실행할 태스크를 결정하여 반환한다. " +
      "deps 확인·완료 판단·checkpoint 생성·state 업데이트를 코드로 처리한다. " +
      "Claude는 반환된 read_files를 로드하고 write_files를 구현한 뒤 submit_task를 호출한다.",
    inputSchema: {
      type: "object" as const,
      properties: {
        phase: { type: "number", description: "실행할 Phase 번호" },
      },
      required: ["phase"],
    },
  },
  {
    name: "submit_task",
    description:
      "태스크 구현 완료를 제출하여 done 기준을 검증하고 다음 액션을 결정한다. " +
      "passed:true → action:next (validate token 생성 + 커밋 허용). " +
      "attempt=1 실패 → action:retry (수정 후 attempt=2로 재호출). " +
      "attempt=2 실패 → action:rollback (자동 rollback + 블로커 기록). " +
      "Claude는 action에 따라서만 다음 행동을 결정한다.",
    inputSchema: {
      type: "object" as const,
      properties: {
        task_id: { type: "string", description: "제출할 태스크 ID" },
        attempt: { type: "number", enum: [1, 2], description: "시도 횟수 (1=첫 시도, 2=수정 후 재시도)" },
      },
      required: ["task_id", "attempt"],
    },
  },
  {
    name: "check_prerequisites_grounded",
    description:
      "prerequisites.md의 ⬜ 차단 항목이 정책 문서(refs/policies/)로 뒷받침되는지 검증한다. " +
      "각 차단 항목은 `근거: refs/policies/{file}.md` 인용 또는 `근거: 사용자 입력` 같은 " +
      "명시적 출처를 가져야 한다. 정책 파일 인용 시 항목 키워드의 grep 매치를 확인한다. " +
      "collect-prerequisites 종료 시점 + check_phase_gate Phase 0.5 보조 호출에서 사용.",
    inputSchema: {
      type: "object" as const,
      properties: {},
    },
  },
];

// ─── MCP 서버 초기화 ───────────────────────────────────────────────────────
const server = new Server(
  { name: "d2a-harness", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: rawArgs } = request.params;

  try {
    let result: unknown;

    switch (name) {
      case "check_phase_gate": {
        const args = CheckPhaseGateInput.parse(rawArgs);
        result = await checkPhaseGate(args);
        recordTrace(name, args, result);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      }

      case "validate_task_done": {
        const args = ValidateTaskDoneInput.parse(rawArgs);
        result = await validateTaskDone(args);
        recordTrace(name, args, result);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      }

      case "update_state": {
        const args = UpdateStateInput.parse(rawArgs);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        result = await updateState({ patch: args.patch as any });
        recordTrace(name, args, result);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      }

      case "create_checkpoint": {
        const args = CheckpointInput.parse(rawArgs);
        result = await createCheckpoint(args);
        recordTrace(name, args, result);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      }

      case "rollback_to_checkpoint": {
        const args = RollbackInput.parse(rawArgs);
        result = await rollbackToCheckpoint(args);
        recordTrace(name, args, result);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      }

      case "get_next_task": {
        const args = GetNextTaskInput.parse(rawArgs);
        result = await getNextTask(args);
        recordTrace(name, args, result);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      }

      case "submit_task": {
        const args = SubmitTaskInput.parse(rawArgs);
        result = await submitTask(args);
        recordTrace(name, args, result);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      }

      case "check_prerequisites_grounded": {
        result = await checkPrerequisitesGrounded();
        recordTrace(name, {}, result);
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
      }

      default:
        return {
          content: [{ type: "text", text: JSON.stringify({ error: `알 수 없는 도구: ${name}` }) }],
          isError: true,
        };
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    recordTrace(name, rawArgs, { error: msg });
    return {
      content: [{ type: "text", text: JSON.stringify({ error: msg }) }],
      isError: true,
    };
  }
});

// ─── 실행 ──────────────────────────────────────────────────────────────────
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stderr: Claude Code는 캡처하지 않으므로 디버그 로그 용도로 안전
  process.stderr.write("[d2a-harness] MCP 서버 시작 (stdio)\n");
}

main().catch((e) => {
  process.stderr.write(`[d2a-harness] 서버 오류: ${e}\n`);
  process.exit(1);
});
