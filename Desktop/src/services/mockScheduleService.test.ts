import { describe, expect, it } from "vitest";
import { generateMockSchedule } from "./mockScheduleService";

describe("generateMockSchedule", () => {
  it("is deterministic for a group and week", () => {
    const first = generateMockSchedule(new Date(2026, 8, 11), 2614, "ВОЯ34-АИФ 2614 П/Г 2");
    const second = generateMockSchedule(new Date(2026, 8, 7), 2614, "ВОЯ34-АИФ 2614 П/Г 2");
    expect(first.lessons).toEqual(second.lessons);
  });
  it("generates sorted unique lessons", () => {
    const snapshot = generateMockSchedule(new Date(2026, 8, 11), 2614, "Тест");
    expect(new Set(snapshot.lessons.map((item) => item.id)).size).toBe(snapshot.lessons.length);
    expect(snapshot.lessons.length).toBeGreaterThan(8);
  });
});
