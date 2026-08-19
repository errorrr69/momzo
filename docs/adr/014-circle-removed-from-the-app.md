# ADR 014 — The Circle is removed from the app

**Status:** Accepted · 19 Aug 2026
**Reverses:** ADR 010 (forum shared-content tables) · **narrows:** ADR 013 (shared-authored content)

## Context

The Circle was built in full as Expansion Plan Phase E: seven tables, a
shared-authored RLS pattern, a guard trigger, auto-hide at three reports, a
moderator queue, a forum identity separate from the account name, 20 database
tests and 10 widget tests. It was verified end to end on a device.

On 18 Aug it was put behind `FeatureFlags.circle = false` — not because anything
was broken, but because a forum is the one feature carrying a **standing
operational cost**, and it launches best into an audience that already exists.

A day later the honest reading of that decision was that it wasn't a launch
sequencing question at all. The flag deferred a cost without reducing it: the
moderation duty a forum creates begins the day it opens and never ends, and it
does not get cheaper for having waited. PRD §5.10 and §13 had already reached
this conclusion once, before the code existed, on the reasoning that a forum
risks recreating the social-media overwhelm Momzo exists to escape.

Keeping it switched off also has a real cost of its own. Dead code in the binary
gets refactored, gets broken, and gets carried through every future change by
people who cannot tell whether it matters.

## Decision

**Remove the Circle from the app.** Delete `features/circle/`, `models/forum.dart`,
`services/forum_service.dart`, the feature flag, the widget tests and the two
seed scripts. Git holds all of it if the decision reverses.

**Keep `supabase/tests/forum_circle.test.mjs`.** The tables outlive the feature,
and a live table whose policies nothing exercises is exactly what leaks later.
"No app code reads it" is not the same as "no client can". The suite is
self-contained, so it survives the seeders it used to sit beside.

**Keep Florie's posts exactly where the redesign put them.** They shared the
Circle's tab, and the tab is theirs now — `PostsScreen`, labelled "Momzo". This
is the load-bearing half of the decision: the UX redesign's single biggest win
was moving those posts from a long scroll inside Learn to one tap, and removing
the community was never allowed to take that with it.

**Leave the database alone, for now.** The seven `forum_*` tables, their
policies, the auto-hide trigger and `is_moderator()` stay. Three applied
migrations reference them, and deleting a migration file does not un-apply it —
dropping the tables requires a new, destructive migration, which is a separate
decision made deliberately rather than as a side effect of a code cleanup.

## Consequences

**The fourth RLS pattern now has no reader.** ADR 013 declared four patterns;
shared-authored was introduced for the Circle, and the only tables using it are
the forum's. The pattern and its coverage guard stay — the classification is
still correct, the tests still run, and `feat/coparent-sharing` needs the same
`security definer` membership shape ADR 010 built. It is a pattern waiting for
its second use rather than a dead one.

**The RLS suite still covers tables the app cannot reach.** That is the right
default: unreachable-from-the-app is not the same as unreachable, and a table
with policies nobody exercises is exactly the kind of thing that leaks later.

**Content Hub posts have no comments and now no discussion home.** PRD §4.11's
"Talk about this in the Circle" hook is gone. This is not a gap to fill: a
comment system is the same moderation duty under a different name, which is the
whole reason for this ADR.

**Reversing this is a revert, not a rebuild.** The schema is live, the seeders
are one `git checkout` away, and the shape of the UI is recorded in UX plan §3.2.
What would have to be decided again is the thing that was actually hard — who
reads the reports, every day.

**Two accounts still hold `is_moderator`** from testing. Harmless with no forum
in the app; worth clearing whenever the tables are dropped.
