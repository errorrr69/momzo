// Backfill the "quick read" fields (hook, quick_points[3], try_this) on every
// published content card, generated from its body via Mistral. Idempotent: skips
// cards that already have them. Run: node supabase/seed/build_quick_reads.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const env = (() => { const o = {}; for (const r of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) { const l = r.trim(); if (!l || l.startsWith('#')) continue; const e = l.indexOf('='); if (e < 0) continue; let v = l.slice(e + 1).trim(); v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim(); o[l.slice(0, e).trim()] = v; } return o; })();
const admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const MKEY = process.env.MISTRAL_API_KEY || env.MISTRAL_API_KEY;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function quickRead(title, body) {
  const prompt =
    'You help a parenting app for mothers of 6-10 year olds who are busy and tired. ' +
    'Turn this article into a calm, scannable summary. Respond with JSON ONLY, keys:\n' +
    '  "hook": one warm sentence (max 26 words) naming a moment a parent notices day to day.\n' +
    '  "points": array of EXACTLY 3 short takeaways, each max 11 words, plain and reassuring.\n' +
    '  "try_this": one concrete thing to try tonight (max 28 words).\n' +
    `No preamble.\n\nTitle: ${title}\n\nArticle:\n${body.slice(0, 5000)}`;
  for (let i = 0; i < 5; i++) {
    const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${MKEY}` },
      body: JSON.stringify({
        model: 'mistral-small-latest',
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' },
        max_tokens: 320,
        temperature: 0.5,
      }),
    });
    if (res.status === 429 || res.status >= 500) { await sleep(2500 * (i + 1)); continue; }
    if (!res.ok) { console.log('  mistral', res.status); return null; }
    const j = await res.json();
    try {
      const obj = JSON.parse(j.choices?.[0]?.message?.content ?? '{}');
      const points = Array.isArray(obj.points) ? obj.points.slice(0, 3).map(String) : [];
      if (!obj.hook || points.length < 3 || !obj.try_this) continue;
      return { hook: String(obj.hook).trim(), points: points.map((p) => p.trim()), try_this: String(obj.try_this).trim() };
    } catch { continue; }
  }
  return null;
}

const { data: cards } = await admin
  .from('content_cards')
  .select('id,title,body,hook,quick_points,try_this')
  .eq('published', true)
  .order('created_at');

let done = 0, skip = 0, fail = 0;
for (const c of cards) {
  const has = c.hook && (c.quick_points?.length ?? 0) >= 3 && c.try_this;
  if (has || !c.body || c.body.trim().length < 80) { skip++; continue; }
  const q = await quickRead(c.title, c.body);
  if (!q) { fail++; console.log('✗ failed:', c.title.slice(0, 50)); continue; }
  await admin.from('content_cards').update({ hook: q.hook, quick_points: q.points, try_this: q.try_this }).eq('id', c.id);
  done++;
  console.log(`✓ ${done} ${c.title.slice(0, 48)}`);
  await sleep(400);
}
console.log(`\nDone. generated: ${done}, skipped: ${skip}, failed: ${fail}`);
