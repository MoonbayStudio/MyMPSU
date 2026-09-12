import { createApp } from "./app.js";
import { loadConfig } from "./config.js";
import { MpguScheduleProvider } from "./providers/schedule/MpguScheduleProvider.js";

const config = loadConfig();
const provider = new MpguScheduleProvider(config);
const app = createApp(config, provider);

const httpServer = app.listen(config.port, "0.0.0.0", () => {
  console.log(
    JSON.stringify({
      level: "info",
      event: "server_started",
      port: config.port,
      endpoints: { mcp: "/mcp", health: "/health" },
    }),
  );
});

function shutdown(signal: string): void {
  console.log(JSON.stringify({ level: "info", event: "server_stopping", signal }));
  httpServer.close((error) => {
    if (error) {
      console.error(JSON.stringify({ level: "error", event: "server_stop_failed" }));
      process.exitCode = 1;
    }
  });
}

process.once("SIGTERM", () => shutdown("SIGTERM"));
process.once("SIGINT", () => shutdown("SIGINT"));
