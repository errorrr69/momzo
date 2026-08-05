// Planning board — local server.
// Serves the board on localhost + LAN and persists per-card discussion threads to
// threads.json and team-created topics/questions to topics.json, which Claude reads.
import { createServer } from "node:http";
import { readFile, writeFile, mkdir, stat, readdir, unlink } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { networkInterfaces, hostname } from "node:os";
import { execFile } from "node:child_process";
import { reverse } from "node:dns/promises";

/* Identify the sender by the connecting machine so nobody types a name.
   localhost → this machine's name; LAN peers → NetBIOS name (nbtstat), then
   reverse DNS, then the bare IP as last resort. Results are cached per IP. */
const whoCache = new Map();
function nbtName(ip) {
  return new Promise(res => {
    execFile("nbtstat", ["-A", ip], { timeout: 4000 }, (err, out) => {
      if (err || !out) return res(null);
      const m = out.match(/^\s*(\S+)\s+<00>\s+UNIQUE/m);
      res(m ? m[1] : null);
    });
  });
}
async function resolveWho(req) {
  let ip = (req.socket.remoteAddress || "").replace(/^::ffff:/, "");
  if (ip === "127.0.0.1" || ip === "::1" || ip === "") return hostname();
  if (whoCache.has(ip)) return whoCache.get(ip);
  let name = await nbtName(ip);
  if (!name) name = await reverse(ip).then(n => (n[0] || "").split(".")[0]).catch(() => null);
  const who = name || ip;
  whoCache.set(ip, who);
  return who;
}

const root = dirname(fileURLToPath(import.meta.url));
const THREADS = join(root, "threads.json");
const TOPICS = join(root, "topics.json");
const NOTES = join(root, "notes.json");
const ATTACH = join(root, "attachments");
const BEAT = join(root, "claude-online.beat"); // touched by Claude's watcher loop
const PORT = Number(process.env.BOARD_PORT || process.argv[2] || 4321);

const MIME = {
  png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif",
  webp: "image/webp", svg: "image/svg+xml", pdf: "application/pdf",
  txt: "text/plain", md: "text/plain", csv: "text/csv", json: "application/json",
  mp4: "video/mp4", zip: "application/zip",
};
// keep only {name, path} string pairs from client-supplied file refs
const cleanFiles = files => (Array.isArray(files) ? files : [])
  .filter(f => f && typeof f.name === "string" && typeof f.path === "string" &&
               !f.path.includes("..") && !f.path.includes("/") && !f.path.includes("\\"))
  .map(f => ({ name: f.name.slice(0, 120), path: f.path.slice(0, 160) }))
  .slice(0, 10);

async function loadThreads() {
  try { return JSON.parse(await readFile(THREADS, "utf8")); } catch { return {}; }
}
async function loadTopics() {
  try { return JSON.parse(await readFile(TOPICS, "utf8")); } catch { return []; }
}
async function loadNotes() {
  try { return JSON.parse(await readFile(NOTES, "utf8")); } catch { return []; }
}
async function readBody(req, max = 45_000_000) {
  let body = "";
  for await (const chunk of req) {
    body += chunk;
    if (body.length > max) throw new Error("body too large");
  }
  return JSON.parse(body);
}

createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  try {
    if (req.method === "GET" && (url.pathname === "/" || url.pathname === "/index.html")) {
      const html = await readFile(join(root, "index.html"), "utf8");
      res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      // index.html is authored headless (the artifact host wraps it); add the doctype
      // here too so the local render doesn't fall into quirks mode.
      res.end("<!doctype html>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" + html);
      return;
    }
    if (req.method === "GET" && url.pathname === "/api/topics") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(await loadTopics()));
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/topic") {
      const { title = "", text = "", who = "", kind = "topic", files = [] } = await readBody(req);
      if (!String(title).trim()) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end('{"error":"title required"}');
        return;
      }
      const sender = String(who).trim() || await resolveWho(req);
      const topics = await loadTopics();
      // "topic" cards (T#) get triaged into board items; "ask" cards (A#) are
      // questions to Claude, answered directly on their thread.
      const prefix = kind === "ask" ? "A" : "T";
      const next = topics.reduce((m, t) =>
        String(t.id)[0] === prefix ? Math.max(m, parseInt(String(t.id).slice(1)) || 0) : m, 0) + 1;
      const id = prefix + next;
      topics.push({ id, kind: prefix === "A" ? "ask" : "topic", title: String(title).slice(0, 120), who: sender.slice(0, 60), ts: new Date().toISOString() });
      await writeFile(TOPICS, JSON.stringify(topics, null, 2));
      // the topic's description becomes the first message of its thread
      const all = await loadThreads();
      (all[id] = all[id] || []).push({
        who: sender.slice(0, 60),
        stance: "",
        text: String(text).trim().slice(0, 5000) || String(title).slice(0, 120),
        files: cleanFiles(files),
        ts: new Date().toISOString(),
      });
      await writeFile(THREADS, JSON.stringify(all, null, 2));
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true, id }));
      return;
    }
    if (req.method === "GET" && url.pathname === "/api/threads") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(await loadThreads()));
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/message") {
      const { id, who = "", text = "", stance = "", files = [] } = await readBody(req);
      const okFiles = cleanFiles(files);
      if (!id || (!String(text).trim() && !stance && !okFiles.length)) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end('{"error":"id and text (or stance/files) required"}');
        return;
      }
      // who override is for Claude's own posts (curl from localhost);
      // the browser client sends no name and gets the machine identity.
      const sender = String(who).trim() || await resolveWho(req);
      const all = await loadThreads();
      (all[id] = all[id] || []).push({
        who: sender.slice(0, 60),
        stance: String(stance).slice(0, 20),
        text: String(text).slice(0, 5000),
        files: okFiles,
        ts: new Date().toISOString(),
      });
      await writeFile(THREADS, JSON.stringify(all, null, 2));
      res.writeHead(200, { "content-type": "application/json" });
      res.end('{"ok":true}');
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/upload") {
      const { name = "file", data = "" } = await readBody(req);
      const safe = String(name).replace(/[^\w.\- ()]+/g, "_").slice(-100) || "file";
      const fname = `${Date.now()}-${safe}`;
      await mkdir(ATTACH, { recursive: true });
      const buf = Buffer.from(String(data), "base64");
      await writeFile(join(ATTACH, fname), buf);
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true, name: safe, path: fname, size: buf.length }));
      return;
    }
    if (req.method === "GET" && url.pathname.startsWith("/files/")) {
      const fname = decodeURIComponent(url.pathname.slice(7));
      if (!fname || fname.includes("..") || fname.includes("/") || fname.includes("\\")) {
        res.writeHead(400, { "content-type": "text/plain" });
        res.end("bad filename");
        return;
      }
      try {
        const buf = await readFile(join(ATTACH, fname));
        const ext = (fname.split(".").pop() || "").toLowerCase();
        // User uploads are untrusted: only inert raster/media types may render
        // inline; active content (svg/html/xml/...) is always a download, and
        // every response is sniff-proofed + CSP-sandboxed (stored-XSS guard).
        const INLINE_OK = new Set(["png", "jpg", "jpeg", "gif", "webp", "pdf", "txt", "md", "csv", "mp4"]);
        const wantInline = !url.searchParams.get("dl") && INLINE_OK.has(ext);
        const mode = wantInline ? "inline" : "attachment";
        res.writeHead(200, {
          "content-type": wantInline ? (MIME[ext] || "application/octet-stream") : "application/octet-stream",
          "content-disposition": `${mode}; filename="${fname.replace(/^\d+-/, "").replace(/"/g, "")}"`,
          "x-content-type-options": "nosniff",
          "content-security-policy": "default-src 'none'; sandbox",
        });
        res.end(buf);
      } catch {
        res.writeHead(404, { "content-type": "text/plain" });
        res.end("file not found");
      }
      return;
    }
    if (req.method === "GET" && url.pathname === "/api/files") {
      let out = [];
      try {
        const names = await readdir(ATTACH);
        out = await Promise.all(names.map(async n => {
          const s = await stat(join(ATTACH, n));
          return { path: n, display: n.replace(/^\d+-/, ""), size: s.size, mtime: s.mtimeMs };
        }));
        out.sort((a, b) => b.mtime - a.mtime);
      } catch {}
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(out));
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/file-delete") {
      const { path = "" } = await readBody(req);
      if (!path || path.includes("..") || path.includes("/") || path.includes("\\")) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end('{"error":"bad path"}');
        return;
      }
      try { await unlink(join(ATTACH, path)); } catch {}
      res.writeHead(200, { "content-type": "application/json" });
      res.end('{"ok":true}');
      return;
    }
    if (req.method === "GET" && url.pathname === "/api/presence") {
      let live = false, ts = null;
      try {
        const s = await stat(BEAT);
        ts = s.mtimeMs;
        live = Date.now() - s.mtimeMs < 30_000;
      } catch {}
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ live, ts }));
      return;
    }
    if (req.method === "GET" && url.pathname === "/api/notes") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(await loadNotes()));
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/note") {
      const { title = "", text = "", who = "", files = [] } = await readBody(req);
      const okFiles = cleanFiles(files);
      if (!String(title).trim() && !String(text).trim() && !okFiles.length) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end('{"error":"title, text or files required"}');
        return;
      }
      const sender = String(who).trim() || await resolveWho(req);
      const notes = await loadNotes();
      const next = notes.reduce((m, n) => Math.max(m, parseInt(String(n.id).slice(1)) || 0), 0) + 1;
      const note = {
        id: "N" + next,
        who: sender.slice(0, 60),
        title: String(title).trim().slice(0, 120),
        text: String(text).slice(0, 10000),
        files: okFiles,
        ts: new Date().toISOString(),
      };
      notes.push(note);
      await writeFile(NOTES, JSON.stringify(notes, null, 2));
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true, id: note.id }));
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/note-update") {
      const { id, title, text = "", files } = await readBody(req);
      const notes = await loadNotes();
      const note = notes.find(n => n.id === id);
      if (!note) {
        res.writeHead(404, { "content-type": "application/json" });
        res.end('{"error":"note not found"}');
        return;
      }
      note.text = String(text).slice(0, 10000);
      if (title !== undefined) note.title = String(title).trim().slice(0, 120);
      if (files !== undefined) note.files = cleanFiles(files);
      note.edited = new Date().toISOString();
      await writeFile(NOTES, JSON.stringify(notes, null, 2));
      res.writeHead(200, { "content-type": "application/json" });
      res.end('{"ok":true}');
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/note-delete") {
      const { id } = await readBody(req);
      const notes = await loadNotes();
      const rest = notes.filter(n => n.id !== id);
      // attachments stay on disk in attachments/ — they belong to the project record
      await writeFile(NOTES, JSON.stringify(rest, null, 2));
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true, removed: notes.length - rest.length }));
      return;
    }
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("not found");
  } catch (e) {
    res.writeHead(500, { "content-type": "text/plain" });
    res.end(String(e));
  }
}).listen(PORT, "0.0.0.0", () => {
  console.log(`Planning board → http://localhost:${PORT}`);
  for (const addrs of Object.values(networkInterfaces()))
    for (const a of addrs || [])
      if (a.family === "IPv4" && !a.internal)
        console.log(`  team (LAN)        → http://${a.address}:${PORT}`);
});
