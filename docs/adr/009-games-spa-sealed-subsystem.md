# ADR 009 — The games SPA is a sealed subsystem

**Status:** Accepted · **not yet implemented** (Expansion Plan Phase B)
**Decided:** August 2026 (`Momzo_Expansion_Plan.md` §A2.2, §3.4)

## Context

The games repo carries **its own Supabase project** — `teacher_profiles`,
`lesson_sessions`, `session_participants`, `game_rounds`, `game_responses`,
`reading_mastery` — with teacher and student RLS. That project is Florie's tutoring
classroom: real children she teaches, entirely separate from Momzo's families.

Embedding the SPA naively would drag that dependency along. The app would carry
classroom credentials, and together-mode play could write into `lesson_sessions` or
`reading_mastery` — mixing two populations of children's data across two legal contexts.

The repo already proved this is avoidable: an `isDemo` path in `src/lib/supabase.ts`
runs the whole app with no Supabase environment at all.

## Decision

**The SPA embedded in Momzo is sealed.**

- The together-mode route runs with **no Supabase environment**, demo-mode style. The
  Momzo app never carries the classroom project's credentials.
- The SPA has **no network of its own**. It is bundled assets.
- Data leaves the WebView **only** through the `MomzoBridge` JavaScript channel, one-way,
  app-inbound.
- The bridge carries **no PII**: game slug, outcome buckets, counts, response times, and
  the observation strings `summary.ts` already produces from the child's in-game choices.
  No names. These games have no free-text entry.
- The bridge shim **no-ops when the channel is absent**, so the same route still works in
  a plain browser for Florie's own testing.
- **The tutoring classroom's Supabase project is permanently out of scope for the app.**
  Momzo recomputes its own progress view from `game_play_sessions`; it never reads or
  writes `reading_mastery`.

## Consequences

**Good.** Two populations of children's data stay in two systems with no path between
them. Momzo's COPPA posture is unaffected by the classroom's, and vice versa.

**Good.** A sealed subsystem is easy to reason about: one channel, one direction, an
enumerable payload.

**Good.** Florie's live teaching is unaffected by anything Momzo does, and Momzo cannot
be broken by a classroom schema change.

**Cost.** Momzo must recompute progress itself rather than reusing `reading_mastery`.
The Expansion Plan accepts this and adopts the same two-day rule from `mastery.ts` — a
skill reads as *secure* only after appearing on two different days, otherwise *emerging*.

**Cost.** Losing a shared backend means no cross-device resume within a game. For
mother-and-child play on one phone, that is not a real loss.

**Constraint on future work.** Any proposal to give the embedded SPA network access, or
to point it at either Supabase project, supersedes this ADR and needs a new one.
