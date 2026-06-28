// Seed the remaining 15 mini-games: catalog rows (all playable) + starter content
// banks per band. expand_game_banks.mjs then tops the question/prompt games to
// ~40/band and the action games to ~30/band via Mistral. The stable-set / scaffold
// games (mood-checkin, two-truths, compliment-toss) ship their full small bank here.
// Idempotent: upserts games, replaces their 'seed' items. Run:
//   node supabase/seed/build_games_rest.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const env = (() => { const o = {}; for (const r of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) { const l = r.trim(); if (!l || l.startsWith('#')) continue; const e = l.indexOf('='); if (e < 0) continue; let v = l.slice(e + 1).trim(); v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim(); o[l.slice(0, e).trim()] = v; } return o; })();
const a = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

// --- catalog rows -------------------------------------------------------------
const games = [
  { slug: 'how-well-know-me', title: 'How Well Do You Know Me?', emoji: '💞', subtitle: 'guess & reveal', type: 'reveal', min_band: 'A', accent: '#A593D6', rounds_a: 3, rounds_b: 4, rounds_c: 5, playable: true, sort: 7 },
  { slug: 'guess-my-answer', title: 'Guess My Answer', emoji: '🔮', subtitle: 'predict & compare', type: 'reveal', min_band: 'A', accent: '#8FC7D6', rounds_a: 3, rounds_b: 4, rounds_c: 5, playable: true, sort: 8 },
  { slug: 'hot-seat', title: 'Hot Seat', emoji: '🔥', subtitle: 'rapid favourites', type: 'question', min_band: 'A', accent: '#EC8366', rounds_a: 4, rounds_b: 6, rounds_c: 8, playable: true, sort: 9 },
  { slug: 'time-machine', title: 'Time Machine', emoji: '⏳', subtitle: 'then & someday', type: 'pair', min_band: 'A', accent: '#A593D6', rounds_a: 2, rounds_b: 3, rounds_c: 4, playable: true, sort: 10 },
  { slug: 'memory-lane', title: 'Memory Lane', emoji: '💭', subtitle: 'happy moments', type: 'prompt', min_band: 'A', accent: '#F2B441', rounds_a: 2, rounds_b: 3, rounds_c: 4, playable: true, sort: 11 },
  { slug: 'gratitude-swap', title: 'Gratitude Swap', emoji: '🌸', subtitle: 'thankful for you', type: 'prompt', min_band: 'A', accent: '#84B89A', rounds_a: 2, rounds_b: 2, rounds_c: 3, playable: true, sort: 12 },
  { slug: 'compliment-toss', title: 'Compliment Toss', emoji: '🎁', subtitle: 'say something kind', type: 'prompt', min_band: 'A', accent: '#E87DA6', rounds_a: 2, rounds_b: 3, rounds_c: 3, playable: true, sort: 13 },
  { slug: 'mood-checkin', title: 'Mood Check-in', emoji: '🌈', subtitle: 'how are you?', type: 'feeling', min_band: 'A', accent: '#A593D6', rounds_a: 1, rounds_b: 2, rounds_c: 2, playable: true, sort: 14 },
  { slug: 'charades', title: 'Charades', emoji: '🎭', subtitle: 'act it out', type: 'action', min_band: 'A', accent: '#EC8366', rounds_a: 3, rounds_b: 4, rounds_c: 5, playable: true, sort: 15 },
  { slug: 'drawing-telephone', title: 'Drawing Telephone', emoji: '✏️', subtitle: 'draw & guess', type: 'action', min_band: 'A', accent: '#8FC7D6', rounds_a: 2, rounds_b: 3, rounds_c: 4, playable: true, sort: 16 },
  { slug: 'dance-freeze', title: 'Dance Freeze', emoji: '🕺', subtitle: 'move & freeze', type: 'action', min_band: 'A', accent: '#F2B441', rounds_a: 4, rounds_b: 5, rounds_c: 5, playable: true, sort: 17 },
  { slug: 'simon-says', title: 'Simon Says', emoji: '🙌', subtitle: 'listen & do', type: 'action', min_band: 'A', accent: '#84B89A', rounds_a: 5, rounds_b: 6, rounds_c: 8, playable: true, sort: 18 },
  { slug: 'mirror-me', title: 'Mirror Me', emoji: '🪞', subtitle: 'copy each other', type: 'action', min_band: 'A', accent: '#A593D6', rounds_a: 3, rounds_b: 4, rounds_c: 4, playable: true, sort: 19 },
];
// two-truths + story-builder already have catalog rows (build_games.mjs) — flip playable.
await a.from('games').update({ playable: true, rounds_a: 2, rounds_b: 3, rounds_c: 4 }).eq('slug', 'two-truths');
await a.from('games').update({ playable: true, rounds_a: 4, rounds_b: 6, rounds_c: 8 }).eq('slug', 'story-builder');

