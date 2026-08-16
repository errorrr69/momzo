// Momzo daily-read cards — seeds the purpose-written card library (00_CARD_SPEC.md).
//
// These replace the scraped article corpus. They are original text written to a
// fixed five-part structure, and they feed BOTH surfaces: the daily read card and
// the AI expert's RAG corpus. After this runs, the AI cites Momzo's own material.
//
// Idempotent by slug. A re-run compares every stored field against the JSON and
// writes nothing when they match — so "did this already run?" is answered by
// running it again, not by remembering.
//
// Validation is a GATE, not a filter: all 90 cards are checked before the first
// write, and any problem aborts the whole run. A seeder that skips the two bad
// rows and reports success is how a library quietly ends up with 88 cards.
//
// Run:  cd supabase/seed && node build_daily_cards.mjs [--dry-run] [--limit N]
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const CARDS_JSON = join(repoRoot, 'momzo_daily_cards_5_6.json');

const EMBED_MODEL = 'gemini-embedding-001'; // 768d — must match content_embeddings

// ---- the controlled vocabularies (00_CARD_SPEC.md §3 and §4) ----
//
// These are duplicated here on purpose. The spec is prose and cannot fail a build;
// this list can. If the two ever disagree, this file is what the database enforces
// and the mismatch shows up as a failed seed rather than as targeting that quietly
// matches nothing.
const CATEGORIES = new Set([
  'big-feelings', 'focus-attention', 'confidence-independence', 'connection-bonding',
  'learning-curiosity', 'getting-along', 'everyday-routines',
]);

const TAG_VOCAB = new Set([
  'big-feelings', 'meltdowns', 'frustration', 'worries', 'anger',
  'focus', 'listening', 'transitions', 'high-energy',
  'confidence', 'independence', 'self-belief',
  'connection', 'bonding', 'rituals',
  'learning', 'curiosity', 'reading', 'numbers',
  'sharing', 'friendships', 'siblings', 'kindness', 'shy-warm-up',
  'sleep', 'mornings', 'mealtimes', 'screens', 'tidying',
]);

const REQUIRED = [
  'slug', 'title', 'summary', 'why_it_matters', 'main_read',
  'activity', 'category', 'subtopic', 'age_min', 'age_max', 'tags', 'concept_basis',
];

// ---- config ----
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
const GKEY = process.env.GOOGLE_API_KEY || env.GOOGLE_API_KEY;
if (!SUPABASE_URL || !SERVICE || !GKEY) {
  throw new Error('Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / GOOGLE_API_KEY.');
}

const admin = createClient(SUPABASE_URL, SERVICE, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const DRY = process.argv.includes('--dry-run');
const limitArg = process.argv.indexOf('--limit');
const LIMIT = limitArg !== -1 ? parseInt(process.argv[limitArg + 1], 10) : Infinity;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const vecLiteral = (v) => '[' + v.join(',') + ']';
const words = (s) => String(s).trim().split(/\s+/).filter(Boolean).length;

// ---- 1. validate everything, then decide whether to write anything ----
const cards = JSON.parse(readFileSync(CARDS_JSON, 'utf8'));
if (!Array.isArray(cards)) throw new Error('Card file must be a JSON array.');

const errors = [];
const warnings = [];
const seenSlugs = new Map();

cards.forEach((c, i) => {
  const at = `card[${i}] ${c?.slug ?? '(no slug)'}`;

  for (const f of REQUIRED) {
    const v = c?.[f];
    const empty = v === undefined || v === null || v === ''
      || (Array.isArray(v) && v.length === 0);
    if (empty) errors.push(`${at}: missing required field "${f}"`);
  }
  if (!c?.slug) return; // everything below reads fields that may not exist

  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(c.slug)) errors.push(`${at}: slug is not kebab-case`);
  if (seenSlugs.has(c.slug)) errors.push(`${at}: duplicate slug (also card[${seenSlugs.get(c.slug)}])`);
  seenSlugs.set(c.slug, i);

  // Age targeting is the whole point of this band — a card outside 5/6 would be
  // served to the wrong child or to nobody.
  if (c.age_min !== 5 || c.age_max !== 6) {
    errors.push(`${at}: age_min/age_max must be 5/6, got ${c.age_min}/${c.age_max}`);
  }

  if (!CATEGORIES.has(c.category)) errors.push(`${at}: category "${c.category}" is not one of the seven (§3)`);

  if (!Array.isArray(c.tags)) {
    errors.push(`${at}: tags must be an array`);
  } else {
    for (const t of c.tags) {
      // §4 is explicit that drift here makes targeting fail silently, so it fails loudly here instead.
      if (!TAG_VOCAB.has(t)) errors.push(`${at}: tag "${t}" is not in the controlled vocabulary (§4)`);
    }
  }

  // Word caps are what keep a card under two minutes (§2). Off-spec length is a
  // content note, not a data fault — it warns so it is visible, and seeds anyway.
  const mr = words(c.main_read);
  if (mr < 120 || mr > 180) warnings.push(`${at}: main_read is ${mr} words (§2 says 120-180)`);
  if (words(c.title) > 8) warnings.push(`${at}: title is ${words(c.title)} words (§2 says <= 8)`);
});

