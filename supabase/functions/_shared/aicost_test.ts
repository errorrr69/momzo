// Unit tests for the AI cost layers (Momzo_AI_Cost_Strategy.md acceptance criteria).
// Pure logic only — no database, no network, no secrets.
//
// Run: deno test supabase/functions/_shared/
import { assert, assertAlmostEquals, assertEquals, assertNotEquals } from 'jsr:@std/assert@1';

import { buildPrompt, promptCacheKey, STATIC_PREFIX } from './prompts.ts';
import {
  BREAKER_MESSAGE, estimateCostUsd, LIMIT_MESSAGE, LIMITS, WORST_CASE_MONTHLY_USD,
} from './aicost.ts';
import { ageBand, bucketKey, isNameFree } from './semcache.ts';
import { referOutReason } from './ai.ts';

// --- §3 Layer 2: prompt caching ---------------------------------------------

Deno.test('static prefix is byte-identical across two different users', () => {
  const a = buildPrompt('qa', 'Child: age 5.\nWorking on: sleep.', 'excerpt A', 'why wont he sleep');
  const b = buildPrompt('qa', 'Child: age 9.\nWorking on: big feelings.', 'excerpt B', 'how do i handle tantrums');
  assertEquals(a.messages[0].content, b.messages[0].content);
  assertEquals(a.messages[0].content, STATIC_PREFIX.qa);
  assertEquals(a.cacheKey, b.cacheKey);
  // ...and everything per-user really is below the boundary.
  assertNotEquals(a.messages[1].content, b.messages[1].content);
});

