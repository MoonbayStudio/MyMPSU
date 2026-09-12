import type { AddressInfo } from "node:net";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { afterEach, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import type { AppConfig } from "../src/config.js";
import type {
  GetScheduleInput,
  GetScheduleResult,
  SearchGroupsResult,
} from "../src/domain/schedule.js";
import type { ScheduleProvider } from "../src/providers/schedule/ScheduleProvider.js";

const config: AppConfig = {
  port: 3000,
  mpguScheduleApiBaseUrl: new URL("https://api.mympsu.moonbaystudio.ru/schedule/v1"),
  upstreamTimeoutMs: 1_000,
  metadataCacheMs: 600_000,
  rateLimitWindowMs: 60_000,
  rateLimitMaxRequests: 100,
  trustProxyHops: 0,
};

class FixtureProvider implements ScheduleProvider {
  async searchGroups(query: string): Promise<SearchGroupsResult> {
    return query.toLocaleLowerCase("ru-RU").includes("ивт")
      ? { groups: [{ id: 101, name: "1б-ИВТ-1/26", institute: "ИИТТО" }] }
      : { groups: [] };
  }

  async getSchedule(input: GetScheduleInput): Promise<GetScheduleResult> {
    return {
      group: { id: 101, name: input.group, institute: "ИИТТО" },
      timezone: "Europe/Moscow",
      dateFrom: input.dateFrom ?? "2026-09-01",
      dateTo: input.dateTo ?? input.dateFrom ?? "2026-09-01",
      days: [{ date: input.dateFrom ?? "2026-09-01", lessons: [] }],
      source: {
        name: "MyMPSU schedule API",
        url: "https://api.mympsu.moonbaystudio.ru/schedule/v1/schedule",
      },
    };
  }
}

const closers: Array<() => Promise<void>> = [];

afterEach(async () => {
  await Promise.all(closers.splice(0).map((close) => close()));
});

async function connectClient(): Promise<Client> {
  const app = createApp(config, new FixtureProvider());
  const httpServer = app.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => httpServer.once("listening", resolve));
  const address = httpServer.address() as AddressInfo;
  const client = new Client({ name: "my-mpsu-schedule-mcp-test", version: "1.0.0" });
  const transport = new StreamableHTTPClientTransport(
    new URL(`http://127.0.0.1:${address.port}/mcp`),
  );
  await client.connect(transport);
  closers.push(async () => {
    await client.close();
    await new Promise<void>((resolve, reject) => {
      httpServer.close((error) => (error ? reject(error) : resolve()));
    });
  });
  return client;
}

describe("remote MCP transport", () => {
  it("completes initialize and exposes both read-only tools", async () => {
    const client = await connectClient();
    const response = await client.listTools();

    expect(response.tools.map((tool) => tool.name)).toEqual([
      "search_groups",
      "get_schedule",
    ]);
    expect(response.tools.every((tool) => tool.annotations?.readOnlyHint)).toBe(true);
  });

  it("returns structured output from each tool", async () => {
    const client = await connectClient();
    const groupResult = await client.callTool({
      name: "search_groups",
      arguments: { query: "ИВТ" },
    });
    expect(groupResult.structuredContent).toMatchObject({
      groups: [{ id: 101 }],
    });

    const scheduleResult = await client.callTool({
      name: "get_schedule",
      arguments: {
        group: "1б-ИВТ-1/26",
        dateFrom: "2026-09-01",
        dateTo: "2026-09-01",
      },
    });
    expect(scheduleResult.structuredContent).toMatchObject({
      timezone: "Europe/Moscow",
      days: [{ date: "2026-09-01", lessons: [] }],
    });
  });

  it("rejects malformed tool input through the MCP schema", async () => {
    const client = await connectClient();
    const result = await client.callTool({
      name: "search_groups",
      arguments: { query: "" },
    });

    expect(result.isError).toBe(true);

    const tooLong = await client.callTool({
      name: "search_groups",
      arguments: { query: "И".repeat(81) },
    });
    expect(tooLong.isError).toBe(true);
  });
});
