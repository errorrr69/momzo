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
import { join, relative, extname, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');

// All source content lives under knowledge base/ (sub-folders walked automatically;
// activities/ and questions/ are skipped — they have their own seeders).
const ROOTS = ['knowledge base'];

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
  // knowledge base/ (2026-06-24 additions)
  'behaviour': { tags: ['behavior', 'self-control'], age: [3, 10] },
  'child development': { tags: ['development', 'milestones'], age: [3, 10] },
  'discipling children': { tags: ['discipline', 'behavior'], age: [3, 10] },
  'emotional development (1)': { tags: ['emotional', 'feelings', 'temperament'], age: [4, 10] },
  'reading': { tags: ['reading', 'literacy'], age: [3, 8] },
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

// Folders that are NOT knowledge cards (seeded by their own pipelines).
const SKIP_DIRS = new Set(['activities', 'questions']);

function walk(dir) {
  const out = [];
  let entries;
  try { entries = readdirSync(dir); } catch { return out; }
  for (const name of entries) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) {
      if (SKIP_DIRS.has(name.toLowerCase())) continue;
      out.push(...walk(p));
    } else if (['.md', '.txt'].includes(extname(p).toLowerCase())) {
      out.push(p);
    }
  }
  return out;
}

function categorize(relPath) {
  for (const seg of relPath.split(/[\\/]/)) {
    if (CATEGORY[seg]) return CATEGORY[seg];
  }
  return DEFAULT_CAT;
}

