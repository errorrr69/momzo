// AI cost & scaling acceptance tests — Momzo_AI_Cost_Strategy.md §4, §5, §8.
//
// The pure logic (prompt prefix, cost math, buckets, warm copy) is covered by
// supabase/functions/_shared/aicost_test.ts. This file covers the parts that only
// the database can prove:
//
//   §5  the semantic cache is bucket-isolated, threshold-gated, TTL'd, and purged
//       when a cited card changes — and is invisible to the app
//   §4  the rate-limit counter counts billable turns only
//   §8  the telemetry table cannot hold PII, and the cost views return real numbers
//
// Run: cd supabase/tests && npm test
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { config } from './config.mjs';

const admin = createClient(config.url, config.serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const PASSWORD = 'Ai-Cost-Test-Pass-123!';
const TEST_EMAIL = 'ai-cost-test@momzo.test';

// Deterministic ids so an aborted run cleans up on the next one.
const CARD_ID = '00000000-0000-4000-8000-0000000000c1';
const BUCKET_A = '8-10|big-feelings|worries-a-lot';
const BUCKET_B = '4-5|big-feelings|worries-a-lot';

const DIM = 768;

// Unit vectors, so cosine similarity is predictable.
function unit(values) {
  const v = new Array(DIM).fill(0);
  for (const [i, x] of Object.entries(values)) v[Number(i)] = x;
  const n = Math.hypot(...v);
  return `[${v.map((x) => x / n).join(',')}]`;
}
const VEC_Q = unit({ 0: 1 });               // the canonical question
const VEC_NEAR = unit({ 0: 1, 1: 0.05 });   // ~0.9988 similar — inside the 0.95 threshold
const VEC_FAR = unit({ 1: 1 });             // orthogonal — 0.0 similar

let testUser = null;
let authed = null;
const cachedIds = [];

async function seedCached({ bucket = BUCKET_A, embedding = VEC_Q, cited = [], expiresAt = null } = {}) {
  const id = randomUUID();
  const row = {
    id,
    question_text: 'how do i handle tantrums',
    question_embedding: embedding,
    bucket_key: bucket,
    answer_text: 'Name the feeling first, then offer a simple choice. It usually passes faster than it feels.',
    cited_card_ids: cited,
  };
  if (expiresAt) row.expires_at = expiresAt;
  const { error } = await admin.from('cached_answers').insert(row);
  assert.ifError(error);
  cachedIds.push(id);
  return id;
}

// Each cache test starts from an empty cache: a leftover live row from the
// previous test would mask exactly the misses we are trying to prove.
async function clearCache() {
  await admin.from('cached_answers').delete().in('bucket_key', [BUCKET_A, BUCKET_B]);
}

async function matchCached(embedding, bucket, threshold = 0.95) {
  const { data, error } = await admin.rpc('match_cached_answer', {
    query_embedding: embedding, bucket, min_similarity: threshold,
  });
  assert.ifError(error);
  return data ?? [];
}

async function cleanup() {
  await admin.from('cached_answers').delete().in('bucket_key', [BUCKET_A, BUCKET_B]);
  await admin.from('content_cards').delete().eq('id', CARD_ID);
  const { data } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
  for (const u of data?.users ?? []) {
    if (u.email === TEST_EMAIL) await admin.auth.admin.deleteUser(u.id);
  }
}

test.before(async () => {
  await cleanup();
  const { error: cardErr } = await admin.from('content_cards')
    .insert({ id: CARD_ID, title: 'Tantrums', body: 'body', published: true });
  assert.ifError(cardErr);

  const { data, error } = await admin.auth.admin.createUser({
    email: TEST_EMAIL, password: PASSWORD, email_confirm: true,
  });
  assert.ifError(error);
  testUser = data.user.id;
  // ai_usage.owner_id references public.users, not auth.users.
  const { error: userErr } = await admin.from('users')
    .insert({ id: testUser, display_name: 'AI cost test' });
  assert.ifError(userErr);

  authed = createClient(config.url, config.anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const signIn = await authed.auth.signInWithPassword({ email: TEST_EMAIL, password: PASSWORD });
  assert.ifError(signIn.error);
});

test.after(cleanup);

// --- §5 semantic answer cache ----------------------------------------------

test('a near-identical question in the same bucket is served from cache', async () => {
  await clearCache();
  const id = await seedCached();
  const hits = await matchCached(VEC_NEAR, BUCKET_A);
  assert.equal(hits.length, 1, 'expected a cache hit for a near-identical question');
  assert.equal(hits[0].id, id);
  assert.ok(hits[0].similarity >= 0.95);
});

test('the SAME question from a DIFFERENT bucket does not hit the cache', async () => {
  await clearCache();
  await seedCached();
  // Identical embedding, different age band — an answer for an 8-year-old must
  // never reach the parent of a 4-year-old.
  const hits = await matchCached(VEC_Q, BUCKET_B);
  assert.equal(hits.length, 0, 'LEAK: a cached answer crossed personalization buckets');
});

test('a merely-related question does not hit at the strict 0.95 threshold', async () => {
  await clearCache();
  await seedCached();
  const hits = await matchCached(VEC_FAR, BUCKET_A);
  assert.equal(hits.length, 0, 'threshold is too loose — an unrelated question hit the cache');
});

test('an expired answer is never served', async () => {
  await clearCache();
  await seedCached({ expiresAt: new Date(Date.now() - 60_000).toISOString() });
  const hits = await matchCached(VEC_Q, BUCKET_A);
  assert.equal(hits.length, 0, 'an expired cached answer was served');
});

test('editing a cited content card purges the answers grounded in it', async () => {
  await clearCache();
  const id = await seedCached({ cited: [CARD_ID] });
  const { error } = await admin.from('content_cards')
    .update({ body: 'revised guidance' }).eq('id', CARD_ID);
  assert.ifError(error);
  const { data } = await admin.from('cached_answers').select('id').eq('id', id);
  assert.equal((data ?? []).length, 0, 'a cached answer survived a change to the card it cites');
});

test('cached answers are invisible to a signed-in parent', async () => {
  await clearCache();
  await seedCached();
  const rd = await authed.from('cached_answers').select('id');
  // Either an explicit denial or an empty set is acceptable; a row is not.
  assert.equal((rd.data ?? []).length, 0, 'LEAK: the app can read the global answer cache');
  const wr = await authed.from('cached_answers')
    .insert({ question_text: 'x', question_embedding: VEC_Q, bucket_key: BUCKET_A, answer_text: 'x' })
    .select('id');
  assert.equal((wr.data ?? []).length, 0, 'LEAK: the app can write to the global answer cache');

  // ...and it cannot reach the cache through the lookup function either.
  const rpc = await authed.rpc('match_cached_answer', {
    query_embedding: VEC_Q, bucket: BUCKET_A, min_similarity: 0.95,
  });
  assert.equal((rpc.data ?? []).length, 0, 'LEAK: the app can query the answer cache via RPC');
});

// --- §4 rate limiting -------------------------------------------------------

test('the rate-limit counter counts billable turns only', async () => {
  const mode = 'qa';
  // Every key is spelled out on every row: a bulk PostgREST insert normalizes
  // columns across rows and would send NULL, not the column default, for any key
  // missing from one of them.
  const mk = (extra) => ({
    owner_id: testUser, mode, model: 'mistral-small-latest', billable: true,
    refer_out: false, rate_limited: false, semantic_cache_hit: false,
    prompt_tokens: 100, completion_tokens: 50, ...extra,
  });
  const { error } = await admin.from('ai_usage').insert([
    mk({}),                                                     // billable
    mk({}),                                                     // billable
    mk({ model: null, billable: false, refer_out: true }),      // safety — must not count
    mk({ model: null, billable: false, rate_limited: true }),   // a previous limit response
    mk({ model: null, billable: false, semantic_cache_hit: true }), // free
  ]);
  assert.ifError(error);

  const billable = await admin.from('ai_usage')
    .select('id', { count: 'exact', head: true })
    .eq('owner_id', testUser).eq('mode', mode).eq('billable', true);
  assert.ifError(billable.error);
  assert.equal(billable.count, 2, 'free paths must not count against a parent’s limit');

  await admin.from('ai_usage').delete().eq('owner_id', testUser);
});

// --- §8 telemetry -----------------------------------------------------------

test('the AI request log has nowhere to put PII', async () => {
  // The guarantee is structural, not procedural: the columns that could hold a
  // question, an answer or a child's name do not exist, so no future edit can
  // quietly start writing them. Every text column that does exist is a fixed
  // vocabulary (mode / model / source / breaker_state).
  for (const column of ['question_text', 'answer_text', 'content', 'child_name', 'child_id', 'text']) {
    const probe = await admin.from('ai_usage').insert({
      owner_id: testUser, mode: 'qa', model: 'mistral-small-latest',
      [column]: 'my child Mia wont sleep',
    });
    assert.ok(probe.error, `ai_usage has a "${column}" column — telemetry must stay PII-free`);
  }
  await admin.from('ai_usage').delete().eq('owner_id', testUser);
});

test('the cost views return numbers', async () => {
  const { error } = await admin.from('ai_usage').insert({
    owner_id: testUser, mode: 'qa', model: 'mistral-small-latest',
    prompt_tokens: 2000, completion_tokens: 250, cached_tokens: 800,
    prompt_cache_hit: true, estimated_cost_usd: 0.000203,
  });
  assert.ifError(error);

  for (const view of ['ai_cost_summary', 'ai_cost_per_active_user', 'ai_daily_spend', 'ai_efficiency', 'ai_top_users', 'ai_spend_24h']) {
    const { data, error: e } = await admin.from(view).select('*').limit(1);
    assert.ifError(e, `view ${view} failed`);
    assert.ok(Array.isArray(data), `view ${view} returned nothing usable`);
  }

  const { data: perUser } = await admin.from('ai_cost_per_active_user').select('*').limit(1);
  assert.ok(Number(perUser[0].cost_per_active_user_usd) >= 0);

  await admin.from('ai_usage').delete().eq('owner_id', testUser);
});
