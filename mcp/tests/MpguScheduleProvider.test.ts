import { describe, expect, it, vi } from "vitest";
import type { AppConfig } from "../src/config.js";
import { MpguMcpError } from "../src/domain/errors.js";
import { MpguScheduleProvider } from "../src/providers/schedule/MpguScheduleProvider.js";

const config: AppConfig = {
  port: 3000,
  mpguScheduleApiBaseUrl: new URL("https://api.mympsu.moonbaystudio.ru/schedule/v1"),
  upstreamTimeoutMs: 1_000,
  metadataCacheMs: 600_000,
  rateLimitWindowMs: 60_000,
  rateLimitMaxRequests: 60,
  trustProxyHops: 0,
};

const groups = [
  { id: 101, name: "1б-ИВТ-1/26", faculty_id: 8 },
  { id: 102, name: "1б-ИВТ-2/26", faculty_id: 8 },
  { id: 103, name: "2м-Психология/25", faculty_id: 20 },
];
const faculties = [
  { id: 8, name: "Институт информационных технологий" },
  { id: 20, name: "Институт психологии" },
];

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function metadataFetch() {
  return vi.fn(async (input: string | URL | Request) => {
    const url = new URL(input instanceof Request ? input.url : input.toString());
    if (url.pathname.endsWith("/groups")) return jsonResponse(groups);
    if (url.pathname.endsWith("/faculties")) return jsonResponse(faculties);
    throw new Error(`Unexpected URL: ${url}`);
  });
}

describe("MpguScheduleProvider.searchGroups", () => {
  it("finds an exact group and attaches its institute", async () => {
    const provider = new MpguScheduleProvider(config, metadataFetch());
    const result = await provider.searchGroups("1б-ИВТ-1/26");

    expect(result.groups).toEqual([
      {
        id: 101,
        name: "1б-ИВТ-1/26",
        institute: "Институт информационных технологий",
      },
    ]);
  });

  it("supports partial case-insensitive Cyrillic queries and multiple matches", async () => {
    const provider = new MpguScheduleProvider(config, metadataFetch());
    const result = await provider.searchGroups("ивт");

    expect(result.groups.map((group) => group.id)).toEqual([101, 102]);
  });

  it("returns an empty list when no group matches", async () => {
    const provider = new MpguScheduleProvider(config, metadataFetch());
    await expect(provider.searchGroups("несуществующая")).resolves.toEqual({ groups: [] });
  });
});

describe("MpguScheduleProvider.getSchedule", () => {
  it("normalizes and enriches a weekly schedule while preserving empty days", async () => {
    const fetchMock = vi.fn(async (input: string | URL | Request) => {
      const url = new URL(input instanceof Request ? input.url : input.toString());
      if (url.pathname.endsWith("/groups")) return jsonResponse(groups);
      if (url.pathname.endsWith("/faculties")) return jsonResponse(faculties);
      if (url.pathname.endsWith("/schedule")) {
        expect(url.searchParams.get("group_id")).toBe("101");
        expect(url.searchParams.get("start_date")).toBe("2026-09-01");
        expect(url.searchParams.get("end_date")).toBe("2026-09-02");
        return jsonResponse([
          {
            id: 1,
            group_id: 101,
            start_time: "2026-09-01T10:00:00+03:00",
            end_time: "2026-09-01T11:30:00+03:00",
            name: "Алгоритмы",
            type: "лекция",
            teacher_id: 501,
            room_id: 601,
            sub_group_id: null,
            class_url: null,
          },
        ]);
      }
      if (url.pathname.endsWith("/teachers")) {
        expect(url.searchParams.get("teacher_ids")).toBe("501");
        return jsonResponse([{ id: 501, name: "Иванов И. И." }]);
      }
      if (url.pathname.endsWith("/rooms")) {
        expect(url.searchParams.get("room_ids")).toBe("601");
        return jsonResponse([{ id: 601, name: "305", building_id: 701 }]);
      }
      if (url.pathname.endsWith("/buildings")) {
        expect(url.searchParams.get("building_ids")).toBe("701");
        return jsonResponse([{ id: 701, name: "наб. реки Мойки, 48" }]);
      }
      throw new Error(`Unexpected URL: ${url}`);
    });
    const provider = new MpguScheduleProvider(config, fetchMock);

    const result = await provider.getSchedule({
      group: "1Б‑ИВТ‑1/26",
      dateFrom: "2026-09-01",
      dateTo: "2026-09-02",
    });

    expect(result.timezone).toBe("Europe/Moscow");
    expect(result.days).toHaveLength(2);
    expect(result.days[0].lessons[0]).toMatchObject({
      startTime: "10:00",
      endTime: "11:30",
      subject: "Алгоритмы",
      teacher: "Иванов И. И.",
      room: "305",
      building: "наб. реки Мойки, 48",
    });
    expect(result.days[1]).toEqual({ date: "2026-09-02", lessons: [] });
  });

  it("uses a seven-day Moscow range when dates are omitted", async () => {
    const fetchMock = vi.fn(async (input: string | URL | Request) => {
      const url = new URL(input instanceof Request ? input.url : input.toString());
      if (url.pathname.endsWith("/groups")) return jsonResponse(groups);
      if (url.pathname.endsWith("/faculties")) return jsonResponse(faculties);
      if (url.pathname.endsWith("/schedule")) {
        expect(url.searchParams.get("start_date")).toBe("2026-09-01");
        expect(url.searchParams.get("end_date")).toBe("2026-09-07");
        return jsonResponse([]);
      }
      throw new Error(`Unexpected URL: ${url}`);
    });
    const provider = new MpguScheduleProvider(
      config,
      fetchMock,
      () => new Date("2026-08-31T22:30:00Z"),
    );

    const result = await provider.getSchedule({ group: "101" });
    expect(result.dateFrom).toBe("2026-09-01");
    expect(result.dateTo).toBe("2026-09-07");
    expect(result.days).toHaveLength(7);
  });

  it("reports an ambiguous partial group without guessing", async () => {
    const provider = new MpguScheduleProvider(config, metadataFetch());
    await expect(provider.getSchedule({ group: "ИВТ" })).rejects.toMatchObject({
      code: "GROUP_AMBIGUOUS",
    } satisfies Partial<MpguMcpError>);
  });

  it("rejects unknown groups and invalid date ranges", async () => {
    const provider = new MpguScheduleProvider(config, metadataFetch());
    await expect(provider.getSchedule({ group: "999" })).rejects.toMatchObject({
      code: "GROUP_NOT_FOUND",
    });
    await expect(
      provider.getSchedule({
        group: "101",
        dateFrom: "2026-09-08",
        dateTo: "2026-09-01",
      }),
    ).rejects.toMatchObject({ code: "INVALID_DATE_RANGE" });
  });

  it("maps a schedule timeout to a stable error code", async () => {
    const fetchMock = vi.fn(async (input: string | URL | Request) => {
      const url = new URL(input instanceof Request ? input.url : input.toString());
      if (url.pathname.endsWith("/groups")) return jsonResponse(groups);
      if (url.pathname.endsWith("/faculties")) return jsonResponse(faculties);
      throw new DOMException("Timed out", "TimeoutError");
    });
    const provider = new MpguScheduleProvider(config, fetchMock);

    await expect(
      provider.getSchedule({
        group: "101",
        dateFrom: "2026-09-01",
        dateTo: "2026-09-01",
      }),
    ).rejects.toMatchObject({ code: "SCHEDULE_UNAVAILABLE" });
  });
});
