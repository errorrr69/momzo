# ADR 010 — The forum introduces shared-content tables

**Status:** Accepted · **not yet implemented** (Expansion Plan Phase E)
**Decided:** August 2026 (`Momzo_Expansion_Plan.md` §2, §4.1)

## Context

A mom community was **explicitly deferred** in PRD §5.10 and §13, on the reasoning that
a forum risks recreating the social-media overwhelm Momzo exists to escape. Florie has
now decided to build it, scoped lean.

This is architecturally significant beyond its feature size. Every table in Momzo so far
has been family-isolated (ADR 002): a row belongs to exactly one account, and no other
account may ever see it. Forum content inverts that — it is written by one mother and
**read by all of them**.

That is a second RLS pattern, and it needs the same rigour the first one got.

## Decision

**Adopt a shared-content RLS pattern**, and treat it as the second and final pattern
(rule 4: a third requires its own ADR):

- **SELECT** — any authenticated user, with `published` / `active` / `hidden` predicates
  in the policy itself.
- **INSERT / UPDATE** — author only, `(select auth.uid()) = author_id`. Catalogs and
  posts are admin/service-write.
- **Moderator powers** — via a `moderators` membership check inside a `security definer`
  function, so the policy stays a direct comparison and does not become a subquery
  (ADR 002's performance rule).
- **Negative tests are mandatory**, not optional: a non-author cannot edit or delete
  another mother's post; a non-moderator cannot hide content; a non-admin cannot publish.

**Safety is part of the architecture, not a later feature.** A report button on every
thread and reply; auto-hide at a threshold (default 3 reports) pending review; a
"someone may need help" report reason that reaches the moderator with priority. The app
never auto-deletes a struggling mother's post — a human decides. Forum identity is a
chosen display name and emoji avatar, never the account name.

## Consequences

**Good.** The pattern is reusable — `social_posts` and `learning_games` need the same
shape, so the content hub and games catalog land on proven ground.

**Prerequisite — met 2026-08-13.** The RLS coverage guard was not originally capable of
policing this: it found tables by looking for `owner_id` / `user_id`, so `forum_threads`,
`forum_replies` and `forum_reports` (keyed on `author_id` / `reporter_id`) would have
passed **silently untested**, while `moderators` and `forum_profiles` would have tripped
it and demanded a family-isolation test that is wrong for them.

The guard now requires every table in `public` to be explicitly classified as
family-isolated, shared-content or server-only, and to have RLS on. **Adding a forum
table without declaring its pattern and testing it now fails CI.** Phase E's job is to
add the forum tables to `SHARED_TABLES` and write the moderator negative tests; the
mechanism to enforce that is in place.

**Cost — operational, not technical.** A forum is ongoing human work: replies, moderation,
tending. This is why it is sequenced **last** of the five expansion phases — it should
launch when there is a community to fill it and capacity to tend it.

**Cost.** Crisis-adjacent content will surface here. The existing refer-out philosophy
extends to it through a pinned resources post and the priority report reason, but a
forum cannot screen every message the way `ai-chat` screens every turn.

**Overlap.** The unmerged `feat/coparent-sharing` branch needs a similar `security
definer` membership function. These two should be reconciled rather than built twice.