function humanize(file) {
  return file.replace(/\.(md|txt)$/i, '').replace(/[-_]+/g, ' ').replace(/\s+/g, ' ').trim()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function parseDoc(text, file) {
  const lines = text.split(/\r?\n/);
  let first = '';
  for (const l of lines) {
    const t = l.trim();
    if (t) { first = t.replace(/^#+\s*/, '').trim(); break; }
  }
  // If the first "line" is actually a whole paragraph (single-block .txt), it's a
  // bad title — fall back to the (descriptive) filename.
  const title = (!first || first.length > 110 || first.split(/\s+/).length > 16)
    ? humanize(file)
    : first;
  return { title: title || humanize(file), body: text.trim() };
}

// Split into embed-sized chunks. Paragraphs first; any paragraph with no blank
// lines (single-block docs) is further split by sentence so no chunk is so large
// the embedding API silently truncates it.
function chunk(body) {
  const paras = body.split(/\n\s*\n/).map((s) => s.trim()).filter(Boolean);
  const units = [];
  for (const p of paras) {
    if (p.length <= 1200) { units.push(p); continue; }
    let cur = '';
    for (const s of p.split(/(?<=[.!?])\s+/)) {
      // A "sentence" with no internal breaks can still be huge (text with no
      // sentence-ending punctuation) — hard-split it by words so no unit blows
      // past the embedding token limit.
      if (s.length > 1500) {
        if (cur) { units.push(cur.trim()); cur = ''; }
        const words = s.split(/\s+/);
        for (let i = 0; i < words.length; i += 200) units.push(words.slice(i, i + 200).join(' '));
        continue;
      }
      if ((cur + ' ' + s).length > 1000 && cur) { units.push(cur.trim()); cur = ''; }
      cur += (cur ? ' ' : '') + s;
    }
    if (cur.trim()) units.push(cur.trim());
  }
  const chunks = [];
  let cur = '';
  let words = 0;
  for (const u of units) {
    const w = u.split(/\s+/).length;
    if (words + w > 280 && cur) { chunks.push(cur.trim()); cur = ''; words = 0; }
    cur += (cur ? '\n\n' : '') + u;
    words += w;
  }
  if (cur.trim()) chunks.push(cur.trim());
  return chunks.length ? chunks : [body.slice(0, 4000)];
}

async function gFetch(url, body, tries = 7) {
  for (let i = 0; i < tries; i++) {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (res.status === 429 || res.status >= 500) { await sleep(5000 * (i + 1)); continue; }
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

// Self-heal index: body -> card. A moved file computes a new slug; rather than
// inserting a duplicate, we re-key the existing card (same body) to the new slug.
// Keyed on body in memory (PostgREST can't filter on very large bodies).
const { data: allCards } = await admin.from('content_cards').select('id,slug,body');
const cardByBody = new Map((allCards || []).map((c) => [c.body, c]));

// Guard against duplicate source files (byte-identical content under two names):
// process each unique body once so we never create or flip-flop a duplicate card.
const seenBodies = new Set();

let cards = 0, embeds = 0, skipped = 0, rekeyed = 0, dupes = 0;
for (const abs of files) {
  const rel = relative(repoRoot, abs);
  const slug = rel.replace(/[\\/]/g, '/').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const cat = categorize(rel);
  // Files under knowledge base/books/ are original notes distilled from reference
  // books: they ground the AI (RAG) but are reference_only — never daily cards, so
  // they skip the "why it matters at home" tie-in.
  const isRef = /(^|[\\/])books[\\/]/i.test(rel);
  const { title, body } = parseDoc(readFileSync(abs, 'utf8'), basename(abs));

  if (seenBodies.has(body)) { console.log('· duplicate content (skipped):', slug); dupes++; continue; }
  seenBodies.add(body);

  let { data: existing } = await admin
    .from('content_cards').select('id,title,body,why_it_matters').eq('slug', slug).maybeSingle();

  // Self-heal: no card at this slug, but a card with identical content exists (a
  // moved file). Re-key it to the new slug — UUID + embeddings untouched, so
  // daily_assignments / cited_card_ids stay valid — instead of inserting a dupe.
  if (!existing) {
    const moved = cardByBody.get(body);
    if (moved) {
      await admin.from('content_cards').update({ slug }).eq('id', moved.id);
      const { data: re } = await admin.from('content_cards')
        .select('id,title,body,why_it_matters').eq('id', moved.id).single();
      existing = re;
      rekeyed++;
      console.log('~ re-keyed:', slug);
    }
  }

  // How many embeddings already exist? (A prior run may have died mid-embed.)
  let embCount = 0;
  if (existing) {
    const { count } = await admin.from('content_embeddings')
      .select('id', { count: 'exact', head: true }).eq('card_id', existing.id);
    embCount = count ?? 0;
  }
  const bodySame = existing && existing.body === body;
  const titleSame = existing && existing.title === title;

  // Truly unchanged: body + title same, tie-in present (reference notes need none),
  // embeddings intact.
  if (bodySame && titleSame && (isRef || existing.why_it_matters) && embCount > 0) {
    console.log('· unchanged:', slug);
    skipped++; cards++;
    continue;
  }

  // Body + title + embeddings intact, only the tie-in missing -> backfill (no re-embed).
  if (!isRef && bodySame && titleSame && embCount > 0 && !existing.why_it_matters) {
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

  // New, changed body, or MISSING embeddings -> full (re)build. Reuse the tie-in
  // if we already have one (don't burn a generation call on a re-embed).
  const why = isRef ? null : (existing?.why_it_matters || await whyItMatters(title, body));
  await sleep(isRef ? 0 : 500);

  const up = await admin.from('content_cards').upsert({
    slug, title, body, why_it_matters: why,
    tags: cat.tags, age_min: cat.age[0], age_max: cat.age[1],
    source: isRef ? 'Momzo expert notes' : 'curated',
    reference_only: isRef, published: true,
  }, { onConflict: 'slug' }).select('id').single();
  if (up.error) throw new Error(`card upsert ${slug}: ${up.error.message}`);
  const cardId = up.data.id;

  await admin.from('content_embeddings').delete().eq('card_id', cardId);
  const chunks = chunk(body);
  for (const ch of chunks) {
    const v = await embed(ch);
    await sleep(900); // stay under the Gemini embedding per-minute limit
    const ins = await admin.from('content_embeddings').insert({ card_id: cardId, chunk: ch, embedding: vecLiteral(v) });
    if (ins.error) throw new Error(`embed insert ${slug}: ${ins.error.message}`);
    embeds++;
  }
  console.log(`✓ ${slug}  (${chunks.length} chunks)${why ? '' : '  [no why_it_matters]'}`);
  cards++;
}

console.log(`\nDone. cards: ${cards} (skipped unchanged: ${skipped}, re-keyed: ${rekeyed}, duplicate files: ${dupes}), embeddings written: ${embeds}`);
