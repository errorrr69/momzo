// Expand mini-game content banks to the spec target (~40/band for question games)
// using Mistral, safety-filtered (games spec §1.4) + de-duplicated against the bank.
// Idempotent-ish: only tops up bands that are below target. Run:
//   node supabase/seed/expand_game_banks.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const env = (() => { const o = {}; for (const r of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) { const l = r.trim(); if (!l || l.startsWith('#')) continue; const e = l.indexOf('='); if (e < 0) continue; let v = l.slice(e + 1).trim(); v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim(); o[l.slice(0, e).trim()] = v; } return o; })();
const a = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const MKEY = process.env.MISTRAL_API_KEY || env.MISTRAL_API_KEY;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const TARGET = 40;
// Action/creative games target ~30/band (games spec §1.3.A); everything else 40.
const TARGETS = { charades: 30, 'drawing-telephone': 30, 'simon-says': 30, 'mirror-me': 30, 'story-builder': 30 };
const BANDS = { A: '4–5 year old (very simple, concrete, everyday words)', B: '6–7 year old (simple, some feeling words, light imagination)', C: '8–10 year old (richer, can handle hypotheticals and "why")' };

// Hard safety post-filter (belt-and-suspenders on top of the prompt).
const BLOCK = /\b(die|died|death|dead|kill|kills|killed|blood|weapon|gun|knife|war|hate|hates|ugly|fat|stupid|dumb|idiot|scary|scared of|nightmare|monster eats|drown|hurt|sick|hospital|divorce|money|rich|poor|prettiest|smartest|religion|god|sexy|kiss)\b/i;

