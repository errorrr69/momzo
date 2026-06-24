# RLS cross-family test harness

Proves a parent can **never** read or write another family's rows — the Hard Rule #20
gate every family-data feature must pass before it's "done".

`rls_cross_family.test.mjs` seeds two families (A, B) with a row in **every**
family-scoped table, signs in as each parent (anon key + real JWT, exactly like the
app), and asserts that neither can SELECT / UPDATE / DELETE the other's rows — while a
positive control confirms each can still read its own. A coverage guard queries the DB
for any `public` table with an `owner_id`/`user_id` column and **fails if one isn't
tested**, so a future un-protected table breaks the build.

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
