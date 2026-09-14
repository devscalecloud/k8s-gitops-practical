import express, { NextFunction, Request, Response } from "express";

const app = express();
const PORT = Number(process.env.PORT) || 4000;

// The frontend's page is served from a different origin (its own Service/
// Ingress) than this API, since the browser calls the backend directly
// rather than through a server-side proxy -- so CORS has to be opened
// explicitly or the browser blocks the response before JS ever sees it.
app.use((_req: Request, res: Response, next: NextFunction) => {
  res.header("Access-Control-Allow-Origin", "*");
  next();
});

app.get("/health", (_req: Request, res: Response) => {
  res.status(200).json({ status: "ok" });
});

app.get("/api/greeting", (_req: Request, res: Response) => {
  res.status(200).json({
    message: "Hello from the backend",
    pod: process.env.HOSTNAME || "unknown",
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`backend listening on :${PORT}`);
});
