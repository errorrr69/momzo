# ADR 008 — Learning games via WebView over a bundled build

**Status:** Accepted · **not yet implemented** (Expansion Plan Phase B)
**Decided:** August 2026 (`Momzo_Expansion_Plan.md` §A2, §3.3)

## Context

Florie has 22 working foundational-learning games — maths, reading, feelings — already
used in her live tutoring sessions. They are a React 19 + TypeScript + Vite SPA, with art
drawn as code (SVG components) rather than media files, so the built bundle is small.

Bringing them into Momzo had three plausible routes: rewrite them in Flutter, host the
SPA and load it remotely, or bundle the built output and run it locally.

Rewriting 22 games in Dart would take months, would fork the content so every future
game had to be built twice, and would risk losing the pedagogy encoded in the existing
modules.

The one genuinely missing capability is that the games currently run **only** inside a
teacher-led, two-device session — teacher creates a session, rounds broadcast over
Realtime, student device renders. There is no solo path.

## Decision

**WebView over a bundled `dist/`, plus one new route in the games repo.**

- Add a **`/play/:gameId` "together mode"** route to the games repo. It acts as a local
  teacher: default settings → the repo's existing pure `createRound()` /
  `createReadingRound()` functions → `GameStage`. The **parent** gets a control strip —
  **Again · Easier · Harder · Next** — wired to the existing `replayRound()`, `easier()`,
  `harder()`.
- Ship the built Vite output as **Flutter assets**. Offline, instant, no hosting, no cost.
- Instrument **one hook** at the `GameProps` callback layer, not 22 games.
- Momzo provides the chrome (header, close, category accent); games keep their own look.
- **Teacher mode is untouched.** `/teacher` and `/join`, their schema, and live-session
  behaviour must not change. The games repo stays the single source of truth for content.

**No auto-progression.** The repo's own pedagogy (`mastery.ts`) states the software never
advances a child — the teacher decides. In Momzo, the mother holds that role.

## Consequences

**Good.** 22 games arrive without a rewrite, and future games in the repo are a rebuild
away rather than a reimplementation.

**Good.** Bundled assets mean the games work with no connectivity and cost nothing to
serve.

**Good.** One instrumentation point means adding a game needs no bridge work.

**Cost.** A game tweak requires rebuilding `dist/` **and shipping an app release**.
Acceptable at current cadence. A hosted path can be added later without a schema change,
because `learning_games.entry_path` is the abstraction that would absorb it.

**Cost.** WebView adds a dependency (`webview_flutter`) and an asset bundle; neither
`assets:` nor that package currently exists in `pubspec.yaml`.

**Prerequisite.** Phase A verification — build the games repo, confirm demo mode renders
with no environment variables, and flag any game whose UX assumes two devices.
