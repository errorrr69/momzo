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
const BANDS = { A: '4–5 year old (very simple, concrete, everyday words)', B: '6–7 year old (simple, some feeling words, light imagination)', C: '8–10 year old (richer, can handle hypotheticals and "why")' };

// Hard safety post-filter (belt-and-suspenders on top of the prompt).
const BLOCK = /\b(die|died|death|dead|kill|kills|killed|blood|weapon|gun|knife|war|hate|hates|ugly|fat|stupid|dumb|idiot|scary|scared of|nightmare|monster eats|drown|hurt|sick|hospital|divorce|money|rich|poor|prettiest|smartest|religion|god|sexy|kiss)\b/i;

async function mistralJson(prompt) {
  for (let i = 0; i < 5; i++) {
    const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${MKEY}` },
      body: JSON.stringify({ model: 'mistral-small-latest', messages: [{ role: 'user', content: prompt }], response_format: { type: 'json_object' }, max_tokens: 1200, temperature: 0.8 }),
    });
    if (res.status === 429 || res.status >= 500) { await sleep(2500 * (i + 1)); continue; }
    if (!res.ok) return null;
    try { return JSON.parse((await res.json()).choices?.[0]?.message?.content ?? '{}'); } catch { continue; }
  }
  return null;
}

const norm = (s) => String(s).toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();

async function topUp(slug, band, existing, makePrompt, toRow, keyOf, safeOf) {
  const seen = new Set(existing.map(keyOf));
  let added = 0, guard = 0;
  while (existing.length + added < TARGET && guard++ < 6) {
    const need = TARGET - (existing.length + added);
    const obj = await mistralJson(makePrompt(band, Math.min(need + 4, 20), [...seen].slice(-40)));
    const arr = Array.isArray(obj?.items) ? obj.items : (Array.isArray(obj) ? obj : []);
    const rows = [];
    for (const it of arr) {
      const key = keyOf(it);
      if (!key || seen.has(key)) continue;
      if (BLOCK.test(safeOf(it))) continue; // safety filter
      seen.add(key);
      rows.push({ game_slug: slug, band, item_type: slug === 'would-you-rather' ? 'pair' : 'question', payload: toRow(it), source: 'ai' });
      if (existing.length + added + rows.length >= TARGET) break;
    }
    if (rows.length) { await a.from('game_items').insert(rows); added += rows.length; }
    console.log(`  ${slug} ${band}: +${rows.length} (now ${existing.length + added})`);
    await sleep(500);
  }
  return added;
}

const games = {
  'would-you-rather': {
    prompt: (band, n, excl) => `Generate ${n} fun "would you rather" pairs for a ${BANDS[band]}. Both options must be APPEALING and SAFE — never fear, harm, losing a person/pet, scary, gross, or adult themes. Respond JSON: {"items":[{"optionA","emojiA","optionB","emojiB"}]}. Each option a short phrase. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.optionA && it.optionB ? norm(it.optionA) + '|' + norm(it.optionB) : null,
    safe: (it) => `${it.optionA} ${it.optionB}`,
    row: (it) => ({ optionA: String(it.optionA), emojiA: String(it.emojiA || '✨'), optionB: String(it.optionB), emojiB: String(it.emojiB || '✨'), askWhy: false }),
  },
  'get-to-know-you': {
    prompt: (band, n, excl) => `Generate ${n} warm "get to know you" questions for a ${BANDS[band]}, each answerable by BOTH parent and child. Categories: favourite, feeling, dream, us. No data-fishing (no address/school/location), nothing embarrassing or comparative. Respond JSON: {"items":[{"question","category"}]} where category is one of favourite|feeling|dream|us. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.question ? norm(it.question) : null,
    safe: (it) => String(it.question),
    row: (it) => ({ question: String(it.question), category: ['favourite', 'feeling', 'dream', 'us'].includes(it.category) ? it.category : 'us' }),
  },
};

for (const [slug, cfg] of Object.entries(games)) {
  for (const band of ['A', 'B', 'C']) {
    const { data } = await a.from('game_items').select('payload').eq('game_slug', slug).eq('band', band).eq('active', true);
    await topUp(slug, band, data || [], cfg.prompt, cfg.row, (x) => cfg.key(x.payload ?? x), (x) => cfg.safe(x.payload ?? x));
  }
}
console.log('done');
