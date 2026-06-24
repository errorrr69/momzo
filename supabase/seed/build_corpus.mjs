// Momzo content-corpus ingest (Task 11) — idempotent and re-runnable as the
// expert corpus grows. For each source article it:
//   1. derives a stable slug (from the file path) so re-runs UPSERT, never dupe
//   2. generates a "why it matters at home" tie-in (Gemini Flash)
//   3. chunks the body and embeds each chunk (Gemini embedding, 768-dim)
//   4. upserts content_cards + replaces content_embeddings
//
// One corpus feeds BOTH daily cards (content_cards) and RAG (content_embeddings),
// per the locked decision. Uses the service_role key (server-side; bypasses RLS).
//
// Run:  cd supabase/seed && npm install && node build_corpus.mjs [--limit N]
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');

// New top-level content folders get added here. Sub-folders are walked automatically.
const ROOTS = ['Preschoolers (4-7)', 'emotional development'];

// Category (matched against any path segment) -> tags + age targeting. The app's
// daily-card targeting (6-10) surfaces the overlapping ones; RAG uses all.
const CATEGORY = {
  'cdcs-developmental-milestones': { tags: ['milestones', 'development'], age: [3, 6] },
  'challenging-behaviors': { tags: ['behavior', 'self-control'], age: [2, 8] },
  'digital-world-and-kids': { tags: ['screen-time', 'digital'], age: [4, 10] },
  'discipline': { tags: ['discipline', 'behavior'], age: [3, 10] },
  'family-dynamics': { tags: ['family', 'connection'], age: [4, 10] },
  'reading & literacy': { tags: ['reading', 'literacy'], age: [3, 7] },
  'milestones': { tags: ['milestones', 'development'], age: [4, 6] },
  'emotional development': { tags: ['emotional', 'feelings', 'temperament'], age: [4, 10] },
};
const DEFAULT_CAT = { tags: ['parenting'], age: [4, 10] };

const EMBED_MODEL = 'gemini-embedding-001';      // embeddings via Gemini (768d)
const GEN_MODEL = 'mistral-small-latest';         // text generation via Mistral (cheap default)

// ---- config (supabase/.env or process.env) ----
function parseEnv(path) {
  const out = {};
  let text;
  try { text = readFileSync(path, 'utf8'); } catch { return out; }
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1).trim();
    if (val.startsWith('"')) val = val.slice(1, val.indexOf('"', 1));
    else val = val.split(/\s+#/)[0].trim();
    out[key] = val;
  }
  return out;
}
const env = parseEnv(join(here, '..', '.env'));
const SUPABASE_URL = process.env.SUPABASE_URL || env.SUPABASE_URL;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
const GKEY = process.env.GOOGLE_API_KEY || env.GOOGLE_API_KEY;          // embeddings
const MKEY = process.env.MISTRAL_API_KEY || env.MISTRAL_API_KEY;        // generation
if (!SUPABASE_URL || !SERVICE || !GKEY) {
  throw new Error('Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / GOOGLE_API_KEY.');
}
const admin = createClient(SUPABASE_URL, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const vecLiteral = (v) => '[' + v.join(',') + ']';

function walk(dir) {
  const out = [];
  let entries;
  try { entries = readdirSync(dir); } catch { return out; }
  for (const name of entries) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (['.md', '.txt'].includes(extname(p).toLowerCase())) out.push(p);
  }
  return out;
}

function categorize(relPath) {
  for (const seg of relPath.split(/[\\/]/)) {
    if (CATEGORY[seg]) return CATEGORY[seg];
  }
  return DEFAULT_CAT;
}

