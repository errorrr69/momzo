# Momzo — Expansion Plan: Content Hub · Forum · Learning Games

**Version:** v1.0 · August 2026
**For:** Claude Code · **Companions:** `Momzo_PRD.md`, `Momzo_BuildGuide.md` (§6 Hard Rules), `Momzo_AI_Cost_Strategy.md`, `Momzo_Onboarding_Personalization_Spec.md`, `BUILD_STATUS.md`
**Status:** Post-Phase-1 expansion. The core loop is live; these are the next three feature areas.

---

## 0. What this adds, and why

Momzo's goal is to make a mother's life easier — to help her understand her child and
help them the right way. This expansion widens the product from "learn + ask + bond"
to also cover:

1. **Content Hub** — every tip/advice post Florie publishes on Instagram/Facebook also
   appears inside the app, so the app becomes the calm home of all her content, not
   just the personalized daily card.
2. **Forum ("the Circle")** — a warm in-app space where moms connect and discuss.
   (Previously deferred in PRD §5.10; Florie has now decided to build it. This doc
   scopes it lean and safe.)
3. **Learning Games** — Florie's foundational-learning browser games (currently built
   for ages 5–6, used in her live sessions) integrated as a mother-and-child games
   area, organised by category (maths, reading, feelings, focus & mental development),
   with a parent dashboard: games played, how the child is progressing, and
   recommended next games. More age bands will be added later — the design must make
   that a data change, not a rebuild.

**Two repos are involved:** the Momzo app repo, and the games-browser repo. Phase A
below requires Claude Code to read both before any build decisions.

---

## Phase A — Games repo: confirmed findings & decisions

> The games repo (`errorrr69/games-for-5-6yr-olds`) **has been reviewed directly**.
> These are findings and decisions, not open questions. Claude Code's Phase-A job
> shrinks to the verification list in A4.

### A1. What the repo actually is
- **React 19 + TypeScript + Vite + react-router**, with `@supabase/supabase-js`.
  Not plain HTML games — a single SPA. Total repo ~1.5 MB; art is **code-drawn SVG**
  (`Illustrations.tsx`, `ReadingArt.tsx`, `FeelingsArt.tsx`), so the built bundle is
  tiny.
- **It is a teacher-led, two-device realtime app**: routes are `/teacher`,
  `/teacher/session/:id`, `/join/:code`, `/student/session/:id`. The teacher creates
  a session; rounds are broadcast over Supabase Realtime; the student device renders
  them. It has its **own Supabase schema** (`teacher_profiles`, `lesson_sessions`,
  `session_participants`, `game_rounds`, `game_responses`, `reading_mastery`) with
  teacher/student RLS — this is Florie's tutoring classroom, entirely separate from
  Momzo's project.
- **A demo mode already exists** (`isDemo` in `src/lib/supabase.ts`): the app runs
  with no Supabase env at all. This proves the games can run fully client-side.
- **22 games**, registered in one switch (`src/games/GameStage`):
  maths ×5 (`flash-hide, feed-monster, bond-garden, ten-frame, number-line`),
  reading ×11 (`robot-translator, sound-safari, skywriter, sound-box-factory,
  monster-lab, digraph-detectives, blend-train, magic-e-wizard, tricky-treasure,
  word-ladder, story-quest`), feelings ×6 (`feeling-thermometer, opposite-game,
  mirror-faces, scavenger-hunt, rock-buddy, freeze-dance`).
- **Round generation and difficulty are already pure functions**:
  `createRound()` / `createReadingRound()` build a round from typed per-game
  settings; `easier()` / `harder()` / `replayRound()` adjust it. Games receive a
  `GameProps` object with `onAnswer` / `onObserve` / `onRoundChange` callbacks —
  a single, uniform instrumentation point.
