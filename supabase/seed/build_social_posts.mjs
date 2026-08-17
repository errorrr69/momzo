// Momzo Content Hub — seeds Florie's posts into `social_posts` (Expansion Plan §1).
//
// The same content she publishes on Instagram/Facebook, mirrored in-app so the app
// is the calm home of everything rather than only the daily card.
//
// Idempotent by slug, exactly like build_daily_cards.mjs: a re-run compares every
// stored field and writes nothing when they match, so "did this already run?" is
// answered by running it again.
//
// Validation is a GATE, not a filter. Every post is checked before the first write
// and any problem aborts the run — a seeder that skips two bad rows and reports
// success is how a feed quietly ends up missing posts nobody notices are gone.
//
// Body format: markdown. For a `carousel`, slides are separated by a line
// containing only `---`, and *asterisks* mark the one emphasised word per line
// (Florie's typographic post guide §3). That convention is why there is no
// separate slides column: the words have one home.
//
// Run:  cd supabase/seed && node build_social_posts.mjs [--dry-run]
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const POSTS_JSON = join(here, 'momzo_social_posts.json');

// Same controlled vocabulary as the cards (00_CARD_SPEC §4), duplicated here on
// purpose: the spec is prose and cannot fail a build, this list can. A tag chip in
// the hub must mean what the same chip means in the library.
const TAG_VOCAB = new Set([
  'big-feelings', 'meltdowns', 'frustration', 'worries', 'anger',
  'focus', 'listening', 'transitions', 'high-energy',
  'confidence', 'independence', 'self-belief',
  'connection', 'bonding', 'rituals',
  'learning', 'curiosity', 'reading', 'numbers',
  'sharing', 'friendships', 'siblings', 'kindness', 'shy-warm-up',
  'sleep', 'mornings', 'mealtimes', 'screens', 'tidying',
]);

const POST_TYPES = new Set(['carousel', 'tip', 'reel', 'article']);
const REQUIRED = ['slug', 'title', 'body', 'post_type', 'tags'];

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
if (!SUPABASE_URL || !SERVICE) {
  throw new Error('Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY.');
}

const admin = createClient(SUPABASE_URL, SERVICE, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const DRY = process.argv.includes('--dry-run');
const slides = (body) => body.split(/^---$/m).map((s) => s.trim()).filter(Boolean);
const words = (s) => String(s).trim().split(/\s+/).filter(Boolean).length;

// ---- 1. validate everything, then decide whether to write anything ----
const posts = JSON.parse(readFileSync(POSTS_JSON, 'utf8'));
if (!Array.isArray(posts)) throw new Error('Post file must be a JSON array.');

const errors = [];
const warnings = [];
const seen = new Map();

posts.forEach((p, i) => {
  const at = `post[${i}] ${p?.slug ?? '(no slug)'}`;

  for (const f of REQUIRED) {
    const v = p?.[f];
    const empty = v === undefined || v === null || v === ''
      || (Array.isArray(v) && v.length === 0);
    if (empty) errors.push(`${at}: missing required field "${f}"`);
  }
  if (!p?.slug) return;

  if (seen.has(p.slug)) errors.push(`${at}: duplicate slug (also post[${seen.get(p.slug)}])`);
  seen.set(p.slug, i);

  if (!/^[a-z0-9-]+$/.test(p.slug)) errors.push(`${at}: slug must be kebab-case`);
  if (p.post_type && !POST_TYPES.has(p.post_type)) {
    errors.push(`${at}: post_type "${p.post_type}" is not one of ${[...POST_TYPES].join(', ')}`);
  }
  for (const t of p.tags ?? []) {
    if (!TAG_VOCAB.has(t)) {
      errors.push(`${at}: tag "${t}" is outside the controlled vocabulary (00_CARD_SPEC §4)`);
    }
  }
  if (p.media !== undefined && !Array.isArray(p.media)) {
    errors.push(`${at}: media must be an array of {type,url,alt}`);
  }
  for (const m of p.media ?? []) {
    if (!m?.type || !m?.url) errors.push(`${at}: every media item needs type and url`);
    if (m?.type === 'image' && !m?.alt) warnings.push(`${at}: image with no alt text`);
  }

  // Carousel shape, per the post guide: one beat per slide, ~12–35 words.
  // A warning, not an error — length is an editorial note, not a data fault.
  if (p.post_type === 'carousel') {
    const parts = slides(p.body ?? '');
    if (parts.length < 2) {
      errors.push(`${at}: a carousel needs at least two slides separated by "---"`);
    }
    parts.forEach((s, n) => {
      const w = words(s);
      if (w > 45) warnings.push(`${at}: slide ${n + 1} runs ${w} words (guide says ~12–35)`);
    });
  }
});

if (errors.length) {
  console.error(`\n✗ ${errors.length} problem(s) — nothing was written:\n`);
  for (const e of errors) console.error('  ' + e);
  process.exit(1);
}
for (const w of warnings) console.warn('  ! ' + w);
console.log(`✓ ${posts.length} posts validated${warnings.length ? ` (${warnings.length} warning(s))` : ''}`);

// ---- 2. upsert by slug, writing only what actually differs ----
const FIELDS = ['title', 'body', 'post_type', 'tags', 'source_url', 'media', 'published'];

const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

let inserted = 0;
let updated = 0;
let unchanged = 0;

for (const p of posts) {
  const row = {
    slug: p.slug,
    title: p.title,
    body: p.body,
    post_type: p.post_type ?? 'tip',
    tags: p.tags ?? [],
    source_url: p.source_url ?? null,
    media: p.media ?? [],
    published: p.published ?? true,
  };

  const { data: existing, error: readErr } = await admin
    .from('social_posts')
    .select('id, ' + FIELDS.join(', '))
    .eq('slug', p.slug)
    .maybeSingle();
  if (readErr) throw new Error(`reading ${p.slug}: ${readErr.message}`);

  if (!existing) {
    if (!DRY) {
      const { error } = await admin.from('social_posts').insert(row);
      if (error) throw new Error(`inserting ${p.slug}: ${error.message}`);
    }
    inserted++;
    console.log(`  + ${p.slug}`);
    continue;
  }

  const drifted = FIELDS.filter((f) => !same(existing[f], row[f]));
  if (drifted.length === 0) {
    unchanged++;
    continue;
  }
  if (!DRY) {
    const { error } = await admin.from('social_posts').update(row).eq('slug', p.slug);
    if (error) throw new Error(`updating ${p.slug}: ${error.message}`);
  }
  updated++;
  console.log(`  ~ ${p.slug} (${drifted.join(', ')})`);
}

console.log(
  `\n${DRY ? '--dry-run: would be ' : ''}${inserted} inserted, ${updated} updated, ${unchanged} unchanged.`,
);
