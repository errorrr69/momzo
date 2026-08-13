// Architecture rule 1 guard — features must reach the outside through services.
//
//   features/  →  services/  →  core/
//
// A screen that talks to Supabase directly bypasses the one place we can put ownership
// checks, error handling and caching, and it makes the screen impossible to test without
// a live backend. This script fails the build when a file under app/lib/features imports
// a backend client directly.
//
// KNOWN VIOLATIONS ARE ALLOWLISTED, NOT IGNORED. Three files predate this rule. They are
// listed below with what each needs, so the debt is visible and bounded. The guard fails
// if a NEW violation appears, and it also fails if an allowlisted file stops violating —
// so the list can never quietly describe a codebase that has moved on.
//
// Run:  node scripts/check_feature_imports.mjs
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const FEATURES = join(ROOT, 'app', 'lib', 'features');

// Imports a feature must not make.
const FORBIDDEN = [
  { pattern: /^\s*import\s+'package:supabase_flutter\//m, what: 'package:supabase_flutter' },
  { pattern: /^\s*import\s+'package:http\//m,             what: 'package:http' },
  { pattern: /^\s*import\s+'[^']*core\/supabase\/supabase_init\.dart'/m, what: 'the Supabase client' },
];

// Pre-existing violations. Each entry says what would retire it.
// Do not add to this list — fix the feature instead.
const ALLOWLIST = new Map([
  ['home/home_screen.dart',
    'queries users.display_name directly — move to ProfileService'],
  ['onboarding/sign_in_screen.dart',
    'imports AuthException + OAuthProvider as TYPES — AuthService should expose its own'],
  ['bonding/quiz_match_screen.dart',
    'calls supabase.removeChannel + names RealtimeChannel — QuizService should own unsubscribe'],
]);

const SELF = 'scripts/check_feature_imports.mjs';

function dartFiles(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) out.push(...dartFiles(full));
    else if (entry.endsWith('.dart')) out.push(full);
  }
  return out;
}

const violations = new Map();
for (const file of dartFiles(FEATURES)) {
  const src = readFileSync(file, 'utf8');
  const hits = FORBIDDEN.filter((f) => f.pattern.test(src)).map((f) => f.what);
  if (hits.length) violations.set(relative(FEATURES, file).split(sep).join('/'), hits);
}

const failures = [];

// 1. Anything new is a hard failure.
for (const [file, hits] of violations) {
  if (!ALLOWLIST.has(file)) {
    failures.push(`NEW violation  app/lib/features/${file}\n     imports ${hits.join(', ')}\n` +
      '     Features reach the outside through a service (architecture rule 1).');
  }
}

// 2. An allowlisted file that no longer violates means the list is stale.
for (const [file, why] of ALLOWLIST) {
  if (!violations.has(file)) {
    failures.push(`FIXED, still allowlisted  app/lib/features/${file}\n` +
      `     Was: ${why}\n     Nice — now remove it from ALLOWLIST in ${SELF}.`);
  }
}

const clean = violations.size - ALLOWLIST.size;
if (failures.length) {
  console.error('\nArchitecture rule 1 — features must not import a backend client directly\n');
  for (const f of failures) console.error(`  ✗ ${f}\n`);
  process.exit(1);
}

console.log(`rule 1 OK — ${dartFiles(FEATURES).length} feature files checked, ` +
  `${ALLOWLIST.size} known violations allowlisted, ${clean === 0 ? 'no' : clean} new.`);
for (const [file, why] of ALLOWLIST) console.log(`  · ${file} — ${why}`);
