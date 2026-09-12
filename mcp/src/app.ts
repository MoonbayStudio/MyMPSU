import { randomUUID } from "node:crypto";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express, { type Express, type Request, type Response } from "express";
import type { AppConfig } from "./config.js";
import { createRateLimit } from "./http/rateLimit.js";
import { createMcpServer } from "./mcp/createMcpServer.js";
import type { ScheduleProvider } from "./providers/schedule/ScheduleProvider.js";

export function createApp(config: AppConfig, provider: ScheduleProvider): Express {
  const app = express();
  app.disable("x-powered-by");
  if (config.trustProxyHops > 0) {
    app.set("trust proxy", config.trustProxyHops);
  }
  app.use(express.json({ limit: "256kb" }));

  app.use((request, response, next) => {
    const requestId = request.header("x-request-id")?.slice(0, 128) || randomUUID();
    response.setHeader("x-request-id", requestId);
    response.locals.requestId = requestId;
    next();
  });

  app.get("/health", (_request, response) => {
    response.json({ status: "ok", service: "my-mpsu-schedule-mcp" });
  });

  app.post(
    "/mcp",
    createRateLimit({
      windowMs: config.rateLimitWindowMs,
      maxRequests: config.rateLimitMaxRequests,
    }),
    async (request: Request, response: Response) => {
      const startedAt = performance.now();
      const server = createMcpServer(provider);
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: undefined,
        enableJsonResponse: true,
      });

      response.on("close", () => {
        void transport.close();
        void server.close();
      });

      try {
        await server.connect(transport);
        await transport.handleRequest(request, response, request.body);
        logRequest(request, response, startedAt, true);
      } catch (error) {
        logRequest(request, response, startedAt, false, error);
        if (!response.headersSent) {
          response.status(500).json({
            jsonrpc: "2.0",
            error: { code: -32603, message: "Internal MCP server error" },
            id: null,
          });
        }
      }
    },
  );

  app.all("/mcp", (_request, response) => {
    response.setHeader("Allow", "POST");
    response.status(405).json({ error: { code: "METHOD_NOT_ALLOWED" } });
  });

  app.use(
    (
      error: unknown,
      _request: Request,
      response: Response,
      _next: express.NextFunction,
    ) => {
      const isSyntaxError = error instanceof SyntaxError;
      response.status(isSyntaxError ? 400 : 500).json({
        error: {
          code: isSyntaxError ? "INVALID_JSON" : "INTERNAL_ERROR",
          message: isSyntaxError ? "Request body is not valid JSON." : "Internal server error.",
        },
      });
    },
  );

  return app;
}

function logRequest(
  request: Request,
  response: Response,
  startedAt: number,
  success: boolean,
  error?: unknown,
): void {
  const payload = {
    level: success ? "info" : "error",
    event: "http_request",
    requestId: response.locals.requestId,
    method: request.method,
    path: request.path,
    status: response.statusCode,
    durationMs: Math.round(performance.now() - startedAt),
    success,
    ...(error instanceof Error ? { error: error.message } : {}),
  };
  (success ? console.log : console.error)(JSON.stringify(payload));
}
