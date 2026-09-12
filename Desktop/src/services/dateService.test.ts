import { describe, expect, it } from "vitest";
import type { Lesson } from "../models/domain";
import { getLessonState, markNextLesson, sortLessons, startOfWeek, toIsoDate } from "./dateService";

const lesson = (id: string, date: string, startTime: string, endTime: string): Lesson => ({ id, date, startTime, endTime, subject: "Тест", teacher: "Преподаватель", room: "1", type: "Лекция" });

describe("dateService", () => {
  it("finds Monday in local time", () => expect(toIsoDate(startOfWeek(new Date(2026, 8, 11)))).toBe("2026-09-07"));
  it("sorts lessons by date and time", () => {
    const items = [lesson("b", "2026-09-08", "09:00", "10:30"), lesson("a", "2026-09-07", "14:20", "15:50")];
    expect(sortLessons(items).map((item) => item.id)).toEqual(["a", "b"]);
  });
  it("detects a current lesson", () => expect(getLessonState(lesson("a", "2026-09-11", "10:40", "12:10"), new Date(2026, 8, 11, 11))).toBe("current"));
  it("marks only the first future lesson as next", () => {
    const items = [lesson("a", "2026-09-11", "12:40", "14:10"), lesson("b", "2026-09-11", "14:20", "15:50")];
    const states = markNextLesson(items, new Date(2026, 8, 11, 11));
    expect(states.get("a")).toBe("next");
    expect(states.get("b")).toBe("later");
  });
});
