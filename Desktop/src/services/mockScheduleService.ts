import type { Lesson, ScheduleSnapshot } from "../models/domain";
import { addDays, startOfWeek, toIsoDate } from "./dateService";

const subjects = [
  ["Иностранный язык", "Смирнова Елена Викторовна", "307", "Практика"],
  ["История России", "Петрова Анна Сергеевна", "402", "Лекция"],
  ["Цифровые технологии в образовании", "Козлов Михаил Андреевич", "205", "Лабораторная"],
  ["Педагогика", "Орлова Марина Игоревна", "А-115", "Семинар"],
  ["Философия", "Волков Дмитрий Олегович", "504", "Лекция"],
  ["Психология", "Соколова Ирина Павловна", "218", "Практика"],
] as const;

const slots = [
  ["09:00", "10:30"],
  ["10:40", "12:10"],
  ["12:40", "14:10"],
  ["14:20", "15:50"],
  ["16:00", "17:30"],
] as const;

function hash(value: string): number {
  let result = 2166136261;
  for (const char of value) {
    result ^= char.charCodeAt(0);
    result = Math.imul(result, 16777619);
  }
  return result >>> 0;
}

function random(seed: number): () => number {
  let state = seed || 1;
  return () => {
    state = Math.imul(1664525, state) + 1013904223;
    return (state >>> 0) / 4294967296;
  };
}

export function generateMockSchedule(
  week: Date,
  groupId: number,
  groupName: string,
): ScheduleSnapshot {
  const monday = startOfWeek(week);
  const weekKey = toIsoDate(monday);
  const nextRandom = random(hash(`${groupId}:${weekKey}`));
  const lessons: Lesson[] = [];

  for (let day = 0; day < 6; day += 1) {
    const count = day === 5 ? Math.floor(nextRandom() * 2) : 2 + Math.floor(nextRandom() * 3);
    const firstSlot = Math.floor(nextRandom() * Math.max(1, slots.length - count));
    const usedSubjects = new Set<number>();

    for (let index = 0; index < count; index += 1) {
      let subjectIndex = Math.floor(nextRandom() * subjects.length);
      while (usedSubjects.has(subjectIndex)) subjectIndex = (subjectIndex + 1) % subjects.length;
      usedSubjects.add(subjectIndex);
      const [subject, teacher, room, type] = subjects[subjectIndex];
      const [startTime, endTime] = slots[firstSlot + index];
      const date = toIsoDate(addDays(monday, day));
      lessons.push({
        id: `mock-${date}-${startTime}-${subjectIndex}`,
        date,
        startTime,
        endTime,
        subject,
        teacher,
        room,
        type,
        address: "проспект Вернадского, 88",
      });
    }
  }

  return {
    groupId,
    groupName,
    weekStart: weekKey,
    lessons,
    fetchedAt: new Date().toISOString(),
    source: "mock",
  };
}
