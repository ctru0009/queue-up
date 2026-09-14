import { buildServer } from "./app.js";

const host = "0.0.0.0";
const port = 3000;

const app = buildServer();

try {
  await app.listen({ host, port });
  app.log.info(`QueueUp API listening on http://${host}:${port}`);
} catch (error) {
  app.log.error(error, "QueueUp API failed to start");
  process.exit(1);
}
