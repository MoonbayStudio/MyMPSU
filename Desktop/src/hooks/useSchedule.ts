import { useQuery } from "@tanstack/react-query";
import { getSchedule } from "../api/schedule";
import { toIsoDate, startOfWeek } from "../services/dateService";
import { useAppContext } from "../app/AppContext";

export function useSchedule(week: Date) {
  const { preferences } = useAppContext();
  return useQuery({
    queryKey: ["schedule", preferences.groupId, preferences.useMockSchedule, toIsoDate(startOfWeek(week))],
    queryFn: () => getSchedule(week),
    staleTime: preferences.useMockSchedule ? Number.POSITIVE_INFINITY : 5 * 60 * 1000,
  });
}
