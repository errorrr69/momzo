# Momzo — Product Requirements Document

**Version:** v2.0
**Date:** 15 August 2026 (v1.0: 22 June 2026)
**Owner:** Florie (Founder)
**Status:** Phase 1 and 2 shipped and running on device · Phase 3 partial · pre-launch

---

## 0. What changed since v1.0

v1.0 described a product that did not exist yet. This version describes one that
largely does, and is honest about the difference.

Every feature below carries a status:

| Tag | Meaning |
|---|---|
| **Built** | Working in the app today |
| **Partial** | Working with a stated gap |
| **Planned** | Agreed and specified, not yet built |
| **Cancelled** | Decided against, recorded so it is not revisited by accident |

The substantive changes from v1.0:

- **Age range widened to 4–10** (was 6–10). Content still targets 6–10; the
  bonding games and learning games reach younger.
- **Three feature areas were added** that v1.0 never contemplated: a 17-game
  bonding suite, a 22-game learning-games area, and a hybrid on-device AI layer.
- **The community was un-deferred.** v1.0 §13 explicitly cut it; it is now
  planned as "the Circle" (§5.10).
- **WhatsApp reminders were cancelled**, not postponed (§7).
- **The AI layer grew a cost architecture** — semantic answer cache, prompt
  caching, rate limits, budget breaker, per-family memory, answer feedback —
  none of which v1.0 anticipated.
- **The onboarding was rebuilt** around a structured personalisation model.
- **The backend was rebuilt** into a new Supabase project in August 2026, after
  the original became unadministrable. No feature change; worth knowing.

Companion specs remain authoritative for their areas: `Momzo_BuildGuide.md`
(§6 Hard Rules), `Momzo_Architecture_Plan.md`, `Momzo_Bonding_Games_Spec.md`,
`Momzo_Onboarding_Personalization_Spec.md`, `Momzo_AI_Cost_Strategy.md`,
`Momzo_OnDevice_AI_Strategy.md`, `Momzo_Expansion_Plan.md`.

---

## 1. Overview

**Tagline:** A few minutes a day to understand your child better — and feel
closer to them.

### Problem

Mothers who want to support their child's development have to dig through an
overwhelming, low-trust ocean of social-media content to find anything useful,
and they don't have the time. Generic parenting content isn't tailored to *their*
child, and the guilt of "not doing enough" makes most parenting apps feel like
one more thing to fail at.

### Solution

One calm space: curated bite-sized daily reads, an AI child expert grounded in
vetted knowledge, activities filtered by the time a mother actually has, games
that turn learning and connection into play, and gentle bonding mechanics that
fit into moments that already exist — dinner, the car, bedtime. Everything
personalised to the specific child.

### Target users

- **Primary — mothers of 4–10 year-olds** who want to support their child and
  stay close, short on time and high on guilt.
- **Secondary — the child**, via a limited, safe in-app surface (wish wall, kid
  mode, shared questions, both game suites).
- **Tertiary — a co-parent or caregiver.** Planned.

### MVP hypothesis

If a mother gets one genuinely personalised, trustworthy, two-minute thing each
day — and something to *do* with her child — she will come back, and she will
feel closer to her child for it.

---

## 2. Success metrics

| Metric | Target | Why it validates the hypothesis |
|---|---|---|
| Onboarding completion | ≥ 70% | Everything downstream depends on the profile |
| Day-2 activation (a read + one other action) | ≥ 40% | The core value lands fast |
| Week-4 retention (≥ 3 days that week) | ≥ 25% | The habit is the whole bet |
| AI sessions / active user / week | ≥ 2 | The expert is genuinely used |
| Activities marked "did it" / user / week | ≥ 1 | Learning converts to action |
| Bonding action / user / week | ≥ 1 | The emotional moat is real |
| AI cost / active user / month | < $0.10 | Economics work at scale |

**Measured so far:** AI cost is running at **~1–2¢ per user per month** against
the $0.10 target. The rest need real users.

---

## 3. Architecture in one paragraph

Flutter app, Supabase backend. The app reads and writes its own family's data
**directly** against Postgres, holding only the anon key, with Row-Level Security
as the access control. Anything needing a secret, a paid third party, or a
schedule goes through a **stateless Edge Function**. The app never holds a
service-role, LLM, or FCM key. Full detail in `docs/architecture.md`.

**Scale today:** 98 Dart files (~14,300 lines), 45 screens, 27 tables, 6 Edge
Functions, 973 embeddings.

---

## 4. Features

### 4.1 Onboarding & child profile — **Built**

