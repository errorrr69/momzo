// Corpus & citation integrity guard (Task 1c). Fails (exit 1) on any dangling
// reference so a bad re-seed or content edit can't silently orphan the app:
//   1. every daily_assignments.card_id resolves to a content_cards row
//   2. every ai_messages.cited_card_ids entry resolves to a content_cards row
//   3. every published content_cards row has >= 1 embedding
// Runs in CI (see .github/workflows). Read-only; uses the service-role key.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));

function env(name) {
  if (process.env[name]) return process.env[name];
  try {
    for (const raw of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) {
      const l = raw.trim();
      if (!l || l.startsWith('#')) continue;
      const eq = l.indexOf('=');
      if (eq < 0 || l.slice(0, eq).trim() !== name) continue;
      let v = l.slice(eq + 1).trim();
      v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim();
      return v;
    }
  } catch { /* no .env in CI — rely on process.env */ }
  return undefined;
}

const url = env('SUPABASE_URL');
const key = env('SUPABASE_SERVICE_ROLE_KEY');
if (!url || !key) {
  console.error('✗ SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set');
  process.exit(1);
}
const a = createClient(url, key, { auth: { persistSession: false } });

const failures = [];

const { data: cards, error: cErr } = await a.from('content_cards').select('id,slug,published');
if (cErr) { console.error('✗ query content_cards:', cErr.message); process.exit(1); }
const cardIds = new Set(cards.map((c) => c.id));

// 1. daily_assignments.card_id
const { data: das } = await a.from('daily_assignments').select('id,card_id');
const daOrphans = (das || []).filter((d) => !cardIds.has(d.card_id));
if (daOrphans.length) failures.push(`${daOrphans.length} daily_assignments reference a missing card (e.g. ${daOrphans[0].card_id})`);

// 2. ai_messages.cited_card_ids
const { data: msgs } = await a.from('ai_messages').select('id,cited_card_ids').not('cited_card_ids', 'eq', '{}');
let citedTotal = 0;
const citedOrphans = [];
for (const m of (msgs || [])) for (const id of (m.cited_card_ids || [])) { citedTotal++; if (!cardIds.has(id)) citedOrphans.push(id); }
if (citedOrphans.length) failures.push(`${citedOrphans.length}/${citedTotal} cited_card_ids reference a missing card (e.g. ${citedOrphans[0]})`);

// 3. published cards must have >= 1 embedding
const withEmb = new Set();
const PAGE = 1000;
for (let from = 0; ; from += PAGE) {
  const { data: page } = await a.from('content_embeddings').select('card_id').range(from, from + PAGE - 1);
  if (!page || !page.length) break;
  for (const e of page) withEmb.add(e.card_id);
  if (page.length < PAGE) break;
}
const noEmb = cards.filter((c) => c.published && !withEmb.has(c.id));
if (noEmb.length) failures.push(`${noEmb.length} published cards have 0 embeddings (e.g. ${noEmb[0].slug})`);

console.log(`Corpus integrity: ${cards.length} cards (${cards.filter((c) => c.published).length} published), ${withEmb.size} cards with embeddings`);
console.log(`  daily_assignments checked: ${(das || []).length} | cited_card_ids checked: ${citedTotal}`);

if (failures.length) {
  console.error('\n✗ INTEGRITY CHECK FAILED:');
  for (const f of failures) console.error('  - ' + f);
  process.exit(1);
}
console.log('✓ integrity check passed — no dangling references, all published cards embedded');