for (const g of games) {
  const { error } = await a.from('games').upsert(g, { onConflict: 'slug' });
  if (error) console.log('game', g.slug, error.message);
}
console.log('upserted', games.length, 'games (+2 flipped playable)');

// --- starter content banks ----------------------------------------------------
async function seed(slug, itemType, byBand, toPayload) {
  await a.from('game_items').delete().eq('game_slug', slug).eq('source', 'seed');
  const rows = [];
  for (const band of ['A', 'B', 'C']) for (const it of (byBand[band] || [])) rows.push({ game_slug: slug, band, item_type: itemType, payload: toPayload(it, band), source: 'seed' });
  const { error } = await a.from('game_items').insert(rows);
  console.log(slug, error ? error.message : `seeded ${rows.length}`);
}

// How Well Do You Know Me? — { about, attribute }
const hwkm = {
  A: ['favourite colour', 'favourite animal', 'favourite snack', 'favourite toy', 'favourite fruit', 'favourite song', 'favourite game', 'favourite story', 'favourite drink', 'favourite place to play'],
  B: ['favourite colour', 'favourite snack', 'favourite animal', 'favourite game', 'what makes them laugh', 'their happiest place', 'favourite song', 'favourite thing to do on a weekend', 'favourite season', 'what they want to learn'],
  C: ['what they are most proud of', 'their happiest memory', 'what makes them laugh', 'something they are good at', 'what they would wish for', 'their favourite way to relax', 'what they love about our family', 'a place they dream of going', 'what makes them feel brave', 'something they want to try'],
};
await seed('how-well-know-me', 'attribute', hwkm, (attr, band) => ({ about: 'child', attribute: attr, band }));
// add the parent-side mirror items too
{
  const rows = [];
  for (const band of ['A', 'B', 'C']) for (const attr of hwkm[band]) rows.push({ game_slug: 'how-well-know-me', band, item_type: 'attribute', payload: { about: 'parent', attribute: attr, band }, source: 'seed' });
  await a.from('game_items').insert(rows);
  console.log('how-well-know-me parent-side +', rows.length);
}

// Guess My Answer — { question, mode, options? }
const gma = {
  A: [['apple', 'banana'], ['the park', 'the playground'], ['a cat', 'a dog'], ['ice cream', 'cake'], ['red', 'blue'], ['pizza', 'pasta'], ['the swing', 'the slide'], ['a story', 'a song'], ['juice', 'milk'], ['day', 'night']],
  B: [['What is the best day of the week?'], ['What is the best dinner ever?'], ['If we got a pet, what should it be?'], ['What is the best dessert?'], ['What is the most fun place to go?'], ['What is the best weather?'], ['What is the silliest animal?'], ['What is the best thing to do on a rainy day?'], ['What is the best ice cream flavour?'], ['What is the best superhero power?']],
  C: [['If we could travel anywhere, where should we go?'], ['If we won a prize, what should we do with it?'], ['What is the best invention ever?'], ['If we made a film, what should it be about?'], ['What is the best way to spend a Saturday?'], ['If we had a robot, what should it do?'], ['What is the best season and why?'], ['If we could meet anyone, who should it be?'], ['What is the best meal to cook together?'], ['If we started a club, what should it be?']],
};
await seed('guess-my-answer', 'question', gma, (it, band) =>
  it.length === 2 ? { question: `Which will they pick — ${it[0]} or ${it[1]}?`, mode: 'either_or', options: it } : { question: it[0], mode: 'open' });