Welcome → sign-in → COPPA consent gate → child basics (name, age 4–10) → six to
eight one-per-screen questions → personalised home.

The questions: time with child · focus goals · what feels tricky · the child's
interests · temperament (four sliders) · daily-moment time and quiet hours · what
would feel like a win *for her*.

**Resumable** — dropping out mid-flow returns to the saved step. Multiple
children supported; the profile is editable afterwards.

*Gap:* the avatar picker is decorative — no image is ever saved.

### 4.2 Daily learning — **Built**

One age- and tag-targeted card per child per day, as a two-minute read. Every card
renders the same five-part shape, so her eye learns where things are: title →
summary → the signature **"why this matters for [child]"** coral callout → the
read → **"try this tonight"** in sage. Marking as read is recorded.

Selection is rule-based and stays that way — age window, then how many of her
answers a card's tags match, then least-recently-shown. No model is in this path;
a daily card has to be explainable and instant.

A topic library (the seven shelves) and bookmarking sit alongside it.

*Content:* 147 cards — **90 purpose-written parent-facing cards for ages 5–6**
(`00_CARD_SPEC.md`), plus 57 reference-only notes that ground the AI without ever
surfacing as a daily read.

*Gap:* **the library covers ages 5–6 only.** 90 cards is about three months before
a repeat, for that band. Bands 7–8 and 9–10 are unwritten, so an older child's
parent has no daily card. This is the single largest content gap in the product.

*History:* the previous 67 parent-facing cards were ingested verbatim from
third-party articles and were removed in August 2026 — a copyright exposure in a
paid app, and content targeted 3–10 that included infant sleep training. See
[ADR 012](docs/adr/012-purpose-written-card-library.md).

### 4.3 AI child expert — **Built**

The heart of the product.

- **Grounded Q&A.** The question is embedded, the top vetted chunks retrieved via
  pgvector, and the answer written **only** from those excerpts — with the source
  cards cited beneath it.
- **"Right now" situational mode.** A short, calm, in-the-moment script.
- **Refer-out safety.** Every turn is screened across three categories —
  self-harm/abuse, medical, developmental concern. On a signal it warmly
  redirects to a professional and does not advise. It never diagnoses.
- **Memory.** The last three turns, the parent's own notes, and recent
  engagement, so a follow-up question makes sense.
- **Feedback.** Thumbs up/down on any answer; a thumbs-down retires the cached
  answer behind it for everyone.
- **Voice input** for asking by speech.

*Gap:* answers say "your child" rather than the child's name. Keeping the name
away from the model is deliberate and verified; putting it back client-side is
specified but not built.

### 4.4 Activities — **Built**

62 activities filtered by the time a mother has (5 / 15 / 30 minutes), the
child's age, and place. Step-by-step detail, and a "we did it" log with an
optional private photo and note that feeds the Memory Timeline.

### 4.5 Bonding & together-games — **Built**

**17 games** on one engine, across conversational, paired, action and
two-player-reveal types, age-banded A (4–5) / B (6–7) / C (8–10). ~40 cards per
band, 1,795 in total, with a family-scoped anti-repeat dealer and an AI top-up
that refills a bank before it runs dry.

Same-phone two-player flows, free on-device speech-to-text for Two Truths & a
Lie, and a "how to play" screen before every game. Scoring is framed as *matches
and moments* — no leaderboards, no losing state.

Alongside: a shared **Question of the Day** (30 prompts, both answer then reveal)
and a **know-each-other quiz** with a live reveal.

### 4.6 Learning games — **Built** (new in v2.0)

Florie's 22 foundational-learning games, playable by mother and child together on
one phone, on four shelves:

| Shelf | Games | Covers |
|---|---|---|
| Maths | 5 | Subitising → ten-frames → number bonds → missing part → number line |
| Reading | 11 | Phonemic awareness → letter formation → blending → segmenting → digraphs → split digraph → tricky words → fluency |
| Feelings | 3 | Naming feelings, reading faces, spotting emotion in a scene |
| Focus & mind | 3 | Self-regulation, breathing, inhibitory control |

The games are a web app **bundled inside Momzo** — offline, instant, no hosting.
The mother drives: a control strip offers **Again · Easier · Harder · Next**, and
nothing auto-advances. That is deliberate — the software never advances the
child; the grown-up decides.

Ages 5–6 today; the section is hidden entirely for families with no child that
age. Age and shelf are data, so widening either is a row, not a release.

### 4.7 Kid wish wall & scheduling — **Partial**

