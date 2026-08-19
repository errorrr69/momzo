# ADR 013 — Shared-authored content: the Circle, and the Content Hub beside it

**Status:** Accepted · 18 Aug 2026 · **narrowed by ADR 014** — the Circle was
removed from the app, so the shared-authored pattern currently has no reader.
The pattern, its tables and its coverage guard all stay.
**Extends:** ADR 002 (RLS everywhere, two patterns) — there are now four

## Context

The expansion added three surfaces at once (Expansion Plan §1–§3), and two of
them broke an assumption the schema had held since the beginning: that every row
belongs to exactly one family.

| Surface | Who writes | Who reads |
|---|---|---|
| Content Hub (`social_posts`) | Florie, via a seeder | every parent |
| Learning games (`learning_games`) | a seeder | every parent |
| Game sessions (`game_play_sessions`) | the app | that family only |
| The Circle (`forum_*`) | **every mother** | **every mother** |

The last row is the new thing. ADR 002 recorded two patterns — family-isolated
and shared-content — and neither describes a table where one user writes a row
another user reads and a third user may hide.

## Decision

**1. Four RLS patterns, all declared, none inferred.** The coverage guard in
`rls_cross_family.test.mjs` requires every table in `public` to be listed under
exactly one of:

- **family-isolated** — `owner_id`/`user_id` equals the caller
- **shared-content** — any authenticated read, no client write at all
- **server-only** — RLS on, zero policies; reachable only by the service role
- **shared-authored** — open read, author-only write, moderator may hide

A new table cannot ship unclassified. Membership is never inferred from column
names: a forum table keyed on `author_id` looks family-scoped and is not.

**2. Column-level rules need a trigger, because RLS grants rows.** This is the
same lesson as `concept_basis` in ADR 012, arriving from the other direction.
There, a policy could not withhold one column, so the fix was a column privilege.
Here, an author legitimately owns her row — which also lets her clear her own
`hidden` flag and reverse a moderation decision. `forum_guard_moderated_columns()`
is what stops that, while leaving her free to edit the words of a post that is
under review.

**3. A post must carry a chosen identity.** `forum_threads.author_id` has a
foreign key to `forum_profiles` **as well as** to `users`. §2.4 makes the forum
name a choice — a display name and an emoji, never the account name — and the FK
means no code path, present or future, can post without one. There is no fallback
to `users.display_name` anywhere in the app.

**4. Reaction counts are public in the Circle and private in the Content Hub.**
Deliberately inconsistent, because the two mean different things. "Eleven other
mothers felt this" is the you-are-not-alone signal and is most of why a forum
works. A tally on a parenting tip is a popularity score on advice, which is not.
In both cases *who* reacted stays private; only the Circle exposes *how many*,
via a trigger-maintained counter on the parent row.

**5. Hidden is not deleted.** Three open reports auto-hide, server-side, but the
author still sees her own words and is told they are being reviewed. A mother who
wrote something hard and got reported must not simply find them gone. A human
decides what happens next (§2.4).

**6. The games dashboard is a pure function.** `GameInsights.build()` takes
sessions, catalogue, profile and a clock, and returns the whole screen. The tone
rules — no score, no comparison to another child, always end on a win — are
therefore properties of a file that can be tested without a database or a widget.
That matters because tone decays silently: nothing crashes when a dashboard
starts quietly telling a mother her child is behind.

## Consequences

**Good.**
- The Circle's guarantees are proved rather than asserted: 20 tests covering
  non-author edit/delete, non-moderator hide, author self-un-hide, the auto-hide
  threshold from both directions, and that no account name is reachable.
- Momzo's dashboard and Florie's own session panel cannot disagree about what
  "secure" means, because both use the two-day rule from `mastery.ts`.
- The games bridge is one hook at the callback layer, so all 22 games are
  instrumented and none of them know it.

**Costs and limits, honestly.**
- **The Circle carries a standing operational cost.** It is built, not launched.
  It needs a moderator (`build_forum.mjs --moderator`) and someone to tend it,
  and §2.4 is right that it should launch into an audience warmed by the other
  phases rather than into an empty room.
- **The coverage guard has one hole.** It requires a forum table to be *declared*
  but cannot verify it is *tested*, because the tests live in another file. A new
  `forum_*` table added to the list without a test would pass.
- **Nav is Option B by default, not by decision.** Games and the Circle both
  enter from Together because §2.5 says to build nothing nav-related before
  Florie chooses. Both living there makes Option A harder the longer it waits.
- **Auto-hide is a blunt instrument.** Three reports hide anything, including
  something true and hard that three people found uncomfortable. That is the
  trade the plan asks for; the mitigation is that it hides rather than deletes
  and that the author is told.
- Six of 22 games have no `ladder_key`, so recommendation rule 2 does nothing for
  them. This is correct rather than missing — they are the feelings and focus
  games, which are not a sequence.

## Alternatives rejected

- **Squeeze the forum into "shared-content".** It would have meant either no
  client writes (no forum) or a catalog anyone can edit. The pattern is genuinely
  different and pretending otherwise is how a policy gets written wrong.
- **Enforce moderated columns in the client.** The client is not a security
  boundary. A guard that lives in the app protects the app's own code paths and
  nothing else.
- **Let the author see nothing when hidden.** Simpler, and worse: her words
  vanish with no explanation at the moment she is most likely to need support.
- **A public reaction count on Content Hub posts too.** Consistency for its own
  sake. It needs a trigger and a security-definer write path, and it puts a
  number on advice.