async function mistralJson(prompt) {
  for (let i = 0; i < 5; i++) {
    const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${MKEY}` },
      body: JSON.stringify({ model: 'mistral-small-latest', messages: [{ role: 'user', content: prompt }], response_format: { type: 'json_object' }, max_tokens: 1600, temperature: 0.8 }),
    });
    if (res.status === 429 || res.status >= 500) { await sleep(2500 * (i + 1)); continue; }
    if (!res.ok) return null;
    try { return JSON.parse((await res.json()).choices?.[0]?.message?.content ?? '{}'); } catch { continue; }
  }
  return null;
}

const norm = (s) => String(s).toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();

async function topUp(slug, itemType, band, existing, makePrompt, toRow, keyOf, safeOf) {
  const target = TARGETS[slug] || TARGET;
  const seen = new Set(existing.map(keyOf));
  let added = 0, guard = 0;
  while (existing.length + added < target && guard++ < 6) {
    const need = target - (existing.length + added);
    const obj = await mistralJson(makePrompt(band, Math.min(need + 4, 20), [...seen].slice(-40)));
    const arr = Array.isArray(obj?.items) ? obj.items : (Array.isArray(obj) ? obj : []);
    const rows = [];
    for (const it of arr) {
      const key = keyOf(it);
      if (!key || seen.has(key)) continue;
      if (BLOCK.test(safeOf(it))) continue; // safety filter
      seen.add(key);
      rows.push({ game_slug: slug, band, item_type: itemType, payload: toRow(it), source: 'ai' });
      if (existing.length + added + rows.length >= target) break;
    }
    if (rows.length) { await a.from('game_items').insert(rows); added += rows.length; }
    console.log(`  ${slug} ${band}: +${rows.length} (now ${existing.length + added})`);
    await sleep(500);
  }
  return added;
}

const games = {
  'would-you-rather': {
    itemType: 'pair',
    prompt: (band, n, excl) => `Generate ${n} fun "would you rather" pairs for a ${BANDS[band]}. Both options must be APPEALING and SAFE — never fear, harm, losing a person/pet, scary, gross, or adult themes. Respond JSON: {"items":[{"optionA","emojiA","optionB","emojiB"}]}. Each option a short phrase. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.optionA && it.optionB ? norm(it.optionA) + '|' + norm(it.optionB) : null,
    safe: (it) => `${it.optionA} ${it.optionB}`,
    row: (it) => ({ optionA: String(it.optionA), emojiA: String(it.emojiA || '✨'), optionB: String(it.optionB), emojiB: String(it.emojiB || '✨'), askWhy: false }),
  },
  'get-to-know-you': {
    itemType: 'question',
    prompt: (band, n, excl) => `Generate ${n} warm "get to know you" questions for a ${BANDS[band]}, each answerable by BOTH parent and child. Categories: favourite, feeling, dream, us. No data-fishing (no address/school/location), nothing embarrassing or comparative. Respond JSON: {"items":[{"question","category"}]} where category is one of favourite|feeling|dream|us. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.question ? norm(it.question) : null,
    safe: (it) => String(it.question),
    row: (it) => ({ question: String(it.question), category: ['favourite', 'feeling', 'dream', 'us'].includes(it.category) ? it.category : 'us' }),
  },
  'finish-the-sentence': {
    itemType: 'prompt',
    prompt: (band, n, excl) => `Generate ${n} OPEN, POSITIVE sentence stems for a ${BANDS[band]} to finish (exactly one blank "___" each). Never lead to a sad or negative answer. Respond JSON: {"items":[{"stem"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.stem ? norm(it.stem) : null,
    safe: (it) => String(it.stem),
    row: (it) => ({ stem: String(it.stem).includes('___') ? String(it.stem) : String(it.stem) + ' ___' }),
  },
  'emoji-decode': {
    itemType: 'emoji_puzzle',
    prompt: (band, n, excl) => `Generate ${n} emoji puzzles for a ${BANDS[band]}. ${band === 'A' ? 'EXACTLY ONE emoji each (no sequences).' : band === 'B' ? 'EXACTLY TWO emojis each.' : 'EXACTLY THREE emojis each.'} The answer must be a GENERIC everyday concept — NEVER a copyrighted title, character, brand, movie, or specific IP. Respond JSON: {"items":[{"emojis","answer","hint"}]} where hint is a gentle clue. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.answer ? norm(it.answer) : null,
    safe: (it) => `${it.answer} ${it.hint}`,
    row: (it) => ({ emojis: String(it.emojis), answer: String(it.answer), hint: String(it.hint || '') }),
  },
  'hot-seat': {
    itemType: 'question',
    prompt: (band, n, excl) => `Generate ${n} rapid-fire "hot seat" questions for a ${BANDS[band]}, each answerable in 1–3 seconds (favourites or this-or-that). Light and fun, no deep/reflective ones, no data-fishing. Respond JSON: {"items":[{"question"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.question ? norm(it.question) : null,
    safe: (it) => String(it.question),
    row: (it) => ({ question: String(it.question), quick: true }),
  },
  'time-machine': {
    itemType: 'pair',
    prompt: (band, n, excl) => `Generate ${n} gentle prompt PAIRS for a ${BANDS[band]} and their grown-up. Each pair: parentPrompt looks BACK to the grown-up's childhood, childPrompt looks FORWARD to the child growing up. Warm, never sad/loss. Respond JSON: {"items":[{"parentPrompt","childPrompt"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.parentPrompt && it.childPrompt ? norm(it.parentPrompt) + '|' + norm(it.childPrompt) : null,
    safe: (it) => `${it.parentPrompt} ${it.childPrompt}`,
    row: (it) => ({ parentPrompt: String(it.parentPrompt), childPrompt: String(it.childPrompt) }),
  },
  'memory-lane': {
    itemType: 'prompt',
    prompt: (band, n, excl) => `Generate ${n} prompts pointing at POSITIVE shared memories for a ${BANDS[band]} and their family. Open to any family shape/budget ("a time we laughed", not "a holiday"). Never a sad time or a time in trouble. Respond JSON: {"items":[{"prompt"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.prompt ? norm(it.prompt) : null,
    safe: (it) => String(it.prompt),
    row: (it) => ({ prompt: String(it.prompt) }),
  },
  'gratitude-swap': {
    itemType: 'prompt',
    prompt: (band, n, excl) => `Generate ${n} warm prompts for a ${BANDS[band]} and their grown-up to each share something they are GRATEFUL FOR ABOUT THE OTHER. Only warmth — never "something you'd change", never about appearance/looks. Bedtime-soft. Respond JSON: {"items":[{"prompt"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.prompt ? norm(it.prompt) : null,
    safe: (it) => String(it.prompt),
    row: (it) => ({ prompt: String(it.prompt) }),
  },
  'guess-my-answer': {
    itemType: 'question',
    prompt: (band, n, excl) => `Generate ${n} fun "predict what they'll say" questions for a ${BANDS[band]} and their grown-up, where there is no wrong answer (opinions/choices/hypotheticals). Respond JSON: {"items":[{"question"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.question ? norm(it.question) : null,
    safe: (it) => String(it.question),
    row: (it) => ({ question: String(it.question), mode: 'open' }),
  },
  'charades': {
    itemType: 'action',
    prompt: (band, n, excl) => `Generate ${n} charades prompts a ${BANDS[band]} can physically act out safely indoors (no jumping off things, no rough/scary actions). Each with one fitting emoji. Cheerful. Respond JSON: {"items":[{"actPrompt","emojiHint"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.actPrompt ? norm(it.actPrompt) : null,
    safe: (it) => String(it.actPrompt),
    row: (it) => ({ actPrompt: String(it.actPrompt), emojiHint: String(it.emojiHint || '🎭') }),
  },
  'drawing-telephone': {
    itemType: 'action',
    prompt: (band, n, excl) => `Generate ${n} drawing prompts for a ${BANDS[band]}: ${band === 'A' ? 'single concrete nouns (a cat, the sun)' : band === 'B' ? 'noun + adjective (a happy dog, a big tree)' : 'fun mini-scenes (a cat on a skateboard)'}. All drawable by a child, cheerful, never scary/complex. Respond JSON: {"items":[{"drawPrompt"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.drawPrompt ? norm(it.drawPrompt) : null,
    safe: (it) => String(it.drawPrompt),
    row: (it) => ({ drawPrompt: String(it.drawPrompt) }),
  },
  'simon-says': {
    itemType: 'action',
    prompt: (band, n, excl) => `Generate ${n} simple, safe, indoor "Simon Says" body-action commands for a ${BANDS[band]} (touch your nose, clap twice). No risky moves. Respond JSON: {"items":[{"command"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.command ? norm(it.command) : null,
    safe: (it) => String(it.command),
    row: (it) => ({ command: String(it.command), isSimonSays: true }),
  },
  'mirror-me': {
    itemType: 'action',
    prompt: (band, n, excl) => `Generate ${n} gentle "starter move" ideas for a ${BANDS[band]} to lead and have the other mirror (slow wave, big stretch). Safe, indoor, gentle. Respond JSON: {"items":[{"moveIdea"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.moveIdea ? norm(it.moveIdea) : null,
    safe: (it) => String(it.moveIdea),
    row: (it) => ({ moveIdea: String(it.moveIdea) }),
  },
  'story-builder': {
    itemType: 'story_seed',
    prompt: (band, n, excl) => `Generate ${n} warm, funny, child-safe story STARTERS for a ${BANDS[band]} (friendly animals/adventures, no peril/scary). Each a single opening line ending with "…". Respond JSON: {"items":[{"starter"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.starter ? norm(it.starter) : null,
    safe: (it) => String(it.starter),
    row: (it) => ({ starter: String(it.starter), twists: ['suddenly it started raining jelly!', 'a friendly dragon appeared', 'they found a magic door', 'everything turned upside down'] }),
  },
};

for (const [slug, cfg] of Object.entries(games)) {
  for (const band of ['A', 'B', 'C']) {
    const { data } = await a.from('game_items').select('payload').eq('game_slug', slug).eq('band', band).eq('active', true);
    await topUp(slug, cfg.itemType, band, data || [], cfg.prompt, cfg.row, (x) => cfg.key(x.payload ?? x), (x) => cfg.safe(x.payload ?? x));
  }
}
console.log('done');
