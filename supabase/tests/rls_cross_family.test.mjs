// RLS isolation harness — Hard Rule #20, architecture rules 4 and 5.
//
// Drives the same PostgREST + RLS path the Flutter app uses (anon key + a real signed-in
// JWT) and proves two different properties, because Momzo now has two RLS patterns:
//
//   FAMILY-ISOLATED  an authenticated parent can NEVER read or write another family's
//                    rows. One test per table, run from both directions.
//   SHARED-CONTENT   any authenticated user may READ, but may never INSERT, UPDATE or
//                    DELETE. These are the negative tests architecture rule 5 requires.
//   SERVER-ONLY      RLS enabled with NO policy at all — invisible to any client,
//                    reachable only by the service role inside an Edge Function.
//
// The coverage guard at the bottom is the important part: it requires EVERY table in
// `public` to be classified into one of those three buckets and to have RLS enabled.
// A new table cannot ship untested, and it cannot ship unclassified.
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
  gameItemId: '00000000-0000-4000-8000-000000000004',
  gameSlug:   'rls-test-game',
};

// ─── Bucket 1: family-isolated ────────────────────────────────────────────────
// Every family-scoped table, and how this harness addresses each family's row.
// (users is keyed by the parent's own id; the rest by a seeded row id.)
//
// NOTE for future tables: membership here is NOT inferred from column names. A forum
// table keyed on `author_id` is still family-authored content and must be declared
// somewhere — see SHARED_TABLES. The coverage guard enforces that nothing is missed.
const FAMILY_TABLES = [
  'users', 'consents', 'children', 'daily_assignments', 'activity_logs',
  'ai_conversations', 'ai_messages', 'ai_usage', 'question_responses', 'wishes',
  'scheduled_events', 'reminders', 'milestones', 'family_members', 'device_tokens',
  'saved_cards', 'game_play_history', 'onboarding_state',
];

// ─── Bucket 2: shared-content ─────────────────────────────────────────────────
// Readable by any authenticated user; never client-writable. Seeded by the service
// role in test.before, so `read` addresses a row that is guaranteed to exist.
//   key   — the primary key column (games is keyed by slug, not id)
//   read  — the seeded row this user is allowed to SELECT
//   write — a fresh row an authenticated user must NOT be able to INSERT
//   patch — an UPDATE an authenticated user must NOT be able to apply
const SHARED_TABLES = [
  { table: 'content_cards', key: 'id',   read: () => g.cardId,
    write: () => ({ id: randomUUID(), title: 'Nope', body: 'x', published: true }),
    patch: { title: 'HACKED' } },
  { table: 'activities',    key: 'id',   read: () => g.activityId,
    write: () => ({ id: randomUUID(), title: 'Nope' }),
    patch: { title: 'HACKED' } },
  { table: 'questions',     key: 'id',   read: () => g.questionId,
    write: () => ({ id: randomUUID(), type: 'daily', prompt: 'Nope?' }),
    patch: { prompt: 'HACKED' } },
  { table: 'games',         key: 'slug', read: () => g.gameSlug,
    write: () => ({ slug: `rls-nope-${randomUUID().slice(0, 8)}`, title: 'Nope', type: 'question' }),
    patch: { title: 'HACKED' } },
  { table: 'game_items',    key: 'id',   read: () => g.gameItemId,
    write: () => ({ id: randomUUID(), game_slug: g.gameSlug, band: 'B', item_type: 'question', payload: {} }),
    patch: { payload: { hacked: true } } },
];

// ─── Bucket 3: server-only ────────────────────────────────────────────────────
// RLS enabled with ZERO policies. A client gets nothing by construction rather than
// by a policy that could be written wrong. Do not "fix" these by adding a policy.
const SERVER_ONLY_TABLES = ['content_embeddings', 'cached_answers'];

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
    saved_cards: randomUUID(),
    game_play_history: randomUUID(),
    onboarding_state: randomUUID(),
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
  await ins('saved_cards', { id: f.rows.saved_cards, owner_id: owner, card_id: g.cardId });
  await ins('game_play_history', { id: f.rows.game_play_history, owner_id: owner, child_id: childId, game_slug: g.gameSlug, item_id: g.gameItemId });
  await ins('onboarding_state', { id: f.rows.onboarding_state, user_id: owner, child_id: childId, step: 0 });
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
  await admin.from('games').delete().eq('slug', g.gameSlug); // cascades to game_items
}

