# RLS cross-family test harness

Proves a parent can **never** read or write another family's rows — the Hard Rule #20
gate every family-data feature must pass before it's "done".

`rls_cross_family.test.mjs` signs in as real users (anon key + real JWT, exactly like
the app) and checks all **three** RLS patterns Momzo now uses:

| Bucket | Property proved |
|---|---|
| **Family-isolated** (18 tables) | Two seeded families, A and B; neither can SELECT / UPDATE / DELETE the other's rows, while a positive control confirms each still reads its own |
| **Shared-content** (5 tables) | Any authenticated user can READ the catalog but can **never** INSERT, UPDATE or DELETE it — the negative tests architecture rule 5 requires |
| **Server-only** (2 tables) | `content_embeddings` and `cached_answers` have RLS on with **no policy at all** and return nothing to any client |

**The coverage guard is the part that matters.** It asks the live database for every
table in `public` and fails unless each one is (a) classified into exactly one of those
three buckets and (b) has RLS enabled. A new table cannot ship untested, and it cannot
ship unclassified.

It deliberately does **not** infer the bucket from column names. An earlier version
looked for `owner_id`/`user_id`, which breaks as soon as a second RLS pattern exists: a
forum table keyed on `author_id` would have been invisible to the guard and shipped
untested, while `moderators` would have been caught and wrongly required to pass a
family-isolation test. Exhaustive classification has neither hole.

**Adding a table?** Add it to `FAMILY_TABLES`, `SHARED_TABLES` or `SERVER_ONLY_TABLES`
in that file — and if it holds child data, give it
`on delete cascade` so it joins the delete-child cascade (architecture rule 6).

## Run locally

```bash
cd supabase/tests
npm install
npm test
```

Config is read from `supabase/.env` (URL, service_role, DB password) and
`app/env.json` (anon key) — both git-ignored. In CI, the same names are supplied as
GitHub Actions secrets (see `.github/workflows/ci.yml`). It drives the **live linked
project**; the harness cleans up its seed data (and the two test auth users) on every
run, before and after.

> `SUPABASE_POOLER_HOST` defaults to `aws-1-us-west-1.pooler.supabase.com` (this
> project's region). Override via env if the project moves.
