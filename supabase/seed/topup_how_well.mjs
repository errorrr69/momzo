// Top up How Well Do You Know Me? to ~40/band. Each attribute becomes TWO items
// (about the child + about the grown-up), so we need ~20 unique attributes/band.
// Generates attributes via Mistral, safety-filtered + de-duped. Run:
//   node supabase/seed/topup_how_well.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const env = (() => { const o = {}; for (const r of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) { const l = r.trim(); if (!l || l.startsWith('#')) continue; const e = l.indexOf('='); if (e < 0) continue; let v = l.slice(e + 1).trim(); v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim(); o[l.slice(0, e).trim()] = v; } return o; })();
const a = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const MKEY = process.env.MISTRAL_API_KEY || env.MISTRAL_API_KEY;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const norm = (s) => String(s).toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();
const BLOCK = /\b(die|died|death|dead|kill|blood|weapon|gun|knife|war|hate|ugly|fat|stupid|dumb|idiot|scary|nightmare|drown|hurt|sick|hospital|divorce|money|rich|poor|prettiest|smartest|religion|god|sexy|kiss)\b/i;
const BANDS = { A: '4–5 year old (concrete favourites only)', B: '6–7 year old (favourites + simple feelings)', C: '8–10 year old (deeper, kindly framed)' };
const TARGET_ATTRS = 20; // × 2 sides = 40 items/band

async function gen(prompt) {
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

for (const band of ['A', 'B', 'C']) {
  // distinct attributes already present (across both sides)
  const { data } = await a.from('game_items').select('payload').eq('game_slug', 'how-well-know-me').eq('band', band).eq('active', true);
  const seen = new Set((data || []).map((r) => norm(r.payload.attribute)));
  let attrs = [...seen];
  let guard = 0;
  while (attrs.length < TARGET_ATTRS && guard++ < 6) {
    const obj = await gen(`Generate ${TARGET_ATTRS - attrs.length + 4} single ATTRIBUTES that both a ${BANDS[band]} and their grown-up could answer about a person (e.g. "favourite snack", "what makes them laugh"). Each a short noun phrase, no "the/their", answerable about anyone, no data-fishing, nothing comparative/embarrassing. Respond JSON: {"items":[{"attribute"}]}. Exclude: ${attrs.slice(-30).join(' | ')}`);
    const arr = Array.isArray(obj?.items) ? obj.items : [];
    for (const it of arr) {
      const k = norm(it.attribute);
      if (!k || seen.has(k) || BLOCK.test(k)) continue;
      seen.add(k); attrs.push(k);
      if (attrs.length >= TARGET_ATTRS) break;
    }
    await sleep(500);
  }
  // insert any NEW attributes as both child- and parent-side
  const existing = new Set((data || []).map((r) => `${r.payload.about}|${norm(r.payload.attribute)}`));
  const rows = [];
  for (const attr of attrs) {
    for (const about of ['child', 'parent']) {
      if (!existing.has(`${about}|${attr}`)) rows.push({ game_slug: 'how-well-know-me', band, item_type: 'attribute', payload: { about, attribute: attr, band }, source: 'ai' });
    }
  }
  if (rows.length) await a.from('game_items').insert(rows);
  console.log(`how-well-know-me ${band}: attrs ${attrs.length}, +${rows.length} items`);
}
console.log('done');
