// AI memory + feedback acceptance tests.
//
// Covers the parts only the database can prove:
//   * rate_ai_answer enforces ownership even though it is SECURITY DEFINER
//   * a thumbs-down retires the cached answer behind it, for everyone
//   * a parent can never reach cached_answers directly, before or after rating
//   * the history query returns the right turns, newest-first, refer-out excluded
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

const PASSWORD = 'Ai-Memory-Test-Pass-123!';
const EMAILS = { owner: 'ai-memory-owner@momzo.test', other: 'ai-memory-other@momzo.test' };
const BUCKET = '8-10|memory-test|memory-test';
const DIM = 768;

function unit(i) {
  const v = new Array(DIM).fill(0);
  v[i] = 1;
  return `[${v.join(',')}]`;
}

const people = { owner: {}, other: {} };
let conversationId = null;

async function seedCachedAnswer() {
  const { data, error } = await admin.from('cached_answers').insert({
    question_text: 'how do i handle tantrums',
    question_embedding: unit(0),
    bucket_key: BUCKET,
    answer_text: 'Name the feeling first, then offer a simple choice.',
  }).select('id').single();
  assert.ifError(error);
  return data.id;
}

async function seedAnswer({
  cachedAnswerId = null, flagged = null, content = 'an answer',
  role = 'assistant', servedFromCache = false,
} = {}) {
  const id = randomUUID();
  const { error } = await admin.from('ai_messages').insert({
    id,
    owner_id: people.owner.id,
    conversation_id: conversationId,
    role,
    content,
    flagged,
    cached_answer_id: cachedAnswerId,
    served_from_cache: servedFromCache,
  });
  assert.ifError(error);
  return id;
}

async function cleanup() {
  await admin.from('cached_answers').delete().eq('bucket_key', BUCKET);
  const { data } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
  const emails = new Set(Object.values(EMAILS));
  for (const u of data?.users ?? []) {
    if (emails.has(u.email)) await admin.auth.admin.deleteUser(u.id);
  }
}

