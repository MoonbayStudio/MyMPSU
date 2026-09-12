import { load } from "@tauri-apps/plugin-store";
import { invoke } from "@tauri-apps/api/core";
import type { AppPreferences, ScheduleSnapshot } from "../models/domain";
import { isTauri } from "./platformService";

const defaultPreferences: AppPreferences = {
  theme: "system",
  apiEnvironment: (import.meta.env.VITE_API_ENV as AppPreferences["apiEnvironment"]) || "production",
  useMockSchedule: import.meta.env.VITE_USE_MOCK_SCHEDULE !== "false",
  groupId: 2614,
  groupName: "ВОЯ34-АИФ 2614 П/Г 2",
};

export interface StorageService {
  getPreferences(): Promise<AppPreferences>;
  setPreferences(value: AppPreferences): Promise<void>;
  getScheduleCache(key: string): Promise<ScheduleSnapshot | null>;
  setScheduleCache(key: string, value: ScheduleSnapshot): Promise<void>;
  getAuthToken(): Promise<string | null>;
  setAuthToken(token: string): Promise<void>;
  clearAuthToken(): Promise<void>;
}

class AppStorageService implements StorageService {
  async getPreferences(): Promise<AppPreferences> {
    const saved = await this.getPublic<AppPreferences>("preferences");
    return { ...defaultPreferences, ...saved };
  }

  async setPreferences(value: AppPreferences): Promise<void> {
    await this.setPublic("preferences", value);
  }

  getScheduleCache(key: string): Promise<ScheduleSnapshot | null> {
    return this.getPublic<ScheduleSnapshot>(`schedule:${key}`);
  }

  setScheduleCache(key: string, value: ScheduleSnapshot): Promise<void> {
    return this.setPublic(`schedule:${key}`, value);
  }

  async getAuthToken(): Promise<string | null> {
    if (!isTauri()) return null;
    return invoke<string | null>("get_auth_token");
  }

  async setAuthToken(token: string): Promise<void> {
    if (!isTauri()) throw new Error("Авторизация доступна только в desktop-приложении");
    await invoke("set_auth_token", { token });
  }

  async clearAuthToken(): Promise<void> {
    if (isTauri()) await invoke("clear_auth_token");
  }

  private async getPublic<T>(key: string): Promise<T | null> {
    if (isTauri()) {
      const store = await load("app-data.json", { autoSave: 100 });
      return (await store.get<T>(key)) ?? null;
    }
    const value = window.localStorage.getItem(`mympsu:${key}`);
    return value ? (JSON.parse(value) as T) : null;
  }

  private async setPublic<T>(key: string, value: T): Promise<void> {
    if (isTauri()) {
      const store = await load("app-data.json", { autoSave: 100 });
      await store.set(key, value);
      return;
    }
    window.localStorage.setItem(`mympsu:${key}`, JSON.stringify(value));
  }
}

export const storageService: StorageService = new AppStorageService();
export { defaultPreferences };
