// Layer 1 guard — Cost Strategy §2 ("Precomputation: audit + guard").
//
// Momzo is cheap because almost nothing calls an LLM per user. This check fails
// the build the moment a NEW LLM call site appears outside the approved list, so
// adding one is always a deliberate, reviewed decision rather than a drift.
//
// It also enforces that the entry points which may reach a model are exactly the
// approved surfaces — daily cards, activities, personalization context and any
// kind of classification must stay rule-based.
//
// Run: cd supabase/tests && npm run llm-guard      (no secrets needed)
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative, sep } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const FUNCTIONS = join(here, '..', 'functions');

// Files allowed to hold a provider key or hit a provider endpoint.
// _shared/ai.ts is the single choke-point (Hard Rule #10); generate-game-items
// keeps its own batched JSON-mode call.
const APPROVED_PROVIDER_FILES = new Set([
  '_shared/ai.ts',
  'generate-game-items/index.ts',
]);

// Functions allowed to *invoke* generation. Retrieval-only embedding is cheap and
// is covered by the same list.
const APPROVED_CALLERS = new Set([
  'ai-chat/index.ts',          // expert Q&A + situational (mode: 'situational')
  'generate-game-items/index.ts',
]);

// Signals that a file talks to a model provider directly.
const PROVIDER_PATTERNS = [
  /api\.mistral\.ai/,
  /generativelanguage\.googleapis\.com/,
  /api\.openai\.com/,
  /api\.anthropic\.com/,
  /MISTRAL_API_KEY/,
  /GOOGLE_API_KEY/,
  /OPENAI_API_KEY/,
  /ANTHROPIC_API_KEY/,
];

// Signals that a file invokes generation through the shared helper.
const CALLER_PATTERNS = [/\bmistralChat\s*\(/, /\bembedQuery\s*\(/];

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (name.endsWith('.ts')) out.push(p);
  }
  return out;
}

const files = walk(FUNCTIONS);
const problems = [];
const providerSites = [];
const callerSites = [];

for (const file of files) {
  const rel = relative(FUNCTIONS, file).split(sep).join('/');
  if (rel.endsWith('_test.ts')) continue;         // unit tests reference the helpers by name
  const src = readFileSync(file, 'utf8');

  if (PROVIDER_PATTERNS.some((re) => re.test(src))) {
    providerSites.push(rel);
    if (!APPROVED_PROVIDER_FILES.has(rel)) {
      problems.push(
        `NEW LLM PROVIDER CALL SITE: ${rel}\n` +
        `  Provider keys/endpoints belong in _shared/ai.ts. If this is intentional, add it to\n` +
        `  APPROVED_PROVIDER_FILES in this file — and say why in the commit message.`,
      );
    }
  }

  if (rel !== '_shared/ai.ts' && CALLER_PATTERNS.some((re) => re.test(src))) {
    callerSites.push(rel);
    if (!APPROVED_CALLERS.has(rel)) {
      problems.push(
        `NEW LLM CALLER: ${rel}\n` +
        `  Per-user LLM calls are the only real AI cost in Momzo (Cost Strategy §2).\n` +
        `  Daily cards, activities, personalization context and classification must stay\n` +
        `  rule-based. If this really needs a model, add it to APPROVED_CALLERS.`,
      );
    }
  }
}

// The list must not silently shrink either — an approved surface that stopped
// calling a model usually means a refactor moved the call somewhere unlisted.
for (const expected of APPROVED_PROVIDER_FILES) {
  if (!providerSites.includes(expected)) {
    problems.push(`Approved provider file no longer contains an LLM call: ${expected} (stale allowlist?)`);
  }
}

console.log('LLM provider call sites:', providerSites.join(', ') || '(none)');
console.log('LLM callers:           ', callerSites.join(', ') || '(none)');

if (problems.length) {
  console.error('\nLLM call-site guard FAILED:\n\n' + problems.join('\n\n') + '\n');
  process.exit(1);
}
console.log('\nLLM call-site guard passed — every call site is on the approved list.');
