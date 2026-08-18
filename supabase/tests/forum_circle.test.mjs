// The Circle — the shared-AUTHORED RLS pattern (Expansion Plan §2.3).
//
// This is the app's first surface where one user writes a row another user reads,
// and §2.3 asks for it to be tested as carefully as the family-isolation suite.
// The negative tests are the point:
//
//   * a non-author cannot edit or delete someone else's post
//   * a non-moderator cannot hide anything
//   * an AUTHOR cannot un-hide her own auto-hidden post either — RLS grants rows,
//     not columns, so without the column guard her legitimate ownership of the row
//     would also let her reverse a moderation decision
//   * three reports auto-hide; a moderator restores; the round trip works
//   * a hidden post is invisible to others but NOT to its author, because §2.4
//     says nothing is auto-deleted and a mother must not simply find her words gone
//   * nobody's real account name is reachable through the forum
//
// Three throwaway accounts (two members, one moderator), all removed in after().
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { config } from './config.mjs';

const admin = createClient(config.url, config.serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const PASSWORD = 'Circle-Test-Pass-123!';
const stamp = Date.now();

const people = {
  amara: { email: `circle-a-${stamp}@momzo.test`, name: 'Amara' },
  bea:   { email: `circle-b-${stamp}@momzo.test`, name: 'Bea' },
  cass:  { email: `circle-c-${stamp}@momzo.test`, name: 'Cass' },  // extra reporter
  flo:   { email: `circle-m-${stamp}@momzo.test`, name: 'Flo', moderator: true },
};

let categoryId;

async function signIn(email) {
  const client = createClient(config.url, config.anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error } = await client.auth.signInWithPassword({ email, password: PASSWORD });
  assert.equal(error, null, `sign in ${email}: ${error?.message}`);
  return client;
}

before(async () => {
  for (const key of Object.keys(people)) {
    const p = people[key];
    const { data, error } = await admin.auth.admin.createUser({
      email: p.email, password: PASSWORD, email_confirm: true,
    });
    assert.equal(error, null, `create ${p.email}: ${error?.message}`);
    p.id = data.user.id;

    // The ACCOUNT name is deliberately different from the Circle name, so a leak
    // is detectable rather than coincidentally identical.
    await admin.from('users').insert({ id: p.id, display_name: `REAL-${p.name}-ACCOUNT` });
    await admin.from('forum_profiles')
      .insert({ user_id: p.id, display_name: p.name, avatar_emoji: '💛' });
    if (p.moderator) await admin.from('moderators').insert({ user_id: p.id });

    p.client = await signIn(p.email);
  }

  const { data: cat, error } = await admin
    .from('forum_categories')
    .insert({ slug: `circle-test-${stamp}`, title: 'Test category', sort: 99 })
    .select('id').single();
  assert.equal(error, null, `seed category: ${error?.message}`);
  categoryId = cat.id;
});

after(async () => {
  await admin.from('forum_categories').delete().eq('id', categoryId);
  for (const p of Object.values(people)) {
    if (p.id) await admin.auth.admin.deleteUser(p.id);
  }
});

/** A fresh thread by Amara. */
async function amaraPosts(title = 'A hard evening') {
  const { data, error } = await people.amara.client
    .from('forum_threads')
    .insert({
      category_id: categoryId, author_id: people.amara.id,
      title, body: 'It went badly and I wanted to say so.',
    })
    .select('id').single();
  assert.equal(error, null, `amara posts: ${error?.message}`);
  return data.id;
}

test('any signed-in mother can read another mother’s thread', async () => {
  const id = await amaraPosts('Readable by all');
  const { data, error } = await people.bea.client
    .from('forum_threads').select('id, title, body').eq('id', id).maybeSingle();
  assert.equal(error, null);
  assert.ok(data, 'Bea should be able to read Amara’s thread');
  assert.equal(data.title, 'Readable by all');
});

test('a non-author cannot EDIT someone else’s thread', async () => {
  const id = await amaraPosts();
  const { error } = await people.bea.client
    .from('forum_threads').update({ body: 'HACKED' }).eq('id', id);

  // PostgREST reports an RLS-blocked update as zero rows affected rather than an
  // error, so the row itself is what has to be checked.
  const { data } = await admin.from('forum_threads').select('body').eq('id', id).single();
  assert.notEqual(data.body, 'HACKED', `Bea rewrote Amara's post (error: ${error?.message})`);
});

test('a non-author cannot DELETE someone else’s thread', async () => {
  const id = await amaraPosts();
  await people.bea.client.from('forum_threads').delete().eq('id', id);
  const { count } = await admin
    .from('forum_threads').select('*', { count: 'exact', head: true }).eq('id', id);
  assert.equal(count, 1, 'Bea deleted Amara’s post');
});

test('an author CAN edit and delete her own', async () => {
  const id = await amaraPosts();
  const { error } = await people.amara.client
    .from('forum_threads').update({ body: 'Reworded, calmer.' }).eq('id', id);
  assert.equal(error, null, `author edit: ${error?.message}`);

  const { data } = await admin.from('forum_threads').select('body').eq('id', id).single();
  assert.equal(data.body, 'Reworded, calmer.');

  await people.amara.client.from('forum_threads').delete().eq('id', id);
  const { count } = await admin
    .from('forum_threads').select('*', { count: 'exact', head: true }).eq('id', id);
  assert.equal(count, 0, 'author should be able to delete her own thread');
});

test('a non-moderator cannot hide anything', async () => {
  const id = await amaraPosts();
  await people.bea.client.from('forum_threads').update({ hidden: true }).eq('id', id);
  const { data } = await admin.from('forum_threads').select('hidden').eq('id', id).single();
  assert.equal(data.hidden, false, 'Bea hid Amara’s post');
});

test('an AUTHOR cannot un-hide her own post — the column guard', async () => {
  // The subtle one. She legitimately owns the row, so the row-level policy lets
  // her UPDATE it; only the column guard stops that update from clearing `hidden`
  // and undoing a moderation decision.
  const id = await amaraPosts();
  await admin.from('forum_threads')
    .update({ hidden: true, hidden_reason: 'under review' }).eq('id', id);

  const { error } = await people.amara.client
    .from('forum_threads').update({ hidden: false }).eq('id', id);
  assert.ok(error, 'clearing her own hidden flag should be refused outright');

  const { data } = await admin.from('forum_threads').select('hidden').eq('id', id).single();
  assert.equal(data.hidden, true, 'author un-hid her own post');
});

test('an author can still edit the WORDS of a hidden post', async () => {
  // The guard must block the moderated columns and nothing else — being reviewed
  // should not freeze her out of her own sentence.
  const id = await amaraPosts();
  await admin.from('forum_threads').update({ hidden: true }).eq('id', id);

  const { error } = await people.amara.client
    .from('forum_threads').update({ body: 'Let me put that better.' }).eq('id', id);
  assert.equal(error, null, `editing the body of a hidden post: ${error?.message}`);
});

test('a hidden thread is invisible to others, and still visible to its author', async () => {
  const id = await amaraPosts('Hidden but not gone');
  await admin.from('forum_threads').update({ hidden: true }).eq('id', id);

  const bea = await people.bea.client
    .from('forum_threads').select('id').eq('id', id).maybeSingle();
  assert.equal(bea.data, null, 'a hidden thread leaked to another member');

  const mine = await people.amara.client
    .from('forum_threads').select('id, hidden').eq('id', id).maybeSingle();
  assert.ok(mine.data, 'the author must still see her own hidden words (§2.4)');
  assert.equal(mine.data.hidden, true);

  const mod = await people.flo.client
    .from('forum_threads').select('id').eq('id', id).maybeSingle();
  assert.ok(mod.data, 'a moderator must be able to see hidden content to review it');
});

test('three reports auto-hide, and a moderator can put it back', async () => {
  const id = await amaraPosts('Reported three times');

  for (const who of ['bea', 'cass', 'flo']) {
    const { error } = await people[who].client.from('forum_reports').insert({
      target_type: 'thread', target_id: id, reporter_id: people[who].id, reason: 'unkind',
    });
    assert.equal(error, null, `${who} reports: ${error?.message}`);
  }

  const hiddenNow = await admin
    .from('forum_threads').select('hidden, hidden_reason').eq('id', id).single();
  assert.equal(hiddenNow.data.hidden, true, 'three reports should auto-hide');
  assert.match(hiddenNow.data.hidden_reason ?? '', /review/i);

  // Restore, as a moderator would from the queue.
  const { error: restoreErr } = await people.flo.client
    .from('forum_threads').update({ hidden: false, hidden_reason: null }).eq('id', id);
  assert.equal(restoreErr, null, `moderator restore: ${restoreErr?.message}`);

  const back = await admin.from('forum_threads').select('hidden').eq('id', id).single();
  assert.equal(back.data.hidden, false, 'moderator could not restore');

  const visible = await people.bea.client
    .from('forum_threads').select('id').eq('id', id).maybeSingle();
  assert.ok(visible.data, 'restored thread should be readable again');
});

test('two reports are not enough — the threshold is three', async () => {
  const id = await amaraPosts('Only two reports');
  for (const who of ['bea', 'cass']) {
    await people[who].client.from('forum_reports').insert({
      target_type: 'thread', target_id: id, reporter_id: people[who].id, reason: 'unkind',
    });
  }
  const { data } = await admin.from('forum_threads').select('hidden').eq('id', id).single();
  assert.equal(data.hidden, false, 'two reports should not hide anything');
});

test('one person cannot reach the threshold alone', async () => {
  const id = await amaraPosts('One angry reporter');
  const first = await people.bea.client.from('forum_reports').insert({
    target_type: 'thread', target_id: id, reporter_id: people.bea.id, reason: 'unkind',
  });
  assert.equal(first.error, null);

  for (let i = 0; i < 2; i++) {
    const again = await people.bea.client.from('forum_reports').insert({
      target_type: 'thread', target_id: id, reporter_id: people.bea.id, reason: 'other',
    });
    assert.ok(again.error, 'a repeat report from the same person should be refused');
    assert.equal(again.error.code, '23505');
  }

  const { data } = await admin.from('forum_threads').select('hidden').eq('id', id).single();
  assert.equal(data.hidden, false, 'one reporter stacked reports to force a hide');
});

test('a member cannot read other people’s reports; a moderator can', async () => {
  const id = await amaraPosts('Who can see reports');
  await people.bea.client.from('forum_reports').insert({
    target_type: 'thread', target_id: id, reporter_id: people.bea.id, reason: 'selling',
  });

  const cass = await people.cass.client
    .from('forum_reports').select('id').eq('target_id', id);
  assert.equal(cass.data.length, 0, 'Cass should not see Bea’s report');

  const flo = await people.flo.client
    .from('forum_reports').select('id').eq('target_id', id);
  assert.ok(flo.data.length >= 1, 'a moderator must see the queue');
});

test('a member cannot resolve a report', async () => {
  const id = await amaraPosts('Resolving');
  const { data: report } = await people.bea.client.from('forum_reports')
    .insert({ target_type: 'thread', target_id: id, reporter_id: people.bea.id, reason: 'other' })
    .select('id').single();

  await people.bea.client
    .from('forum_reports').update({ resolved: true }).eq('id', report.id);
  const { data } = await admin
    .from('forum_reports').select('resolved').eq('id', report.id).single();
  assert.equal(data.resolved, false, 'a reporter marked her own report resolved');
});

test('nobody can make themselves a moderator', async () => {
  const { error } = await people.bea.client
    .from('moderators').insert({ user_id: people.bea.id });
  assert.ok(error, 'inserting into moderators should be refused');

  const { count } = await admin
    .from('moderators').select('*', { count: 'exact', head: true }).eq('user_id', people.bea.id);
  assert.equal(count, 0);
});

test('the Circle never exposes a real account name', async () => {
  // §2.4: forum identity is a chosen display name, never the account name. The
  // account names here are all prefixed REAL-, so any leak is unmistakable.
  const id = await amaraPosts('Identity check');
  const { data, error } = await people.bea.client
    .from('forum_threads')
    .select('id, title, body, author_id, forum_profiles!forum_threads_author_profile_fkey(display_name, avatar_emoji)')
    .eq('id', id).single();
  assert.equal(error, null, `embed: ${error?.message}`);
  assert.equal(data.forum_profiles.display_name, 'Amara');
  assert.ok(!JSON.stringify(data).includes('REAL-'), 'an account name leaked into the forum');

  // And the users table itself stays closed to her.
  const users = await people.bea.client
    .from('users').select('display_name').eq('id', people.amara.id);
  assert.equal(users.data?.length ?? 0, 0, 'Bea could read Amara’s account row');
});

test('a thread cannot be posted without a Circle identity', async () => {
  // The foreign key to forum_profiles is what makes "choose a name first" a
  // guarantee rather than a UI convention.
  const { data: u } = await admin.auth.admin.createUser({
    email: `circle-noprofile-${stamp}@momzo.test`, password: PASSWORD, email_confirm: true,
  });
  await admin.from('users').insert({ id: u.user.id, display_name: 'No Profile' });
  const client = await signIn(`circle-noprofile-${stamp}@momzo.test`);

  const { error } = await client.from('forum_threads').insert({
    category_id: categoryId, author_id: u.user.id, title: 'No identity', body: 'x',
  });
  assert.ok(error, 'posting without a forum profile should be refused');
  assert.equal(error.code, '23503', `expected a foreign-key violation, got ${error.code}`);

  await admin.auth.admin.deleteUser(u.user.id);
});

test('reply counts and last activity are maintained server-side', async () => {
  const id = await amaraPosts('Counting replies');
  const before = await admin
    .from('forum_threads').select('reply_count, last_activity_at').eq('id', id).single();
  assert.equal(before.data.reply_count, 0);

  await people.bea.client.from('forum_replies')
    .insert({ thread_id: id, author_id: people.bea.id, body: 'I know this evening.' });

  const after1 = await admin
    .from('forum_threads').select('reply_count, last_activity_at').eq('id', id).single();
  assert.equal(after1.data.reply_count, 1);
  assert.ok(
    new Date(after1.data.last_activity_at) >= new Date(before.data.last_activity_at),
    'last_activity_at should move forward on a reply',
  );
});

test('a reaction count is public, and cannot be double-counted', async () => {
  const id = await amaraPosts('Hearts');

  for (const who of ['bea', 'cass']) {
    const { error } = await people[who].client.from('forum_reactions').insert({
      target_type: 'thread', target_id: id, user_id: people[who].id,
    });
    assert.equal(error, null, `${who} hearts: ${error?.message}`);
  }
  const twice = await people.bea.client.from('forum_reactions').insert({
    target_type: 'thread', target_id: id, user_id: people.bea.id,
  });
  assert.equal(twice.error?.code, '23505', 'a second heart should be refused');

  // The COUNT is public — that is the you-are-not-alone signal — while who
  // hearted it is not.
  const seen = await people.amara.client
    .from('forum_threads').select('reaction_count').eq('id', id).single();
  assert.equal(seen.data.reaction_count, 2);

  const others = await people.amara.client
    .from('forum_reactions').select('user_id').eq('target_id', id);
  assert.equal(others.data.length, 0, 'Amara should not see who hearted her post');
});

test('removing a heart decrements the public count', async () => {
  const id = await amaraPosts('Un-hearting');
  await people.bea.client.from('forum_reactions')
    .insert({ target_type: 'thread', target_id: id, user_id: people.bea.id });
  await people.bea.client.from('forum_reactions')
    .delete().eq('target_id', id).eq('user_id', people.bea.id);

  const { data } = await admin
    .from('forum_threads').select('reaction_count').eq('id', id).single();
  assert.equal(data.reaction_count, 0);
});

test('a hidden REPLY follows the same rules as a hidden thread', async () => {
  const id = await amaraPosts('Reply moderation');
  const { data: reply } = await people.bea.client.from('forum_replies')
    .insert({ thread_id: id, author_id: people.bea.id, body: 'Something unkind.' })
    .select('id').single();

  await admin.from('forum_replies').update({ hidden: true }).eq('id', reply.id);

  const seenByOther = await people.cass.client
    .from('forum_replies').select('id').eq('id', reply.id).maybeSingle();
  assert.equal(seenByOther.data, null, 'a hidden reply leaked');

  const seenByAuthor = await people.bea.client
    .from('forum_replies').select('id').eq('id', reply.id).maybeSingle();
  assert.ok(seenByAuthor.data, 'the author should still see her own hidden reply');

  const unhide = await people.bea.client
    .from('forum_replies').update({ hidden: false }).eq('id', reply.id);
  assert.ok(unhide.error, 'a reply author should not be able to un-hide herself');
});
