import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AppPreferences, ScheduleSnapshot } from "../models/domain";

const mocks = vi.hoisted(() => ({
  preferences: {
    theme: "system",
    apiEnvironment: "development",
    useMockSchedule: false,
    groupId: 2614,
    groupName: "Тест",
  } as AppPreferences,
  cache: null as ScheduleSnapshot | null,
  setScheduleCache: vi.fn(),
  apiRequest: vi.fn(),
}));

vi.mock("../platform/storageService", () => ({
  storageService: {
    getPreferences: vi.fn(async () => mocks.preferences),
    getScheduleCache: vi.fn(async () => mocks.cache),
    setScheduleCache: mocks.setScheduleCache,
  },
}));
vi.mock("./client", () => ({ apiRequest: mocks.apiRequest }));

import { getSchedule } from "./schedule";

describe("getSchedule offline cache", () => {
  beforeEach(() => {
    mocks.cache = null;
    mocks.apiRequest.mockReset();
    mocks.setScheduleCache.mockReset();
  });

  it("returns a stale snapshot without overwriting it when the network fails", async () => {
    mocks.cache = {
      groupId: 2614,
      groupName: "Тест",
      weekStart: "2026-09-07",
      lessons: [],
      fetchedAt: "2026-09-07T10:00:00.000Z",
      source: "network",
    };
    mocks.apiRequest.mockRejectedValue(new Error("offline"));

    await expect(getSchedule(new Date(2026, 8, 11))).resolves.toMatchObject({ source: "cache" });
    expect(mocks.setScheduleCache).not.toHaveBeenCalled();
  });

  it("keeps the original error when no cache exists", async () => {
    mocks.apiRequest.mockRejectedValue(new Error("offline"));
    await expect(getSchedule(new Date(2026, 8, 11))).rejects.toThrow("offline");
  });
});