- **Florie's pedagogy is encoded in the modules** and must be preserved:
  `mastery.ts` ("two-day mastery… never shown to the child, never a badge, the
  software never advances a child on its own — the teacher decides") and
  `summary.ts` ("observations only — never a grade, a rank, a percentage"), which
  buckets responses as **firstTime / anotherLook / stillExploring** plus the child's
  own words as notes.

### A2. Decisions (made from the evidence)
1. **Integration = WebView + a new solo route, not a rewrite.** The one genuinely
   missing piece is that games currently *only* run inside a teacher session. Add a
   **`/play/:gameId` "together mode" route** to the games repo: it acts as a local
   teacher — default settings → `createRound()` → `GameStage` → on answer/observe,
   the **parent** gets a small control strip (**Again · Easier · Harder · Next**).
   This is deliberate: the code's own rule is that software never advances the child —
   in Momzo, *the mom holds that role*. No auto-progression.
2. **Solo route runs with NO Supabase.** It ships demo-mode style (no env, no anon
   key). The Momzo app never carries the classroom project's credentials, and
   together-mode play can never touch `lesson_sessions`/`reading_mastery` (those stay
   teacher-owned). Progress leaves the WebView **only** via the bridge (§3.4).
3. **Bundle, don't host.** The built Vite `dist/` will be well under a few MB
   (SVG-as-code, no media). Ship it as Flutter assets → offline, instant, zero
   hosting, zero cost. A hosted path can be added later if update cadence demands it.
4. **Bridge = one hook, not 22.** Instrument the solo route's callback layer once and
   emit a `summary.ts`-shaped payload per session — no per-game changes.
5. **Four display categories via the Momzo registry, no repo change.** The repo has
   three (`maths | reading | feelings`); Florie wants four. Split at the registry:
   `feeling-thermometer, opposite-game, mirror-faces` → **Feelings**;
   `freeze-dance, rock-buddy, scavenger-hunt, flash-hide*` → **Focus & mind**
   (*flash-hide stays listed in Maths, cross-tagged working-memory). Display category
   is a registry column, so Florie can re-shelve games without code.
6. **Teacher mode stays untouched.** The solo route is additive; `/teacher` and
   `/join` flows, their schema, and live-session behavior must not change. The games
   repo remains the single source of truth for game content.

### A3. Momzo-side ingestion (unchanged)
Confirm current app state against `BUILD_STATUS.md`: schema + RLS coverage guard,
tab shell, kid-mode gating, delete-child cascade, seeding conventions. Note drift.

### A4. Verification checklist before building (quick, not a research phase)
- `npm ci && npm run build && npm test` pass on the games repo; note the `dist/` size.
- The demo-mode path truly renders games with no env vars.
- Confirm `GameProps` callbacks carry enough signal for the §3.4 payload
  (`useRoundAnswer` already records correctness + `responseTimeMs`; observations
  flow through `onObserve`).
- Flag any game whose UX assumes two devices/teacher cues and needs a together-mode
  tweak (candidates: games leaning on `TeacherCues`) — list them, don't silently fix.

**Done when:** the checklist passes and the together-mode route design (control strip
+ bridge hook) is sketched for Florie's quick sign-off.

---

## 1. Feature: Content Hub (Florie's posts, in-app)

### 1.1 What it is
A feed inside the **Learn** tab (a second section alongside the daily card) showing
the tips/advice content Florie publishes on social — carousels, reels-as-cards, text
posts. The daily card stays the personalized hero; the hub is the browsable library
of everything else.

### 1.2 Data model
```
social_posts
  id uuid PK
  slug text unique              -- idempotent re-seeding, same convention as content_cards
  title text
  body text                     -- markdown
  media jsonb                   -- [{type:'image'|'video', url, alt}] (Supabase Storage)
  post_type text                -- 'carousel' | 'tip' | 'reel' | 'article'
  tags text[]                   -- same tag vocabulary as content_cards where possible
  source_url text               -- optional link to the IG/FB original
  published_at timestamptz
  published bool
```
RLS: **readable by all authenticated users, writable by admin only** — this and the
forum are the app's first shared-content tables; see §4.1 for the pattern.

### 1.3 Ingestion path
- **v1 (build now): seeder/admin script.** Florie already produces content through a
  defined workflow; add a simple idempotent seeder (slug-based, like `content_cards`)
  she can run per batch. No CMS build-out.
- **v2 (fast-follow, note but don't build):** Florie publishes to Instagram via the
  Graph API — the same publish step can write the post into `social_posts`
  automatically. Publish once, appears both places. Design the table so this needs no
  migration.

### 1.4 Behavior
- Feed sorted by `published_at`, filter chips by tag.
- Posts are **read-only** (no comments here) with an optional light reaction (💛).
  Discussion belongs in the forum — each post can show a "Talk about this in the
  Circle" link that opens/creates the matching thread (§2). One discussion home, not two.
- Media from Supabase Storage: public-read bucket for this content (it's public
  content by nature), size-capped uploads.

**Acceptance:** seeding a batch is idempotent; feed renders text + carousel posts on
device; tags filter; RLS proves non-admin cannot write; reactions record per-user
(RLS-scoped) without double-counting.

---

## 2. Feature: Forum — "the Circle"

### 2.1 Scope: lean, warm, moderated
Threads + replies. No DMs, no images in v1 (text + optional link), no algorithmic
feed. Categories seeded to match the community's rhythm and the app's topics, e.g.:
*Ask the Circle · Wins · Big feelings · School & learning · Just chatting.*

### 2.2 Data model
```
forum_categories (id, slug, title, sort, active)
forum_threads   (id, category_id, author_id, title, body, created_at,
                 last_activity_at, reply_count, hidden bool, hidden_reason text)
forum_replies   (id, thread_id, author_id, body, created_at, hidden bool)
forum_reactions (id, target_type 'thread'|'reply', target_id, user_id, kind '💛')
forum_reports   (id, target_type, target_id, reporter_id, reason, created_at,
                 resolved bool, resolution text)
forum_profiles  (user_id PK, display_name, avatar_emoji)   -- forum identity, NOT real name by default
moderators      (user_id PK)                                -- Florie initially
```

### 2.3 The RLS shift — read §4.1 first
Until now every table was family-isolated. Forum content is **shared**: readable by
all authenticated users, writable by the author, hidable by moderators. This is a new
policy pattern and it must be tested as carefully as the isolation suite —
including tests that a non-author **cannot edit or delete someone else's post** and a
non-moderator cannot hide content.

### 2.4 Safety & moderation (non-negotiable)
- **Report button** on every thread/reply → `forum_reports` → moderator queue screen
  (simple list, hide/restore/resolve). Auto-hide a post that receives N (default 3)
  reports pending review.
- **Crisis-adjacent content:** the forum is where hard things will surface. Reuse the
  existing refer-out philosophy: a pinned, warmly-written resources post; the report
  flow includes a "someone may need help" reason that pings the moderator with
  priority. The app never diagnoses and never auto-deletes a struggling mom's post —
  a human (Florie) decides.
- **Privacy defaults:** forum identity is a chosen display name + emoji avatar, not
  the account name. First-post moment shows the community rules (kindness only, no
  judgment, no selling, avoid children's full names/identifying details).
- **Tone:** all forum UI copy follows Hard Rule #18 — warm, zero shame. Community
  rules are written in the community-plan voice.
- **Honest operational note (for Florie, not code):** a forum is ongoing work —
  replies, moderation, tending. It ships last in the phasing (§5) deliberately, so it
  launches when there's a community to fill it and capacity to tend it.

### 2.5 Placement & navigation
The shell has 5 tabs (Home · Learn · Ask · Together · Me) and this expansion adds two
destinations (games, forum). Recommendation — **Option A:** restructure to
**Home · Learn · Ask · Play · Circle**, where **Play** = bonding games + learning
games, **Circle** = forum, and **Me** moves to a profile avatar in the Home header.
**Option B (smaller change):** keep the 5 tabs, put learning games inside Together,
and enter the Circle from a Home card. **Florie decides in the Phase-A memo review;**
build nothing nav-related before that.

**Acceptance:** create/read/reply/react flows work on device; shared-read RLS suite
passes (including the non-author-edit and non-moderator-hide negative tests); report
→ auto-hide at threshold → moderator restore round-trips; rules shown at first post;
no real names leak by default.

---

## 3. Feature: Learning Games (the big one)

### 3.1 What it is
Florie's foundational-learning browser games, playable in-app by mother and child
together, organised by category:

| Category | Momzo accent | Maps to Florie's practice |
|---|---|---|
| Maths | Honey | Number foundations (her maths ladder) |
| Reading | Sage | Phonemic awareness → decoding (reading ladder) |
| Feelings | Coral | Behavioral/emotional tools (dragon breath, "yet", etc.) |
| Focus & mind | Lavender | Attention, memory, self-regulation games |

Framed in-app as **Momzo Learning Games** — grounded in child development, delivered
as play. Not branded as tutoring, no session-booking links (Florie's standing
preference to keep the practice and the app separate in public-facing surfaces).

### 3.2 Age gating (5–6 now, bands later)
- `learning_games.age_min / age_max` per game. Today every game ships 5–6.
- The games area is **visible only when the family has at least one child aged 5–6**
  (per Florie's instruction). The section simply doesn't render otherwise.
  - *Option for Florie:* a soft teaser for other ages ("Learning games for
    [child]'s age are on their way 💛") costs nothing and warms up demand — say the
    word and it's a one-line change. Default: hidden.
- Adding future age bands = inserting rows with new ranges. No code change. Build the
  registry, filtering, and dashboard age-aware from day one.
- If a family has multiple children, games follow the **selected child**; sessions
  attribute to that child.

### 3.3 Architecture (confirmed — see Phase A)
- **Player:** a WebView screen (`webview_flutter`) with Momzo chrome (header, close,
  category accent) loading the games SPA's **`/play/:gameId` together-mode route**
  from **bundled Flutter assets** (the built Vite `dist/`). Games keep their own
  internal look; the chrome is Momzo.
- **Together mode (new route in the games repo):** a local round-driver built from
  the repo's existing pure functions — default per-game settings → `createRound()` /
  `createReadingRound()` → `GameStage`. A parent-facing control strip (**Again ·
  Easier · Harder · Next**, wired to `replayRound()` / `easier()` / `harder()`)
  keeps the human in charge of progression, exactly as the repo's own pedagogy
  demands. Runs with **no Supabase env** (demo-mode style) — the classroom schema
  and Florie's teacher/live-session flows are untouched and unreachable from the app.
- **Update path:** a game tweak = rebuild `dist/` + app release. Acceptable at
  current cadence; a hosted path can be added later without schema change (the
  registry's `entry_path` stays the abstraction).

### 3.4 The JS ↔ Flutter bridge contract
Flutter registers a JavaScript channel `MomzoBridge`. The **together-mode route**
(not the individual games) emits — one hook at the `GameProps` callback layer covers
all 22 games:

```js
{ event: 'game_ready',   game: 'ten-frame' }
// per answered round (from useRoundAnswer: correctness + response time exist already)
{ event: 'round_result', game: 'ten-frame',
  bucket: 'firstTime' | 'anotherLook' | 'stillExploring', responseTimeMs: 4200 }
// on exit/close — the summary.ts-shaped rollup
{ event: 'session_summary', game: 'ten-frame', durationSec: 240,
  rounds: 10, firstTime: 7, anotherLook: 2, stillExploring: 1,
  notes: ['Placed the feeling at 3', 'Chose belly breathing'] }   // child's choices, per summary.ts vocab
```

Rules:
- `session_summary` is the payload that matters; if it never arrives (app killed),
  the session still logs by open/close time. `round_result` is optional granularity.
- Payloads are stored as-is in jsonb; the dashboard reads only what it understands.
- No PII crosses the bridge: game slug, buckets, counts, and the observation
  strings `summary.ts` already produces (child's in-game choices — no names, no
  free-typed text exists in these games).
- The bridge shim **no-ops when the channel is absent**, so the route also works in
  a plain browser for Florie's own testing.

### 3.5 Data model
```
learning_games                  -- seed = the 22 games inventoried in Phase A1
  id, slug unique,              -- matches the repo's GameId ('ten-frame', 'blend-train', …)
  title, category text,         -- DISPLAY category: maths|reading|feelings|focus (per A2.5 mapping)
  age_min int, age_max int,     -- all 5–6 today
  skill_tags text[],            -- e.g. {number-pairs, decoding, working-memory, self-regulation}
  ladder_key text, ladder_step int,   -- reading games map to the repo's ReadingStage order; maths to bond ladders
  entry_path text,              -- '/play/<slug>'
  thumbnail text, active bool

game_play_sessions
  id, child_id FK, game_id FK, user_id,       -- who was driving (parent account)
  started_at, ended_at, duration_sec,
  completed bool, progress jsonb              -- raw bridge payloads, minimal retention policy
```
- RLS: `learning_games` shared-read (it's a catalog); `game_play_sessions`
  **family-isolated** like all child data, indexed on `(child_id, started_at)`.
- **Extend the delete-child cascade** to `game_play_sessions` — the existing
  zero-residual-rows verification must cover it. The RLS coverage CI guard will trip
  on these new tables by design; write the policies and tests it demands.
- Consent: play/performance data is child data → sits behind the existing consent
  gate; collect the minimum (no free text, no audio, no camera).

### 3.6 The parent dashboard ("How it's going")
Lives at the top of the games area. **For the mom, not the child** — the child sees
celebration in-game, never analytics.

**Insights (all computed by simple SQL/rules — no LLM, per the cost strategy):**
- **Played this week / lately:** which games, total together-time, by category.
- **Progress:** per game, the `summary.ts` buckets over time — **got it first time /
  wanted another look / still exploring** — always **relative to the child's own
  earlier sessions only.** Adopt the repo's two-day rule from `mastery.ts` for any
  "secure" framing: a skill reads as *secure* only after showing up on two different
  days; one great session shows as *emerging*. (Recomputed Momzo-side from
  `game_play_sessions`; the classroom's `reading_mastery` table is teacher-owned and
  is never read or written by the app.)
- **Little moments:** the observation notes the games already produce in the child's
  own choices ("Chose belly breathing", "Named frustrated") — shown as warm moments,
  never scored.
- **Strengths & growing areas:** categories/skills with the most progress vs. the
  ones least explored. Framed as exploration, not deficiency.
- **Recommended next (rule-based, in priority order):**
  1. Profile match — child's `challenges`/`focus_goals` map to `skill_tags`
     (e.g. focus struggles → focus games first).
  2. Ladder order — if `ladder_step` metadata exists, suggest the next step after
     repeated completion of the current one.
  3. Balance — least-played category in the last 14 days.
  4. Finish the fun — games started but not completed.

**Tone rules — these come from Florie's own pedagogy and are hard requirements:**
- **Compare the child only to their own previous performance.** Never peers, never
  percentiles, never "behind," never age-norm language.
- **Wrong ≠ penalty.** Low scores never render as red/failure; a dip is "still
  growing 🌱," and the copy scaffolds ("Number Pairs is a big one — little and often
  works best").
- **Always end on a win:** the dashboard's last element is always something that went
  well ("She cleared level 3 of Sound Hunt this week 💛").
- **Empty state is warm,** not a guilt nudge: "When you two play, I'll keep gentle
  notes here."
- No streaks, no daily-play pressure, no leaderboards. Hard Rule #18 everywhere.

**Acceptance (games + dashboard):**
- On a device with a 5–6-year-old profile: games area visible, categories render,
  a game opens in the WebView, bridge events land in `game_play_sessions`.
- On a family with no 5–6-year-old: games area absent, nothing broken.
- Florie's standalone browser use of the games still works untouched.
- Dashboard shows real sessions, self-comparison only (copy audit), a
  recommendation that visibly changes when the child profile's struggles change, and
  a warm empty state.
- Delete-child leaves zero game rows; RLS suite (including new tables) passes.

---

## 4. Cross-cutting build notes

### 4.1 The new shared-content RLS pattern
This expansion introduces the app's first non-family-isolated tables
(`social_posts`, `forum_*`, `learning_games`). Pattern:
- **SELECT:** any authenticated user (`auth.role() = 'authenticated'`), plus
  `published/active/hidden` predicates in the policy.
- **INSERT/UPDATE:** author only (`(select auth.uid()) = author_id`) for forum;
  admin/service only for catalogs and posts.
- **Moderator powers** via a `moderators` membership check in a `security definer`
  function (per Build Guide §3.2 — no subquery-in-policy).
- Index every policy column, as always. Add **negative tests**: non-author can't
  modify, non-moderator can't hide, non-admin can't publish. The isolation suite
  stays green for all family tables.

### 4.2 Free-tier awareness
All three features are DB reads/writes and static assets — no new AI cost (the
dashboard is rule-based; the CI guard on LLM call sites stays intact). Watch: forum
and game-session writes add row volume (fine); hosted games traffic should sit on a
CDN-backed path, not hammer the DB.

### 4.3 Docs to update at the end
`BUILD_STATUS.md` (new features + tables), `Momzo_PRD.md` §5 (forum un-deferred,
games + content hub added), Build Guide §1 note if a games host was added.

---

## 5. Phasing (each phase shippable)

**Phase A — Verify & sketch** (now small — §A4 checklist + together-mode sketch).
Quick sign-off from Florie, then build.

**Phase B — Learning Games core.** Together-mode route + bridge in the games repo ·
registry seeded with the 22 games (A2.5 category mapping) · games area UI
(categories, age gating, child switcher) · WebView player over bundled `dist/` ·
session logging · cascade + RLS tests. *The differentiator ships first.*

**Phase C — Content Hub.** Table + seeder + Learn-tab feed + reactions. Small,
high-visibility win; also produces the thread-link hook the forum will use.

**Phase D — Games dashboard.** Insights + rule-based recommendations + tone-audited
copy. (Sequenced after B so real session data exists to design against.)

**Phase E — Forum.** Schema + shared RLS + threads/replies/reactions · report +
moderation queue · rules & privacy defaults · nav placement per Florie's Option A/B
decision. *Last on purpose: it's the one feature with a standing operational cost,
and it launches best into an audience warmed up by Phases B–D.*

---

## 6. Open decisions for Florie (answer at the Phase-A checkpoint)

1. **Navigation:** Option A (Play + Circle tabs, Me → header avatar) or Option B
   (minimal change)? Recommendation: A.
2. **Games for other ages:** fully hidden (current instruction) or soft teaser?
3. **Category shelving:** confirm the A2.5 split of the six feelings-coded games
   into Feelings vs Focus & mind (easy to re-shelve later — it's registry data).
4. **Forum categories:** confirm/edit the seeded list.
5. **Content hub v2:** green-light designing the IG-publish-→-app auto-sync now
   (build later), or leave entirely manual?

*(Games delivery is settled: WebView over bundled assets, together-mode route, no
Supabase in the app's copy — see Phase A2.)*

---

*End of plan. Read both repos first, decide with evidence, ship the games, then the
content, then the Circle — and keep every word of it warm.*
