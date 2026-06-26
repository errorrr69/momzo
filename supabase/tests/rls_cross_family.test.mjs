// RLS cross-family isolation harness — Hard Rule #20.
//
// Proves that an authenticated parent can NEVER read or write another family's rows,
// across every family-data table, by driving the same PostgREST + RLS path the Flutter
// app uses (anon key + a real signed-in JWT). A coverage guard fails the build if a new
// table with owner_id/user_id is added without a test here.
//
// Run:  cd supabase/tests && npm install && npm test
import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import pg from 'pg';
import { config } from './config.mjs';

const ref = config.url.match(/https:\/\/([^.]+)\./)[1];
const POOLER_HOST = process.env.SUPABASE_POOLER_HOST || 'aws-1-us-west-1.pooler.supabase.com';
const PASSWORD = 'Rls-Test-Pass-123!';

// Service-role client: bypasses RLS, used only to seed/clean and to confirm rows survive
// a cross-family delete attempt. The app NEVER holds this key (Build Guide §5).
const admin = createClient(config.url, config.serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// Deterministic global reference rows (shared content) so re-runs clean up cleanly.
const g = {
  cardId:     '00000000-0000-4000-8000-000000000001',
  activityId: '00000000-0000-4000-8000-000000000002',
  questionId: '00000000-0000-4000-8000-000000000003',
};

// Every family-scoped table, and how this harness addresses each family's row.
// (users is keyed by the parent's own id; the rest by a seeded row id.)
const TABLES = [
  'users', 'consents', 'children', 'daily_assignments', 'activity_logs',
  'ai_conversations', 'ai_messages', 'ai_usage', 'question_responses', 'wishes',
  'scheduled_events', 'reminders', 'milestones', 'family_members', 'device_tokens',
];

const families = {
  A: { email: 'rls-test-a@momzo.test' },
  B: { email: 'rls-test-b@momzo.test' },
};

async function ins(table, row) {
  const { error } = await admin.from(table).insert(row);
  if (error) throw new Error(`seed ${table} failed: ${error.message}`);
}

async function seedFamily(key) {
  const f = families[key];
  const owner = f.id;
  const childId = randomUUID();
  f.rows = {
    users: owner,
    consents: randomUUID(),
    children: childId,
    daily_assignments: randomUUID(),
    activity_logs: randomUUID(),
    ai_conversations: randomUUID(),
    ai_messages: randomUUID(),
    ai_usage: randomUUID(),
    question_responses: randomUUID(),
    wishes: randomUUID(),
    scheduled_events: randomUUID(),
    reminders: randomUUID(),
    milestones: randomUUID(),
    family_members: randomUUID(),
    device_tokens: randomUUID(),
  };
  const now = new Date().toISOString();
  await ins('users', { id: owner, display_name: `Parent ${key}` });
  // Consent must exist before a child can be created (children_require_consent trigger).
  await ins('consents', { id: f.rows.consents, user_id: owner, policy_version: 'test', method: 'parent_attestation' });
  await ins('children', { id: childId, owner_id: owner, name: `Kid ${key}`, age: 8 });
  await ins('daily_assignments', { id: f.rows.daily_assignments, owner_id: owner, child_id: childId, card_id: g.cardId, date: '2026-06-24' });
  await ins('activity_logs', { id: f.rows.activity_logs, owner_id: owner, child_id: childId, activity_id: g.activityId, user_id: owner });
  await ins('ai_conversations', { id: f.rows.ai_conversations, user_id: owner, mode: 'qa' });
  await ins('ai_messages', { id: f.rows.ai_messages, owner_id: owner, conversation_id: f.rows.ai_conversations, role: 'user', content: 'hi' });
  await ins('ai_usage', { id: f.rows.ai_usage, owner_id: owner, conversation_id: f.rows.ai_conversations, mode: 'qa', model: 'mistral-small-latest' });
  await ins('question_responses', { id: f.rows.question_responses, owner_id: owner, question_id: g.questionId, child_id: childId, respondent: 'parent', answer: { v: 'yes' } });
  await ins('wishes', { id: f.rows.wishes, owner_id: owner, child_id: childId, text: 'play' });
  await ins('scheduled_events', { id: f.rows.scheduled_events, owner_id: owner, child_id: childId, title: 'Park', starts_at: now });
  await ins('reminders', { id: f.rows.reminders, user_id: owner, type: 'nudge', channel: 'push', send_at: now });
  await ins('milestones', { id: f.rows.milestones, owner_id: owner, child_id: childId, title: 'First' });
  await ins('family_members', { id: f.rows.family_members, child_id: childId, user_id: owner, relationship: 'parent', status: 'active' });
  await ins('device_tokens', { id: f.rows.device_tokens, user_id: owner, token: `tok-${key}-${owner}`, platform: 'android' });
}

async function deleteTestUsers() {
  const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
  if (error) throw new Error(`listUsers failed: ${error.message}`);
  const emails = new Set(Object.values(families).map((f) => f.email));
  for (const u of data.users) {
    if (emails.has(u.email)) await admin.auth.admin.deleteUser(u.id); // cascades all family rows
  }
}

async function deleteGlobals() {
  await admin.from('content_cards').delete().eq('id', g.cardId);
  await admin.from('activities').delete().eq('id', g.activityId);
  await admin.from('questions').delete().eq('id', g.questionId);
}

test.before(async () => {
  // Clean any leftovers from a previous/aborted run, then seed fresh.
  await deleteTestUsers();
  await deleteGlobals();

  await ins('content_cards', { id: g.cardId, title: 'Card', body: 'b', published: true });
  await ins('activities', { id: g.activityId, title: 'Activity' });
  await ins('questions', { id: g.questionId, type: 'daily', prompt: 'Q?' });

  for (const key of Object.keys(families)) {
    const { data, error } = await admin.auth.admin.createUser({
      email: families[key].email, password: PASSWORD, email_confirm: true,
    });
    if (error) throw new Error(`createUser ${key} failed: ${error.message}`);
    families[key].id = data.user.id;
  }
  await seedFamily('A');
  await seedFamily('B');

  for (const key of Object.keys(families)) {
    const c = createClient(config.url, config.anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { error } = await c.auth.signInWithPassword({ email: families[key].email, password: PASSWORD });
    if (error) throw new Error(`signIn ${key} failed: ${error.message}`);
    families[key].client = c;
  }
});

test.after(async () => {
  await deleteTestUsers();
  await deleteGlobals();
});

// One isolation test per family table, run from BOTH directions (A↔B).
for (const table of TABLES) {
  test(`${table}: no cross-family read/update/delete`, async () => {
    for (const [self, other] of [['A', 'B'], ['B', 'A']]) {
      const client = families[self].client;
      const ownId = families[self].rows[table];
      const otherId = families[other].rows[table];

      // Positive control: the policy is not just deny-all — self can read its own row.
      const own = await client.from(table).select('id').eq('id', ownId);
      assert.ifError(own.error);
      assert.equal(own.data.length, 1, `${self} should be able to read its OWN ${table} row`);

      // SELECT must not leak the other family's row.
      const rd = await client.from(table).select('id').eq('id', otherId);
      assert.ifError(rd.error);
      assert.equal(rd.data.length, 0, `LEAK: ${self} read ${other}'s ${table} row`);

      // UPDATE must affect zero rows.
      const up = await client.from(table).update({ updated_at: new Date().toISOString() }).eq('id', otherId).select('id');
      assert.equal((up.data || []).length, 0, `LEAK: ${self} updated ${other}'s ${table} row`);

      // DELETE must affect zero rows...
      const del = await client.from(table).delete().eq('id', otherId).select('id');
      assert.equal((del.data || []).length, 0, `LEAK: ${self} deleted ${other}'s ${table} row`);

      // ...and the row must still exist (confirmed via service role).
      const still = await admin.from(table).select('id').eq('id', otherId);
      assert.equal(still.data.length, 1, `LEAK: ${other}'s ${table} row was destroyed by ${self}`);
    }
  });
}

// Multi-child isolation (Task 23): a parent can own >1 child; the second child must
// follow the same owner-scoped RLS — visible to its parent, invisible to other families.
test('multi-child: a parent sees all their own children; another family sees none', async () => {
  const extraId = randomUUID();
  await ins('children', { id: extraId, owner_id: families.A.id, name: 'Kid A2', age: 9 });

  const mine = await families.A.client.from('children').select('id').eq('owner_id', families.A.id);
  assert.ifError(mine.error);
  assert.ok(mine.data.length >= 2, `family A should see >=2 of its own children, saw ${mine.data.length}`);

  const theirs = await families.B.client.from('children').select('id').in('id', [families.A.rows.children, extraId]);
  assert.ifError(theirs.error);
  assert.equal(theirs.data.length, 0, 'LEAK: family B can see family A children');
});

// Coverage guard: any public table with an owner_id/user_id column must be tested above.
test('coverage: every family table is covered by an RLS test', async () => {
  const client = new pg.Client({
    connectionString: `postgresql://postgres.${ref}:${encodeURIComponent(config.dbPassword)}@${POOLER_HOST}:6543/postgres`,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();
  const res = await client.query(`
    select distinct c.relname as t
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid
    where n.nspname = 'public' and c.relkind = 'r'
      and a.attname in ('owner_id','user_id') and not a.attisdropped
    order by 1;`);
  await client.end();

  const tested = new Set(TABLES);
  const uncovered = res.rows.map((r) => r.t).filter((t) => !tested.has(t));
  assert.equal(uncovered.length, 0,
    `Untested family tables (have owner_id/user_id but no RLS test): ${uncovered.join(', ')}`);
});