// Hot Seat — { question, quick }
const hot = {
  A: ['Favourite colour?', 'Cats or dogs?', 'Sweet or salty?', 'Favourite fruit?', 'Favourite animal?', 'Pizza or pasta?', 'Sun or rain?', 'Favourite toy?', 'Red or blue?', 'Day or night?', 'Big or small?', 'Hop or spin?'],
  B: ['Favourite season?', 'Beach or mountains?', 'Pancakes or waffles?', 'Best superhero?', 'Favourite ice cream?', 'Morning or night?', 'Favourite pizza topping?', 'Books or films?', 'Swimming or biking?', 'Favourite snack?', 'Summer or winter?', 'Best game ever?'],
  C: ['Sweet or savoury?', 'City or countryside?', 'Best holiday spot?', 'Favourite subject?', 'Early bird or night owl?', 'Favourite drink?', 'Music or podcasts?', 'Favourite app or game?', 'Best pizza topping?', 'Cook or order in?', 'Favourite emoji?', 'Best day of the week?'],
};
await seed('hot-seat', 'question', hot, (q) => ({ question: q, quick: true }));

// Time Machine — { parentPrompt, childPrompt }
const tm = {
  A: [['What did you play with when you were little?', 'What is your favourite toy now?'], ['What was your favourite food as a kid?', 'What food do you love most now?'], ['What made you laugh when you were small?', 'What makes you giggle today?']],
  B: [['What was your favourite game at my age?', 'What do you think you will love when you are big?'], ['Who was your best friend as a child?', 'What kind of friend do you want to be?'], ['What did you want to be when you grew up?', 'What do you dream of being one day?']],
  C: [['What were you a little scared of at my age?', 'What do you feel brave about now?'], ['What is something you wish you knew as a kid?', 'What do you hope is true about you at 20?'], ['What was the best adventure of your childhood?', 'What adventure do you dream of having?'], ['What did you argue with your parents about?', 'What do you hope we always understand about you?']],
};
await seed('time-machine', 'pair', tm, ([p, c]) => ({ parentPrompt: p, childPrompt: c }));

// Memory Lane — { prompt }
const mem = {
  A: ['a fun thing we did this week', 'a yummy thing we ate together', 'a silly thing that made us laugh', 'a game we played together', 'a time we went somewhere fun'],
  B: ['a fun day we had together', 'a time we laughed really hard', 'a yummy thing we made together', 'a silly thing that happened', 'our favourite thing to do at home', 'a time we helped someone'],
  C: ['a memory of us that always makes you smile', 'a time you felt really proud of us', 'an adventure we had together', 'a tradition of ours you love', 'a time we got through something hard together', 'a small ordinary moment you treasure'],
};
await seed('memory-lane', 'prompt', mem, (prompt) => ({ prompt }));

// Gratitude Swap — { prompt } (kindness-locked)
const grat = {
  A: ['one thing you love about each other', 'a way they make you smile', 'something fun you did together today', 'a way they are kind to you', 'something nice they say to you', 'a yummy thing they share with you', 'a game they play with you', 'a way they help you', 'a hug or cuddle you love', 'a song or story they do with you', 'something they do that makes you happy', 'a time they made you laugh', 'a way they keep you cosy and safe', 'something you like to do together', 'a way they cheer you up', 'something they are really good at'],
  B: ['one thing you are thankful for about each other', 'a kind thing they did recently', 'a way they make home feel happy', 'something they are really good at', 'a moment you felt happy together'],
  C: ['a way they helped you this week', 'something they do that makes home feel cosy', 'a quality you admire in them', 'a time they were there for you', 'something you are grateful they taught you', 'a small thing they do that means a lot'],
};
await seed('gratitude-swap', 'prompt', grat, (prompt) => ({ prompt }));