test.before(async () => {
  // Clean any leftovers from a previous/aborted run, then seed fresh.
  await deleteTestUsers();
  await deleteGlobals();

  await ins('content_cards', { id: g.cardId, title: 'Card', body: 'b', published: true });
  await ins('activities', { id: g.activityId, title: 'Activity' });
  await ins('questions', { id: g.questionId, type: 'daily', prompt: 'Q?' });
  await ins('games', { slug: g.gameSlug, title: 'Test Game', type: 'question' });
  await ins('game_items', { id: g.gameItemId, game_slug: g.gameSlug, band: 'B', item_type: 'question', payload: {} });

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
for (const table of FAMILY_TABLES) {
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

// ─── Shared-content: readable by all, writable by none ────────────────────────
// The negative tests architecture rule 5 requires. A catalog that any signed-in user
// could edit would let one mother rewrite the content every other mother reads.
for (const s of SHARED_TABLES) {
  test(`${s.table}: authenticated user can read but NEVER write`, async () => {
    const client = families.A.client;
    const id = s.read();

    // Positive control: the policy is not deny-all — a signed-in user can read it.
    const rd = await client.from(s.table).select(s.key).eq(s.key, id);
    assert.ifError(rd.error);
    assert.equal(rd.data.length, 1, `${s.table} should be readable by any authenticated user`);

    // INSERT must be refused (either an RLS error, or zero rows returned).
    const row = s.write();
    const ins = await client.from(s.table).insert(row).select(s.key);
    // Clean up defensively before asserting, so a failure can never pollute the DB.
    await admin.from(s.table).delete().eq(s.key, row[s.key]);
    assert.ok(ins.error || (ins.data || []).length === 0,
      `LEAK: an authenticated user INSERTed into shared catalog ${s.table}`);

    // UPDATE must affect zero rows, and must not change the row.
    const up = await client.from(s.table).update(s.patch).eq(s.key, id).select(s.key);
    assert.ok(up.error || (up.data || []).length === 0,
      `LEAK: an authenticated user UPDATEd shared catalog ${s.table}`);

    // DELETE must affect zero rows...
    const del = await client.from(s.table).delete().eq(s.key, id).select(s.key);
    assert.ok(del.error || (del.data || []).length === 0,
      `LEAK: an authenticated user DELETEd from shared catalog ${s.table}`);

    // ...and the row must still be there, unchanged (confirmed via service role).
    const still = await admin.from(s.table).select(s.key).eq(s.key, id);
    assert.equal(still.data.length, 1, `LEAK: shared catalog row in ${s.table} was destroyed`);
  });
}

// ─── Server-only: invisible to every client ───────────────────────────────────
for (const table of SERVER_ONLY_TABLES) {
  test(`${table}: invisible to an authenticated user (RLS on, no policy)`, async () => {
    const seen = await admin.from(table).select('*', { count: 'exact', head: true });
    const adminCount = seen.count ?? 0;

    const rd = await families.A.client.from(table).select('*', { count: 'exact', head: true });
    // A revoked table privilege is also an acceptable outcome — it denies just as hard.
    if (rd.error) return;

    assert.equal(rd.count ?? 0, 0,
      `LEAK: an authenticated user read ${rd.count} rows from server-only table ${table}`);

    if (adminCount === 0) {
      console.warn(`  note: ${table} is empty, so this run proves "no rows returned", ` +
                   'not "existing rows are hidden".');
    }
  });
}

// ─── Coverage guard ───────────────────────────────────────────────────────────
// The guard that makes forgetting impossible. It asks the LIVE database for every
// table in `public` and requires each one to be (a) classified into exactly one of the
// three buckets above, and (b) have RLS enabled.
//
// This deliberately does NOT infer membership from column names. The previous version
// looked for `owner_id`/`user_id`, which had two failure modes once a second RLS
// pattern arrived: a forum table keyed on `author_id` would have been invisible to the
// guard and shipped untested, while `moderators` would have been caught and wrongly
// required to pass a family-isolation test. Exhaustive classification has neither hole.
test('coverage: every public table is classified, tested, and has RLS on', async () => {
  const client = new pg.Client({
    connectionString: `postgresql://postgres.${ref}:${encodeURIComponent(config.dbPassword)}@${POOLER_HOST}:6543/postgres`,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();
  const res = await client.query(`
    select c.relname as t, c.relrowsecurity as rls
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
    order by 1;`);
  await client.end();

  const classified = new Set([
    ...FAMILY_TABLES,
    ...SHARED_TABLES.map((s) => s.table),
    ...SERVER_ONLY_TABLES,
  ]);
  const live = res.rows.map((r) => r.t);

  // 1. Nothing unclassified. A new table must declare its RLS pattern (rule 4).
  const unclassified = live.filter((t) => !classified.has(t));
  assert.equal(unclassified.length, 0,
    `Unclassified public tables: ${unclassified.join(', ')}. Every table must be declared ` +
    'family-isolated (FAMILY_TABLES), shared-content (SHARED_TABLES) or server-only ' +
    '(SERVER_ONLY_TABLES) and tested above — architecture rule 4.');

  // 2. RLS actually enabled everywhere (Hard Rule #1). The old guard never checked this.
  const rlsOff = res.rows.filter((r) => !r.rls).map((r) => r.t);
  assert.equal(rlsOff.length, 0,
    `Tables with RLS DISABLED: ${rlsOff.join(', ')}. Hard Rule #1 — RLS on every table.`);

  // 3. No stale entries, so the lists can't quietly describe a schema that moved on.
  const stale = [...classified].filter((t) => !live.includes(t));
  assert.equal(stale.length, 0,
    `Classified tables that no longer exist: ${stale.join(', ')}. Remove them from this file.`);
});
