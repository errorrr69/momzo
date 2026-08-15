// Seed the Momzo Learning Games registry (Expansion Plan §3.5).
//
// The catalog only — the games themselves are a bundled web app. A row here says
// "this game exists, it belongs on this shelf, it suits these ages, and it lives
// at this path". Nothing here calls an LLM.
//
// Slugs ARE the games app's GameId. Keep them identical: `entry_path` is built
// from the slug, and the WebView loads exactly that route.
//
// DISPLAY CATEGORY IS DATA, NOT CODE. The games repo has three categories
// (maths | reading | feelings); Momzo shelves four. The split lives here so a
// game can be re-shelved with a re-run rather than a release (§A2.5).
//
// Idempotent: upserts on slug, like every other seeder here.
//
// Run:  cd supabase/seed && node build_learning_games.mjs
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'node:fs';

function env() {
  const out = {};
  for (const line of readFileSync(new URL('../.env', import.meta.url), 'utf8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i > 0) out[t.slice(0, i).trim()] = t.slice(i + 1).trim();
  }
  return out;
}

const e = env();
const admin = createClient(
  process.env.SUPABASE_URL || e.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY || e.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

// Every game ships 5–6 today. Adding a band later is an edit here, not a migration.
const AGE_MIN = 5;
const AGE_MAX = 6;

// Ordered as they should appear on each shelf.
//   ladder_key/ladder_step encode Florie's own progressions, so "recommended next"
//   can follow her teaching order rather than guessing.
const GAMES = [
  // ── Maths — the number ladder ───────────────────────────────────────────────
  ['flash-hide',         'Flash & Hide',             'maths',    'See a number without counting it',
    ['subitising', 'working-memory'],                 'number', 1],
  ['ten-frame',          'Ten-Frame Builder',        'maths',    'Build a clear picture of five and ten',
    ['ten-frame', 'number-sense'],                    'number', 2],
  ['bond-garden',        'Number Bond Garden',       'maths',    'Split a number in lots of ways',
    ['number-bonds', 'part-whole'],                   'number', 3],
  ['feed-monster',       'Feed the Monster',         'maths',    'Find the missing part of a whole',
    ['number-bonds', 'missing-part'],                 'number', 4],
  ['number-line',        'Number-Line Adventure',    'maths',    'Make adding and taking away move',
    ['addition', 'subtraction', 'number-line'],       'number', 5],

  // ── Reading — phonemic awareness → decoding ────────────────────────────────
  ['sound-safari',       'Sound Safari',             'reading',  'Hunt for things that start with a sound',
    ['phonemic-awareness', 'initial-sounds'],         'reading', 1],
  ['skywriter',          'Skywriter Studio',         'reading',  'Draw a letter and say its sound',
    ['letter-formation', 'grapheme-phoneme'],         'reading', 2],
  ['robot-translator',   'Robot Translator',         'reading',  'Hear the sounds, say the word',
    ['blending', 'oral-blending'],                    'reading', 3],
  ['sound-box-factory',  'Sound Box Factory',        'reading',  'One box for every sound in a word',
    ['segmenting', 'phoneme-count'],                  'reading', 4],
  ['blend-train',        'Blend Train',              'reading',  'One carriage for every sound',
    ['blending', 'segmenting'],                       'reading', 5],
  ['monster-lab',        'Monster Name Lab',         'reading',  'Sound out a name nobody has read before',
    ['decoding', 'nonsense-words'],                   'reading', 6],
  ['digraph-detectives', 'Digraph Detectives',       'reading',  'Find the letters working as a team',
    ['digraphs', 'decoding'],                         'reading', 7],
  ['magic-e-wizard',     'Magic-e Wizard',           'reading',  'Add an e and change the word',
    ['split-digraph', 'long-vowels'],                 'reading', 8],
  ['word-ladder',        'Word Ladder Workshop',     'reading',  'Change one sound and climb a rung',
    ['phoneme-manipulation', 'decoding'],             'reading', 9],
  ['tricky-treasure',    'Tricky Word Treasure',     'reading',  'Words we know by sight, not by sounding out',
    ['sight-words', 'tricky-words'],                  'reading', 10],
  ['story-quest',        'Story Quest',              'reading',  'Read a whole little story',
    ['fluency', 'comprehension'],                     'reading', 11],

  // ── Feelings — naming and reading emotion ─────────────────────────────────
  ['feeling-thermometer', 'Feeling Thermometer',     'feelings', 'How big is the feeling right now?',
    ['emotion-vocabulary', 'intensity', 'self-awareness'], null, null],
  ['mirror-faces',        'Mirror Face Charades',    'feelings', 'What might this face be telling us?',
    ['emotion-recognition', 'perspective-taking'],    null, null],
  ['scavenger-hunt',      'Character Scavenger Hunt','feelings', 'Find the feelings hiding in a scene',
    ['emotion-recognition', 'context-clues'],         null, null],

  // ── Focus & mind — attention, regulation, impulse control ─────────────────
  // Split out of the repo's "feelings" per §A2.5: these are body-and-brain games
  // rather than emotion-naming ones, and a mother looking for "help him settle"
  // should not have to read past three feelings games to find them.
  ['rock-buddy',          'Rock the Buddy',          'focus',    'Rock a buddy to sleep with slow breaths',
    ['self-regulation', 'breathing', 'calming'],      null, null],
  ['opposite-game',       'The Opposite Game',       'focus',    'Do the opposite — practise brain brakes',
    ['inhibitory-control', 'executive-function'],     null, null],
  ['freeze-dance',        'Freeze Dance',            'focus',    'Dance, then stop your whole body',
    ['inhibitory-control', 'gross-motor', 'listening'], null, null],
];

const rows = GAMES.map(([slug, title, category, blurb, skills, ladderKey, ladderStep], i) => ({
  slug,
  title,
  category,
  age_min: AGE_MIN,
  age_max: AGE_MAX,
  skill_tags: skills,
  ladder_key: ladderKey,
  ladder_step: ladderStep,
  entry_path: `/play/${slug}`,
  thumbnail: null,
  active: true,
  // Keep the authored order; the shelf sorts by (category, sort).
  sort: i + 1,
}));

// Blurbs live in the games repo's GAME_BLURBS and are shown by the games app
// itself, so they are deliberately NOT duplicated into a column here — one place
// to change a game's description. Kept above only as a reading aid.

const { error } = await admin.from('learning_games').upsert(rows, { onConflict: 'slug' });
if (error) {
  console.error('seed failed:', error.message);
  process.exit(1);
}

const { data, error: readErr } = await admin
  .from('learning_games')
  .select('category, slug')
  .eq('active', true);
if (readErr) {
  console.error('verify failed:', readErr.message);
  process.exit(1);
}

const byCat = {};
for (const r of data) (byCat[r.category] ??= []).push(r.slug);
console.log(`seeded ${rows.length} learning games:`);
for (const c of ['maths', 'reading', 'feelings', 'focus']) {
  console.log(`  ${c.padEnd(9)} ${(byCat[c] || []).length}`);
}
const total = Object.values(byCat).reduce((n, a) => n + a.length, 0);
console.log(`  ${'total'.padEnd(9)} ${total}`);
