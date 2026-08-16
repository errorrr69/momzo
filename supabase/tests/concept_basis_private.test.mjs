// concept_basis must never reach a client (00_CARD_SPEC §6).
//
// It records which established developmental concept a card teaches — "affect
// labelling", "co-regulation" — so the library can be audited. It is QA
// vocabulary, not something to show a mother reading about her five-year-old.
//
// RLS cannot enforce this: a policy chooses ROWS, never columns. The guarantee is
// a column privilege (20260816090000_daily_cards_v2.sql), which the database
// itself checks on every query. This test signs in as a real user and confirms
// the privilege is actually in force — because the migration could be reverted, a
// later `grant select on content_cards` could silently re-open it, and nothing in
// the app would look any different.
//
// Read-only apart from one throwaway auth user, which is deleted in after().
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createClient } from '@supabase/supabase-js';
import { config } from './config.mjs';

const admin = createClient(config.url, config.serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const EMAIL = `concept-basis-${Date.now()}@momzo.test`;
const PASSWORD = 'Concept-Basis-Test-123!';

let userId;
let client; // signed in as `authenticated`

before(async () => {
  const { data, error } = await admin.auth.admin.createUser({
    email: EMAIL, password: PASSWORD, email_confirm: true,
  });
  assert.equal(error, null, `create test user: ${error?.message}`);
  userId = data.user.id;

  client = createClient(config.url, config.anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error: signInError } = await client.auth.signInWithPassword({
    email: EMAIL, password: PASSWORD,
  });
  assert.equal(signInError, null, `sign in: ${signInError?.message}`);
});

after(async () => {
  if (userId) await admin.auth.admin.deleteUser(userId);
});

test('a client asking for concept_basis is refused', async () => {
  const { data, error } = await client.from('content_cards').select('id, concept_basis').limit(1);
  assert.ok(error, 'selecting concept_basis should fail, but it succeeded');
  assert.match(
    `${error.message} ${error.details ?? ''}`,
    /permission denied/i,
    `expected a permission error, got: ${error.message}`,
  );
  assert.equal(data, null);
});

test('select=* is refused rather than silently including it', async () => {
  // The important half of the guarantee. If `*` succeeded, every existing and
  // future `select('*')` in the app would ship the field without anyone noticing.
  const { error } = await client.from('content_cards').select('*').limit(1);
  assert.ok(error, 'select=* should fail while concept_basis is revoked');
  assert.match(`${error.message} ${error.details ?? ''}`, /permission denied/i);
});

test('the columns the app actually asks for still work', async () => {
  const columns =
    'id, slug, title, summary, why_it_matters, main_read, activity, ' +
    'category, subtopic, tags, age_min, age_max, source, slides';
  const { data, error } = await client.from('content_cards').select(columns).limit(3);
  assert.equal(error, null, `app column list must succeed: ${error?.message}`);
  assert.ok(data.length > 0, 'expected at least one readable card');
  for (const row of data) {
    assert.ok(!('concept_basis' in row), 'concept_basis leaked into an app response');
    assert.ok(row.title, 'card should have a title');
  }
});

test('the server can still read it — the field exists, it is just private', async () => {
  // Guards against "passing" because the column was quietly dropped instead of
  // revoked: a deleted column would satisfy every test above for the wrong reason.
  const { data, error } = await admin
    .from('content_cards').select('concept_basis').not('concept_basis', 'is', null).limit(1);
  assert.equal(error, null, `service role must still read concept_basis: ${error?.message}`);
  assert.ok(data.length === 1 && data[0].concept_basis, 'expected a stored concept_basis value');
});