function parseDoc(text) {
  const lines = text.split(/\r?\n/);
  let title = '';
  for (const l of lines) {
    const t = l.trim();
    if (t) { title = t.replace(/^#+\s*/, '').trim(); break; }
  }
  return { title: title || 'Untitled', body: text.trim() };
}

function chunk(body) {
  const paras = body.split(/\n\s*\n/).map((s) => s.trim()).filter(Boolean);
  const chunks = [];
  let cur = '';
  let words = 0;
  for (const p of paras) {
    const w = p.split(/\s+/).length;
    if (words + w > 280 && cur) { chunks.push(cur.trim()); cur = ''; words = 0; }
    cur += (cur ? '\n\n' : '') + p;
    words += w;
  }
  if (cur.trim()) chunks.push(cur.trim());
  return chunks.length ? chunks : [body];
}

async function gFetch(url, body, tries = 5) {
  for (let i = 0; i < tries; i++) {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (res.status === 429 || res.status >= 500) { await sleep(2500 * (i + 1)); continue; }
    const j = await res.json();
    if (!res.ok) throw new Error(`${res.status} ${JSON.stringify(j).slice(0, 200)}`);
    return j;
  }
  throw new Error('gemini: rate-limited after retries');
}

async function embed(text) {
  const j = await gFetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${EMBED_MODEL}:embedContent?key=${GKEY}`,
    { model: `models/${EMBED_MODEL}`, content: { parts: [{ text }] }, outputDimensionality: 768 },
  );
  return j.embedding.values;
}

async function whyItMatters(title, body) {
  if (!MKEY) return null;
  const prompt =
    'You are helping a parenting app for mothers of 6-10 year olds. In ONE warm, ' +
    'concrete sentence (max 30 words), finish the thought "Why this matters at home:" ' +
    '— connect the article to something a parent notices day to day. Output only the ' +
    `sentence, no preamble or quotes.\n\nTitle: ${title}\n\nArticle:\n${body.slice(0, 4000)}`;
  for (let i = 0; i < 4; i++) {
    const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${MKEY}` },
      body: JSON.stringify({
        model: GEN_MODEL,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 90,
        temperature: 0.6,
      }),
    });
    if (res.status === 429 || res.status >= 500) { await sleep(2500 * (i + 1)); continue; }
    if (!res.ok) return null;
    const j = await res.json();
    return j.choices?.[0]?.message?.content?.trim() || null;
  }
  return null;
}

// ---- main ----
const limitArg = process.argv.indexOf('--limit');
const limit = limitArg !== -1 ? parseInt(process.argv[limitArg + 1], 10) : Infinity;

let files = ROOTS.flatMap((r) => walk(join(repoRoot, r))).sort();
if (Number.isFinite(limit)) files = files.slice(0, limit);
console.log(`Ingesting ${files.length} file(s)…\n`);

let cards = 0, embeds = 0, skipped = 0;
for (const abs of files) {
  const rel = relative(repoRoot, abs);
  const slug = rel.replace(/[\\/]/g, '/').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const cat = categorize(rel);
  const { title, body } = parseDoc(readFileSync(abs, 'utf8'));

  const { data: existing } = await admin
    .from('content_cards').select('id,body,why_it_matters').eq('slug', slug).maybeSingle();

  if (existing && existing.body === body) {
    if (existing.why_it_matters) {
      console.log('· unchanged:', slug);
      skipped++; cards++;
      continue;
    }
    // Body unchanged, only the tie-in is missing -> backfill it (no re-embedding).
    const why = await whyItMatters(title, body);
    await sleep(400);
    if (why) {
      await admin.from('content_cards').update({ why_it_matters: why }).eq('id', existing.id);
      console.log('+ why backfilled:', slug);
    } else {
      console.log('· still no why:', slug);
    }
    cards++;
    continue;
  }

  const why = await whyItMatters(title, body);
  await sleep(600);

  const up = await admin.from('content_cards').upsert({
    slug, title, body, why_it_matters: why,
    tags: cat.tags, age_min: cat.age[0], age_max: cat.age[1],
    source: 'curated', published: true,
  }, { onConflict: 'slug' }).select('id').single();
  if (up.error) throw new Error(`card upsert ${slug}: ${up.error.message}`);
  const cardId = up.data.id;

  await admin.from('content_embeddings').delete().eq('card_id', cardId);
  const chunks = chunk(body);
  for (const ch of chunks) {
    const v = await embed(ch);
    await sleep(250);
    const ins = await admin.from('content_embeddings').insert({ card_id: cardId, chunk: ch, embedding: vecLiteral(v) });
    if (ins.error) throw new Error(`embed insert ${slug}: ${ins.error.message}`);
    embeds++;
  }
  console.log(`✓ ${slug}  (${chunks.length} chunks)${why ? '' : '  [no why_it_matters]'}`);
  cards++;
}

console.log(`\nDone. cards: ${cards} (skipped unchanged: ${skipped}), embeddings written: ${embeds}`);