The child adds wishes for time together; the parent turns one into a scheduled
together-time, which creates a push reminder. An in-app calendar shows what's
coming.

*Gap:* Kid Mode has **no parent gate** — the lock badge is a back button. The
spec calls for a parent unlock before handing the phone over.

### 4.8 Reminders & nudges — **Built**

A gentle daily nudge at the mother's chosen slot, honouring quiet hours,
dispatched by a scheduled job every 15 minutes and idempotent by construction —
it can never double-send. Activity and playdate reminders ride the same path.

No guilt, no streak-shaming, ever.

*Gap:* the app registers for push but has no handler, so tapping a notification
opens the app without going anywhere specific.

### 4.9 Progress & continuity — **Partial**

- **Memory Timeline** — activity photos and notes, and milestones, as a private
  keepsake served through short-lived signed URLs. *Gap: nothing in the app ever
  writes a milestone, so that half is always empty.*
- **Weekly recap** — what the week held, days connected, a warm reflection, and
  one small thing to try next. Rule-based, never an LLM.
- **Gentle streak** — encouragement only. Never punishes a miss.

### 4.10 The Circle (community) — **Built, switched off**

Un-deferred from v1.0. Threads and replies, no DMs, no images, no algorithmic
feed. Categories along the lines of *Ask the Circle · Wins · Big feelings ·
School & learning · Just chatting*.

Identity is a chosen display name and emoji avatar — never the account name.
A report button on everything, auto-hide at a threshold pending review, a pinned
resources post, and a "someone may need help" reason that reaches a moderator
with priority. The app never auto-deletes a struggling mother's post.

Sequenced last on purpose: it is the one feature with a standing operational
cost, and it launches best into an audience that already exists. *Built and tested,
and currently HIDDEN behind `FeatureFlags.circle = false`. Not because anything
is wrong with it — 20 database tests and 10 widget tests pass and the whole loop
was verified on a device — but because a forum is the one feature with a standing
operational cost, and it launches best into an audience the rest of the app has
already warmed up. Turning it on is one line plus a moderator
(`build_forum.mjs --moderator`); the tables, policies, auto-hide and moderator
queue are already live.*

While it is off, its tab shows Florie's posts alone and is named "From Momzo".
Hiding the community must never bury the posts — they are the freshest content
in the app.

### 4.11 Content Hub — **Built**

Every tip Florie publishes on Instagram or Facebook, also inside the app, as a
browsable library alongside the personalised daily card. Read-only with a light
reaction; discussion belongs in the Circle, so a post can link to its thread
rather than growing a second comment system.

### 4.12 Learning-games dashboard — **Built**

For the mother, never the child. Which games were played, together-time by
category, and progress expressed in the games' own vocabulary — *got it first
time / wanted another look / still exploring* — always **compared only to the
child's own earlier sessions**. A skill reads as secure only after showing up on
two different days.

Recommendations are rule-based, in priority order: profile match, then ladder
order, then least-played category, then games started but not finished.

Hard tone rules: never peers, never percentiles, never "behind". A dip is "still
growing 🌱". The last thing on the screen is always something that went well.
*All of which are asserted in tests rather than left to review, because tone is
what decays quietly.*

### 4.13 Family sharing — **Partial**

Co-parent and caregiver access. Schema exists; the multi-member policy work sits
on an unmerged branch.

### 4.14 Cancelled

- **WhatsApp reminders.** Push works, costs nothing, and needed no template
  approval or per-message billing. Recorded in ADR 006.
- **Task-and-reward / chore charts.** Raised, considered, and declined: a points
  system cuts against the no-guilt principle. A warm version could be revisited,
  but not as a compliance tracker.

---

## 5. AI & knowledge layer

**Models.** Embeddings on Google Gemini `gemini-embedding-001` (768-dim).
Generation on Mistral — `mistral-small-latest` by default, escalating to
`mistral-medium-latest` only when retrieval similarity is low or the question
screens as sensitive.

**Grounding.** Answers come from vetted content only, and cite it. The corpus is
147 cards and 282 embeddings: the 90 purpose-written daily cards, plus 57
reference-only notes distilled from 25 reference books in Momzo's own voice. Every
card is Momzo's own text — nothing in the corpus is reproduced from a book or an
article. Verified end-to-end: the top retrieval hit is a new card on every question
tried, and a live answer cited three of them.

**Safety ordering is a product decision, not an implementation detail.** The
refer-out screen is cheap and runs *before* the rate limit and *before* the
budget breaker. A mother in a hard moment can never hit a cost-shaped wall — and
because the screen is rule-based, it works even if the model is completely down.

