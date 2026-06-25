// Momzo activities seeder (Task 18) — parses the themed activity lists in
// knowledge base/activities/*.txt into structured `activities` rows. Idempotent
// via a slug (re-run as the library grows). No LLM needed; deterministic parse.
//
// Run:  cd supabase/seed && node build_activities.mjs
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const dir = join(repoRoot, 'knowledge base', 'activities');

function parseEnv(p) {
  const o = {};
  for (const r of readFileSync(p, 'utf8').split(/\r?\n/)) {
    const l = r.trim(); if (!l || l.startsWith('#')) continue;
    const e = l.indexOf('='); if (e < 0) continue;
    const k = l.slice(0, e).trim(); let v = l.slice(e + 1).trim();
    v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim();
    o[k] = v;
  }
  return o;
}
const env = parseEnv(join(here, '..', '.env'));
const admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

// Per-file domain -> default age band.
const DOMAIN = [
  { match: /behaviour/i, domain: 'behaviour', age: [3, 9] },
  { match: /emotional/i, domain: 'emotional', age: [4, 10] },
  { match: /reading/i, domain: 'reading', age: [3, 9] },
];

const slugify = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60);

function skillFor(theme) {
  const t = theme.toLowerCase();
  if (/independ|self-esteem|self esteem|confiden|courage|choice|author/.test(t)) return 'confidence';
  if (/emotion|stress|regulat|calm|anxiet|fear|lid|gratitude|positiv/.test(t)) return 'regulation';
  if (/communicat|listen|kindness|empath|connection|attention|temperament|manner/.test(t)) return 'connection';
  if (/read|literacy|book|stor|milestone|media|values/.test(t)) return 'literacy';
  if (/pick|eat|instruct|transition|lying|sleep|behaviou?r|why|analysis/.test(t)) return 'behavior';
  return 'play';
}

function durationFor(text) {
  const m = text.match(/(\d+)\s*(?:[–-]\s*(\d+))?\s*min/i);
  if (m) {
    const n = m[2] ? Number(m[2]) : Number(m[1]);
    return n <= 7 ? 5 : n <= 22 ? 15 : 30;
  }
  return 15; // sensible default bucket
}

function locationsFor(text) {
  const t = text.toLowerCase();
  const out = new Set();
  if (/cook|kitchen|dishwasher|\bsink\b|recipe|\bmeal\b|sandwich|pizza|\bfood\b|snack|eat/.test(t)) out.add('kitchen');
  if (/\bcar\b|car ride|appointment|doctor|grocery|shopping|library|outside|outdoor|playground|community|nursing home|food bank/.test(t)) out.add('outdoor');
  if (out.size === 0) out.add('indoor');
  return [...out];
}

const MATERIALS = ['jar', 'timer', 'book', 'blanket', 'pillow', 'lamp', 'stuffed animal', 'paper', 'crayon', 'blocks', 'doll', 'puppet', 'mask', 'chart', 'card'];
function materialsFor(text) {
  const t = text.toLowerCase();
  return MATERIALS.filter((m) => t.includes(m));
}

function steps(text) {
  return text
    .split(/(?<=[.!?])\s+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 12)
    .slice(0, 5);
}

function cleanTitle(raw) {
  return raw.replace(/[“”"']/g, '').replace(/^The\s+/i, '').replace(/\s+/g, ' ').trim();
}

function parseFile(text) {
  const out = [];
  let theme = 'Play';
  let current = null;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line === '.') continue;
    const th = line.match(/^(\d+)\.\s+(.+)$/);
    if (th) { theme = th[2].trim(); current = null; continue; }
    const act = line.match(/^Actionable Step:\s*(.+)$/i);
    if (act) { if (current) current.body += ' ' + act[1]; continue; }
    const colon = line.indexOf(':');
    if (colon > 0 && colon < 80) {
      current = { theme, title: cleanTitle(line.slice(0, colon)), body: line.slice(colon + 1).trim() };
      out.push(current);
    } else if (current) {
      current.body += ' ' + line; // wrapped continuation
    }
  }
  return out;
}

let count = 0;
for (const file of readdirSync(dir).filter((f) => f.endsWith('.txt'))) {
  const meta = DOMAIN.find((d) => d.match.test(file)) ?? { domain: 'general', age: [4, 10] };
  const acts = parseFile(readFileSync(join(dir, file), 'utf8'));
  for (const a of acts) {
    if (!a.title || !a.body) continue;
    const row = {
      slug: `${meta.domain}-${slugify(a.title)}`,
      title: a.title,
      steps: steps(a.body),
      skill: skillFor(a.theme),
      age_min: meta.age[0],
      age_max: meta.age[1],
      duration_min: durationFor(a.body),
      location: locationsFor(a.body),
      materials: materialsFor(a.body),
    };
    const { error } = await admin.from('activities').upsert(row, { onConflict: 'slug' });
    if (error) throw new Error(`${row.slug}: ${error.message}`);
    count++;
  }
  console.log(`${file}: ${acts.length} activities`);
}
console.log(`\nDone. activities upserted: ${count}`);