test.before(async () => {
  await cleanup();
  for (const key of ['owner', 'other']) {
    const { data, error } = await admin.auth.admin.createUser({
      email: EMAILS[key], password: PASSWORD, email_confirm: true,
    });
    assert.ifError(error);
    people[key].id = data.user.id;
    const { error: uErr } = await admin.from('users')
      .insert({ id: people[key].id, display_name: `Memory ${key}` });
    assert.ifError(uErr);

    const c = createClient(config.url, config.anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const si = await c.auth.signInWithPassword({ email: EMAILS[key], password: PASSWORD });
    assert.ifError(si.error);
    people[key].client = c;
  }

  const { data: conv, error: convErr } = await admin.from('ai_conversations')
    .insert({ user_id: people.owner.id, mode: 'qa' }).select('id').single();
  assert.ifError(convErr);
  conversationId = conv.id;
});

test.after(cleanup);

// --- feedback ---------------------------------------------------------------

test('a parent can rate her own answer', async () => {
  const id = await seedAnswer();
  const { error } = await people.owner.client.rpc('rate_ai_answer', {
    p_message_id: id, p_rating: 1,
  });
  assert.ifError(error);

  const { data } = await admin.from('ai_messages').select('feedback,feedback_at').eq('id', id).single();
  assert.equal(data.feedback, 1);
  assert.ok(data.feedback_at, 'feedback_at should be stamped');
});

test('another family cannot rate an answer that is not theirs', async () => {
  const id = await seedAnswer();
  const { error } = await people.other.client.rpc('rate_ai_answer', {
    p_message_id: id, p_rating: -1,
  });
  assert.ok(error, 'LEAK: a different family rated someone else’s answer');

  const { data } = await admin.from('ai_messages').select('feedback').eq('id', id).single();
  assert.equal(data.feedback, null, 'LEAK: the rating was written anyway');
});

test('the question turn cannot be rated — only an answer', async () => {
  const id = await seedAnswer({ role: 'user', content: 'my question' });
  const { error } = await people.owner.client.rpc('rate_ai_answer', {
    p_message_id: id, p_rating: 1,
  });
  assert.ok(error, 'a user turn should not be ratable');
});

test('an out-of-range rating is rejected', async () => {
  const id = await seedAnswer();
  const { error } = await people.owner.client.rpc('rate_ai_answer', {
    p_message_id: id, p_rating: 5,
  });
  assert.ok(error, 'ratings must be -1, 1 or null');
});

test('a rating can be undone', async () => {
  const id = await seedAnswer();
  await people.owner.client.rpc('rate_ai_answer', { p_message_id: id, p_rating: 1 });
  const { error } = await people.owner.client.rpc('rate_ai_answer', {
    p_message_id: id, p_rating: null,
  });
  assert.ifError(error);
  const { data } = await admin.from('ai_messages').select('feedback,feedback_at').eq('id', id).single();
  assert.equal(data.feedback, null);
  assert.equal(data.feedback_at, null);
});

// --- the loop actually closes ----------------------------------------------

test('a thumbs-down retires the cached answer behind it, for everyone', async () => {
  const cachedId = await seedCachedAnswer();
  const messageId = await seedAnswer({ cachedAnswerId: cachedId });

  const { error } = await people.owner.client.rpc('rate_ai_answer', {
    p_message_id: messageId, p_rating: -1,
  });
  assert.ifError(error);

  const { data } = await admin.from('cached_answers').select('id').eq('id', cachedId);
  assert.equal((data ?? []).length, 0, 'an unhelpful cached answer is still being served');

  // The conversation history must survive — only the shared cache entry goes.
  const { data: msg } = await admin.from('ai_messages')
    .select('id,cached_answer_id,feedback').eq('id', messageId).single();
  assert.ok(msg, 'her own message was destroyed by rating it');
  assert.equal(msg.cached_answer_id, null, 'the dangling link should be nulled, not orphaned');
  assert.equal(msg.feedback, -1);
});

test('a thumbs-up leaves the cached answer in place', async () => {
  const cachedId = await seedCachedAnswer();
  const messageId = await seedAnswer({ cachedAnswerId: cachedId });
  await people.owner.client.rpc('rate_ai_answer', { p_message_id: messageId, p_rating: 1 });

  const { data } = await admin.from('cached_answers').select('id').eq('id', cachedId);
  assert.equal((data ?? []).length, 1, 'a helpful cached answer should be kept');
});

test('rating does not hand the app any access to the cache', async () => {
  const cachedId = await seedCachedAnswer();
  const messageId = await seedAnswer({ cachedAnswerId: cachedId });
  await people.owner.client.rpc('rate_ai_answer', { p_message_id: messageId, p_rating: 1 });

  const rd = await people.owner.client.from('cached_answers').select('id').eq('id', cachedId);
  assert.equal((rd.data ?? []).length, 0, 'LEAK: the app can read the shared answer cache');
});

test('a retired cached answer is still counted as having come from the cache', async () => {
  // Regression: cached_answer_id is a live FK and is nulled when the thumbs-down
  // deletes the cached row. If the analytics split on it, every disliked cached
  // answer would silently re-file itself as "freshly generated" — biasing the
  // from_cache comparison in exactly the direction that hides a problem.
  const cachedId = await seedCachedAnswer();
  const messageId = await seedAnswer({ cachedAnswerId: cachedId, servedFromCache: true });

  await people.owner.client.rpc('rate_ai_answer', { p_message_id: messageId, p_rating: -1 });

  const { data } = await admin.from('ai_messages')
    .select('cached_answer_id,served_from_cache,feedback').eq('id', messageId).single();
  assert.equal(data.cached_answer_id, null, 'the live link should be released');
  assert.equal(data.served_from_cache, true, 'provenance must outlive the cached row');
  assert.equal(data.feedback, -1);
});

// --- conversation history ---------------------------------------------------

test('history returns the most recent turns, and excludes refer-out', async () => {
  const { data: conv } = await admin.from('ai_conversations')
    .insert({ user_id: people.owner.id, mode: 'qa' }).select('id').single();

  const rows = [
    { role: 'user', content: 'turn 1', flagged: null },
    { role: 'assistant', content: 'answer 1', flagged: null },
    { role: 'user', content: 'is he suicidal', flagged: 'safety' },
    { role: 'assistant', content: 'refer out copy', flagged: 'safety' },
    { role: 'user', content: 'turn 2', flagged: null },
    { role: 'assistant', content: 'answer 2', flagged: null },
  ];
  for (const r of rows) {
    // Sequential inserts so created_at ordering is deterministic.
    const { error } = await admin.from('ai_messages').insert({
      owner_id: people.owner.id, conversation_id: conv.id, ...r,
    });
    assert.ifError(error);
  }

  // The same shape the Edge Function's recentTurns() uses.
  const { data, error } = await admin.from('ai_messages')
    .select('role,content,flagged')
    .eq('conversation_id', conv.id)
    .order('created_at', { ascending: false })
    .limit(6);
  assert.ifError(error);

  const usable = data.filter((r) => !r.flagged).reverse();
  assert.deepEqual(usable.map((r) => r.content), ['turn 1', 'answer 1', 'turn 2', 'answer 2']);
  assert.ok(!usable.some((r) => r.content.includes('refer out')),
    'a refer-out response must never be replayed as context');
});

test('history is scoped to one conversation', async () => {
  const { data } = await admin.from('ai_messages')
    .select('conversation_id').eq('conversation_id', conversationId);
  assert.ok(data.every((r) => r.conversation_id === conversationId));
});

// --- dashboard --------------------------------------------------------------

test('the feedback view returns numbers', async () => {
  const { data, error } = await admin.from('ai_answer_feedback').select('*').limit(5);
  assert.ifError(error);
  assert.ok(Array.isArray(data));
  for (const row of data) {
    assert.ok(Number(row.answers) >= 0);
    assert.ok(Number(row.helpful_pct) >= 0 && Number(row.helpful_pct) <= 100);
    assert.ok(Number(row.cache_retirements) >= 0);
    assert.equal(typeof row.from_cache, 'boolean');
  }
});
