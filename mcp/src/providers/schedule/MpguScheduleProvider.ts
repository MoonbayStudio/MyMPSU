import { z } from "zod";
import type { AppConfig } from "../../config.js";
import { MpguMcpError } from "../../domain/errors.js";
import {
  MPGU_TIMEZONE,
  type GetScheduleInput,
  type GetScheduleResult,
  type Group,
  type ScheduleDay,
  type ScheduleLesson,
  type SearchGroupsResult,
} from "../../domain/schedule.js";
import type { ScheduleProvider } from "./ScheduleProvider.js";

const MAX_RESPONSE_BYTES = 4 * 1024 * 1024;
const MAX_DATE_RANGE_DAYS = 31;
const DEFAULT_DATE_RANGE_DAYS = 7;
const MAX_GROUP_RESULTS = 20;

const upstreamGroupSchema = z.object({
  id: z.number().int(),
  name: z.string(),
  faculty_id: z.number().int(),
});

const upstreamFacultySchema = z.object({
  id: z.number().int(),
  name: z.string(),
});

const upstreamScheduleSchema = z.object({
  start_time: z.string(),
  end_time: z.string(),
  name: z.string(),
  type: z.string(),
  teacher_id: z.number().int().nullish(),
  room_id: z.number().int().nullish(),
  sub_group_id: z.number().int().nullish(),
  class_url: z.string().nullish(),
});

const upstreamTeacherSchema = z.object({
  id: z.number().int(),
  name: z.string(),
});

const upstreamRoomSchema = z.object({
  id: z.number().int(),
  name: z.string(),
  building_id: z.number().int().nullish(),
});

const upstreamBuildingSchema = z.object({
  id: z.number().int(),
  name: z.string(),
});

type FetchLike = typeof fetch;
type UpstreamGroup = z.infer<typeof upstreamGroupSchema>;
type UpstreamFaculty = z.infer<typeof upstreamFacultySchema>;

interface MetadataCache {
  expiresAt: number;
  groups: UpstreamGroup[];
  faculties: UpstreamFaculty[];
}

function normalizeGroupName(value: string): string {
  return value
    .normalize("NFKC")
    .toLocaleLowerCase("ru-RU")
    .replace(/[‐‑‒–—−]/g, "-")
    .replace(/\s+/g, "")
    .trim();
}

function parseDateOnly(value: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    return null;
  }
  return date;
}

function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setUTCDate(result.getUTCDate() + days);
  return result;
}

