import type { ScheduleSnapshot } from "../models/domain";
import { storageService } from "../platform/storageService";
import { generateMockSchedule } from "../services/mockScheduleService";
import { startOfWeek, toIsoDate } from "../services/dateService";
import { apiRequest } from "./client";

export async function getSchedule(week: Date): Promise<ScheduleSnapshot> {
  const preferences = await storageService.getPreferences();
  const weekStart = toIsoDate(startOfWeek(week));
  const cacheKey = `${preferences.groupId}:${weekStart}`;

  if (preferences.useMockSchedule) {
    const snapshot = generateMockSchedule(week, preferences.groupId, preferences.groupName);
    await storageService.setScheduleCache(cacheKey, snapshot);
    return snapshot;
  }

  try {
    const snapshot = await apiRequest<ScheduleSnapshot>(
      `/schedule/v1/schedule?group_id=${preferences.groupId}&start_date=${weekStart}`,
    );
    const networkSnapshot = { ...snapshot, source: "network" as const, fetchedAt: new Date().toISOString() };
    await storageService.setScheduleCache(cacheKey, networkSnapshot);
    return networkSnapshot;
  } catch (error) {
    const cached = await storageService.getScheduleCache(cacheKey);
    if (cached) return { ...cached, source: "cache" };
    throw error;
  }
}