Deno.test('no per-user value can appear in the static prefix', () => {
  for (const prefix of Object.values(STATIC_PREFIX)) {
    // A concrete age is the classic cache-killer: it makes the prefix unique per
    // family and destroys the hit rate for everyone.
    assert(!/\b(?:[4-9]|10)[-\s]year[-\s]old\b/.test(prefix), 'prefix contains a concrete age');
    assert(!/\bage\s+\d/i.test(prefix), 'prefix contains a concrete age');
    // Templating is how a per-user value sneaks in — there must be none left.
    assert(!/\$\{|\{\{|%s\b/.test(prefix), 'prefix still contains a template placeholder');
    assert(prefix.length > 600, 'prefix is too short to be worth caching (Mistral caches in 64-token blocks)');
  }
});

Deno.test('prefix is long enough and the personalization context stays below the boundary', () => {
  const ctx = 'Child: age 7.\nTricky right now: bedtime.';
  const { messages } = buildPrompt('situational', ctx, 'excerpt', 'he is melting down');
  assert(!messages[0].content.includes('age 7'));
  assert(messages[1].content.includes(ctx));
  assert(messages[1].content.includes('he is melting down'));
});

Deno.test('cache key is stable and per-mode', () => {
  assertEquals(promptCacheKey('qa'), promptCacheKey('qa'));
  assertNotEquals(promptCacheKey('qa'), promptCacheKey('situational'));
});

// --- §1 cost model ----------------------------------------------------------

Deno.test('a small turn costs about the modelled $0.000275', () => {
  assertAlmostEquals(estimateCostUsd('mistral-small-latest', 2000, 250, 0), 0.000275, 1e-9);
});

Deno.test('a medium turn costs about the modelled $0.0013', () => {
  assertAlmostEquals(estimateCostUsd('mistral-medium-latest', 2000, 250, 0), 0.0013, 1e-9);
});

Deno.test('the blended per-turn cost is under the $0.0005 target', () => {
  const small = estimateCostUsd('mistral-small-latest', 2000, 250, 0);
  const medium = estimateCostUsd('mistral-medium-latest', 2000, 250, 0);
  const blended = 0.9 * small + 0.1 * medium;
  assert(blended <= 0.0005, `blended turn cost ${blended} exceeds the $0.0005 target`);
});

Deno.test('an average active user costs well under the $0.05/month target', () => {
  // §1's model: ~43 turns a month, 90/10 small/medium.
  const blended = 0.9 * estimateCostUsd('mistral-small-latest', 2000, 250, 0)
    + 0.1 * estimateCostUsd('mistral-medium-latest', 2000, 250, 0);
  assert(blended * 43 <= 0.05, `per-user monthly ${blended * 43} exceeds the $0.05 target`);
});

Deno.test('worst case a single user can reach under the limits does not drift', () => {
  // Realistic routing: situational never escalates, Q&A escalates at the 10%
  // target rate. See WORST_CASE_MONTHLY_USD for why this exceeds §1's $0.30.
  const qaTurn = 0.9 * estimateCostUsd('mistral-small-latest', 2000, 450, 0)
    + 0.1 * estimateCostUsd('mistral-medium-latest', 2000, 450, 0);
  const sitTurn = estimateCostUsd('mistral-small-latest', 2000, 280, 0);
  const monthly = (LIMITS.qa * qaTurn + LIMITS.situational * sitTurn) * 30;
  assert(
    monthly <= WORST_CASE_MONTHLY_USD,
    `worst-case monthly ${monthly} exceeds the recorded ceiling ${WORST_CASE_MONTHLY_USD}`,
  );
});

Deno.test('cached prefix tokens bill at a tenth of the input rate', () => {
  const uncached = estimateCostUsd('mistral-small-latest', 2000, 250, 0);
  const cached = estimateCostUsd('mistral-small-latest', 2000, 250, 1600);
  assert(cached < uncached);
  // 1600 cached input tokens save 90% of their input cost.
  assertAlmostEquals(uncached - cached, 1600 * 0.10 * 0.9 / 1e6, 1e-12);
});

Deno.test('free paths cost nothing', () => {
  assertEquals(estimateCostUsd(null, 0, 0, 0), 0);
});

// --- §4 Layer 3: rate limiting ----------------------------------------------

Deno.test('limits match the strategy table', () => {
  assertEquals(LIMITS.qa, 30);
  assertEquals(LIMITS.situational, 15);
  assertEquals(LIMITS.game_items, 5);
});

Deno.test('limit copy is warm — no shame, no counters, no cost language', () => {
  const banned = [
    /exceed/i, /limit/i, /quota/i, /too many/i, /cost/i, /pay/i, /upgrade/i,
    /\d+\s*(of|\/)\s*\d+/, /usage/i, /throttl/i, /error/i,
  ];
  for (const [mode, copy] of Object.entries(LIMIT_MESSAGE)) {
    for (const re of banned) {
      assert(!re.test(copy), `${mode} limit copy matches banned pattern ${re}: "${copy}"`);
    }
  }
  for (const re of banned) {
    assert(!re.test(BREAKER_MESSAGE), `breaker copy matches banned pattern ${re}`);
  }
});

// --- §4 non-negotiable: safety is never traded for cost ---------------------

Deno.test('the refer-out screen is pure and cheap — it needs no quota, DB or network', () => {
  // If this ever required IO it could no longer be guaranteed to run BEFORE the
  // rate-limit check, which is the property that keeps a mother from hitting a
  // cost-shaped wall in a hard moment.
  assertEquals(referOutReason('he keeps talking about wanting to die'), 'safety');
  assertEquals(referOutReason('she swallowed a battery'), 'medical');
  assertEquals(referOutReason('should i be worried that he is autistic'), 'developmental');
  assertEquals(referOutReason('how do i handle tantrums at bedtime'), null);
});

// --- §5 Layer 4: semantic answer cache --------------------------------------

Deno.test('age bands are the coarse 4-5 / 6-7 / 8-10 buckets', () => {
  assertEquals(ageBand(4), '4-5');
  assertEquals(ageBand(5), '4-5');
  assertEquals(ageBand(6), '6-7');
  assertEquals(ageBand(7), '6-7');
  assertEquals(ageBand(8), '8-10');
  assertEquals(ageBand(10), '8-10');
});

Deno.test('bucket separates children the same answer would not fit', () => {
  const anxious8 = bucketKey(8, ['big feelings'], ['worries a lot']);
  const boisterous5 = bucketKey(5, ['big feelings'], ['worries a lot']);
  assertNotEquals(anxious8, boisterous5);
  // Same shape of child -> same bucket, so the cache can actually hit.
  assertEquals(bucketKey(9, ['Big Feelings'], ['Worries a lot']), anxious8);
});

Deno.test('bucket key carries no free text or identifier', () => {
  const k = bucketKey(6, ['confidence & self-esteem'], ["won't listen"]);
  assertEquals(k, '6-7|confidence-self-esteem|won-t-listen');
  assert(!/\s/.test(k));
});

Deno.test('missing profile fields still produce a stable bucket', () => {
  assertEquals(bucketKey(4, [], []), '4-5|none|none');
});

Deno.test('an answer containing the child name is never cacheable', () => {
  assert(!isNameFree('Try giving Mia a two-minute warning.', 'Mia'));
  assert(!isNameFree('try giving mia a warning', 'Mia'));
  assert(isNameFree('Try giving your child a two-minute warning.', 'Mia'));
  // Substring matches must not false-positive a common word out of existence.
  assert(isNameFree('Amiable mornings help.', 'Mia'));
  assert(isNameFree('anything at all', null));
});
