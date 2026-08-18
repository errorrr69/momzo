// Demo content for the Circle, so a first look at it isn't five empty folders.
//
// NOT part of the product. These are throwaway accounts with obviously-test
// emails, and `--remove` deletes every one of them along with everything they
// wrote. Use it to see the forum working, then take it out.
//
//   node demo_circle.mjs            seed
//   node demo_circle.mjs --remove   delete the accounts and all their content
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const here = dirname(fileURLToPath(import.meta.url));

function parseEnv(path) {
  const out = {};
  let text;
  try { text = readFileSync(path, 'utf8'); } catch { return out; }
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    let val = line.slice(eq + 1).trim();
    if (val.startsWith('"')) val = val.slice(1, val.indexOf('"', 1));
    else val = val.split(/\s+#/)[0].trim();
    out[line.slice(0, eq).trim()] = val;
  }
  return out;
}

const env = parseEnv(join(here, '..', '.env'));
const admin = createClient(
  process.env.SUPABASE_URL || env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const MARK = '@circle-demo.momzo.test'; // the handle for finding and removing them

const PEOPLE = [
  { email: `nadia${MARK}`, name: 'Nadia', emoji: '🌷' },
  { email: `priya${MARK}`, name: 'Priya', emoji: '🌿' },
  { email: `jo${MARK}`,    name: 'Jo',    emoji: '☕' },
];

const THREADS = [
  {
    by: 'Nadia', category: 'big-feelings',
    title: 'The school run is undoing me',
    body: 'Every single morning ends with one of us crying and it is not always '
        + 'her. She is fine once she is in. I am not fine once I am back in the car.',
    replies: [
      { by: 'Priya', body: 'The car cry is so real. Mine took about six weeks to '
          + 'settle and then one day it just… stopped. Nothing I did. It was time.' },
      { by: 'Jo', body: 'We started doing the goodbye at the gate instead of the '
          + 'door, same words every day. Not magic but it gave us both a script.' },
    ],
  },
  {
    by: 'Priya', category: 'wins',
    title: 'He said sorry without being asked',
    body: 'Knocked his sister\'s tower over, saw her face, and said it himself. '
        + 'Six years of modelling it and I nearly fell over.',
    replies: [
      { by: 'Nadia', body: 'This is the good stuff. Well done both of you.' },
    ],
  },
  {
    by: 'Jo', category: 'ask-the-circle',
    title: 'How do you handle the 5pm hour?',
    body: 'Between pickup and dinner everything falls apart. Everyone is hungry, '
        + 'nobody can hear me, and I turn into someone I do not like. What works '
        + 'in your house?',
    replies: [],
  },
];

if (process.argv.includes('--remove')) {
  const { data } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  let n = 0;
  for (const u of data.users) {
    if (u.email?.includes(MARK)) {
      // Cascades: forum_profiles → threads → replies → reactions.
      await admin.auth.admin.deleteUser(u.id);
      n++;
      console.log(`  - ${u.email}`);
    }
  }
  console.log(`\nRemoved ${n} demo account(s) and everything they wrote.`);
  process.exit(0);
}

const { data: cats } = await admin.from('forum_categories').select('id, slug');
const catBySlug = Object.fromEntries(cats.map((c) => [c.slug, c.id]));

const ids = {};
for (const p of PEOPLE) {
  const { data, error } = await admin.auth.admin.createUser({
    email: p.email, password: `Demo-${Date.now()}-Aa1!`, email_confirm: true,
  });
  if (error) {
    console.error(`  ! ${p.email}: ${error.message} (already seeded? use --remove first)`);
    process.exit(1);
  }
  ids[p.name] = data.user.id;
  await admin.from('users').insert({ id: data.user.id, display_name: p.name });
  await admin.from('forum_profiles')
    .insert({ user_id: data.user.id, display_name: p.name, avatar_emoji: p.emoji });
  console.log(`  + ${p.name}`);
}

for (const t of THREADS) {
  const { data: thread, error } = await admin.from('forum_threads').insert({
    category_id: catBySlug[t.category], author_id: ids[t.by],
    title: t.title, body: t.body,
  }).select('id').single();
  if (error) throw new Error(`${t.title}: ${error.message}`);
  console.log(`  + "${t.title}"`);
  for (const r of t.replies) {
    await admin.from('forum_replies')
      .insert({ thread_id: thread.id, author_id: ids[r.by], body: r.body });
  }
  // A couple of hearts, so the public count has something to show.
  for (const who of Object.values(ids).slice(0, 2)) {
    if (who === ids[t.by]) continue;
    await admin.from('forum_reactions')
      .insert({ target_type: 'thread', target_id: thread.id, user_id: who });
  }
}

console.log('\nDemo Circle seeded. Remove it with:  node demo_circle.mjs --remove');
