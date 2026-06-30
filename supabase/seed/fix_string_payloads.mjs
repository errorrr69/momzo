// One-off repair: some game_items had their jsonb `payload` double-encoded as a
// STRING (a generate-game-items insert bug). Decode each back into a proper object.
// Idempotent. Run: node supabase/seed/fix_string_payloads.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const env = (() => { const o = {}; for (const r of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) { const l = r.trim(); if (!l || l.startsWith('#')) continue; const e = l.indexOf('='); if (e < 0) continue; let v = l.slice(e + 1).trim(); v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim(); o[l.slice(0, e).trim()] = v; } return o; })();
const a = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const { data } = await a.from('game_items').select('id,game_slug,payload');
let fixed = 0, unfixable = 0;
for (const r of data) {
  if (r.payload && typeof r.payload === 'object' && !Array.isArray(r.payload)) continue; // already good
  let obj = null;
  if (typeof r.payload === 'string') {
    try { obj = JSON.parse(r.payload); } catch { /* maybe double-stringified */ }
    if (typeof obj === 'string') { try { obj = JSON.parse(obj); } catch { /* give up */ } }
  }
  if (obj && typeof obj === 'object' && !Array.isArray(obj)) {
    await a.from('game_items').update({ payload: obj }).eq('id', r.id);
    fixed++;
  } else {
    unfixable++;
    console.warn('  could not repair', r.id, r.game_slug, JSON.stringify(r.payload)?.slice(0, 50));
  }
}
console.log(`repaired ${fixed} payload(s); ${unfixable} unfixable.`);
