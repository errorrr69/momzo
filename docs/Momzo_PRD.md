# Momzo — Product Requirements Document

**Version:** v1.0
**Date:** June 22, 2026
**Owner:** Florie (Founder)
**Build target:** Claude Code
**Status:** Ready for build

---

## Table of Contents

1. [Overview](#1-overview)
2. [Goals & Success Metrics](#2-goals--success-metrics)
3. [User Personas & Stories](#3-user-personas--stories)
4. [Tech Stack & Architecture (summary)](#4-tech-stack--architecture-summary)
5. [Features](#5-features)
6. [AI & Knowledge Layer](#6-ai--knowledge-layer)
7. [Notifications & Reminders](#7-notifications--reminders)
8. [Data Models](#8-data-models)
9. [Auth & Permissions](#9-auth--permissions)
10. [Privacy & Child-Safety Compliance](#10-privacy--child-safety-compliance)
11. [Non-Functional Requirements](#11-non-functional-requirements)
12. [Monetization](#12-monetization)
13. [Out of Scope (this version)](#13-out-of-scope-this-version)
14. [Build Phasing](#14-build-phasing)

---

## 1. Overview

**App Name:** Momzo
**Tagline:** A few minutes a day to understand your child better — and feel closer to them.

### Problem

Mothers who want to support their child's development have to dig through an
overwhelming, low-trust ocean of social-media content to find anything useful,
and they don't have the time. Generic parenting content isn't tailored to *their*
child, and the guilt of "not doing enough" makes most parenting apps feel like one
more thing to fail at. Busy working mothers in particular struggle to find small,
reliable ways to learn about their child and stay connected when work and household
demands eat the day.

### Solution

Momzo replaces the social-media scavenger hunt with a single, calm space: curated,
bite-sized daily lessons on child development and psychology (2–3 minute reads /
slide cards), an AI "child expert" grounded in vetted knowledge that answers
in-the-moment questions, age-appropriate activities filtered by how much time a mom
actually has, and gentle bonding mechanics (shared questions, paired quizzes, a kid
wish-wall) that fit into moments that already exist — dinner, the car, bedtime.
Everything is personalized to the specific child's age, temperament, and current
struggles, so it never feels generic.

### Target Users

- **Primary — Busy mothers** of children aged 6–10 who want to support their
  child's development and stay close, but are short on time and high on guilt.
- **Secondary — The child** (6–10): a limited, safe in-app surface to add things
  they'd like to do with their parent (the "wish wall"). Always under the parent's
  account and consent.
- **Tertiary — Co-parent / caregiver** (dad, grandparent): an optional invited
  member who shares the same child profile, so connection isn't only the mother's job.

### Competitive Context

The space splits into three buckets, none of which does what Momzo does:

- **Activity / learning-content apps** (e.g., Cooper / parenting-tip apps,
  Khan Academy Kids, screen-time-replacement apps): either content *for the child*
  to consume directly, or undifferentiated tip libraries with no personalization
  and no in-the-moment help.
- **Parenting-advice / coaching apps** (e.g., Parent Lab, Big Little Feelings
  courses, AI parenting-coach chatbots): good on knowledge, but course-length and
  effortful — the opposite of "a few minutes a day," and they don't connect parent
  and child.
- **Family-organizer / calendar apps** (e.g., Cozi, FamilyWall): logistics, not
  learning or bonding.

**Market gap Momzo leans into:** *personalized, ultra-low-effort daily learning
fused with parent–child bonding mechanics.* The differentiator is not the content
library (that's table stakes) — it's (a) tailoring everything to the specific child,
(b) in-the-moment situational AI help, and (c) the two-sided bonding loop including
the child's own voice via the wish wall. Keep these three sharp; everything else is
support.

---

## 2. Goals & Success Metrics

### MVP Hypothesis

> We believe **busy mothers of 6–10 year-olds will return to Momzo several times a
> week** — and feel it's worth paying for — **because it turns "learn about and bond
> with my child" from an overwhelming, guilt-laden project into a 3-minute daily
> habit that fits their life.** We'll know this is true when a meaningful share of
> activated users are still opening the app, doing activities, and using the AI in
> week 4.

### MVP Goals

- Prove the **daily habit** forms: moms come back to read + do, not just install.
- Prove the **AI expert is trusted and used** for real questions, not a gimmick.
- Prove the **bonding loop creates emotional stickiness** (the thing that makes a
  mom keep and pay for it).
- Ship something **stable under real load** — no crashes or runaway costs as users
  grow (see Build Guide).

### MVP Success Metrics

| Metric | Target | Timeframe | Why it validates the hypothesis |
|--------|--------|-----------|----------------------------------|
| Onboarding completion (child profile created) | ≥ 70% | First session | The personalization that powers everything depends on this |
| Day-2 activation (read 1 daily card + 1 other action) | ≥ 40% | First 48h | Proves the core value lands fast |
| Week-4 retention (opened app ≥ 3 days that week) | ≥ 25% | First month | The habit is the whole bet |
| AI sessions per active user / week | ≥ 2 | First month | The expert is genuinely used |
| Activities marked "did it" / activated user / week | ≥ 1 | First month | Learning converts to action |
| Bonding action completed (shared Q, quiz, or wish scheduled) | ≥ 1 / user / week | First month | The emotional moat is real |
| AI cost per active user / month | < $0.10 | Ongoing | Economics work at scale |

---

## 3. User Personas & Stories

### Persona: Priya — the primary mom

**Who:** 34, works full-time, mother of an 8-year-old. Phone-first, on WhatsApp
constantly, almost never on a laptop for personal stuff. Feels she "should" be
doing more for her child's development but has 5 spare minutes here and there.
**Goal:** Understand her child better and have small, real moments of connection
without adding a big task to her day.
**Pain point:** Social media is a noisy, time-eating rabbit hole; generic advice
doesn't fit her specific, slightly anxious kid; she feels guilty.

**User stories**
- As a mom, I want a single 3-minute thing to read each day so I learn something
  useful without searching.
- As a mom, I want what I see to be about *my* child's age and temperament so it
  feels relevant, not generic.
- As a mom, when my kid is melting down *right now*, I want a quick, calm script to
  handle it, not an article to read later.
- As a mom, I want activity ideas I can filter by "I only have 10 minutes" so I
  actually do them.
- As a mom, I want gentle nudges — never guilt-trips — to do a small thing with my kid.
- As a mom, I want one easy way each week to feel closer to my child.

### Persona: Aarav — the child (secondary)

**Who:** 8, uses a shared/parent device with permission. Limited, playful surface.
**Goal:** Tell mom what he'd like to do together this weekend; play the
get-to-know quiz.
**Pain point:** His ideas for time together get lost in the busyness.

**User stories**
- As a kid, I want to add something I'd love to do with mom so it doesn't get
  forgotten.
- As a kid, I want to answer fun questions and see how well mom and I match.

### Persona: Sameer — the co-parent (tertiary, optional)

**Who:** Invited by the mom; shares the child profile.
**Goal:** Take part in activities and bonding so it's not all on mom.

**User stories**
- As a co-parent, I want to see the same child profile and take a turn doing an
  activity or answering the daily question.

---

## 4. Tech Stack & Architecture (summary)

> Full rationale, scaling rules, repo layout, and the "won't crash" checklist live
> in **`Momzo_BuildGuide.md`**. This is the at-a-glance version so the PRD is
> self-contained.

| Layer | Technology | Notes |
|-------|-----------|-------|
| Mobile app | **Flutter (latest stable, 3.x)** | Single codebase, iOS + Android. Mobile-first; this is a phone product. |
| Backend / DB | **Supabase (PostgreSQL 15+)** | Managed Postgres + Auth + Storage + Realtime + Edge Functions. |
| Server logic / secrets | **Supabase Edge Functions (Deno/TypeScript)** | All third-party API keys (LLM, WhatsApp) live here — never in the app. |
| AI chat | **Gemini 3.5 Flash (default)** + escalation tier (e.g. Sonnet/GPT-mid) | Routed; cheap default, stronger model for sensitive/nuanced queries. |
| AI grounding | **pgvector (Supabase) RAG** | Answers grounded in a curated, vetted knowledge base — not free-form. |
| Push notifications | **Firebase Cloud Messaging (FCM)** via Flutter | Primary, free reminder channel. |
| WhatsApp reminders | **WhatsApp Cloud API** (utility templates) | Differentiator; opt-in; pre-approved utility templates only. |
| Scheduling | **Supabase `pg_cron` → Edge Function** | Fires due reminders; sends push + (if opted in) WhatsApp. |
| Hosting | Supabase (backend); App Store + Play Store (app) | Optional small web landing on Vercel. |

### Architecture in one paragraph

The Flutter app talks to Supabase directly for ordinary reads/writes, fully
protected by Row-Level Security so the client can never see another family's data.
Anything that needs a secret key or heavier logic — AI calls, WhatsApp sends,
scheduled reminders — goes through stateless Supabase Edge Functions that connect to
Postgres via the transaction pooler. The AI expert is a retrieval-augmented system:
the user's question plus the relevant child profile is used to fetch vetted content
chunks from a pgvector store, which are passed to the LLM with a strict system
prompt and safety guardrails, so the model answers *from approved knowledge* and
escalates or refers out when appropriate.

---

## 5. Features

**Priority tiers**

- **P0 — Core. Build first.** The app cannot validate its hypothesis without these.
- **P1 — Supporting. Needed for a non-embarrassing, complete launch**, but the core
  loop can be tested without them.
- **P2 — Later.** Documented here because you asked for the full vision, but
  deliberately scheduled after launch (see Build Phasing). Building these in Phase 1
  is the main risk to stability and timeline.

> **Founder note (Florie):** You asked to include *all* features, and they're all
> here. The P-tiers are not me cutting your vision — they're the *build order* that
> keeps the app stable and gets you to real users fastest. My honest recommendation
> is to ship P0+P1 first, learn from real moms, then build P2. I've sequenced it that
> way in §14, but the call is yours.

### 5.1 Onboarding & Child Profile (the personalization engine)

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Mom sign-up / login | P0 | Table stakes | Email + social (Google/Apple) auth via Supabase Auth. |
| Child profile creation | P0 | **Differentiator** | Name/nickname, age (6–10), and a short temperament + current-struggles intake (e.g. shy, anxious, won't share, hyperactive, screen-obsessed). Drives reads, activities, and AI context. |
| Multiple children | P1 | — | Mom can add >1 child; content/activities switch per selected child. |
| Edit / update profile | P1 | — | Update struggles as the child changes; this keeps relevance high over time. |

### 5.2 Daily Learning (the habit)

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Daily card / micro-read | P0 | Table stakes | One 2–3 min read or swipeable slide set per day on child development/psychology, selected for the child's age + struggles. |
| "Why this matters to *your* child" | P0 | **Differentiator** | Each card ties the lesson to a behavior the mom actually sees at home. This is what beats generic content. |
| Save / bookmark | P1 | — | Keep favourites in a personal library. |
| Topic library / browse | P1 | — | Browse past + categorized content on demand (not just today's card). |
| Slide / card content format | P0 | — | Content supports text + image + simple slide decks (carousel). |

### 5.3 AI Child Expert (the "ask anything")

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| AI Q&A chat | P0 | **Differentiator** | Grounded chat that answers child-development/psychology questions for *this* child, citing the knowledge it used. See §6. |
| "Right now" situational mode | P0 | **Differentiator** | A mode for in-the-moment help ("he's melting down because I said no"), returning a short, calm, actionable script — not an essay. |
| Voice input | P1 | — | Speech-to-text for hands-full moments. |
| Safety escalation / refer-out | P0 | **Required** | Recognizes when something is beyond an app (possible developmental delay, safety/abuse signals, medical) and gently directs to a pediatrician/professional. Non-negotiable for trust + liability. See §6.3. |
| Suggested follow-ups | P1 | — | After an answer, offer 2–3 tap-to-ask follow-ups. |

### 5.4 Activities (learning → action)

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Activity suggestions by age + skill | P0 | Table stakes | Activities targeting a skill to build (focus, emotional regulation, confidence, motor skills) appropriate to the child's age. |
| **Time filter** (5 / 15 / 30 min) | P0 | **Differentiator** | The filter busy moms will actually use. Also filter by location (indoor/car/kitchen) and materials needed. |
| "How to do it" steps | P0 | — | Each activity has simple step-by-step guidance. |
| Mark "did it" | P0 | — | One tap to log completion; feeds streak (gentle) + weekly recap. |
| Post-activity photo + note | P1 | **Differentiator** | Optional photo/note after an activity → feeds the Memory Timeline (§5.6). |

### 5.5 Bonding & Together-Games (the emotional moat)

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Shared Question of the Day | P0 | **Differentiator** | One light question both mom and child answer; reveals each other's answers. Low effort, daily connection. |
| "How well do you know each other?" quiz | P1 | **Differentiator** | Mom and child answer the same questions separately, then reveal matches. The flagship bonding game. |
| Together mini-games / quizzes library | P1 | — | A small set of co-play games/quizzes (get-to-know, would-you-rather, etc.). |
| Audio "letters" | P2 | — | Mom and kid record short voice messages for each other / "future you." |

### 5.6 Kid Wish Wall & Playdate Scheduling (the child's voice)

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Kid wish wall | P1 | **Differentiator** | Safe, simple kid-facing surface to add things they'd like to do with a parent. Flips the dynamic so connection isn't only mom's labour. |
| Schedule a wish → calendar | P1 | — | Mom turns a wish into a scheduled "together time" on the in-app calendar. |
| Playdate / together-time reminder | P1 | **Differentiator** | Reminder fires (push + opt-in WhatsApp) ahead of the scheduled time, with a tip on how to make it special. See §7. |
| In-app calendar view | P1 | — | See upcoming together-times and activities. |

### 5.7 Reminders & Nudges

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Gentle daily nudge | P0 | — | A *kind*, non-shaming push to read today's card / do a small thing. Tone is critical (see below). |
| Activity reminder | P1 | — | Nudge to do a chosen activity, with the "how." |
| WhatsApp reminders (opt-in) | P1 | **Differentiator** | Playdate + activity reminders on WhatsApp for moms who live there. Utility templates only. See §7. |
| Quiet hours / frequency control | P0 | **Required** | Mom controls timing + frequency. Prevents nag-fatigue and uninstalls. |

> **Tone rule (applies to all nudges):** No streak-shaming, no guilt. Celebrate
> small wins ("you connected 3 days this week 🌱"); never punish a miss. A parenting
> app that makes a tired mom feel worse will be deleted.

### 5.8 Progress & Continuity

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Gentle streak / consistency | P1 | — | Soft, encouraging consistency indicator. Never harsh. |
| Memory Timeline | P1 | **Differentiator** | Scrollable, private feed of photos/notes from activities + milestones. Emotional, sticky, treasured. |
| Milestone log | P1 | — | Capture developmental wins; builds a keepsake record. |
| Weekly recap | P1 | — | "Here's what you learned + did, here's one small thing to try next week." |

### 5.9 Family Sharing

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Co-parent / caregiver invite | P2 | — | Invite dad/grandparent to share a child profile and take part. |

### 5.10 Community (explicitly deferred)

| Feature | Priority | Type | Description |
|---------|----------|------|-------------|
| Mom community / forum | P2 → **Out of Scope for now** | — | A forum risks recreating the social-media overwhelm Momzo exists to escape. If ever built: expert-moderated and small. See §13. |

---

## 6. AI & Knowledge Layer

This is the heart of the product's trust, and the part most likely to cause harm if
built naively. **The AI must not freelance parenting/medical advice from a raw model.**

### 6.1 Retrieval-Augmented (grounded) design

- Maintain a **curated knowledge base** of vetted child-development/psychology
  content (the same source material that feeds the daily cards). Store as chunked
  text with embeddings in **pgvector** inside Supabase.
- On each question: embed the question, retrieve the top-K relevant vetted chunks,
  and pass them to the LLM with the child's profile (age, temperament, struggles)
  and a strict system prompt: *answer only from the provided material + general
  well-established developmental knowledge; if the material doesn't cover it, say so;
  keep it warm, concrete, and short.*
- **Cite the source** of the answer in the UI ("based on Momzo's guide on big
  emotions") to build trust and discourage hallucination.

### 6.2 Model routing (cost + quality)

- **Default model: Gemini 3.5 Flash** (fast, cheap) for ordinary questions and
  situational scripts.
- **Escalate to a stronger model** (Claude Sonnet-class / GPT-mid) when the query is
  flagged sensitive, emotionally heavy, or low-confidence from retrieval.
- Use **prompt caching** for the large static system prompt to cut cost.
- All calls go through an **Edge Function** — keys never touch the app.

### 6.3 Safety guardrails (P0, non-negotiable)

- **Refer-out classifier:** detect signals of (a) possible developmental delay /
  clinical concern, (b) child-safety / abuse / self-harm, (c) medical issues. On
  detection, the AI does **not** attempt to advise — it responds with warmth and
  directs to the appropriate professional (pediatrician, child psychologist, local
  helpline). Log the event (without sensitive content) for review.
- **No diagnosis.** The AI never diagnoses the child. It can describe and suggest
  when to seek a professional opinion.
- **Scope fence:** the AI stays on child-development/parenting topics; politely
  declines off-topic or unsafe requests.
- **Child-directed safety:** if any AI surface is ever exposed to the child, it is
  separately locked to age-appropriate, safe behavior. (For MVP, AI is mom-facing only.)

### 6.4 Cost control

- Cap `max_output_tokens`; situational scripts are short by design.
- Cache the system prompt; retrieve tightly (small K).
- Rate-limit per user (e.g. soft cap with friendly messaging) to prevent abuse and
  runaway cost.
- Target **< $0.10 AI cost per active user per month** (see Build Guide cost model).

---

## 7. Notifications & Reminders

### 7.1 Channels

1. **Push (FCM) — primary, free.** All reminders/nudges default here.
2. **WhatsApp (opt-in) — differentiator.** For the mom who lives on WhatsApp,
   playdate + activity reminders can be delivered there.

> **Build push first.** It fully validates the reminder loop at zero marginal cost.
> WhatsApp is an enhancement (P1), not a dependency.

### 7.2 WhatsApp specifics (built from current Meta rules)

- Requires your own **WhatsApp Business Account (WABA)** and the **WhatsApp Cloud
  API** (the on-prem option is gone). You can integrate Cloud API directly or via a
  BSP (e.g. Twilio) that adds tooling for a per-message markup.
- **Reminders must be sent as pre-approved *utility* templates** (transactional),
  **never marketing.** Utility is dramatically cheaper and, in India, a small
  fraction of a cent per message. A template mis-categorized as marketing costs far
  more and can be reclassified by Meta.
- Each template must be **submitted and approved** in Meta Business Manager before
  use. Build a small set: playdate reminder, activity reminder, weekly recap nudge.
- **Opt-in is required.** Capture explicit consent to message on WhatsApp; store it;
  honor opt-out.
- Personalization (child name, time) goes in template variables.

### 7.3 Scheduling

- A **`pg_cron`** job runs on a schedule and invokes a **"send-due-reminders" Edge
  Function**, which queries reminders due in the window and dispatches push and/or
  WhatsApp. Idempotent (mark sent; never double-send).

---

## 8. Data Models

Pseudo-schema; close enough to generate Postgres migrations. **Every table has RLS**
(see §9 and Build Guide). `created_at`/`updated_at` timestamps assumed on all tables.

### users (Supabase auth.users is source of truth; profile extends it)
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK = auth.users.id |
| display_name | text | |
| role | text | 'parent' default; reserved for future |
| whatsapp_number | text | nullable; E.164 |
| whatsapp_opt_in | bool | default false |
| timezone | text | for scheduling |
| quiet_hours | jsonb | { start, end } |

### children
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| owner_id | uuid | FK users.id (the creating parent) |
| name | text | |
| age | int | 6–10 (validated) |
| temperament | text[] | e.g. {shy, anxious} |
| struggles | text[] | current focus areas |
| avatar | text | optional |

### family_members (co-parent sharing — P2)
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| child_id | uuid | FK children.id |
| user_id | uuid | FK users.id |
| relationship | text | 'parent','coparent','grandparent' |
| invited_by | uuid | FK users.id |
| status | text | 'invited','active' |

### content_cards (daily reads / slides + knowledge source)
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| title | text | |
| body | text | markdown |
| slides | jsonb | optional carousel [{image,text}] |
| age_min / age_max | int | targeting |
| tags | text[] | topics / struggles it addresses |
| why_it_matters | text | the "behavior at home" tie-in |
| source | text | attribution for trust |
| published | bool | |

### content_embeddings (RAG)
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| card_id | uuid | FK content_cards.id |
| chunk | text | |
| embedding | vector | pgvector |

### daily_assignments (which card a child sees each day)
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| child_id | uuid | FK children.id |
| card_id | uuid | FK content_cards.id |
| date | date | |
| read_at | timestamp | nullable |
| saved | bool | |

### activities
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| title | text | |
| steps | jsonb | ordered steps |
| skill | text | focus/regulation/confidence/motor |
| age_min / age_max | int | |
| duration_min | int | 5/15/30 buckets |
| location | text[] | indoor/outdoor/car/kitchen |
| materials | text[] | |

### activity_logs
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| child_id | uuid | FK children.id |
| activity_id | uuid | FK activities.id |
| user_id | uuid | who did it |
| completed_at | timestamp | |
| photo_url | text | nullable (Supabase Storage) |
| note | text | nullable |

### ai_conversations / ai_messages
| Field | Type | Notes |
|-------|------|-------|
| conversation.id | uuid | PK |
| conversation.user_id | uuid | FK |
| conversation.child_id | uuid | FK (context) |
| conversation.mode | text | 'qa' / 'situational' |
| message.id | uuid | PK |
| message.conversation_id | uuid | FK |
| message.role | text | 'user'/'assistant' |
| message.content | text | |
| message.cited_card_ids | uuid[] | for source display |
| message.flagged | text | nullable: 'refer_out' etc. |

### questions (shared question of the day + quizzes)
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| type | text | 'daily'/'know_each_other'/'game' |
| prompt | text | |
| options | jsonb | nullable |
| age_min/age_max | int | |

### question_responses
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| question_id | uuid | FK |
| child_id | uuid | FK |
| respondent | text | 'parent'/'child' |
| answer | text/jsonb | |
| answered_at | timestamp | |

### wishes (kid wish wall)
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| child_id | uuid | FK |
| text | text | what they'd like to do |
| created_by | text | 'child'/'parent' |
| status | text | 'open'/'scheduled'/'done' |

### scheduled_events (calendar)
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| child_id | uuid | FK |
| wish_id | uuid | nullable FK |
| activity_id | uuid | nullable FK |
| title | text | |
| starts_at | timestamp | |
| tip | text | "how to make it special" |

### reminders
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| user_id | uuid | FK |
| event_id | uuid | nullable FK scheduled_events |
| type | text | 'nudge'/'activity'/'playdate'/'recap' |
| channel | text | 'push'/'whatsapp' |
| send_at | timestamp | |
| sent_at | timestamp | nullable (idempotency) |
| template_name | text | for WhatsApp utility template |

### milestones
| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| child_id | uuid | FK |
| title | text | |
| note | text | |
| photo_url | text | nullable |
| date | date | |

### Relationships (summary)
- A `user` owns many `children`; a `child` can have many `family_members` (P2).
- A `child` has many `daily_assignments`, `activity_logs`, `question_responses`,
  `wishes`, `scheduled_events`, `milestones`.
- A `content_card` has many `content_embeddings`.
- A `reminder` optionally references a `scheduled_event`.

---

## 9. Auth & Permissions

### Roles
| Role | Who | Permissions |
|------|-----|-------------|
| Parent (owner) | Mom who created the account | Full control of her account, her children, and all related rows. |
| Co-parent (P2) | Invited caregiver | Access to the shared child profile and its activities/bonding rows; cannot delete the child or remove the owner. |
| Child | Uses a parent's device | **No separate login in MVP.** Reaches the wish-wall/quiz via a parent-unlocked "kid mode" on the parent's session. No independent account, minimal data. |

### Auth flow
- Supabase Auth, email + Google/Apple social login. Short-lived JWT + refresh.
- **RLS on every table**, scoped by ownership/membership (see Build Guide for the
  exact, performance-safe policy patterns — this is where apps leak data or get slow).
- Kid mode is a client-side gated view operating under the parent's session; it can
  only write `wishes` and `question_responses` for that family.

---

## 10. Privacy & Child-Safety Compliance

Momzo handles data *about children*, which triggers special obligations. Bake these
in from day one — retrofitting is painful.

- **Parent-owned, consent-based child data.** The child has no independent account;
  the parent creates and owns the child profile and consents to processing. This
  aligns with India's **DPDP Act** (verifiable parental consent for processing
  children's data; no behavioral monitoring or targeted advertising directed at
  children) and **COPPA**-style rules if you launch in the US.
- **Data minimization.** Collect only what features need. No precise location. No
  third-party ad SDKs targeting children — Momzo shows no ads to children, ever.
- **No selling data.** State this plainly in the privacy policy.
- **Photos/notes are private** to the family by default (Storage private buckets +
  signed URLs).
- **AI logs** store metadata and flags but minimize storage of sensitive free text;
  define a retention policy.
- **Right to delete.** A parent can delete the child profile and all associated data.
- **Decide launch geography early** — it determines which regime is primary. (Open
  question for Florie: India-first, or India + others?)

---

## 11. Non-Functional Requirements

| Requirement | Specification |
|-------------|--------------|
| Performance | App cold-start to usable < 3s on mid-range Android over 4G. Typical DB query p95 < 50ms (enforced via indexes + lean RLS). AI first-token < 2s. |
| Scalability | Designed for 100k+ MAU without architectural change: stateless Edge Functions, transaction-pooled DB connections, RLS-protected client reads. See Build Guide. |
| Reliability | Reminders are idempotent (never double-send). Scheduled jobs retried on failure. |
| Security | RLS on all tables; service-role key server-side only; secrets in Edge Function env, never in app; all template/LLM/WhatsApp calls server-side. |
| Cost safety | Per-user AI rate limits; utility-only WhatsApp templates; push-first reminders. Cost model in Build Guide. |
| Offline | Read-only cache of today's card + saved content; graceful offline messaging. (Full offline sync is out of scope.) |
| Observability | Slow-query monitoring (`pg_stat_statements`), error tracking, AI cost + refer-out dashboards. |
| Accessibility | Large tap targets, readable type, voice input (P1); usable one-handed. |

---

## 12. Monetization

> **Open question for Florie — flagged, not assumed.** I've specced a **freemium**
> model as the most natural fit, but you haven't decided, so treat this as a
> proposal. It mainly affects feature-gating and whether to add billing in Phase 1
> (recommendation: **don't** — validate retention first, add billing in a later phase).

### Proposed tiers
| Tier | Price | Includes |
|------|-------|----------|
| Free | ₹0 | Daily card, limited AI questions/day, basic activities, shared question of the day. Enough to form the habit. |
| Momzo+ | small monthly | Unlimited AI, full activity + game library, memory timeline, weekly recap, WhatsApp reminders, multiple children, co-parent sharing. |

### Payment stack (when added)
- In-app purchase via Apple/Google (required for digital subscriptions on mobile).
- Gate features by tier in app + enforce server-side in Edge Functions / RLS.

---

## 13. Out of Scope (this version)

Conscious cuts to protect stability, timeline, and focus. Deferred to v2+:

### Deferred features
- **Mom community / forum** — risks recreating the social-media overwhelm Momzo
  exists to escape. Revisit only as small + expert-moderated.
- **Audio "letters"** between mom and child (P2).
- **Co-parent / caregiver sharing** (P2) — adds invite flows + multi-user RLS
  complexity; not needed to prove the core mom loop.
- **Voice input for AI** (P1, but after text works well).
- **Web app** — this is a phone product; a marketing landing page is enough.
- **Therapist/expert marketplace, video courses, professional booking.**
- **Wearables, smart-home, or device-level screen-time control** (that's a different
  product).

### Deferred polish
- Dark mode, elaborate animations, custom illustration sets, gamified avatars/mascot.

### Deferred scale/ops
- Full offline sync, localization/multi-language, multi-region DB, advanced caching
  layers, in-house content CMS (seed content via migrations/admin scripts at first).

### Deferred monetization
- Subscriptions/billing — add after retention is proven.

---

## 14. Build Phasing

This sequencing is how "all the features" gets built **without** producing an
unstable 20-feature blob. Each phase is shippable and testable.

**Phase 0 — Foundation (no user-visible features yet)**
Auth, child profile schema, RLS on every table (correct + indexed), Edge Function
scaffold, secrets, push (FCM) wiring, observability. *Get the skeleton right; this is
what prevents crashes later.*

**Phase 1 — Core loop (P0) → first real users**
Onboarding + child profile · daily card with "why it matters" · grounded AI Q&A +
situational mode + safety escalation · activities with time filter + "did it" ·
shared question of the day · gentle daily nudge (push) + quiet hours.
*This validates the hypothesis. Ship to a small group of real moms here.*

**Phase 2 — Completeness (P1)**
Know-each-other quiz + games library · kid wish wall + scheduling + calendar ·
WhatsApp reminders (utility templates) · memory timeline · milestones · weekly recap
· save/library · multiple children · gentle streak.

**Phase 3 — Expansion (P2)**
Co-parent sharing · audio letters · voice input · (and only if validated) a small,
moderated community.

**Cross-cutting, every phase:** keep RLS correct + indexed, keep AI grounded +
guard-railed, keep reminders idempotent, watch AI cost and DB connections.

---

*End of PRD. Pair this with `Momzo_BuildGuide.md` for the stack rationale, the
exact scaling rules, the repo layout, the cost model, and the pre-launch checklist.*
