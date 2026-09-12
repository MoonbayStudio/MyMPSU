import type { Lesson } from "../models/domain";

export function toIsoDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function startOfWeek(date: Date): Date {
  const result = new Date(date);
  const weekday = (result.getDay() + 6) % 7;
  result.setHours(0, 0, 0, 0);
  result.setDate(result.getDate() - weekday);
  return result;
}

export function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

export function combineDateAndTime(date: string, time: string): Date {
  return new Date(`${date}T${time}:00`);
}

export function sortLessons(lessons: Lesson[]): Lesson[] {
  return [...lessons].sort((left, right) =>
    `${left.date}T${left.startTime}`.localeCompare(`${right.date}T${right.startTime}`),
  );
}

export function getLessonState(
  lesson: Lesson,
  now: Date,
): "past" | "current" | "next" | "later" {
  const start = combineDateAndTime(lesson.date, lesson.startTime);
  const end = combineDateAndTime(lesson.date, lesson.endTime);
  if (now >= start && now < end) return "current";
  if (now >= end) return "past";
  return "later";
}

export function markNextLesson(lessons: Lesson[], now: Date): Map<string, ReturnType<typeof getLessonState>> {
  const states = new Map(lessons.map((lesson) => [lesson.id, getLessonState(lesson, now)]));
  const next = sortLessons(lessons).find((lesson) => states.get(lesson.id) === "later");
  if (next) states.set(next.id, "next");
  return states;
}
