// Momzo question-of-the-day seeder (Task 19). Parses the categorised prompt list
// into `questions` rows. Idempotent via slug. Run: cd supabase/seed && node build_questions.mjs
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));
const file = join(here, '..', '..', 'knowledge base', 'questions', 'questions-of-the-day.txt');

function parseEnv(p) {
  const o = {};
  for (const r of readFileSync(p, 'utf8').split(/\r?\n/)) {
    const l = r.trim(); if (!l || l.startsWith('#')) continue;
    const e = l.indexOf('='); if (e < 0) continue;
    let v = l.slice(e + 1).trim();
    v = v.startsWith('"') ? v.slice(1, v.indexOf('"', 1)) : v.split(/\s+#/)[0].trim();
    o[l.slice(0, e).trim()] = v;
  }
  return o;
}
const env = parseEnv(join(here, '..', '.env'));
const admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const slugify = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60);

function typeFor(header) {
  const h = header.toLowerCase();
  if (h.includes('feeling')) return 'daily';
  if (h.includes('know each other') || h.includes('know-each-other')) return 'know_each_other';
  return 'game'; // "silly and fun"
}

let type = null;
let count = 0;
const byType = {};
for (const raw of readFileSync(file, 'utf8').split(/\r?\n/)) {
  const line = raw.trim();
  if (!line) continue;
  // Category headers have no trailing '?' and are short.
  if (!line.endsWith('?') && line.split(/\s+/).length <= 5) {
    type = typeFor(line);
    continue;
  }
  if (!type) continue;
  const row = {
    slug: `${type}-${slugify(line)}`,
    type,
    prompt: line,
    age_min: 4,
    age_max: 12,
  };
  const { error } = await admin.from('questions').upsert(row, { onConflict: 'slug' });
  if (error) throw new Error(`${row.slug}: ${error.message}`);
  byType[type] = (byType[type] || 0) + 1;
  count++;
}
console.log('seeded questions:', count, '|', JSON.stringify(byType));
