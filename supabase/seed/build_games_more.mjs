// Seed two more games (Finish the Sentence, Emoji Decode) + their starter banks,
// and mark them playable. expand_game_banks.mjs then tops them to ~40/band.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const env = (() => { const o = {}; for (const r of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) { const l = r.trim(); if (!l || l.startsWith('#')) continue; const e = l.indexOf('='); if (e < 0) continue; let v = l.slice(e + 1).trim(); v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim(); o[l.slice(0, e).trim()] = v; } return o; })();
const a = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

await a.from('games').update({ playable: true }).in('slug', ['finish-the-sentence', 'emoji-decode']);

// Finish the Sentence — payload { stem }
const fts = {
  A: ['My favourite snack is ___', 'I love to play ___', 'My favourite animal is ___', 'I feel happy when ___', 'The best toy ever is ___', 'I like to eat ___', 'My favourite colour is ___', 'I love it when we ___', 'My favourite game is ___', 'The best place to play is ___'],
  B: ['I feel happiest when ___', 'I feel brave when ___', 'I feel proud when ___', 'Something that makes me giggle is ___', 'I love it when we ___ together', 'My favourite thing about weekends is ___', 'I feel cosy when ___', 'If I had a magic wish it would be ___', 'The best surprise would be ___', 'I feel excited when ___'],
  C: ['I wish we could ___ together', "Something I'm proud of is ___", 'I feel most like myself when ___', 'The best part of my day is ___', 'I feel brave when ___', "Something I'd love to learn is ___", 'A perfect day for us would be ___', 'I feel really grateful for ___', 'One thing I love about our family is ___', 'A goal I have is ___'],
};

// Emoji Decode — payload { emojis, answer, hint } (generic answers, no copyrighted titles)
const ed = {
  A: [['🐶', 'dog', 'a pet that says woof'], ['🍎', 'apple', 'a red fruit'], ['☀️', 'sun', "it's up in the sky by day"], ['😀', 'happy', 'a big-smile feeling'], ['🌧️', 'rain', 'wet drops from the sky'], ['⭐', 'star', 'it twinkles at night'], ['🐱', 'cat', 'a pet that says meow'], ['🍌', 'banana', 'a yellow fruit'], ['🌈', 'rainbow', 'colours in the sky after rain'], ['🐟', 'fish', 'it swims in water']],
  B: [['🌧️☂️', 'a rainy day', 'you need an umbrella'], ['🎂🎉', 'a birthday', 'cake and a party'], ['🍦😋', 'an ice cream treat', 'a cold sweet treat'], ['🐱😴', 'a sleepy cat', 'a tired kitty'], ['🌙⭐', 'night time', 'when the sky is dark'], ['🏖️☀️', 'a beach day', 'sand and sunshine'], ['🍿🎬', 'movie night', 'snacks and a screen'], ['🐶🦴', 'a dog with a bone', "a pet's favourite chew"], ['🌻🐝', 'a sunny garden', 'flowers and buzzing bees'], ['🎈🥳', 'a party', 'balloons and fun']],
  C: [['🦸‍♂️🏙️', 'a superhero in the city', 'they save the day'], ['🍫🏭', 'a chocolate factory', 'where sweets are made'], ['🚀🌕', 'a trip to the moon', 'blast off into space'], ['🦖🌳', 'dinosaurs in the jungle', 'big reptiles long ago'], ['🏰👑', 'a castle and a crown', 'where royalty lives'], ['🌊🏄', 'surfing the waves', 'riding the ocean'], ['🎨🖌️', 'painting a picture', 'making art with colours'], ['⚽🥅', 'scoring a goal', 'kick it in the net'], ['🏕️🔥', 'a camping trip', 'tents and a campfire'], ['🧑‍🍳🍳', 'cooking breakfast', 'making food in the kitchen']],
};

async function seed(slug, itemType, byBand, toPayload) {
  await a.from('game_items').delete().eq('game_slug', slug).eq('source', 'seed');
  const rows = [];
  for (const band of ['A', 'B', 'C']) for (const it of byBand[band]) rows.push({ game_slug: slug, band, item_type: itemType, payload: toPayload(it), source: 'seed' });
  const { error } = await a.from('game_items').insert(rows);
  console.log(slug, error ? error.message : `seeded ${rows.length}`);
}

await seed('finish-the-sentence', 'prompt', fts, (stem) => ({ stem }));
await seed('emoji-decode', 'emoji_puzzle', ed, ([emojis, answer, hint]) => ({ emojis, answer, hint }));
console.log('done');
