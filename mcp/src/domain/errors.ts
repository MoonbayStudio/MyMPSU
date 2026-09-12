export const errorCodes = [
  "GROUP_NOT_FOUND",
  "GROUP_AMBIGUOUS",
  "SCHEDULE_UNAVAILABLE",
  "INVALID_DATE_RANGE",
  "UPSTREAM_UNAVAILABLE",
] as const;

export type MpguErrorCode = (typeof errorCodes)[number];

export class MpguMcpError extends Error {
  constructor(
    public readonly code: MpguErrorCode,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = "MpguMcpError";
  }
}

export function serializeError(error: unknown): {
  code: MpguErrorCode;
  message: string;
  details?: unknown;
} {
  if (error instanceof MpguMcpError) {
    return {
      code: error.code,
      message: error.message,
      ...(error.details === undefined ? {} : { details: error.details }),
    };
  }

  return {
    code: "UPSTREAM_UNAVAILABLE",
    message: "The official MyMPSU schedule service is unavailable.",
  };
}
