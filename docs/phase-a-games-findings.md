# Phase A — Games repo verification & together-mode sketch

_Run 2026-08-13 against `errorrr69/games-for-5-6yr-olds` @ `main`._
_Companion to `Momzo_Expansion_Plan.md` §A4. **Needs Florie's sign-off before Phase B.**_

## Verdict

**The checklist passes, and the integration is easier than the plan assumed.** Three
of the 22 games need a together-mode decision; the other 19 need nothing. Details below.

---

## A4 checklist results

| Check | Result |
|---|---|
| `npm ci` | ✅ clean, 0 vulnerabilities |
| `npm run build` | ✅ TypeScript clean, 129 modules |
| `npm test` | ✅ **174 tests, 11 files, all passing** |
| `dist/` size | ✅ **493 kB total** (~142 kB gzipped) |
| Demo mode renders with no env | ✅ — stronger than expected, see below |
| `GameProps` carries the bridge payload | ✅ — correctness and timing already recorded |
| Games assuming two devices | ⚠️ **3 of 22** — listed below |

### Bundle size

```
dist/index.html                 0.41 kB │ gzip:   0.29 kB
dist/assets/index-*.css        50.64 kB │ gzip:  10.49 kB
dist/assets/index-*.js        442.17 kB │ gzip: 131.26 kB
```

Half a megabyte. Bundling as Flutter assets (ADR 008) is comfortably the right call —
there is no case for hosting at this size.

---

## The important finding: the game layer is already sealed

ADR 009 requires the embedded SPA to run with **no Supabase**. That isn't just
achievable — **it is already architecturally true**:

> **Neither `src/games/` nor `src/core/` imports Supabase at all.**

Supabase appears only in `src/lib/`, `src/pages/` and `src/realtime/` — the teacher
dashboard, session service, and realtime channel. The games themselves, and the round
logic that drives them, have no dependency on it.

Three further confirmations:

1. **There is no `.env` file in the repo** (only `.env.example`), so the build and the
   entire test suite already run with `VITE_SUPABASE_*` undefined.
2. **No test stubs the environment** — nothing mocks or injects Supabase config.
3. `games.test.tsx`, `reading.test.tsx` and `feelings.test.tsx` — **71 tests** — import
   `GameStage` and `createRound` directly and render games in jsdom.

So the tests already exercise **precisely the path together-mode will use**:
`createRound()` → `GameStage`, with no Supabase anywhere. That is better evidence than a
screenshot of the home page, because it covers all 22 games rather than one route.

`isDemo` also degrades every Supabase touchpoint cleanly — the dashboard auto-signs-in,
the realtime channel goes local, and the session service falls back to local storage.

> **Note on method:** I could not load the built bundle in a browser — Chrome could not
> reach the local preview server (the extension's site permissions don't appear to cover
> `127.0.0.1`). The server itself served HTTP 200 to `curl`. If you want to see it
> yourself: `cd <repo> && npm run build && npx vite preview` then open the printed URL.

---

## The bridge contract is fully supported

Everything §3.4 asks for already exists at the `GameProps` callback layer:

**Per-round.** `useRoundAnswer` (`src/games/shared.ts:88–109`) already computes both
signals the payload needs, with no game changes:

```ts
const correct = options?.correct ?? answer === round.expected
// ...
responseTimeMs: Date.now() - startedAt.current
```

**Session rollup.** `GameSummary` (`src/core/summary.ts`) is already shaped like the
planned payload — `rounds`, `firstTime`, `anotherLook`, `stillExploring`, `notes` — plus
`gotIt` / `neededAnother` from teacher observation. The only field Momzo must add is
`durationSec`, which the plan already says the app computes from open/close time.

**One integration detail worth knowing.** The buckets are not a property of an answer;
they are derived per round from whether and when it was solved
(`src/core/summary.ts:98–105`):

```
stillExploring  →  never solved
firstTime       →  solved on attempt 1
anotherLook     →  solved on a later attempt
```