// Compliment Toss — { scaffold, focus } (kindness-locked, small bank N≈12)
const comp = {
  A: [['Tell each other something nice!', 'open'], ['I love how you ___', 'kind'], ['You are really good at ___', 'helpful'], ['You always make me feel ___', 'open']],
  B: [['I love how you ___', 'kind'], ['You are really good at ___', 'helpful'], ['Something brave about you is ___', 'brave'], ['You always make me ___', 'funny'], ['You are so kind when you ___', 'kind']],
  C: [['My favourite thing about you is ___', 'open'], ['Something brave about you is ___', 'brave'], ['You are really thoughtful when you ___', 'kind'], ['I admire how you ___', 'open'], ['You make me laugh when you ___', 'funny'], ['You are so helpful when you ___', 'helpful']],
};
await seed('compliment-toss', 'prompt', comp, ([scaffold, focus]) => ({ scaffold, focus }));

// Mood Check-in — { feelings:[{emoji,label}], gentleFollowUp } (stable sets)
const FA = [{ emoji: '😀', label: 'happy' }, { emoji: '😢', label: 'sad' }, { emoji: '😴', label: 'sleepy' }, { emoji: '🤩', label: 'excited' }];
const FB = [...FA, { emoji: '😌', label: 'calm' }, { emoji: '😟', label: 'worried' }];
const FC = [...FB, { emoji: '😤', label: 'frustrated' }, { emoji: '😳', label: 'nervous' }, { emoji: '🥰', label: 'loved' }, { emoji: '😎', label: 'proud' }];
const mood = {
  A: [{ feelings: FA, gentleFollowUp: 'What made you feel that?' }],
  B: [{ feelings: FB, gentleFollowUp: 'What made you feel that?' }, { feelings: FB, gentleFollowUp: 'Want to tell me more?' }],
  C: [{ feelings: FC, gentleFollowUp: 'Want to tell me about it?' }, { feelings: FC, gentleFollowUp: 'What would help right now?' }],
};
await seed('mood-checkin', 'feeling', mood, (it) => it);

// Charades — { actPrompt, emojiHint }
const char = {
  A: [['a hopping bunny', '🐰'], ['a sleepy cat', '😴'], ['a flying bird', '🐦'], ['a stomping elephant', '🐘'], ['a wiggly fish', '🐟'], ['a happy puppy', '🐶'], ['a jumping frog', '🐸'], ['a slithering snake', '🐍']],
  B: [['brushing your teeth', '🪥'], ['a chef cooking', '👩‍🍳'], ['watering plants', '🪴'], ['a superhero pose', '🦸'], ['riding a bike', '🚲'], ['a happy puppy', '🐶'], ['a swimming fish', '🐠'], ['playing football', '⚽']],
  C: [['an astronaut walking on the moon', '🚀'], ['a robot dancing', '🤖'], ['a juggler', '🤹'], ['someone very surprised', '😲'], ['a cat chasing a butterfly', '🦋'], ['a chef tasting soup', '🍲'], ['a tightrope walker', '🎪'], ['someone who just won a prize', '🏆']],
};
await seed('charades', 'action', char, ([actPrompt, emojiHint]) => ({ actPrompt, emojiHint }));

// Drawing Telephone — { drawPrompt }
const draw = {
  A: ['a cat', 'the sun', 'a ball', 'a flower', 'a fish', 'a star', 'an apple', 'a house', 'a dog', 'a tree'],
  B: ['a happy dog', 'a big balloon', 'a sleepy cat', 'a tall tree', 'a funny hat', 'a rainy cloud', 'a smiling sun', 'a cosy house', 'a bright rainbow', 'a tiny mouse'],
  C: ['a cat on a skateboard', 'a robot eating ice cream', 'a dog flying a kite', 'a dancing banana', 'a penguin in a hat', 'a frog playing guitar', 'a turtle racing a snail', 'an octopus juggling', 'a dinosaur having tea', 'a cloud raining flowers'],
};
await seed('drawing-telephone', 'action', draw, (drawPrompt) => ({ drawPrompt }));

// Dance Freeze — { moveTheme }
const dance = {
  A: ['wiggle like jelly', 'flap like a bird', 'stomp like a dino', 'spin like a top', 'tiptoe like a cat', 'bounce like a kangaroo', 'sway like a tree', 'shake like a leaf'],
  B: ['dance like a robot', 'float like underwater', 'march like a soldier', 'twirl like a dancer', 'hop like a frog', 'wave like the ocean', 'shuffle like a penguin', 'gallop like a horse'],
  C: ['dance like you are underwater', 'dance like a robot losing power', 'move in slow motion', 'dance like a superhero', 'dance like nobody is watching', 'dance like a rockstar', 'dance like a windy day', 'dance like a melting snowman'],
};
await seed('dance-freeze', 'action', dance, (moveTheme) => ({ moveTheme }));

