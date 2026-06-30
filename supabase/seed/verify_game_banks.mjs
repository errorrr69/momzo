// Bank-coverage guard (edits #4): a game must never ship with an EMPTY content bank
// for a supported age band. Fails (exit 1) if any playable game has zero active
// game_items for any band from its min_band up to C. Run in CI / before release:
//   node supabase/seed/verify_game_banks.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const env = (() => { const o = {}; for (const r of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) { const l = r.trim(); if (!l || l.startsWith('#')) continue; const e = l.indexOf('='); if (e < 0) continue; let v = l.slice(e + 1).trim(); v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim(); o[l.slice(0, e).trim()] = v; } return o; })();
const a = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const BANDS = ['A', 'B', 'C'];
const { data: games } = await a.from('games').select('slug,min_band,playable').eq('playable', true).order('sort');

let failures = 0;
for (const g of games) {
  const minIdx = Math.max(0, BANDS.indexOf(g.min_band || 'A'));
  const supported = BANDS.slice(minIdx);
  const counts = [];
  for (const band of supported) {
    const { count } = await a.from('game_items')
      .select('id', { count: 'exact', head: true })
      .eq('game_slug', g.slug).eq('band', band).eq('active', true);
    counts.push(`${band}:${count}`);
    if (!count) {
      console.error(`✗ ${g.slug}: EMPTY bank for supported band ${band}`);
      failures++;
    }
  }
  console.log(`${failures ? ' ' : '✓'} ${g.slug.padEnd(20)} [${counts.join(' ')}]`);
}

if (failures) {
  console.error(`\nFAIL: ${failures} empty bank(s) — a playable game cannot ship without items for every supported band.`);
  process.exit(1);
}
console.log(`\nOK: all ${games.length} playable games have content for every supported band.`);