**Cost control.** Cheap-by-default routing, capped output, small-K retrieval, a
per-user rate limit, prompt-prefix caching, a semantic answer cache shared across
families in the same bucket, and a daily budget circuit breaker.

**Privacy.** The child's name is never fetched for the AI call, let alone sent.
The cache refuses to store an answer containing it.

**On-device AI — Partial.** A risk-aware router (green / amber / red) with a real
Gemini Nano path on Android and silent cloud fallback everywhere else. Red is
always cloud. Today the native bridge reports no confidence score, so only
low-risk game content can run on-device; everything else falls back by
construction. iOS is not built.

---

## 6. Notifications

**Push only.** One channel, free, idempotent, quiet-hours aware. A daily nudge at
the chosen slot, plus reminders for scheduled together-times.

Copy obeys the tone rule absolutely: celebrate small wins, never punish a miss,
never imply falling behind.

---

## 7. Data model

27 tables, RLS on every one, in three patterns:

- **Family-isolated (19)** — one family's rows, owner-only: children, consents,
  daily assignments, activity logs, AI conversations and messages, AI usage,
  question responses, wishes, scheduled events, reminders, milestones, device
  tokens, saved cards, onboarding state, and both games' play history.
- **Shared reference (6)** — readable by any signed-in parent, writable by none:
  content cards, activities, questions, and both game catalogues.
- **Server-only (2)** — content embeddings and the answer cache, reachable only
  by the service role inside an Edge Function.

Any table holding child data joins the delete-child cascade in the same change
that creates it.

---

## 8. Auth & permissions

Email sign-up and sign-in, with Google and Apple coded and awaiting credentials.
The child has **no independent account** — all data is parent-owned and
consent-gated, enforced by a database trigger that blocks child creation until a
consent record exists.

---

## 9. Privacy & child safety

Non-negotiable, and mostly enforced by the database rather than by app code:

- Child data is parent-owned, consent-first
- No ads, no third-party tracking aimed at children, no precise location
- Photos in a private bucket, served via short-lived signed URLs
- **Delete-my-child-and-all-data** — a transactional cascade with verified zero
  residual rows
- No child identifier reaches any model
- Cross-family isolation proven by a test suite that fails the build if a new
  table ships untested

---

## 10. Monetisation — **Planned**

| Tier | Includes |
|---|---|
| Free | Daily card, limited AI, basic activities, question of the day |
| Momzo+ | Unlimited AI, full activity and game libraries, memory timeline, weekly recap, multiple children, co-parent sharing |

In-app purchase via Apple and Google. Gated in the app **and** enforced
server-side. Deferred until retention is proven.

---

## 11. Roadmap

| Phase | Contents | Status |
|---|---|---|
| 0 | Foundation, auth, RLS, consent, push, erasure | ✅ Done |
| 1 | Onboarding, daily card, AI expert, activities, question of the day, nudges | ✅ Done |
| 2 | Multi-child, library, bonding games, wish wall, calendar, timeline, recap, streak | ✅ Done |
| B | Learning games | ✅ Done |
| C | Content Hub | Planned |
| D | Learning-games dashboard | Planned |
| E | The Circle | Planned |
| 3 | Co-parent sharing · audio letters · billing | Partial / planned |

---

## 12. Pre-launch blockers

None of these are feature work, and all of them gate a real launch:

1. **COPPA verifiable parental consent.** The app records a checkbox. The gate
   and audit trail exist; the *method* is not sufficient for a US launch.
2. **Privacy policy** is a draft and needs a lawyer, then publishing.
3. **Email auth runs with auto-confirm on** — re-enable confirmation, or make
   Google sign-in primary.
4. **Confirm the Mistral account is on the paid tier.** The free tier trains on
   prompts by default.
5. **Firebase** was recreated in August 2026; push works, but the original
   project is unrecoverable.
6. **Rotate credentials** exposed during the August rebuild.

## 13. Known gaps

Worth fixing before real users, none of them blocking:

- Kid Mode has no parent gate
- Nothing writes milestones
- Push has no tap handler
- The child's name is never re-inserted into AI answers
- Widespread silent error handling shows sample data on failure
- Thin app-level test coverage — the AI router is well tested, the 22 services
  are not

---

## 14. Out of scope

Web app · therapist marketplace · video courses · professional booking ·
open-ended child-to-child interaction of any kind.

---

*End of PRD v2.0. The Hard Rules in the Build Guide §6 outrank anything here.*
