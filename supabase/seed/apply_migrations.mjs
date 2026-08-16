// Apply pending SQL migrations over a direct Postgres connection.
//
// `supabase db push` is still the canonical path and is what CI runs
// (.github/workflows/ci.yml). This exists because the CLI needs an access token
// and a linked project, neither of which is available on every machine — and
// because a schema change should never wait on that. It writes the same ledger
// the CLI reads (supabase_migrations.schema_migrations), so the two stay in
// sync: anything applied here is skipped by a later `db push`, and vice versa.
//
// Each file runs inside its OWN transaction. A migration that fails rolls back
// whole and is not recorded, so a partial schema can't be left behind and a
// re-run picks up exactly where it stopped.
//
// Port 5432 on the pooler is session mode. The transaction pooler (6543) is
// wrong for this: DDL and multi-statement transactions need a session.
//
// Run:  cd supabase/seed && node apply_migrations.mjs [--dry-run]
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS = join(here, '..', 'migrations');
const DRY = process.argv.includes('--dry-run');

function parseEnv(path) {
  const out = {};
  let text;
  try { text = readFileSync(path, 'utf8'); } catch { return out; }
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let val = line.slice(eq + 1).trim();
    if (val.startsWith('"')) val = val.slice(1, val.indexOf('"', 1));
    else val = val.split(/\s+#/)[0].trim();
    out[key] = val;
  }
  return out;
}

const env = parseEnv(join(here, '..', '.env'));
const URL = process.env.SUPABASE_URL || env.SUPABASE_URL;
const PASS = process.env.SUPABASE_DB_PASSWORD || env.SUPABASE_DB_PASSWORD;
const HOST = process.env.SUPABASE_POOLER_HOST || 'aws-0-us-west-1.pooler.supabase.com';
if (!URL || !PASS) throw new Error('Missing SUPABASE_URL / SUPABASE_DB_PASSWORD.');

const ref = URL.split('//')[1].split('.')[0];
const client = new pg.Client({
  connectionString: `postgresql://postgres.${ref}:${encodeURIComponent(PASS)}@${HOST}:5432/postgres`,
  ssl: { rejectUnauthorized: false },
  // A big content migration can outlast the default; the statement itself is the
  // thing worth waiting on, not the socket.
  statement_timeout: 300_000,
});

await client.connect();

const applied = new Set(
  (await client.query('select version from supabase_migrations.schema_migrations')).rows.map((r) => r.version),
);

// Filenames are <version>_<name>.sql, and version ordering IS apply ordering.
const files = readdirSync(MIGRATIONS).filter((f) => f.endsWith('.sql')).sort();
const pending = files.filter((f) => !applied.has(f.split('_')[0]));

if (!pending.length) {
  console.log(`Nothing to apply — all ${files.length} migrations are recorded.`);
  await client.end();
  process.exit(0);
}

console.log(`${applied.size} applied, ${pending.length} pending:`);
pending.forEach((f) => console.log('  ·', f));
if (DRY) { console.log('\n--dry-run: nothing was applied.'); await client.end(); process.exit(0); }

for (const file of pending) {
  const version = file.split('_')[0];
  const name = file.replace(/^\d+_/, '').replace(/\.sql$/, '');
  const sql = readFileSync(join(MIGRATIONS, file), 'utf8');

  process.stdout.write(`\napplying ${file} … `);
  try {
    await client.query('begin');
    await client.query(sql);
    await client.query(
      'insert into supabase_migrations.schema_migrations (version, name, statements) values ($1, $2, $3)',
      [version, name, [sql]],
    );
    await client.query('commit');
    console.log('ok');
  } catch (e) {
    await client.query('rollback');
    console.log('FAILED');
    console.error(`\n✗ ${file} rolled back — nothing from it was applied.`);
    console.error(`  ${e.message}`);
    if (e.position) {
      // Point at the offending line rather than making the reader count bytes.
      const upto = sql.slice(0, Number(e.position));
      console.error(`  at line ${upto.split('\n').length}: ${sql.split('\n')[upto.split('\n').length - 1]?.trim()}`);
    }
    await client.end();
    process.exit(1);
  }
}

console.log(`\n✓ applied ${pending.length} migration(s).`);
await client.end();