function dateOnly(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function todayInMoscow(now: Date): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: MPGU_TIMEZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function timeFromIso(value: string): string {
  const match = value.match(/T(\d{2}:\d{2})/);
  return match?.[1] ?? value.slice(11, 16);
}

function uniqueIds(values: Array<number | null | undefined>): number[] {
  return [...new Set(values.filter((value): value is number => value != null))];
}

export class MpguScheduleProvider implements ScheduleProvider {
  private metadataCache: MetadataCache | null = null;

  constructor(
    private readonly config: AppConfig,
    private readonly fetchImpl: FetchLike = fetch,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async searchGroups(query: string): Promise<SearchGroupsResult> {
    const normalizedQuery = normalizeGroupName(query);
    const { groups, faculties } = await this.getMetadata();
    const facultyNames = new Map(faculties.map((faculty) => [faculty.id, faculty.name]));

    const matches = groups
      .filter((group) => normalizeGroupName(group.name).includes(normalizedQuery))
      .sort((left, right) => {
        const leftExact = normalizeGroupName(left.name) === normalizedQuery ? 0 : 1;
        const rightExact = normalizeGroupName(right.name) === normalizedQuery ? 0 : 1;
        return leftExact - rightExact || left.name.localeCompare(right.name, "ru");
      })
      .slice(0, MAX_GROUP_RESULTS)
      .map((group) => this.toGroup(group, facultyNames));

    return { groups: matches };
  }

  async getSchedule(input: GetScheduleInput): Promise<GetScheduleResult> {
    const { start, end } = this.resolveDateRange(input.dateFrom, input.dateTo);
    const { groups, faculties } = await this.getMetadata();
    const facultyNames = new Map(faculties.map((faculty) => [faculty.id, faculty.name]));
    const group = this.resolveGroup(input.group, groups, facultyNames);

    const schedule = await this.request(
      "schedule",
      {
        group_id: String(group.id),
        start_date: dateOnly(start),
        end_date: dateOnly(end),
        exam_only: "false",
      },
      z.array(upstreamScheduleSchema),
      "SCHEDULE_UNAVAILABLE",
    );

    const teacherIds = uniqueIds(schedule.map((lesson) => lesson.teacher_id));
    const roomIds = uniqueIds(schedule.map((lesson) => lesson.room_id));

    const [teachers, rooms] = await Promise.all([
      teacherIds.length === 0
        ? []
        : this.request(
            "teachers",
            { teacher_ids: teacherIds.join(",") },
            z.array(upstreamTeacherSchema),
          ),
      roomIds.length === 0
        ? []
        : this.request(
            "rooms",
            { room_ids: roomIds.join(",") },
            z.array(upstreamRoomSchema),
          ),
    ]);

    const buildingIds = uniqueIds(rooms.map((room) => room.building_id));
    const buildings =
      buildingIds.length === 0
        ? []
        : await this.request(
            "buildings",
            { building_ids: buildingIds.join(",") },
            z.array(upstreamBuildingSchema),
          );

    const teacherNames = new Map(teachers.map((teacher) => [teacher.id, teacher.name]));
    const roomsById = new Map(rooms.map((room) => [room.id, room]));
    const buildingNames = new Map(
      buildings.map((building) => [building.id, building.name]),
    );
    const lessonsByDate = new Map<string, ScheduleLesson[]>();

    for (const lesson of schedule) {
      const date = lesson.start_time.slice(0, 10);
      if (!parseDateOnly(date)) continue;
      const room = lesson.room_id == null ? undefined : roomsById.get(lesson.room_id);
      const normalized: ScheduleLesson = {
        startTime: timeFromIso(lesson.start_time),
        endTime: timeFromIso(lesson.end_time),
        subject: lesson.name,
        type: lesson.type,
        teacher:
          lesson.teacher_id == null ? null : (teacherNames.get(lesson.teacher_id) ?? null),
        room: room?.name ?? null,
        building:
          room?.building_id == null ? null : (buildingNames.get(room.building_id) ?? null),
        subgroup: lesson.sub_group_id == null ? null : String(lesson.sub_group_id),
        classUrl: lesson.class_url ?? null,
      };
      const lessons = lessonsByDate.get(date) ?? [];
      lessons.push(normalized);
      lessonsByDate.set(date, lessons);
    }

    const days: ScheduleDay[] = [];
    for (let date = start; date <= end; date = addDays(date, 1)) {
      const key = dateOnly(date);
      const lessons = lessonsByDate.get(key) ?? [];
      lessons.sort((left, right) => left.startTime.localeCompare(right.startTime));
      days.push({ date: key, lessons });
    }

    return {
      group,
      timezone: MPGU_TIMEZONE,
      dateFrom: dateOnly(start),
      dateTo: dateOnly(end),
      days,
      source: {
        name: "MyMPSU schedule API",
        url: new URL("schedule", `${this.config.mpguScheduleApiBaseUrl.toString()}/`).toString(),
      },
    };
  }

  private async getMetadata(): Promise<{
    groups: UpstreamGroup[];
    faculties: UpstreamFaculty[];
  }> {
    if (this.metadataCache && this.metadataCache.expiresAt > Date.now()) {
      return this.metadataCache;
    }

    const [groups, faculties] = await Promise.all([
      this.request("groups", undefined, z.array(upstreamGroupSchema)),
      this.request("faculties", undefined, z.array(upstreamFacultySchema)),
    ]);
    this.metadataCache = {
      groups,
      faculties,
      expiresAt: Date.now() + this.config.metadataCacheMs,
    };
    return this.metadataCache;
  }

  private resolveGroup(
    value: string,
    groups: UpstreamGroup[],
    facultyNames: Map<number, string>,
  ): Group {
    const trimmed = value.trim();
    const numericId = /^\d+$/.test(trimmed) ? Number(trimmed) : null;
    const matches = numericId == null
      ? groups.filter((group) =>
          normalizeGroupName(group.name).includes(normalizeGroupName(trimmed)),
        )
      : groups.filter((group) => group.id === numericId);
    const exactMatches = numericId == null
      ? matches.filter(
          (group) => normalizeGroupName(group.name) === normalizeGroupName(trimmed),
        )
      : matches;
    const candidates = exactMatches.length > 0 ? exactMatches : matches;

    if (candidates.length === 0) {
      throw new MpguMcpError(
        "GROUP_NOT_FOUND",
        `No MPGU student group matches "${trimmed}".`,
      );
    }
    if (candidates.length > 1) {
      throw new MpguMcpError(
        "GROUP_AMBIGUOUS",
        `More than one MPGU student group matches "${trimmed}".`,
        {
          groups: candidates.slice(0, MAX_GROUP_RESULTS).map((group) =>
            this.toGroup(group, facultyNames),
          ),
        },
      );
    }

    return this.toGroup(candidates[0], facultyNames);
  }

  private resolveDateRange(dateFrom?: string, dateTo?: string): {
    start: Date;
    end: Date;
  } {
    const defaultStart = todayInMoscow(this.now());
    const startText = dateFrom ?? defaultStart;
    const endText = dateTo ?? (dateFrom ? startText : dateOnly(addDays(parseDateOnly(defaultStart)!, DEFAULT_DATE_RANGE_DAYS - 1)));
    const start = parseDateOnly(startText);
    const end = parseDateOnly(endText);

    if (!start || !end || end < start) {
      throw new MpguMcpError(
        "INVALID_DATE_RANGE",
        "dateFrom and dateTo must be valid YYYY-MM-DD dates, and dateTo must not precede dateFrom.",
      );
    }

    const rangeDays = Math.floor((end.getTime() - start.getTime()) / 86_400_000) + 1;
    if (rangeDays > MAX_DATE_RANGE_DAYS) {
      throw new MpguMcpError(
        "INVALID_DATE_RANGE",
        `The requested date range must not exceed ${MAX_DATE_RANGE_DAYS} days.`,
      );
    }

    return { start, end };
  }

  private toGroup(group: UpstreamGroup, facultyNames: Map<number, string>): Group {
    return {
      id: group.id,
      name: group.name,
      institute: facultyNames.get(group.faculty_id) ?? null,
    };
  }

  private async request<T>(
    path: string,
    params: Record<string, string> | undefined,
    schema: z.ZodType<T>,
    errorCode: "SCHEDULE_UNAVAILABLE" | "UPSTREAM_UNAVAILABLE" = "UPSTREAM_UNAVAILABLE",
  ): Promise<T> {
    const url = new URL(
      `${this.config.mpguScheduleApiBaseUrl.pathname.replace(/\/$/, "")}/${path}`,
      this.config.mpguScheduleApiBaseUrl,
    );
    for (const [key, value] of Object.entries(params ?? {})) {
      url.searchParams.set(key, value);
    }

    try {
      const response = await this.fetchImpl(url, {
        headers: { accept: "application/json" },
        signal: AbortSignal.timeout(this.config.upstreamTimeoutMs),
      });
      if (!response.ok) {
        throw new MpguMcpError(
          response.status >= 500 ? "UPSTREAM_UNAVAILABLE" : errorCode,
          `The official MyMPSU schedule API returned HTTP ${response.status}.`,
        );
      }

      const contentLength = Number(response.headers.get("content-length") ?? "0");
      if (contentLength > MAX_RESPONSE_BYTES) {
        throw new MpguMcpError(errorCode, "The official MyMPSU schedule API response is too large.");
      }
      const body = await response.text();
      if (Buffer.byteLength(body, "utf8") > MAX_RESPONSE_BYTES) {
        throw new MpguMcpError(errorCode, "The official MyMPSU schedule API response is too large.");
      }
      return schema.parse(JSON.parse(body));
    } catch (error) {
      if (error instanceof MpguMcpError) throw error;
      throw new MpguMcpError(
        errorCode === "SCHEDULE_UNAVAILABLE" ? errorCode : "UPSTREAM_UNAVAILABLE",
        "The official MyMPSU schedule service is unavailable.",
      );
    }
  }
}
