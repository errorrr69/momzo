# Momzo — Onboarding & Personalization Spec

### Onboarding questions · personalization engine · user-state isolation

**Version:** v1.0 · June 2026
**For:** Claude Code · **Companion to:** `Momzo_PRD.md`, `Momzo_BuildGuide.md`, `Momzo_OnDevice_AI_Strategy.md`
**Status:** **Full replacement** of the current onboarding (welcome → sign-in → consent →
child basics → temperament/struggles → home). Redesign the question flow + data model +
personalization plumbing as specified here. **Keep** the existing COPPA consent gate and
auth — they slot into the flow unchanged.

---

## 0. What this delivers

1. A **short, warm onboarding** (6–8 required questions) that gives the AI enough to
   personalize day one — without the long-quiz drop-off that loses tired moms.
2. A **personalization engine**: how the collected data turns into tailored content,
   tips, activities, and AI answers.
3. **User-state isolation**: a concrete design so one family's data can never leak into
   another's, and the AI never mixes users up. (This is the "AI should remember the right
   user" requirement — solved at the database + request layer, not by trusting the model.)
4. **Progressive profiling**: how the profile deepens over time via the weekly check-in,
   so onboarding stays short but the AI keeps getting smarter about each child.

---

## 1. Design principles

- **Short first, deep later.** Required core is 6–8 questions. Everything else is optional
  and gathered gradually. She reaches the home screen fast.
- **Every question earns its place.** Each maps to a real personalization use. If a
  question doesn't change what she sees, it's cut or made optional.
- **Warm, not clinical.** No symptom checklists, no labeling a child with problems. "What
  feels tricky right now?" not "What disorders does your child have?"
