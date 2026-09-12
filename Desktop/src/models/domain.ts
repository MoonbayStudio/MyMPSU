export type ThemePreference = "system" | "light" | "dark";
export type ApiEnvironment = "production" | "development";

export interface Lesson {
  id: string;
  date: string;
  startTime: string;
  endTime: string;
  subject: string;
  teacher: string;
  room: string;
  type: "Лекция" | "Практика" | "Семинар" | "Лабораторная";
  address?: string;
  subgroup?: string;
}

export interface ScheduleSnapshot {
  groupId: number;
  groupName: string;
  weekStart: string;
  lessons: Lesson[];
  fetchedAt: string;
  source: "mock" | "network" | "cache";
}

export interface UserRole {
  type: string;
  title: string;
  groupId?: number | null;
}

export interface UserProfile {
  id: string;
  displayName?: string | null;
  email?: string | null;
  contactEmail?: string | null;
  roles: UserRole[];
  tier: string;
  linkedProviders: string[];
}

export interface UserSettings {
  selectedGroupId: number | null;
  selectedGroupName: string | null;
  scheduleCacheWeeks: number;
  liveActivityEnabled: boolean;
}

export interface Homework {
  id: number;
  group_id: number;
  lesson_date: string;
  lesson_time?: string | null;
  subject: string;
  teacher?: string | null;
  room?: string | null;
  text: string;
  created_by: number;
  created_at: string;
  updated_at: string;
}

export type HomeworkDraft = Pick<
  Homework,
  "lesson_date" | "lesson_time" | "subject" | "teacher" | "room" | "text"
>;

export interface AppPreferences {
  theme: ThemePreference;
  apiEnvironment: ApiEnvironment;
  useMockSchedule: boolean;
  groupId: number;
  groupName: string;
}

export interface AssistantMessage {
  id: string;
  role: "user" | "assistant";
  content: string;
}

export interface AssistantChatResponse {
  reply: string;
  remaining: number;
  plan: string;
}
