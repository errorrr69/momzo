// The Circle — seeds forum categories (Expansion Plan §2.1).
//
// Idempotent by slug, like every other seeder here: a re-run updates the title or
// blurb and writes nothing when they match.
//
// Also grants moderator rights, because a forum with no moderator is a forum with
// no report queue and §2.4 makes moderation non-negotiable. Pass the account's
// email; the script refuses rather than guessing.
//
// Run:  cd supabase/seed && node build_forum.mjs [--dry-run]
//       cd supabase/seed && node build_forum.mjs --moderator you@example.com
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));

// §2.1's suggested list. Florie confirms or edits these at the Phase-A checkpoint
// (open decision 4); changing one is an edit here and a re-run, not a migration.
const CATEGORIES = [
  {
    slug: 'ask-the-circle', title: 'Ask the Circle', sort: 1,
    blurb: 'A question for the mothers who have been there',
  },
  {
    slug: 'wins', title: 'Wins', sort: 2,
    blurb: 'Small things that went right — they count',
  },
  {
    slug: 'big-feelings', title: 'Big feelings', sort: 3,
    blurb: 'Meltdowns, worries, and the hard end of the day',
  },
  {
    slug: 'school-and-learning', title: 'School & learning', sort: 4,
    blurb: 'Reading, numbers, homework, teachers',
  },
  {
    slug: 'just-chatting', title: 'Just chatting', sort: 5,
    blurb: 'Not everything has to be a problem',
  },
];

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
const modArg = process.argv.indexOf('--moderator');
const MODERATOR_EMAIL = modArg !== -1 ? process.argv[modArg + 1] : null;

// ---- categories ----
let inserted = 0;
let updated = 0;
let unchanged = 0;

for (const c of CATEGORIES) {
  const { data: existing, error } = await admin
    .from('forum_categories')
    .select('id, title, blurb, sort, active')
    .eq('slug', c.slug)
    .maybeSingle();
  if (error) throw new Error(`reading ${c.slug}: ${error.message}`);

  const row = { slug: c.slug, title: c.title, blurb: c.blurb, sort: c.sort, active: true };

  if (!existing) {
    if (!DRY) {
      const { error: e } = await admin.from('forum_categories').insert(row);
      if (e) throw new Error(`inserting ${c.slug}: ${e.message}`);
    }
    inserted++;
    console.log(`  + ${c.slug}`);
    continue;
  }

  const drifted = ['title', 'blurb', 'sort', 'active']
    .filter((f) => JSON.stringify(existing[f]) !== JSON.stringify(row[f]));
  if (drifted.length === 0) { unchanged++; continue; }
  if (!DRY) {
    const { error: e } = await admin.from('forum_categories').update(row).eq('slug', c.slug);
    if (e) throw new Error(`updating ${c.slug}: ${e.message}`);
  }
  updated++;
  console.log(`  ~ ${c.slug} (${drifted.join(', ')})`);
}

console.log(
  `\n${DRY ? '--dry-run: would be ' : ''}${inserted} inserted, ${updated} updated, ${unchanged} unchanged.`,
);

// ---- moderator ----
if (MODERATOR_EMAIL) {
  const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (error) throw new Error(`listUsers: ${error.message}`);
  const user = data.users.find((u) => u.email?.toLowerCase() === MODERATOR_EMAIL.toLowerCase());
  if (!user) {
    console.error(`\n✗ no account found for ${MODERATOR_EMAIL} — nobody was made a moderator.`);
    process.exit(1);
  }
  if (!DRY) {
    const { error: e } = await admin
      .from('moderators').upsert({ user_id: user.id }, { onConflict: 'user_id' });
    if (e) throw new Error(`granting moderator: ${e.message}`);
  }
  console.log(`\n✓ ${MODERATOR_EMAIL} is a moderator.`);
} else {
  const { count } = await admin
    .from('moderators').select('*', { count: 'exact', head: true });
  if (!count) {
    // Loud on purpose. Auto-hide still works without a moderator, but nothing
    // ever gets reviewed, so hidden content would stay hidden forever.
    console.warn(
      '\n! No moderators exist. Reports will queue and auto-hide will fire, but\n' +
      '  nobody can review or restore anything. Grant one with:\n' +
      '      node build_forum.mjs --moderator you@example.com',
    );
  }
}
