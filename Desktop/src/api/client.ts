import { storageService } from "../platform/storageService";

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
    public readonly offline = false,
  ) {
    super(message);
  }
}

const urls = {
  production: import.meta.env.VITE_API_PRODUCTION_URL || "https://api.mympsu.moonbaystudio.ru",
  development: import.meta.env.VITE_API_DEVELOPMENT_URL || "http://127.0.0.1:8000",
};

export async function apiRequest<T>(
  path: string,
  init: RequestInit = {},
  timeoutMs = 12_000,
): Promise<T> {
  const { apiEnvironment } = await storageService.getPreferences();
  const token = await storageService.getAuthToken();
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(`${urls[apiEnvironment]}${path}`, {
      ...init,
      signal: controller.signal,
      headers: {
        Accept: "application/json",
        ...(init.body ? { "Content-Type": "application/json" } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...init.headers,
      },
    });
    if (!response.ok) {
      const payload = (await response.json().catch(() => null)) as { detail?: string } | null;
      throw new ApiError(payload?.detail || `Ошибка сервера (${response.status})`, response.status);
    }
    if (response.status === 204) return undefined as T;
    return (await response.json()) as T;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(
      error instanceof DOMException && error.name === "AbortError"
        ? "Сервер не ответил вовремя"
        : "Нет соединения с сервером",
      undefined,
      true,
    );
  } finally {
    window.clearTimeout(timeout);
  }
}
