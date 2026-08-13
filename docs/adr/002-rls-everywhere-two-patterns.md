# ADR 002 — RLS everywhere, two patterns only

**Status:** Accepted · backfilled 2026-08-13
**Decided:** June 2026 (Build Guide §6 Hard Rules 1, 3)

## Context

Because the app queries Postgres directly with the anon key (ADR 001), the database is
the security boundary. There is no server-side code between a malicious client and the
tables. Momzo also holds children's data under COPPA, so a cross-family leak is not
merely a bug — it is a reportable incident.

Two failure modes had to be designed out. First, forgetting RLS on a new table. Second,
RLS policies that are correct but slow: a policy containing a subquery or join runs per
row, and at a few thousand rows it turns every query into a table scan.

## Decision

**RLS is enabled on every table in `public`, without exception**, and policies use one
of exactly **two patterns**:

1. **Family-isolated** — a direct comparison, `(select auth.uid()) = owner_id` (or
   `user_id`). No joins, no `IN` subqueries. `auth.uid()` is wrapped in `select` so
   Postgres evaluates it once per statement rather than once per row.
2. **Shared reference** — `SELECT` for any authenticated user, with a published/active
   predicate. No client writes; seeding happens via the service role.

Every column a policy filters on is indexed. To keep pattern 1 join-free, `owner_id` was
denormalised onto child-scoped tables that the PRD's data model did not originally carry
it on.

Two tables — `content_embeddings` and `cached_answers` — have **RLS enabled with no
policy at all**. They are service-role-only. A client gets zero rows by construction
rather than by a policy that could be written wrong.

A third pattern requires a new ADR. The forum introduces one (ADR 010).

## Consequences

**Good.** Isolation is enforced by the database, so it holds regardless of what the app
does. Policies stay fast and predictable.

**Good.** The pattern is uniform enough to test exhaustively. `supabase/tests/rls_cross_family.test.mjs`
seeds two families, signs in as each with real JWTs, and proves neither can read, update
or delete the other's rows across every family table — with a **coverage guard that
fails CI when a new table appears untested**.

**Cost.** `owner_id` denormalisation must be kept correct on insert.

**Cost — active.** The coverage guard detects tables by looking for an `owner_id` or
`user_id` column. That was sufficient while every table was family-isolated. It is not
sufficient for shared-content tables: forum tables keyed on `author_id` or `reporter_id`
would pass untested, while `moderators` and `forum_profiles` would trip the guard and
demand a family-isolation test that is wrong for them. **The guard must be made
pattern-aware before the forum ships.**
