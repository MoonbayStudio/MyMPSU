export const MPGU_TIMEZONE = "Europe/Moscow" as const;

export interface Group {
  id: number;
  name: string;
  institute: string | null;
}

export interface ScheduleLesson {
  startTime: string;
  endTime: string;
  subject: string;
  type: string;
  teacher: string | null;
  room: string | null;
  building: string | null;
  subgroup: string | null;
  classUrl: string | null;
}

export interface ScheduleDay {
  date: string;
  lessons: ScheduleLesson[];
}

export interface SearchGroupsResult {
  groups: Group[];
}

export interface GetScheduleInput {
  group: string;
  dateFrom?: string;
  dateTo?: string;
}

export interface GetScheduleResult {
  group: Group;
  timezone: typeof MPGU_TIMEZONE;
  dateFrom: string;
  dateTo: string;
  days: ScheduleDay[];
  source: {
    name: string;
    url: string;
  };
}
