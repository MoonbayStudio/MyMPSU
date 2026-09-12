import { beforeEach, describe, expect, it, vi } from "vitest";
import type { ScheduleSnapshot } from "../models/domain";

const mocks = vi.hoisted(() => ({ apiRequest: vi.fn() }));
vi.mock("./client", () => ({ apiRequest: mocks.apiRequest }));

import { sendAssistantMessage } from "./assistant";

describe("sendAssistantMessage", () => {
  beforeEach(() => mocks.apiRequest.mockReset());

  it("sends group and cached schedule context without exposing an API key", async () => {
    mocks.apiRequest.mockResolvedValue({ reply: "Ответ", remaining: 4, plan: "anonymous" });
    const schedule: ScheduleSnapshot = {
      groupId: 2614,
      groupName: "ВОЯ34-АИФ 2614 П/Г 2",
      weekStart: "2026-09-07",
      fetchedAt: "2026-09-11T09:00:00.000Z",
      source: "network",
      lessons: [{
        id: "lesson-1",
        date: "2026-09-11",
        startTime: "10:10",
        endTime: "11:40",
        subject: "Французский язык",
        teacher: "Преподаватель",
        room: "301",
        type: "Практика",
      }],
    };

    await sendAssistantMessage({
      message: "Какие пары сегодня?",
      conversationId: "conversation-1",
      groupId: 2614,
      groupName: schedule.groupName,
      targetDate: "2026-09-11",
      schedule,
    });

    const [, init, timeout] = mocks.apiRequest.mock.calls[0];
    const body = JSON.parse(init.body as string);
    expect(timeout).toBe(120_000);
    expect(body.groupId).toBe(2614);
    expect(body.cachedSchedule.lessons[0]).toMatchObject({
      name: "Французский язык",
      startTime: "10:10",
      room: "301",
    });
    expect(JSON.stringify(body)).not.toContain("OPENROUTER_API_KEY");
  });
});