So `round_result` should be emitted **when a round closes**, not on every answer —
otherwise the bucket isn't known yet. The data needed is already in the callback layer.

---

## The 3 games that need a decision

All three are cue-driven: they expect a live teacher to push an instruction. Two are
functionally blocked without one; the third works but reads oddly.

### 1. Opposite Game — **functionally blocked**

`src/games/OppositeGame.tsx:37`

```ts
const correct = option.id === cue?.expect
```

With no cue, `cue?.expect` is `undefined`, so **no answer can ever be correct**. The
screen renders a permanent waiting card: *"Get ready… ?"*. The game's premise is that
the teacher says a word and the child gives its opposite — with no one supplying the
word, there is nothing to oppose.

*Options:* have the parent control strip supply the command word, or generate it from
the round. This is a real design decision, not a tweak.

### 2. Freeze Dance — **functionally blocked**

`src/games/FreezeDance.tsx:15,50`

```ts
const commanded = cue?.state ?? 'dance'
// ...
{!cue && <p className="feedback">Wait for Florie to start the music…</p>}
```

Without a cue it sits on "dance" forever and tells the child to wait. The dance/freeze
switch **is** the game, and a teacher drives every switch.

*Options:* a game-specific parent control (Dance / Freeze) rather than the generic
Again · Easier · Harder · Next strip.

### 3. Mirror Faces — **works, but the copy assumes a video call**

Functionally fine: `cue?.headline ?? round.askFor?.label ?? 'HAPPY'` falls back to the
round's own data. But the copy says (`MirrorFaces.tsx:48`):

> *"Florie can see you on the video call. Hold it for a moment!"*

*Options:* copy-only change for together-mode.

### Related: the teacher's name is in child-facing copy

Those same three files say **"Florie"** to the child in eight places — *"Florie says"*,
*"Show Florie with your body!"*, *"You told Florie!"*. In Momzo the mother is driving,
not Florie. Whatever is decided above, this copy needs a pass.

**The other 19 games reference neither a teacher, a cue, nor a video call.** They should
work in together-mode unchanged.

---

## Together-mode route sketch

Per §A2.1, `/play/:gameId` acts as a local teacher.

```
/play/:gameId
  ├─ default per-game Settings  →  createRound() / createReadingRound()
  ├─ <GameStage game={id} round={round} … />          ← unchanged, 22 games
  ├─ parent control strip:  Again · Easier · Harder · Next
  │      wired to replayRound() / easier() / harder()   ← existing pure functions
  └─ bridge hook at the GameProps callback layer (ONE hook, not 22):
        onAnswer  ─┐
        onObserve ─┼─►  window.MomzoBridge?.postMessage(...)   ← no-ops in a browser
        round close┘
```

**No auto-progression.** The strip is the only thing that advances a round — the
software never advances the child, which is `mastery.ts`'s own rule with the mother in
the teacher's seat.

**Teacher mode untouched.** `/teacher`, `/join`, their schema and live-session behaviour
are not modified. The route is purely additive.

---

## What I need from you

1. **Opposite Game** — parent supplies the command word, or generate it from the round?
2. **Freeze Dance** — add a game-specific Dance/Freeze parent control, or drop the game
   from together-mode v1?
3. **Mirror Faces + the "Florie" copy** — reword for a parent audience? (I'd suggest
   "your grown-up", matching the bonding-games spec's family-shape-neutral rule.)

A fourth thing, not a question but a prerequisite: **the games repo currently exists here
only as a temporary clone in the session scratchpad.** Building Phase B needs a permanent
working copy, and a decision on whether the together-mode route is committed to
`errorrr69/games-for-5-6yr-olds` (recommended — it keeps that repo the single source of
truth for game content, per §A2.6).

---

## Also worth noting

The games repo has **174 tests across 11 files**. The Momzo app has **2 test files**
covering only the AI router, and CI does not run them. When Phase B joins these two
codebases, the better-tested one is the one being embedded.
