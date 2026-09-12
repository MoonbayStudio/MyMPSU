import type { AssistantChatResponse, ScheduleSnapshot } from "../models/domain";
import { apiRequest } from "./client";

interface SendAssistantMessageInput {
  message: string;
  conversationId: string;
  groupId: number;
  groupName: string;
  targetDate: string;
  schedule?: ScheduleSnapshot;
}

export function sendAssistantMessage(input: SendAssistantMessageInput): Promise<AssistantChatResponse> {
  const cachedSchedule = input.schedule
    ? {
        generatedAt: input.schedule.fetchedAt,
        source: `desktop_${input.schedule.source}`,
        lessons: input.schedule.lessons.map((lesson) => ({
          name: lesson.subject,
          type: lesson.type,
          startTime: lesson.startTime,
          endTime: lesson.endTime,
          date: lesson.date,
          room: lesson.room,
          teacher: lesson.teacher,
        })),
      }
    : undefined;

  return apiRequest<AssistantChatResponse>(
    "/assistant/chat",
    {
      method: "POST",
      body: JSON.stringify({
        message: input.message,
        persona: "pelikasha",
        conversationId: input.conversationId,
        groupId: input.groupId,
        groupName: input.groupName,
        targetDate: input.targetDate,
        context: {
          selectedGroupId: input.groupId,
          selectedGroupName: input.groupName,
          selectedDate: input.targetDate,
        },
        cachedSchedule,
      }),
    },
    120_000,
  );
}
