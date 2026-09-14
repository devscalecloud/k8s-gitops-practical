import path from "path";
import express, { Request, Response } from "express";

const app = express();
const PORT = Number(process.env.PORT) || 3000;

// The frontend never talks to the backend directly from server-side code --
// the browser's own fetch() call does, via BACKEND_URL baked into the page.
// This keeps the dependency visible and breakable at the network layer
// (Service DNS, NetworkPolicy, backend health) rather than hidden behind a
// server-side proxy.
const BACKEND_URL = process.env.BACKEND_URL || "http://backend:4000";

app.get("/health", (_req: Request, res: Response) => {
  res.status(200).json({ status: "ok" });
});

app.get("/config.js", (_req: Request, res: Response) => {
  res.type("application/javascript").send(`window.BACKEND_URL = "${BACKEND_URL}";`);
});

app.use(express.static(path.join(__dirname, "..", "public")));

app.listen(PORT, () => {
  console.log(`frontend listening on :${PORT}, backend=${BACKEND_URL}`);
});