- **Never-shaming tone** (Hard Rule #18) throughout; each question carries a tiny "why we
  ask" so it feels caring, not interrogating.
- **Mostly taps, some typing.** Multi-choice chips by default (fast on mobile); a typing
  "something else…" where it adds value; sliders for temperament.
- **Editable anytime.** Reassure her she can change any answer later (Me tab).
- **Resumable.** If she drops mid-flow, she resumes where she left off.
- **Child-data minimal + consented.** Collect only what personalizes; the existing
  parent-consent gate stays in front of any child data (PRD §10).

---

## 2. Onboarding flow (screen order)

```
1. Welcome           — warm one-liner: "A few minutes a day, just for [your child]."
2. Sign in / sign up — existing auth (email + Google/Apple)
3. Consent gate      — existing COPPA consent (blocks child creation until given)
4. Child basics      — Q1 (name + age)
5. Core questions    — Q2–Q8 (one question per screen, progress "3 of 8")
6. Daily moment      — Q7 sets the nudge time (the habit engine)
7. All set!          — friendly confirm: "Here's [child]'s first thing for today →" → Home
```

- Progress indicator on the core questions.
- A **Skip for now** affordance only on anything non-essential (none of Q1–Q8 are
  skippable except the free-text extras).
- After finishing, drop her straight into a personalized Home (today's card already
  chosen from her answers) so she sees the payoff immediately.

---

## 3. The questions

Two parts: **A — Required core (6–8)**, asked at onboarding; **B — Optional depth**,
gathered later (weekly check-in / "tell us more" in Me). Each question lists its
**purpose** (the personalization it drives), **type**, and **options**.

### Part A — Required core

> Copy uses the child's name once it's known (e.g. "What's tricky for Aarav right now?").

**Q1 · Child basics**
- *Purpose:* age drives content targeting + the games age-band (A 4–5 / B 6–7 / C 8–10);
  name personalizes tone.
- *Type:* text (name/nickname) + number/picker (age).
- *Note:* accept ages 4–10. Content targets 6–10; games support 4–10. Age sets the band.

**Q2 · How much time do you usually get with [child] in a day?**
- *Purpose:* sets the **default activity time-filter** (5/15/30 min) and the tone of
  nudges; calibrates expectations so suggestions feel doable.
- *Type:* single select.
- *Options:* Under 15 minutes · About half an hour · An hour or more · It really varies.

**Q3 · What would you love to help [child] with right now?**
- *Purpose:* **primary content + activity targeting** (the topics she sees first).
- *Type:* multi-select (pick up to 3) + "something else…" text.
- *Options:* Handling big feelings · Confidence & self-belief · Focus & attention ·
  Kindness & sharing · Independence & responsibility · Love of learning & curiosity ·
  Friendships & social skills · Calmer routines (sleep / meals / mornings) ·
  Screen-time balance · Creativity & imagination.

**Q4 · What feels a bit tricky at the moment?**  *(gentle reframe of "struggles")*
- *Purpose:* targeting + AI context, in everyday language — never a clinical label.
- *Type:* multi-select + optional text.
- *Options:* Big emotions / meltdowns · Takes a while to warm up / shy · Lots of energy,
  hard to settle · Gets frustrated easily · Sharing & taking turns · Listening &
  following directions · Worries or nervousness · Changes & transitions are hard ·
  Sibling moments · Honestly, nothing major right now.
- *Safety:* this is **topic tagging, not diagnosis.** If her free text describes a
  clinical or safety concern, the app responds with the warm **refer-out** (see §8), and
  does **not** try to "treat" it via content.

**Q5 · What does [child] love? (interests & hobbies)**
- *Purpose:* makes activities, game prompts, and examples feel personal to *this* child.
- *Type:* multi-select + "something else…" text.
- *Options:* Drawing & art · Building (blocks / Lego) · Sports & active play · Music &
  dancing · Animals & nature · Books & stories · Pretend & imaginative play · Puzzles &
  games · How things work / science · Video games & screens · Cooking & helping out.

**Q6 · A little about [child] (temperament)**
- *Purpose:* tunes the **tone of advice** and the **type of activities** (e.g. calmer vs
  active, solo vs social).
- *Type:* 3–4 gentle sliders / either-or. Framed "no right answer — every kid's different."
- *Dimensions:*
  - Warms up to new things: *slowly* ↔ *dives right in*
  - Energy: *calm & cozy* ↔ *always on the go*
  - Feelings: *keeps them in* ↔ *shows them big*
  - Play: *loves company* ↔ *happy on their own*

**Q7 · When should we send your daily moment?**
- *Purpose:* sets the **daily nudge** (the habit engine) + quiet hours; channel.
- *Type:* time picker + quiet-hours range; channel = Push (default; WhatsApp later).
- *Copy:* "We'll bring you one 5-minute thing for [child] at this time. Change it anytime."

**Q8 · What would feel like a win for you?**
- *Purpose:* orients **which features surface first** and the app's framing toward *her*
  goal (not just the child's).
- *Type:* multi-select (pick up to 2).
- *Options:* Feel closer to [child] · Understand [child] better · Learn practical tools ·
  Have nice things to do together · Feel less stressed or guilty · Build better routines.

### Part B — Optional depth (gathered later, never blocks onboarding)

Surfaced via the weekly check-in and a "Tell us more about [child]" card in the Me tab.
Stored in the flexible `attributes` field (§4) so adding more never churns the schema.

- **More children / siblings** — add another child profile (multi-child, §7).
- **Co-parent involved?** — seeds Phase 2 co-parent sharing.
- **Reading independently yet?** — refines games reading mode + content reading level.
- **Languages / culture at home** — relevance of examples.
- **A specific situation to focus on** — sleep · mornings · mealtimes · homework · screens · transitions.
- **What you've already tried** — so the AI doesn't suggest the obvious thing she's done.
- **How [child] likes attention** — quality time · words of praise · doing things together · little surprises (kid-friendly "love language").

---

## 4. Data model (replacement)

All tables **RLS-protected, scoped to the family** (Hard Rule #1; policy + index per §3.2
of the Build Guide). Timestamps on all.

**`profiles`** (mom-level; extends `auth.users` — keep existing, add fields)
| Field | Type | Notes |
|------|------|------|
| id | uuid | = auth.users.id |
| display_name | text | |
| time_with_child | text | Q2 bucket |
| mom_goals | text[] | Q8 |
| daily_nudge_time | time | Q7 |
| quiet_hours | jsonb | {start,end} |
| nudge_channel | text | 'push' (default) |

**`children`** (replace temperament/struggles fields with this clean shape)
| Field | Type | Notes |
|------|------|------|
| id | uuid | PK |
| owner_id | uuid | FK profiles.id |
| name | text | Q1 (used in UI; **not** sent to LLM — see §5) |
| age | int | Q1 (4–10) |
| focus_goals | text[] | Q3 |
| challenges | text[] | Q4 (everyday tags, not labels) |
| interests | text[] | Q5 |
| temperament | jsonb | Q6 slider values, e.g. {warmup:0.2, energy:0.8, expressive:0.7, social:0.4} |
| notes | text | any "something else…" free text (safety-screened) |
| attributes | jsonb | Part B optional depth (extensible) |

**`onboarding_state`** (resumability + versioning)
| Field | Type | Notes |
|------|------|------|
| id | uuid | PK |
| user_id | uuid | FK |
| child_id | uuid | FK (nullable until created) |
| step | int | last completed step (resume here) |
| completed | bool | |
| version | int | onboarding version (re-ask deltas if we add core questions) |
| completed_at | timestamptz | |

> **Why structured columns + one `attributes` jsonb:** the core fields that drive
> targeting are typed columns (queryable, indexable); optional/evolving depth goes in
> `attributes` so the schema doesn't churn each time we add a question.

---

## 5. Personalization engine — how data becomes tailored output

The profile drives four things. The mechanism is the same everywhere: **fetch the
family's data (under RLS) → build a compact "personalization context" → use it.**

### 5.1 The Personalization Context
A small, deterministic context block built **server-side, per request**, for the
selected child. Example shape (illustrative — not the child's real name):

```
Child: age 8.
Working on: handling big feelings, confidence.
Tricky right now: meltdowns around changes of plan.
Loves: drawing, animals, pretend play.
Temperament: warms up slowly, high energy, shows feelings openly, enjoys company.
Parent has ~30 min/day; wants to feel closer.
Personalize tone, examples, and suggestions to this child. Do not diagnose. If anything
suggests a clinical or safety concern, follow the refer-out guidance.
```

**Privacy rule (carry over the existing stance):** the **child's name and any identifier
are NOT included** in what's sent to the cloud LLM. Use "your child" / age + traits only.
If you want the answer to *show* the name, re-insert it **client-side** after the answer
returns. This keeps Momzo's "no child identifiers to the model" guarantee intact and is
consistent with `Momzo_OnDevice_AI_Strategy.md`.

### 5.2 Where the context is used
| Use | How the profile feeds it |
|-----|--------------------------|
| **Daily card selection** | Rule-based: filter `content_cards` by age + `focus_goals`/`challenges` tags; pick today's. No LLM needed. |
| **AI expert Q&A + situational** | Inject the personalization context into the existing `ai-chat` Edge Function alongside the RAG chunks. |
| **Activities** | Default the time-filter to Q2; rank activities by `interests` + `focus_goals` + age + temperament (e.g. active kid → more movement). |
| **Bonding games** | Age sets the band (A/B/C); `interests` bias prompt selection where relevant. |

### 5.3 Important: the AI does not "remember" — the database does
The LLM is **stateless**; it retains nothing between calls. "Remembering this mom and
child" = the app stores the profile in Supabase and **injects the right context on every
call.** This is what makes isolation enforceable (next section) rather than a hope.

---

## 6. User-state management & isolation (the "don't mix up users" requirement)

This is the explicit ask: family A's data must never reach family B, and the AI must
always act on the *current* user's child. Solved at three layers — none of which trusts
the model to keep things separate.

### 6.1 Database layer — RLS (the hard guarantee)
- Every personalization table (`profiles`, `children`, `onboarding_state`,
  `ai_conversations`, `ai_messages`, all game/activity tables) has **RLS scoped to the
  owner** (`(select auth.uid()) = owner_id`), with an index on the policy column.
- Effect: even a buggy query can only ever return the authenticated user's own rows.
  Cross-family reads are impossible at the database.

### 6.2 Request layer — stateless, ownership-checked context
- The app calls the AI through the **`ai-chat` Edge Function** carrying the user's JWT and
  a `child_id`.
- The function **verifies the `child_id` belongs to the authenticated user** (ownership
  check under RLS) **before** building any context. If it doesn't belong to them → reject.
- It then builds the personalization context **from that user's row only**, for **that
  request only.** Nothing is carried over between requests or shared across users.
- **No global/in-memory personal caches** in the Edge Function keyed in a way that could
  bleed across users. The static system prompt may be cached (it's non-personal); the
  **personalization context is never cached across users.**

### 6.3 Conversation layer — per-user history
- If the expert chat keeps history, messages live in `ai_conversations`/`ai_messages`,
  RLS-scoped to the owner. A request loads **only that user's conversation** — never
  another's. The model is sent only the current user's relevant turns.

### 6.4 Multi-child within one family
- Context is per **selected `child_id`.** Switching child switches context. Ownership is
  re-checked on every call. (One mom, two kids never cross-contaminate either.)

### 6.5 Required tests (add to the existing RLS suite)
- Building a personalization context for child X **as a non-owner** returns nothing /
  is rejected.
- An `ai-chat` request with a `child_id` not owned by the caller is **rejected** (not
  silently answered with someone else's context).
- Two concurrent requests from different users never share context (no cross-request
  state); verify the Edge Function holds no per-user state between invocations.
- The existing 15/15 cross-family isolation suite still passes with the new tables.

---

## 7. Progressive profiling, editing & multiple children

- **Weekly check-in (already planned):** asks 1–2 light questions ("What's felt tricky
  this week?", "Anything new [child]'s loving?") and **updates `challenges` / `interests`
  / `focus_goals`.** Content adapts immediately. This is how the profile deepens without a
  long initial quiz.
- **"Tell us more about [child]" (Me tab):** optional, fills Part B into `attributes`.
- **Editing:** every onboarding answer is editable from the Me tab → child profile. Edits
  re-target content/AI from the next request (no rebuild needed — context is built fresh
  each call).
- **Add / switch child:** add another child (re-runs Q1–Q8 for that child); a child
  switcher sets the active `child_id` everywhere.

---

## 8. Safety (carried through onboarding)

- **No diagnosis, ever.** `challenges` are everyday topic tags used to pick content — not
  a clinical label on the child. The AI is told this in the context block.
- **Free-text is screened.** Any typed input (Q4/Q5 "something else", notes) passes the
  existing refer-out/scope-fence screen. If it signals a clinical or safety concern, the
  app shows the warm refer-out ("this is worth raising with [child]'s pediatrician") and
  does not attempt to handle it via tailored content.
- **Data minimization.** Only collect fields that drive personalization. No address,
  school name, precise location, etc. (PRD §10).
- **Consent stays in front.** The existing COPPA consent gate continues to block child
  creation until consent exists.
- **Tone reviewed.** Every question + helper line follows Hard Rule #18 — warm, optional
  where possible, never implying she's behind or her child is a problem.

---

## 9. Onboarding UX notes (design-guide aligned)

- One question per screen; multi-choice **chips** (selected = accent fill, per the design
  guide), big tap targets, "tap to type" only where useful.
- A small **"why we ask"** line under each question (builds trust, reduces drop-off).
- **Progress** ("3 of 8") on the core set; warm Newsreader headers, cream/coral theme.
- **Reassurance** copy: "You can change any of this later."
- **Resumable** via `onboarding_state.step`.
- **Immediate payoff:** finish → land on a Home already personalized (today's card chosen
  from her answers), so the effort visibly paid off.

---

## 10. Build notes & acceptance criteria

**Build notes**
- Replace the old onboarding flow + the `children` temperament/struggles fields with the
  §4 model (migration; keep consent + auth).
- Add a single **`buildPersonalizationContext(userJwt, childId)`** helper used by
  `ai-chat` (and reused by situational mode). It does the ownership check + context build
  in one place — the isolation choke-point.
- Daily-card selection and activity ranking read the typed profile columns directly (no
  LLM).
- Keep the context **name-free** for the model; client re-inserts the name in the UI.

**Acceptance criteria**
- A new mom completes onboarding in 6–8 questions and lands on a Home personalized to her
  answers (today's card matches her `focus_goals`/age).
- Dropping mid-onboarding and reopening **resumes** at the right step.
- The AI expert's answers reflect the child's age/goals/interests **without** the child's
  name ever being sent to the model (verify in code + logs).
- Ownership tests pass: a request with another user's `child_id` is rejected; context for
  a non-owned child returns nothing; the cross-family RLS suite still passes.
- Editing a profile answer changes the next AI/content result with no redeploy.
- The weekly check-in updates the stored profile and visibly shifts content.

---

*End of spec. Short warm onboarding → structured profile in Supabase → fresh,
name-free personalization context injected per request → RLS + ownership check as the
isolation guarantee. The database remembers; the AI is simply handed the right page each
time, for the right family.*
