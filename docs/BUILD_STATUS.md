# Momzo — Build Status

_Last updated: 2026-08-18_

A warm Flutter + Supabase app that gives busy mothers of 4–10-year-olds a few cozy
minutes a day to understand their child better. This doc summarizes everything
built so far. The authoritative specs live in [`Momzo_PRD.md`](Momzo_PRD.md) and
[`Momzo_BuildGuide.md`](Momzo_BuildGuide.md); companion specs cover the bonding
games, on-device AI, and onboarding. The build plan + task statuses live in
Taskmaster (`.taskmaster/`).

## Status at a glance

- **Phase 1 (core loop): complete** except the ship-readiness gate (#22).
- **Phase 2 in progress:** wish→calendar (#27), playdate/activity reminders (#28),
  post-activity photos + Memory Timeline (#30) all done; weekly recap (#31) and
  gentle streak (#32) remain. WhatsApp reminders (#29) **cancelled** — push only.
- **Beyond the original plan (built from companion specs this cycle):**
  - **Together & Bonding mini-games** — a full 17-game suite (engine + content banks
    + AI top-up + per-game rules screens + same-phone & voice flows).
  - **On-device AI architecture** — risk-routed provider abstraction with a real
    Gemini Nano (AICore) path + cloud fallback + telemetry.
  - **Onboarding rebuild + personalization engine + user-state isolation.**
- The product runs **on a real Android device** (verified end-to-end, incl. push,
  the new onboarding flow, and the games).
- **Expansion (Content Hub · Learning Games · the Circle): all five phases built.**
  See `Momzo_Expansion_Plan.md`; status per phase under "The expansion" below.
- **RLS suite: 82/82** in CI, across four declared patterns. Everything committed;
  secrets git-ignored.

## Tech stack

| Layer | Choice |
|-------|--------|
| App | Flutter (single codebase; Android built & device-tested, iOS deferred) |
| Backend | Supabase (Postgres 17, Auth, Storage, Realtime, Edge Functions, pg_cron, pgvector) — **Free tier** |
| AI — embeddings | Google **Gemini** `gemini-embedding-001` (768-dim) |
| AI — generation | **Mistral** (`mistral-small` default → `mistral-medium` escalation) |
| Push | Firebase Cloud Messaging (FCM HTTP v1) |
| Project | Supabase ref `uwpmwqsxqociiojeauuk`; Firebase project `momzo-3a942`; Android package `app.momzo` |

**Architecture:** the app talks to Supabase **directly** for ordinary reads/writes,
protected by Row-Level Security (anon key only). Anything needing a secret (AI keys,
FCM, cascade delete) goes through a **stateless Edge Function** on the 6543
transaction pooler. The app never holds a service_role / LLM / FCM key.

---

## What's built

### Foundation & security (Phase 0)
- **Monorepo** (`app/`, `supabase/`, `docs/`, `.github/`) with CI (analyze/test, migrations, RLS suite, function deploy).
- **Database schema** — 18 tables (PRD §8) via versioned migrations only.
- **Row-Level Security on every table**, direct-comparison policies (`(select auth.uid()) = owner_id`) with an index on every policy column.
- **RLS cross-family test harness** (`supabase/tests/`) — proves no family can read/write another's rows across all 18 family tables, plus a coverage guard that fails CI if a new table is added untested. **20/20 passing.**
- **Auth** — email sign-up/sign-in; profile upserted on first sign-in. (Google/Apple wired in code, disabled pending OAuth credentials.)
- **Edge Function scaffold** — shared pooled DB client, JWT verify, PII-free logging, CORS.
- **COPPA consent gate** — a `consents` record + a DB trigger that **blocks child creation until consent exists** (enforced server-side, can't be bypassed).
- **Delete-my-child-and-all-data** — ownership-checked Edge Function, transactional cascade across every table (+ best-effort Storage), verified zero residual rows.
- **FCM push** — Android client registers device tokens; server sends via service-account → Google OAuth → FCM v1. **Verified delivering to a real phone.**

### Core loop (Phase 1)
- **Onboarding → child profile (rebuilt — see Onboarding & Personalization below)** — welcome → sign-in → consent → child basics (name, age **4–10**) → a short 6–8 question flow → personalized home.
- **Daily card** — one age/struggle-targeted card per child per day, shown as a micro-read with the signature **"why it matters"** tie-in; "mark as read" recorded.
- **AI expert** (the heart of the app):
  - **Q&A** — embeds the question, retrieves top vetted chunks via pgvector, answers **only** from approved knowledge, **cites the source cards**.
  - **"Right now" situational mode** — a short, calm in-the-moment script.
  - **Refer-out safety** — every turn screened across 3 categories (self-harm/abuse, medical, developmental concern); warmly redirects to a professional, never diagnoses. Off-topic requests are scope-fenced.
  - **Cost controls** — cheap-by-default model routing, token caps, small-K retrieval, per-user rate limit; model + token usage logged for a cost dashboard.
- **Activities** — 62-activity library filtered by the time a mom has (5/15/30) + age + place; step-by-step detail; "we did it" logging with an **optional photo (now live — private Storage)** + note.
- **Question of the Day** — 30 prompts; today's question is shared by parent + child, each answers, then a side-by-side reveal.
- **Gentle daily nudge + quiet hours** — pg_cron → Edge Function dispatches a kind daily nudge at the user's chosen slot, honors quiet hours, idempotent (never double-sends). No guilt/shame.
- **Tone** — every screen + server copy reviewed: no guilt, shame, or streak-pressure (Hard Rule #18).
- **App shell** — boots like a real app (auth-routed: returning users land in Home), with a working 5-tab bottom nav (Home · Learn · Ask · Together · Me).

### Onboarding & Personalization (rebuild)
_(Onboarding & Personalization spec — full replacement of the old temperament/struggles flow.)_
- **Short, warm onboarding** — Q1 basics (name, age 4–10) then **6–8 one-per-screen questions** (time-with-child, focus goals, what's tricky, interests, temperament **sliders**, daily-moment time + quiet hours, her own "win") with a progress bar, chips, and a "why we ask" line. **Resumable** — drops mid-flow resume at the saved step (`onboarding_state`).
- **Structured profile** — `children` now carries `focus_goals[]`, `challenges[]`, `interests[]`, `temperament` (jsonb sliders), `notes`, `attributes` (extensible); `users` carries `time_with_child`, `mom_goals[]`, `daily_nudge_time`, `nudge_channel`. Existing data was migrated, not dropped. Profile editable from the Me tab.
- **Personalization engine** — one server-side `buildPersonalizationContext(jwt, childId)` builds a **name-free** context (age/goals/challenges/interests/temperament + parent goals) injected into `ai-chat`; daily-card targeting reads the typed columns directly.
- **User-state isolation** — that helper is the choke-point: it **verifies ownership** and rejects a `child_id` that isn't the caller's (verified: 403, no leak). Cross-family RLS suite still 20/20.

### Together & Bonding mini-games
_(Bonding Games spec — 17 games on one engine.)_
- **Engine** — global `games` catalog + per-band `game_items` content banks + a family-scoped anti-repeat dealer (unseen-first, cooldown, shuffle), all RLS-scoped.
- **17 games** across conversational, paired, action, and 2-player-reveal types, age-banded A/B/C. Each has **~40 cards/band** (30 for action games); content seeded + safety-filtered (§1.4).
- **Per-game rules screen** — one reusable `GameRulesScreen` shown before every game ("how to play" → Start).
- **Same-phone 2-player** — How Well Do You Know Me? + Guess My Answer use a pass-the-phone flow (answer hidden → hand-off → second answer → reveal side-by-side).
- **Two Truths & a Lie** — free **on-device speech-to-text** (falls back to typing) to enter three statements; the other guesses; gentle reveal. Band A = "Two Real, One Silly".
- **AI top-up** — `generate-game-items` Edge Function refills a bank when a family nears the end (Mistral, screened, de-duped, cached globally). A `verify_game_banks.mjs` guard fails CI if any playable game has an empty bank for a supported band.

### On-device AI architecture (hybrid)
_(On-Device AI Strategy spec — built behind a clean abstraction so it degrades to cloud everywhere.)_
- **`AiProvider` seam** — all generation routes through one risk-aware `AiRouter` (green/amber/red). Red (sensitive/expert) is **always cloud**; the refer-out screen runs regardless of brain.
- **Capability probe + `OnDeviceProvider`** — native bridge checks for Android **AICore (Gemini Nano)**; a real `GenerativeModel.generateContent` path is wired and runtime-guarded (API 31+). On the large majority of phones the probe reports unavailable and everything **silently uses cloud** — no user-visible downgrade.
- **Guards** — amber confidence gating, a post-answer safety screen (discards sensitive on-device output → cloud), and cloud fallback on any decline/failure; game items pass the §1.4 filter.
- **Telemetry** — PII-free per-answer routing metadata (source / fell_back / refer_out / latency). 22 unit tests cover the table, guards, fallback, and the real-engine channel contract. (Live Nano inference needs an allowlisted device to exercise; iOS Foundation Models deferred.)

### Scheduling, reminders & memories (Phase 2)
- **Wish → calendar (#27)** — turn a child's open wish into a scheduled together-time (day/time picker → `scheduled_events`, wish flips to "scheduled"); an in-app calendar shows what's coming up.
- **Playdate/activity reminders (#28)** — scheduling auto-creates a push reminder ahead of the event that the live `send-due-reminders` cron delivers (idempotent, quiet-hours-aware).
- **Private media + Memory Timeline (#28 photo + #30)** — a private `family-media` Storage bucket (per-user RLS, 10 MB cap, image-only) holds post-activity photos; the **Memory Timeline** aggregates activity photos/notes + milestones, served via short-lived **signed URLs** (never public).

### Knowledge base / content
- **147 content cards / 282 embeddings**, feeding both the daily card and RAG.
  - **90 purpose-written cards (ages 5–6)** to `00_CARD_SPEC.md`'s fixed five-part
    structure — Momzo's own words, replacing the scraped article corpus (ADR 012).
  - **57 `reference_only` notes** (ages 7–10), AI-visible, never shown to a parent.
- **12 Content Hub posts**, written to Florie's typographic post guide.
- **62 activities**, **30 questions**, **22 learning games**, **5 forum categories**.
- All seeders are idempotent (slug-based) and re-runnable as content grows.

### The expansion (Content Hub · Learning Games · the Circle)
- **Phase A — verify & sketch.** Findings in `docs/phase-a-games-findings.md`.
- **Phase B — Learning Games.** 22 games shelved into four display categories,
  played in a WebView over a bundled 493 KB SPA build, with a one-way JS bridge
  (`MomzoBridge`) writing outcome buckets to `game_play_sessions`.
- **Phase C — Content Hub.** `social_posts` + `post_reactions`, an idempotent
  seeder, and a feed in the Learn tab with tag chips and a private 💛.
- **Phase D — games dashboard.** "How it's going": rule-based insights, Florie's
  two-day rule for "Got this", and four ordered recommendation rules. No LLM.
- **Phase E — the Circle.** Threads, replies, reactions, reports, auto-hide at
  three, and a moderator queue. The app's first shared-authored RLS pattern.

### Edge Functions deployed
`hello-world` (template) · `ai-chat` (RAG Q&A + situational + refer-out + routing + name-free personalization) ·
`generate-game-items` (mini-game bank AI top-up) · `delete-child` (cascade erasure) ·
`send-push` (test/sender) · `send-due-reminders` (cron dispatcher).

---

## Verified

- RLS suite: **82/82**, in CI. Every public table is classified into one of four
  patterns and the coverage guard fails on any table that is not: family-isolated,
  shared-content (read-only catalog), server-only (RLS on, zero policies), and
  shared-authored (the Circle — mothers write rows other mothers read).
- **Flutter tests: 94**, `flutter analyze`: **0 errors**.
- Per-feature backend smoke tests (run as the real signed-in user, RLS enforced): auth, consent gate, child creation (age 4–10), daily-card targeting + read, AI (grounded + citations + refer-out battery + cost routing), **personalization ownership/isolation (own child answered, other user's child → 403)**, **full onboarding write-path** (all fields + profile + resumable state), activities query + log, **photo upload + signed-URL read + cross-user denial**, **wish→event→reminder→status flip**, question reveal, push delivery, reminder dispatch (idempotency + quiet hours), **game deal + bank coverage guard (17/17)**.
- **On-device (real Android phones):** boots to Home with real data; daily card; AI grounded answer + citations; FCM notification; **new 8-question onboarding renders & saves**; **Together → 17 mini-games, per-game rules screen → Start, games show cards**.
- AI layer: **22 unit tests** (routing table, guards, fallback, telemetry, real-engine channel contract). `flutter analyze`: 0 errors.
- Bugs found on-device and fixed this cycle: `WhyItMatters` layout crash; nav/action bars behind the system bar; **Time Machine row overflow** (caught by golden render); **blank games** — root-caused to AI top-up writing **double-encoded jsonb payloads** (fixed at 3 layers: Edge Function `sql.json()`, data repair of 60 rows, resilient `GameItem.fromMap`).

---

## Hardening pass (2026-06-26)

A dedicated hardening pass addressed the highest-risk pre-launch items:
- **✅ Task 1 — Corpus & citation integrity:** self-healing, idempotent re-seed;
  deduped (66 cards / 780 embeddings); permanent integrity check wired into CI.
- **✅ Task 2 — Survive Supabase Free:** automated daily off-platform `pg_dump`
  backup (verified) + keep-warm + documented restore & upgrade triggers
  ([`OPERATIONS.md`](OPERATIONS.md)).
- **✅ Task 4 — Observability:** Sentry in app + functions (PII-scrubbed, IP nulled —
  both test events verified in `momzo-app`); `pg_stat_statements`; `ai_cost_summary`
  view (verified).
- **✅ Task 5 — Mistral cost/training:** ~1–2¢/user/mo (< $0.10 target); paid API not
  trained on; no child identifier reaches the LLM ([`AI_COST_AND_PRIVACY.md`](AI_COST_AND_PRIVACY.md)).
- **✅ Task 6 — Privacy/consent (US/COPPA):** draft policy + verifiable-consent plan
  ([`legal/PRIVACY_POLICY_DRAFT.md`](legal/PRIVACY_POLICY_DRAFT.md), [`legal/CONSENT_PLAN.md`](legal/CONSENT_PLAN.md)).
- Repo now lives on GitHub (private) with CI running (app analyze + RLS + integrity).

## Known caveats & pre-launch blockers

Still open, **must be addressed before real users**:
- **Email auth** runs with auto-confirm ON — re-enable real confirmation **or** make
  **Google sign-in** the primary login (recommended; already coded). _(Task 3, deferred.)_
- **COPPA verifiable consent** — still `parent_attestation`; the upgrade is **planned
  but not built** (see `legal/CONSENT_PLAN.md`). Required for a US launch.
- **Privacy policy** is now a **DRAFT** (`legal/PRIVACY_POLICY_DRAFT.md`) — needs
  lawyer review + publishing.
- **Gemini key** has `generateContent` quota = 0 (why generation runs on Mistral);
  embeddings are unaffected. _(Informational, not a blocker.)_
- **Sentry geo** — IP is scrubbed; Sentry still derives a city-level geo (minor).
- **iOS** push/build deferred (needs paid Apple Developer account + APNs). On-device
  AI on iOS (Foundation Models) is also iOS-only and not yet built.
- **On-device Gemini Nano** generation is wired + compiles against the real AICore SDK
  but **live inference is unverified** — it needs an allowlisted device (Pixel 8+/Galaxy
  S24-class); every other phone falls back to cloud (the verified path).
- **The card library covers ages 5–6 only.** 90 cards is roughly three months before
  a repeat, for that band alone. A 7-year-old's parent currently gets no daily card;
  bands 7–8 and 9–10 have to be written before those ages can be sold to. This is
  the largest content gap in the product.
- **A release build without `--dart-define-from-file=env.json` does not fail** — it
  boots, looks normal, and runs in UI-only mock mode with no backend. It shipped
  that way once. Always build with the flag.
- **The Circle has no moderator by default.** `build_forum.mjs --moderator <email>`
  grants one. Without it, auto-hide still fires but nothing is ever reviewed, so
  hidden content stays hidden. The seeder warns loudly when the table is empty.
- **The Circle is untested with real traffic** and carries a standing operational
  cost — replies, moderation, tending. It is built, not launched.

## What's next

- **#22 Ship-readiness gate** — final pre-launch checklist (last Phase-1 task), incl.
  resolving the COPPA caveat (pseudonymize server-side or move `ai-chat` to paid tier).
- **Phase 2 remainder:** weekly recap (#31), gentle streak (#32).
- **Phase 3** (#33–37): co-parent sharing, audio letters, voice input, billing.
  (Community is now built — see the Circle.)
- **Nav decision, open for Florie** (Expansion Plan §2.5 / §6.1): Option A moves to
  Home · Learn · Ask · Play · Circle with Me in the header; Option B keeps five tabs
  and enters games and the Circle from Together. **Option B is what is built**,
  because §2.5 says to build nothing nav-related before she decides. It gets harder
  to change the longer both features live inside Together.
- **Content Hub v2** (§6.5): publishing to Instagram via the Graph API could write
  `social_posts` in the same step. The table is designed for it; nothing is built.
- **On-device AI Phase 2b/3:** light up on-device for situational/expert once games are
  proven on capable hardware; iOS Foundation Models path.
- Pending UX tweaks: onboarding question copy (per user feedback); sign-out + a
  manage/delete-child entry point on the **Me** tab (the delete-child screen exists
  but has no in-app entry point yet).
