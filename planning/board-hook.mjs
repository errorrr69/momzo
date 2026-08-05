// SessionStart hook: ensure the planning-board server is running and tell Claude
// what's pending. Stdout lands in Claude's context at session start.
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const PORT = 4321;

const alive = await fetch(`http://127.0.0.1:${PORT}/api/threads`, { signal: AbortSignal.timeout(1500) })
  .then(r => r.ok).catch(() => false);
if (alive) {
  console.log(`[board] server already running on :${PORT}`);
} else {
  spawn(process.execPath, [join(here, "server.mjs"), String(PORT)], { detached: true, stdio: "ignore" }).unref();
  console.log(`[board] server started on :${PORT}`);
}

const load = f => { try { return JSON.parse(readFileSync(join(here, f), "utf8")); } catch { return null; } };
const threads = load("threads.json") || {};
const pending = Object.entries(threads)
  .filter(([, msgs]) => msgs.length && msgs[msgs.length - 1].who !== "Claude")
  .map(([id]) => id);
const notes = load("notes.json") || [];
console.log(`[board] pending threads: ${pending.length}${pending.length ? ` (${pending.join(", ")})` : ""} · notes parked: ${notes.length}`);
console.log(pending.length
  ? "[board] ACTION: answer pending threads via POST /api/message (who:\"Claude\"), then arm the watcher — see the project's board memory."
  : "[board] ACTION: arm the threads.json watcher (persistent Monitor, 2s stat poll + touch claude-online.beat heartbeat).");
