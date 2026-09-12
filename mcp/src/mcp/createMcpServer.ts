import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { serializeError } from "../domain/errors.js";
import type { ScheduleProvider } from "../providers/schedule/ScheduleProvider.js";

const groupSchema = z.object({
  id: z.number().int(),
  name: z.string(),
  institute: z.string().nullable(),
});

const lessonSchema = z.object({
  startTime: z.string(),
  endTime: z.string(),
  subject: z.string(),
  type: z.string(),
  teacher: z.string().nullable(),
  room: z.string().nullable(),
  building: z.string().nullable(),
  subgroup: z.string().nullable(),
  classUrl: z.string().nullable(),
});

const toolAnnotations = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
} as const;

function successResult<T extends object>(value: T) {
  const structuredContent = { ...value } as Record<string, unknown>;
  return {
    content: [{ type: "text" as const, text: JSON.stringify(structuredContent) }],
    structuredContent,
  };
}

function errorResult(error: unknown) {
  const value = serializeError(error);
  return {
    isError: true,
    content: [{ type: "text" as const, text: JSON.stringify(value) }],
  };
}

export function createMcpServer(provider: ScheduleProvider): McpServer {
  const server = new McpServer(
    { name: "my-mpsu-schedule-mcp", version: "0.1.0" },
    {
      instructions:
        "Provides schedule data from the configured MyMPSU API. Never invent missing university information. Ask for the student's group when it is not available in the conversation or client memory.",
    },
  );

  server.registerTool(
    "search_groups",
    {
      title: "Search MPGU student groups",
      description:
        "Search MPGU student groups exposed by the configured MyMPSU API. If several groups match, show the options and ask the user to choose; never guess.",
      inputSchema: {
        query: z
          .string()
          .trim()
          .min(2)
          .max(80)
          .describe("Full or partial student group name, in Russian or Latin characters."),
      },
      outputSchema: {
        groups: z.array(groupSchema),
      },
      annotations: toolAnnotations,
    },
    async ({ query }) => {
      const startedAt = performance.now();
      try {
        const result = await provider.searchGroups(query);
        logTool("search_groups", startedAt, true);
        return successResult(result);
      } catch (error) {
        const serialized = serializeError(error);
        logTool("search_groups", startedAt, false, serialized.code);
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "get_schedule",
    {
      title: "Get the MyMPSU class schedule",
      description:
        "Get the configured MyMPSU schedule for a student group and date range. The group may be a numeric ID or an unambiguous name. If the user's group is unknown, ask for it or call search_groups first. Dates use Europe/Moscow.",
      inputSchema: {
        group: z
          .string()
          .trim()
          .min(1)
          .max(80)
          .describe("Official group ID or an unambiguous group name."),
        dateFrom: z
          .string()
          .regex(/^\d{4}-\d{2}-\d{2}$/)
          .optional()
          .describe("First date, inclusive, as YYYY-MM-DD in Europe/Moscow."),
        dateTo: z
          .string()
          .regex(/^\d{4}-\d{2}-\d{2}$/)
          .optional()
          .describe("Last date, inclusive, as YYYY-MM-DD in Europe/Moscow."),
      },
      outputSchema: {
        group: groupSchema,
        timezone: z.literal("Europe/Moscow"),
        dateFrom: z.string(),
        dateTo: z.string(),
        days: z.array(
          z.object({
            date: z.string(),
            lessons: z.array(lessonSchema),
          }),
        ),
        source: z.object({
          name: z.string(),
          url: z.string(),
        }),
      },
      annotations: toolAnnotations,
    },
    async (input) => {
      const startedAt = performance.now();
      try {
        const result = await provider.getSchedule(input);
        logTool("get_schedule", startedAt, true, undefined, "api.mympsu.moonbaystudio.ru");
        return successResult(result);
      } catch (error) {
        const serialized = serializeError(error);
        logTool(
          "get_schedule",
          startedAt,
          false,
          serialized.code,
          "api.mympsu.moonbaystudio.ru",
        );
        return errorResult(error);
      }
    },
  );

  return server;
}

function logTool(
  tool: string,
  startedAt: number,
  success: boolean,
  errorCode?: string,
  upstream?: string,
): void {
  console.log(
    JSON.stringify({
      level: "info",
      event: "tool_call",
      tool,
      durationMs: Math.round(performance.now() - startedAt),
      success,
      ...(upstream ? { upstream } : {}),
      ...(errorCode ? { errorCode } : {}),
    }),
  );
}