if (warnings.length) {
  console.log(`${warnings.length} content warning(s):`);
  warnings.forEach((w) => console.log('  ! ' + w));
  console.log();
}

if (errors.length) {
  console.error(`✗ VALIDATION FAILED — ${errors.length} problem(s). Nothing was written.\n`);
  errors.forEach((e) => console.error('  - ' + e));
  process.exit(1);
}
console.log(`✓ validated ${cards.length} cards — schema, ages, categories and tag vocabulary all clean.\n`);

// ---- 2. embedding ----
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

// One chunk per card, deliberately.
//
// The article seeder splits at ~280 words because an article argues one point
// across several pages. These cards are ~250-280 words TOTAL and teach exactly
// one idea (§5 rule 3), so the card IS the retrieval unit — splitting it would
// hand the AI half an idea and let the other half lose the similarity race.
//
// concept_basis is excluded: it is internal QA vocabulary ("affect labelling"),
// not something a parent would ever ask in those words, and embedding it would
// pull cards toward jargon that never appears in a real question.
function retrievalText(c) {
  return [
    c.title,
    c.summary,
    c.why_it_matters,
    c.main_read,
    `Try this tonight: ${c.activity}`,
  ].join('\n\n');
}

// ---- 3. upsert ----
const sameTags = (a, b) =>
  Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((t, i) => t === b[i]);

const toSeed = Number.isFinite(LIMIT) ? cards.slice(0, LIMIT) : cards;
console.log(`Seeding ${toSeed.length} card(s)${DRY ? ' [dry run]' : ''}…\n`);

let created = 0, updated = 0, unchanged = 0, embedded = 0;

for (const c of toSeed) {
  const { data: existing } = await admin
    .from('content_cards')
    .select('id, title, summary, why_it_matters, main_read, activity, category, subtopic, age_min, age_max, tags, concept_basis, published, reference_only, source')
    .eq('slug', c.slug)
    .maybeSingle();

  let embCount = 0;
  if (existing) {
    const { count } = await admin
      .from('content_embeddings')
      .select('id', { count: 'exact', head: true })
      .eq('card_id', existing.id);
    embCount = count ?? 0;
  }

  const identical = existing
    && existing.title === c.title
    && existing.summary === c.summary
    && existing.why_it_matters === c.why_it_matters
    && existing.main_read === c.main_read
    && existing.activity === c.activity
    && existing.category === c.category
    && existing.subtopic === c.subtopic
    && existing.age_min === c.age_min
    && existing.age_max === c.age_max
    && existing.concept_basis === c.concept_basis
    && existing.published === true
    && existing.reference_only === false
    && existing.source === 'Momzo'
    && sameTags(existing.tags, c.tags);

  // Embeddings are part of "seeded". A card whose text matches but whose vectors
  // are missing (a run that died mid-embed) is not done, and saying "unchanged"
  // would strand it out of the RAG corpus forever.
  if (identical && embCount > 0) {
    unchanged++;
    continue;
  }

  if (DRY) {
    console.log(`${existing ? '~' : '+'} ${c.slug}${identical ? '  [text ok, embeddings missing]' : ''}`);
    existing ? updated++ : created++;
    continue;
  }

  const up = await admin.from('content_cards').upsert({
    slug: c.slug,
    title: c.title,
    summary: c.summary,
    why_it_matters: c.why_it_matters,
    main_read: c.main_read,
    activity: c.activity,
    category: c.category,
    subtopic: c.subtopic,
    age_min: c.age_min,
    age_max: c.age_max,
    tags: c.tags,
    concept_basis: c.concept_basis,
    source: 'Momzo',
    reference_only: false,
    published: true,
  }, { onConflict: 'slug' }).select('id').single();
  if (up.error) throw new Error(`card upsert ${c.slug}: ${up.error.message}`);
  const cardId = up.data.id;

  // Replace rather than append, so a re-embed can't leave stale vectors behind
  // pointing at text that no longer exists.
  await admin.from('content_embeddings').delete().eq('card_id', cardId);
  const v = await embed(retrievalText(c));
  const ins = await admin.from('content_embeddings').insert({
    card_id: cardId, chunk: retrievalText(c), embedding: vecLiteral(v),
  });
  if (ins.error) throw new Error(`embed insert ${c.slug}: ${ins.error.message}`);
  embedded++;
  await sleep(900); // stay inside the Gemini embedding per-minute limit

  console.log(`${existing ? '~' : '✓'} ${c.slug}`);
  existing ? updated++ : created++;
}

console.log(
  `\nDone. created: ${created}, updated: ${updated}, unchanged: ${unchanged}, embeddings written: ${embedded}`,
);
if (unchanged === toSeed.length) console.log('Nothing changed — the library is already seeded.');
