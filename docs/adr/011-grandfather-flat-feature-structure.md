# ADR 011 — Grandfather the flat feature structure

**Status:** Accepted
**Decided:** 2026-08-13

## Context

`Momzo_Architecture_Plan.md` §8 specifies that every feature folder contains `data/`,
`widgets/`, `screens/` and `state/` subfolders.

The app does not look like that. Its 10 feature folders are **flat** — 45 files sitting
directly inside `activities/`, `ai/`, `bonding/`, `daily/`, `home/`, `onboarding/`,
`reminders/`, `shell/`, `timeline/`, `wishes/`. The one nested folder, `bonding/games/`,
groups a subsystem rather than a layer.

Writing the rule as stated would silently mandate restructuring every screen in a
working, device-tested application. That deserved an explicit decision rather than a
document quietly implying one.

The relevant risk: the app has **two test files, covering only the AI router**, and CI
does not run `flutter test` at all. A 45-file move with roughly 31 files needing import
changes would be caught by `flutter analyze` for import errors — but not for behavioural
regressions, because nothing tests behaviour.

## Decision

**The flat structure of the 10 existing feature folders is permanent.**

**New features use the four-subfolder structure**: learning games, content hub, and
forum are built as `data/ · widgets/ · screens/ · state/`.

The codebase will have two shapes. That is accepted and recorded here so it reads as a
decision rather than as drift.

## Consequences

**Good.** Zero churn against a working app. No risk of breaking device-verified
behaviour for a change no user can perceive.

**Good.** The three largest features still to be built adopt the structure, so the
pattern is established where the code volume is going, not where it has been.

**Good.** Review attention stays on the expansion rather than on a diff of 45 moved
files.

**Cost.** Mixed conventions. A newcomer sees two shapes and must be told why — which is
what this record is for.

**Cost.** The existing flat folders keep their current weakness: no repository layer, so
screens call services directly. Three of them still import the Supabase client directly
(`home_screen`, `sign_in_screen`, `quiz_match_screen`), which is the remaining obstacle
to the rule-1 lint.

**Explicitly rejected:** migrating folders opportunistically when substantially
reworked. It sounds tidy but produces an indeterminate state where no one can predict
which shape a given folder has. Two clear rules — old is flat, new is structured — beat
a gradient.

**Revisit if:** the app gains real widget-test coverage *and* a feature is being rewritten
anyway. Superseding this needs a new ADR.
