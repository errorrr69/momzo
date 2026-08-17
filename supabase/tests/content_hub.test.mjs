// Content Hub — the guarantees the RLS harness does not cover (Expansion Plan §1).
//
// rls_cross_family.test.mjs already proves the shape: social_posts is shared-read
// and never client-writable, post_reactions is isolated per user. This file covers
// the two things specific to the feature:
//
//   1. An UNPUBLISHED post is invisible. The read policy is `using (published)`,
//      so a draft is not merely hidden by a client filter that could be forgotten.
//   2. A 💛 cannot be double-counted. The guarantee is a unique constraint, not
//      client discipline — a double tap, an offline retry, or a second device must
//      not be able to produce two rows.
//
// Read-only apart from one throwaway post and one throwaway auth user, both
// removed in after().
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { config } from './config.mjs';

const admin = createClient(config.url, config.serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const EMAIL = `content-hub-${Date.now()}@momzo.test`;
const PASSWORD = 'Content-Hub-Test-123!';

const PUBLISHED_ID = randomUUID();
const DRAFT_ID = randomUUID();

let userId;
let client; // signed in as `authenticated`

before(async () => {
  const { data, error } = await admin.auth.admin.createUser({
    email: EMAIL, password: PASSWORD, email_confirm: true,
  });
  assert.equal(error, null, `create test user: ${error?.message}`);
  userId = data.user.id;
  // The app's own users row, which post_reactions.user_id references.
  await admin.from('users').insert({ id: userId, display_name: 'Content Hub Test' });

  const { error: seedErr } = await admin.from('social_posts').insert([
    {
      id: PUBLISHED_ID, slug: `hub-test-live-${Date.now()}`,
      title: 'A published post', body: 'one\n\n---\n\ntwo',
      post_type: 'carousel', tags: ['big-feelings'], published: true,
    },
    {
      // Same keys as the row above on purpose: PostgREST unions the columns across
      // a batch insert and sends an explicit null for any key a row omits, which
      // overrides the column default and trips the not-null constraint.
      id: DRAFT_ID, slug: `hub-test-draft-${Date.now()}`,
      title: 'A draft nobody should see', body: 'secret',
      post_type: 'tip', tags: [], published: false,
    },
  ]);
  assert.equal(seedErr, null, `seed posts: ${seedErr?.message}`);

  client = createClient(config.url, config.anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error: signInError } = await client.auth.signInWithPassword({
    email: EMAIL, password: PASSWORD,
  });
  assert.equal(signInError, null, `sign in: ${signInError?.message}`);
});

after(async () => {
  await admin.from('social_posts').delete().in('id', [PUBLISHED_ID, DRAFT_ID]);
  if (userId) await admin.auth.admin.deleteUser(userId);
});

test('a published post is readable by any signed-in parent', async () => {
  const { data, error } = await client
    .from('social_posts')
    .select('id, slug, title, body, post_type, tags, published_at')
    .eq('id', PUBLISHED_ID)
    .maybeSingle();
  assert.equal(error, null, `read published: ${error?.message}`);
  assert.ok(data, 'expected the published post to be readable');
  assert.equal(data.title, 'A published post');
});

test('an unpublished draft is invisible, by policy and not by client filter', async () => {
  const { data, error } = await client
    .from('social_posts').select('id').eq('id', DRAFT_ID).maybeSingle();
  assert.equal(error, null);
  assert.equal(data, null, 'a draft leaked to a signed-in parent');

  // And it is absent from an unfiltered feed query too — the policy, not the query,
  // is what withholds it.
  const { data: feed } = await client.from('social_posts').select('id');
  assert.ok(!feed.some((r) => r.id === DRAFT_ID), 'draft appeared in the feed');
});

test('a 💛 records once, and a second one is refused by the database', async () => {
  const first = await client
    .from('post_reactions').insert({ post_id: PUBLISHED_ID, user_id: userId });
  assert.equal(first.error, null, `first heart: ${first.error?.message}`);

  const second = await client
    .from('post_reactions').insert({ post_id: PUBLISHED_ID, user_id: userId });
  assert.ok(second.error, 'a second heart should be refused, not silently duplicated');
  assert.equal(second.error.code, '23505', `expected a unique violation, got ${second.error.code}`);

  // The count is what actually matters: exactly one row, whatever the client did.
  const { count } = await admin
    .from('post_reactions')
    .select('*', { count: 'exact', head: true })
    .eq('post_id', PUBLISHED_ID);
  assert.equal(count, 1, 'expected exactly one reaction row');
});

test('un-hearting removes it, and it can be hearted again', async () => {
  const del = await client
    .from('post_reactions').delete().eq('post_id', PUBLISHED_ID).eq('user_id', userId);
  assert.equal(del.error, null, `remove heart: ${del.error?.message}`);

  const { count: gone } = await admin
    .from('post_reactions').select('*', { count: 'exact', head: true })
    .eq('post_id', PUBLISHED_ID);
  assert.equal(gone, 0, 'heart should be gone');

  const again = await client
    .from('post_reactions').insert({ post_id: PUBLISHED_ID, user_id: userId });
  assert.equal(again.error, null, `re-heart should be allowed: ${again.error?.message}`);
});

test('a parent cannot heart on behalf of somebody else', async () => {
  const { error } = await client
    .from('post_reactions')
    .insert({ post_id: PUBLISHED_ID, user_id: randomUUID() });
  assert.ok(error, 'inserting a reaction for another user should be refused');
});

test('deleting a post takes its hearts with it', async () => {
  const scratchId = randomUUID();
  await admin.from('social_posts').insert({
    id: scratchId, slug: `hub-test-cascade-${Date.now()}`,
    title: 'Cascade', body: 'x', published: true,
  });
  await client.from('post_reactions').insert({ post_id: scratchId, user_id: userId });

  await admin.from('social_posts').delete().eq('id', scratchId);

  const { count } = await admin
    .from('post_reactions').select('*', { count: 'exact', head: true })
    .eq('post_id', scratchId);
  assert.equal(count, 0, 'reactions should cascade with the post');
});
