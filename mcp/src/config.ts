import { z } from "zod";

const integerFromEnv = (fallback: number, min: number, max: number) =>
  z.coerce.number().int().min(min).max(max).catch(fallback);

export interface AppConfig {
  port: number;
  mpguScheduleApiBaseUrl: URL;
  upstreamTimeoutMs: number;
  metadataCacheMs: number;
  rateLimitWindowMs: number;
  rateLimitMaxRequests: number;
  trustProxyHops: number;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const mpguScheduleApiBaseUrl = new URL(
    env.MPGU_SCHEDULE_API_BASE_URL ?? "https://api.mympsu.moonbaystudio.ru/schedule/v1",
  );

  if (mpguScheduleApiBaseUrl.protocol !== "https:") {
    throw new Error("MPGU_SCHEDULE_API_BASE_URL must use HTTPS");
  }

  if (mpguScheduleApiBaseUrl.hostname !== "api.mympsu.moonbaystudio.ru") {
    throw new Error("MPGU_SCHEDULE_API_BASE_URL must point to api.mympsu.moonbaystudio.ru");
  }

  mpguScheduleApiBaseUrl.pathname = mpguScheduleApiBaseUrl.pathname.replace(/\/+$/, "");

  return {
    port: integerFromEnv(3000, 1, 65_535).parse(env.PORT),
    mpguScheduleApiBaseUrl,
    upstreamTimeoutMs: integerFromEnv(10_000, 500, 30_000).parse(
      env.MPGU_SCHEDULE_API_TIMEOUT_MS,
    ),
    metadataCacheMs: integerFromEnv(600_000, 0, 3_600_000).parse(
      env.MPGU_METADATA_CACHE_MS,
    ),
    rateLimitWindowMs: integerFromEnv(60_000, 1_000, 3_600_000).parse(
      env.RATE_LIMIT_WINDOW_MS,
    ),
    rateLimitMaxRequests: integerFromEnv(60, 1, 10_000).parse(
      env.RATE_LIMIT_MAX_REQUESTS,
    ),
    trustProxyHops: integerFromEnv(0, 0, 3).parse(env.TRUST_PROXY_HOPS),
  };
}
