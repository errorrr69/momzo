// Seed the mini-games catalog + starter content banks (Would You Rather,
// Get-to-Know-You). Idempotent: upserts games; replaces the seed items for these
// games. Run: node supabase/seed/build_games.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const env = (() => { const o = {}; for (const r of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) { const l = r.trim(); if (!l || l.startsWith('#')) continue; const e = l.indexOf('='); if (e < 0) continue; let v = l.slice(e + 1).trim(); v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim(); o[l.slice(0, e).trim()] = v; } return o; })();
const a = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const games = [
  { slug: 'would-you-rather', title: 'Would You Rather', emoji: '🤔', subtitle: 'silly choices', type: 'choose_one', min_band: 'A', accent: '#EC8366', rounds_a: 3, rounds_b: 5, rounds_c: 6, playable: true, sort: 1 },
  { slug: 'get-to-know-you', title: 'Get to Know Me', emoji: '💛', subtitle: 'favourites & more', type: 'question', min_band: 'A', accent: '#F2B441', rounds_a: 3, rounds_b: 5, rounds_c: 6, playable: true, sort: 2 },
  { slug: 'two-truths', title: 'Two Truths & a Lie', emoji: '🕵️', subtitle: 'spot the fib', type: 'choose_one', min_band: 'C', accent: '#A593D6', rounds_a: 4, rounds_b: 5, rounds_c: 6, playable: false, sort: 3 },
  { slug: 'finish-the-sentence', title: 'Finish the Sentence', emoji: '✏️', subtitle: 'fill it in together', type: 'prompt', min_band: 'A', accent: '#84B89A', rounds_a: 3, rounds_b: 5, rounds_c: 6, playable: false, sort: 4 },
  { slug: 'emoji-decode', title: 'Emoji Decode', emoji: '🎬', subtitle: 'guess it!', type: 'puzzle', min_band: 'B', accent: '#8FC7D6', rounds_a: 4, rounds_b: 5, rounds_c: 6, playable: false, sort: 5 },
  { slug: 'story-builder', title: 'Story Builder', emoji: '📖', subtitle: 'one line each', type: 'prompt', min_band: 'A', accent: '#E87DA6', rounds_a: 3, rounds_b: 5, rounds_c: 6, playable: false, sort: 6 },
];

// Would You Rather: payload { optionA, emojiA, optionB, emojiB, askWhy }
const wyr = {
  A: [
    ['be a puppy', '🐶', 'be a kitten', '🐱'], ['have ice cream', '🍦', 'have cake', '🍰'],
    ['be a fish', '🐠', 'be a bird', '🐦'], ['jump in leaves', '🍂', 'build a sandcastle', '🏖️'],
    ['be very tall', '🦒', 'be very tiny', '🐭'], ['have a balloon', '🎈', 'have a bubble', '🫧'],
    ['play in the sun', '☀️', 'play in the rain', '🌧️'], ['eat pizza', '🍕', 'eat pancakes', '🥞'],
    ['have a pet bunny', '🐰', 'have a pet fish', '🐟'], ['wear a cape', '🦸', 'wear a crown', '👑'],
    ['bounce on a trampoline', '🤸', 'swing on a swing', '🛝'], ['be a lion', '🦁', 'be a dolphin', '🐬'],
  ],
  B: [
    ['be able to fly', '🦅', 'be invisible', '👻'], ['talk to animals', '🐾', 'breathe underwater', '🐠'],
    ['have a pet dragon', '🐉', 'have a pet unicorn', '🦄'], ['always be warm', '🔥', 'always be cool', '❄️'],
    ['have a giant pizza', '🍕', 'have a giant cookie', '🍪'], ['live in a bouncy castle', '🏰', 'live in a treehouse', '🌳'],
    ['have wings', '🪽', 'have a magic carpet', '🧞'], ['glow in the dark', '✨', 'change any colour', '🌈'],
    ['have a robot friend', '🤖', 'have a talking pet', '🐕'], ['visit the moon', '🌙', 'visit under the sea', '🐙'],
  ],
  C: [
    ['stop time', '⏰', 'teleport anywhere', '🌀'], ['have a robot for homework', '🤖', 'have a robot for chores', '🧹'],
    ['be a famous inventor', '💡', 'be a famous explorer', '🧭'], ['have only summer', '☀️', 'have only winter', '⛄'],
    ['have super strength', '💪', 'have super speed', '⚡'], ['live in a treehouse', '🌳', 'live in a houseboat', '⛵'],
    ['read minds', '🧠', 'see the future', '🔮'], ['be a movie star', '🎬', 'be a sports star', '⚽'],
    ['explore space', '🚀', 'explore the ocean', '🌊'], ['have a library of any book', '📚', 'a kitchen of any food', '🍱'],
  ],
};

// Get-to-Know-You: payload { question, category }
const gtky = {
  A: [
    ['favourite', "What's your favourite colour?"], ['favourite', "What's your favourite animal?"],
    ['favourite', "What's your favourite food?"], ['favourite', "What's your favourite toy?"],
    ['favourite', "What's your favourite song?"], ['favourite', "What's your favourite game to play?"],
    ['favourite', 'Which fruit do you like best?'], ['us', "What's your favourite thing to do outside?"],
    ['feeling', 'What makes you giggle?'], ['favourite', "What's your favourite story?"],
  ],
  B: [
    ['feeling', 'What makes you laugh the most?'], ['feeling', 'What makes you feel cosy?'],
    ['us', "What's your favourite thing we do together?"], ['dream', 'What would you love to learn?'],
    ['feeling', "What's something you're really good at?"], ['us', 'A place that feels happy to you?'],
    ['feeling', 'What makes you feel brave?'], ['dream', 'If you had a superpower, what would it be?'],
    ['favourite', "What's the best part of your day usually?"], ['dream', 'What would your perfect playdate be?'],
  ],
  C: [
    ['feeling', 'What are you most proud of?'], ['us', 'What do you wish we did more together?'],
    ['us', "What's your happiest memory of us?"], ['feeling', 'What always cheers you up?'],
    ['dream', 'If you could plan our perfect day, what would we do?'], ['dream', "What's something you'd love to be one day?"],
    ['feeling', "What's a small thing that makes a day great?"], ['feeling', "What's something you've gotten better at lately?"],
    ['us', "What's something you'd love to try together?"], ['feeling', 'When do you feel most like yourself?'],
  ],
};

// --- upsert games ---
for (const g of games) {
  const { error } = await a.from('games').upsert(g, { onConflict: 'slug' });
  if (error) { console.log('game', g.slug, error.message); }
}
console.log('upserted', games.length, 'games');

// --- replace seed items for the two playable games ---
async function seedItems(slug, itemType, byBand, toPayload) {
  await a.from('game_items').delete().eq('game_slug', slug).eq('source', 'seed');
  const rows = [];
  for (const band of ['A', 'B', 'C']) {
    for (const it of byBand[band]) rows.push({ game_slug: slug, band, item_type: itemType, payload: toPayload(it), source: 'seed' });
  }
  const { error } = await a.from('game_items').insert(rows);
  console.log(slug, error ? error.message : `seeded ${rows.length} items`);
}

await seedItems('would-you-rather', 'pair', wyr,
  ([oa, ea, ob, eb]) => ({ optionA: oa, emojiA: ea, optionB: ob, emojiB: eb, askWhy: false }));
await seedItems('get-to-know-you', 'question', gtky,
  ([cat, q]) => ({ question: q, category: cat }));

console.log('done');
