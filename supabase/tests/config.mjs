// Loads the secrets the RLS harness needs, from the same git-ignored files the rest
// of the project uses — or from process.env when running in CI.
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_DB_PASSWORD  <- supabase/.env
//   SUPABASE_ANON_KEY                                              <- app/env.json
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

// Minimal .env parser. Honors quoted values; for unquoted values strips only a
// " #comment" (space-hash) so passwords containing '#' (e.g. M@mzo#...) survive.
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
    if (val.startsWith('"')) {
      val = val.slice(1, val.indexOf('"', 1) === -1 ? undefined : val.indexOf('"', 1));
    } else {
      val = val.split(/\s+#/)[0].trim();
    }
    out[key] = val;
  }
  return out;
}

const supaEnv = parseEnv(join(here, '..', '.env'));            // supabase/.env
let anonKey = process.env.SUPABASE_ANON_KEY;
if (!anonKey) {
  try {
    anonKey = JSON.parse(readFileSync(join(here, '..', '..', 'app', 'env.json'), 'utf8')).SUPABASE_ANON_KEY;
  } catch { /* fall through to the check below */ }
}

export const config = {
  url:        process.env.SUPABASE_URL              || supaEnv.SUPABASE_URL,
  serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY || supaEnv.SUPABASE_SERVICE_ROLE_KEY,
  dbPassword: process.env.SUPABASE_DB_PASSWORD      || supaEnv.SUPABASE_DB_PASSWORD,
  anonKey,
};

const missing = Object.entries(config).filter(([, v]) => !v).map(([k]) => k);
if (missing.length) {
  throw new Error(
    `RLS harness missing config: ${missing.join(', ')}. ` +
    `Provide via supabase/.env + app/env.json, or env vars in CI.`,
  );
}