// Simon Says — { command, isSimonSays }
const simon = {
  A: ['touch your nose', 'clap your hands', 'pat your head', 'wiggle your fingers', 'touch your toes', 'give a high five', 'stomp your feet', 'give yourself a hug'],
  B: ['hop on one foot', 'spin around', 'make a funny face', 'blink three times', 'touch your ears', 'jump up high', 'wave your arms', 'tap your knees'],
  C: ['hop twice and clap', 'touch your nose then your toes', 'spin around slowly', 'pat your head and rub your tummy', 'march in place', 'do a big stretch', 'strike a superhero pose', 'wink and smile'],
};
await seed('simon-says', 'action', simon, (command) => ({ command, isSimonSays: true }));

// Mirror Me — { moveIdea }
const mirror = {
  A: ['a slow wave', 'a big stretch', 'a silly face', 'march in place', 'gentle sway', 'shoulder shrug', 'tiptoe steps', 'a slow clap'],
  B: ['a slow-motion jump', 'draw a circle in the air', 'blow a pretend bubble', 'a robot walk', 'a graceful bow', 'a stretch to the sky', 'a wiggle dance', 'a big yawn and stretch'],
  C: ['a slow-motion high five', 'a flowing wave like water', 'a freeze-and-swap pose', 'a tai-chi style stretch', 'an exaggerated tiptoe', 'a mirror handshake', 'a slow spin', 'a synchronised bow'],
};
await seed('mirror-me', 'action', mirror, (moveIdea) => ({ moveIdea }));

// Two Truths & a Lie — { mode, scaffold } (scaffold-level, small bank)
const tt = {
  A: [['silly', 'a food you like, an animal, something silly you pretend'], ['silly', 'a colour you love, a toy, something make-believe'], ['silly', 'a game you play, a snack, a silly superpower'], ['silly', 'an animal, a fruit, something impossible and funny']],
  B: [['simple', 'a food you like, a place you have been, a favourite toy'], ['simple', 'something you can do, a colour, an animal'], ['simple', 'a game you like, a snack, a superpower you wish for'], ['simple', 'two real favourites and one you make up'], ['simple', 'somewhere you have been, a hobby, a pretend fact']],
  C: [['classic', 'a place you have visited, a skill you have, a hidden fact'], ['classic', 'a food you have tried, an experience, a made-up but believable claim'], ['classic', 'something about your past, a talent, a clever lie'], ['classic', 'two true things and one believable bluff'], ['classic', 'a hobby, an achievement, a sneaky made-up fact'], ['classic', 'somewhere you want to go, something you have done, a fib']],
};
await seed('two-truths', 'scaffold', tt, ([mode, scaffold]) => ({ mode, scaffold }));

// Story Builder — { starter, twists[] }
const TWISTS = ['suddenly it started raining jelly!', 'a friendly dragon appeared', 'they found a magic door', 'everything turned upside down', 'a tiny robot wanted to help', 'the floor became a trampoline'];
const story = {
  A: ['Once upon a time, a tiny mouse found a giant cheese…', 'One day, a little duck went looking for its splashy puddle…', 'A small kitten followed a butterfly into the garden…', 'A friendly snail set off on a big slow adventure…'],
  B: ['One morning, the cat woke up and could suddenly talk…', 'Deep in a friendly forest lived a bear who loved to bake…', 'A little cloud wanted to learn how to dance…', 'A brave puppy set sail on a paper boat…', 'A curious fox found a map under the stairs…'],
  C: ['A young inventor built a robot that only spoke in riddles…', 'On a quiet island, a lighthouse keeper found a glowing shell…', 'A kid discovered their treehouse could fly…', 'Two friends found a door at the back of the library that led somewhere new…', 'A explorer found footprints that changed colour…', 'A village woke up to find the river had turned to music…'],
};
await seed('story-builder', 'story_seed', story, (starter) => ({ starter, twists: TWISTS }));

console.log('done');
