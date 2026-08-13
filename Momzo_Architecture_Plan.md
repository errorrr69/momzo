# Momzo — System Architecture Plan

**Version:** v1.0 · August 2026
**For:** Claude Code (implement + maintain) · **Companions:** `Momzo_BuildGuide.md`,
`Momzo_Expansion_Plan.md`, `Momzo_AI_Cost_Strategy.md`, `Momzo_OnDevice_AI_Strategy.md`,
`BUILD_STATUS.md`
**Framework:** the five architecture views from standard system-design practice
(conceptual · component · deployment · sequence · data-flow), plus the enforcement
rules that keep them true as features grow.

> **Reconciled against the code on 2026-08-13.** Sixteen statements in v1.0 did not
> match what was built; they are corrected below and each is marked ⟨corrected⟩ with
> what it used to say. Items that are agreed direction but not yet built are marked
> **Target** rather than deleted, so intent stays on record.
>
> The living copy required by §0.1 now exists at [`docs/architecture.md`](docs/architecture.md),
> and the ADR log required by §10 at [`docs/adr/`](docs/adr/). **`docs/architecture.md`
> is the file to update when a boundary changes** — this document is the spec that
> established the architecture.

---

## 0. Why this doc exists, and how it binds

Momzo is growing from a core loop into a multi-subsystem product: daily content, a
grounded AI expert, bonding games, a learning-games WebView subsystem, a content hub,
a forum, notifications, and (later) on-device AI. Without an explicit architecture,
each new feature invents its own wiring and the system rots.

**This doc is binding in three ways:**
1. The **diagrams** (§2–§6) are the agreed shape of the system. Claude Code keeps a
   live copy at `docs/architecture.md` in the repo and **updates it in the same PR**
   as any change that alters a boundary, component, or flow.
2. The **rules** (§7–§8) are constraints on every future change — same standing as
   the Build Guide's Hard Rules.
3. The **extension protocol** (§9) is the required checklist for adding any feature.
   The **ADR log** (§10) records why decisions were made so they aren't relitigated
   or accidentally reversed.

---

## 1. The five views (what each answers)

| View | Question it answers | Momzo section |
|---|---|---|
| Conceptual | What is the system, who/what does it talk to? | §2 |
| Component | What are the parts inside, and their interfaces? | §3 |
| Deployment | Where does each part physically run? | §4 |
| Sequence | How do the critical flows unfold over time? | §5 |
| Data flow | Where does data (esp. child data) come from, transform, rest? | §6 |

A well-formed view always shows: **boundaries, labeled interactions, protocols,
security measures, and error paths** — every diagram below follows that checklist.

---

## 2. Conceptual view (system context)

```
                                   ┌────────────────────┐
                                   │  Mom (primary user) │
                                   │  + child (kid mode) │
                                   └─────────┬───────────┘
                                             │ uses (HTTPS)
                                             ▼
   ┌──────────────┐   errors (HTTPS)     ┌═══════════════════┐   push (FCM)   ┌───────────┐
   │ Sentry       │◄─────────────────────║                   ║───────────────►│ Firebase  │
   │ PII-scrubbed │                      ║      MOMZO        ║                │ Cloud Msg │
   └──────────────┘                      ║  (app + backend)  ║                └───────────┘
   ┌──────────────┐   embeddings (HTTPS) ║                   ║  gen (HTTPS)  ┌───────────┐
   │ Gemini API   │◄─────────────────────║                   ║──────────────►│ Mistral   │
   │ (embeddings) │                      ╚═══════╤═══════════╝               │ small→med │
   └──────────────┘                              │                           └───────────┘
                                                 │ contains (asset bundle, no network)
                                                 ▼
                                   ┌─────────────────────────┐
                                   │ Learning-games SPA       │  ← Target
                                   │ (bundled dist/, /play/*) │
                                   └─────────────────────────┘
        OUTSIDE the boundary, never reachable from the app:
        Florie's tutoring classroom (games repo /teacher, its own Supabase project)
        Instagram/Facebook (content originates there; enters Momzo via seeding)
```

**Boundary rules:** the app talks to exactly four external services (Supabase is
*inside* the system — see §3). The learning-games SPA ships **inside** the app with
no network of its own. The tutoring classroom and social platforms are **outside**
and stay outside.

⟨corrected⟩ v1.0 listed WhatsApp Cloud API as the fourth external service and omitted
Sentry. **WhatsApp was cancelled** (task 29; `nudge_channel` is push-only) — see ADR 006.
**Sentry is a real external service** in both the app and the Edge Functions. The four
are therefore: Gemini · Mistral · Firebase FCM · Sentry.

---

## 3. Component view

### 3.1 The system's three tiers

```
┌─────────────────────────── FLUTTER APP ───────────────────────────────┐
│  features/   10 folders, FLAT (grandfathered — ADR 011)               │
│    activities · ai · bonding(+games) · daily · home · onboarding      │
│    reminders · shell · timeline · wishes                              │
│    Target: learning_games · content_hub · forum (structured, §8)      │
│  ────────────────────────────────────────────────────────────────────  │
│  services/   22 focused services (the ONLY way features reach out)    │
│    auth·child·consent·onboarding·profile·daily·library·activity       │
│    ai·game·question·quiz·wish·scheduled_event·reminder·notification   │
│    memory·recap·media·deletion·stt·tts                                │
│    Target: GamesBridgeService (WebView host + MomzoBridge)            │
│  core/       ai · env · push · routing · supabase · theme · widgets   │
│  models/     child · content_card · daily_card · activity             │
└───────────────┬───────────────────────────────┬───────────────────────┘
                │ Supabase client SDK           │ HTTPS (JWT)
                │ (RLS enforced, port 443)      ▼
                │              ┌─────────── EDGE FUNCTIONS (6) ─────────┐
                │              │ ai-chat (RAG + route + refer-out+cache)│
                │              │ generate-game-items (batched top-up)   │
                │              │ delete-child (cascade erasure)         │
                │              │ send-due-reminders (pg_cron invoked)   │
                │              │ send-push · hello-world (smoke test)   │
                │              │  — hold ALL secrets; stateless;        │
                │              │    pooler :6543, prepared stmts off    │
                │              └───────────────┬────────────────────────┘
                ▼                              ▼
┌────────────────────────────── SUPABASE (Postgres 17) ─────────────────┐
│  25 tables, RLS enabled on every one                                  │
│  Family-isolated (18)  (select auth.uid()) = owner_id / user_id       │
│    users, children, consents, daily_assignments, activity_logs,       │
│    ai_conversations, ai_messages, ai_usage, question_responses,       │
│    wishes, scheduled_events, reminders, milestones, family_members,   │
│    device_tokens, saved_cards, onboarding_state, game_play_history    │
│  Shared reference (5)  authenticated SELECT only, no client write     │
│    content_cards, activities, questions, games, game_items            │
│  Server-only (2)       RLS ON with ZERO policies — service_role only  │
│    content_embeddings, cached_answers                                 │
│  Target: game_play_sessions (family) · learning_games, social_posts,  │
│          forum_* (shared-content — new pattern, ADR 010)              │
│  + Auth · Storage (family-media PRIVATE, signed URLs)                 │
│  + pg_cron (2 jobs) · pgvector (HNSW) · pg_stat_statements            │
│  + Realtime: question_responses ONLY                                  │
└────────────────────────────────────────────────────────────────────────┘
```

⟨corrected⟩ v1.0 showed a single `SupabaseService` (there are **22** focused services), a
`kid_mode` gate in `core/` (**none exists**), five Edge Functions including a
`whatsapp-send` that was never built (**there are 6**, adding `hello-world` and
`send-push`), and Realtime on "quiz reveal + wish wall" (**only `question_responses`** is
in the publication). The table list is now the full 25, split three ways rather than two —
`content_embeddings` and `cached_answers` have RLS enabled with **no policy at all**, so
they are unreachable except by the service role. That is deliberate; do not "fix" it.

### 3.2 Interfaces (the contracts between components)

| Interface | Protocol / shape | Rule |
|---|---|---|
| features → services | Dart method calls | Features NEVER import supabase/http clients directly — **Partial: 3 of 45 files still do** (`home_screen`, `sign_in_screen`, `quiz_match_screen`); these block the §11 lint |
| app → Supabase | supabase-dart over HTTPS, anon key + JWT | Only family-isolated + shared-read tables; RLS is the guard |
| app → Edge Functions | HTTPS POST, JWT in header | Anything needing a secret or heavier logic |
| Edge Fn → Postgres | transaction pooler :6543, prepared statements off | Never direct :5432 — the one exception is the nightly `pg_dump`, which cannot run through the transaction pooler (ADR 005) |
| Edge Fn → Mistral/Gemini | HTTPS, keys in Fn env | Static-prefix prompt ordering (cost strategy §3) |
| WebView SPA → app | `MomzoBridge` JS channel, JSON events | One-way telemetry; no PII; no network in SPA |
| pg_cron → send-due-reminders | scheduled invoke | Idempotent via `sent_at` |

---

## 4. Deployment view

```
  MOM'S PHONE                          SUPABASE CLOUD (Free tier — see notes)
┌───────────────────────┐            ┌─────────────────────────────────────┐
│ Momzo Flutter app     │  HTTPS 443 │ Postgres 17 + pgvector + pg_cron    │
│  ├ Supabase SDK       │───────────►│ Supavisor pooler (:6543)            │
│  │   (persists session)│           │ Edge Functions (Deno, stateless)    │
│  ├ bundled games dist/│  ← Target  │ Auth · Storage · Realtime           │
│  └ FCM receiver       │            └───────┬───────┬───────────┬─────────┘
└──────────┬────────────┘                    │ HTTPS │ HTTPS     │ HTTPS
           │ FCM                             ▼       ▼           ▼
     ┌─────────────┐              ┌────────────┐ ┌──────────┐ ┌──────────┐
     │ Firebase    │              │ Mistral API│ │ Gemini   │ │ Sentry   │
     │ (push)      │              └────────────┘ └──────────┘ └──────────┘
     └─────────────┘
  Android only — there is no ios/ target.
  CI/CD: GitHub Actions → supabase db push · functions deploy · RLS suite
         + nightly pg_dump → off-platform storage (Free-tier backup)
         + keep-warm ping (Free-tier pause mitigation)
```

⟨corrected⟩ v1.0 showed `flutter_secure_storage` holding tokens. **It is not a
dependency** — the Supabase Flutter SDK persists the auth session itself. Sentry was
also missing from the deployment picture.

**Single-points-of-failure, named honestly:** Supabase project (mitigated by nightly
off-platform dumps + documented restore; upgrade trigger documented), Mistral API
(degrades to semantic cache + warm retry message; refer-out path is rule-based and
never depends on the LLM being up).

---

## 5. Sequence views (the three flows most likely to rot)

### 5.1 AI expert question (safety + cost path)
```
Mom → App: types question (child_id attached)
App → ai-chat Fn: POST {question, child_id} + JWT
ai-chat: verify JWT → OWNERSHIP CHECK (child belongs to caller; else 403)
ai-chat: SAFETY PRE-SCREEN (rules+classifier)
   ├─ flagged → warm refer-out response  ──────────────► App (STOP)
ai-chat: rate-limit check (after safety, never before)
   ├─ over limit → warm "later today" message ─────────► App (STOP)
ai-chat: build memory (≤3 turns history, notes, engagement)
ai-chat: embed question (Gemini) → semantic cache lookup (bucketed)
         (only when mode=qa AND the turn carries no personal context)
   ├─ hit ≥0.95 similarity → cached answer ────────────► App (STOP)
ai-chat: budget breaker
   ├─ hard → warm breaker message ─────────────────────► App (STOP)
ai-chat: pgvector retrieve (K=6) → dedupe → cite ≤3 → build name-free context
ai-chat: Mistral small (→medium if topSim <0.5 or question is sensitive)
         max tokens: 280 situational / 450 qa
ai-chat: cache write (refused if the answer contains the child's name)
         → persist msg + PII-free usage row
App ← answer + cited_card_ids → renders with source chips + 👍/👎
```

⟨corrected⟩ v1.0 said retrieval was **K=3**; it is **K=6, narrowed to at most 3
citations** (`ai-chat/index.ts:170,179`). v1.0 also placed the budget breaker outside
this flow and omitted the memory step.

⟨corrected⟩ v1.0 said the app "renders with the child's name re-inserted CLIENT-side."
**This is not implemented.** No substitution happens anywhere in the AI screens — answers
render exactly as the model produced them, saying "your child". The name appears only in
surrounding UI chrome. Keeping the name away from the model is real and verified; putting
it back afterwards is **Target** (specified in the Onboarding & Personalization spec).

### 5.2 Reminder dispatch (idempotency)
```
pg_cron (*/15 * * * *) → send-due-reminders Fn  (auth: x-cron-secret, not a JWT)
Fn → DB: SELECT reminders WHERE send_at ≤ now AND sent_at IS NULL
        AND channel = 'push' AND quiet hours honored (tz_offset_minutes)
Fn → FCM per reminder; prune dead tokens (UNREGISTERED / INVALID_ARGUMENT)
Fn → DB: UPDATE sent_at  (mark AFTER send; retried run re-sends only unsent)
Any step fails → row stays unsent → next cron picks it up. Never double-send.

The daily nudge is separately idempotent: it checks for an existing reminders row
since the user's local midnight before creating one.
```

⟨corrected⟩ v1.0 said **every 5 minutes**; the schedule is **`*/15 * * * *`**. WhatsApp
is removed (ADR 006). There is also a **second cron job** v1.0 did not mention:
`purge-expired-cached-answers` at `17 4 * * *`.

### 5.3 Learning-game session (bridge + isolation) — **Target** (Expansion Phase B)
```
Mom → App: opens game (child aged 5–6 selected)
App: WebView loads bundled /play/<slug>  (NO network, NO Supabase in SPA)
SPA: createRound() → GameStage → mom drives Again/Easier/Harder/Next
SPA → MomzoBridge: round_result{bucket, responseTimeMs} … session_summary{…}
App → DB: INSERT game_play_sessions (family RLS; jsonb payload)
App killed mid-game → session logged by open/close time (summary optional)
Dashboard reads sessions → SQL-only insights (child vs. own past ONLY)
```

---

## 6. Data-flow view (child data, privacy lens)

```
SOURCES              PROCESSES                        STORES
Mom's answers ──► Onboarding intake ───────────────► children (RLS, consent-gated
                  (resumable, 8 steps)                by DB trigger), onboarding_state
Profile edits ──► profile update (Me tab) ─────────► children.focus_goals/challenges/
                                                     interests/temperament (jsonb)
Question text ──► [refer-out screen]                 ai_messages (content)
                  →[name-free ctx]────────────────► ai_usage (NO content, NO PII)
                  →[cache bucket: age band +         cached_answers (GLOBAL; write
                    goal + challenge]                refused if it contains the name)
Game play ──────► bridge events (no names) ────────► game_play_sessions   ← Target
Photos ─────────► size-capped upload (10MB, ──────► Storage family-media PRIVATE,
                  image mime allowlist)              per-user folder, signed URLs
Forum posts ────► [display-name identity] ─────────► forum_* (SHARED store — no child
                                                     full names by rule; report path)
DESTRUCTION: delete-child → ownership check → ONE transaction:
             DELETE ai_conversations (child_id)  ← explicit: its FK is SET NULL
             DELETE children                     ← everything else CASCADEs
             → best-effort Storage purge → verified zero residual rows
NEVER FLOWS: child name → any LLM · family rows → another family ·
             app data → tutoring classroom DB · message content → logs
```

⟨corrected⟩ v1.0 named the telemetry store `ai_request_log`; the table is **`ai_usage`**.
v1.0 also showed a **weekly check-in** feeding profile updates — **that is not built**;
profile edits happen from the Me tab. The semantic answer cache was missing entirely.

**Practical note on rule 6:** joining the cascade means declaring
`child_id … references children(id) on delete cascade` in the migration. The Edge
Function needs no change — it deletes the `children` row and lets Postgres do the rest.
Only the zero-residual test must be extended.

---

## 7. Architectural rules (binding, additive to Build Guide §6)

**Layering & dependencies**
1. Dependency direction is one-way: `features → services → core`. A feature never
   imports another feature's internals; shared logic moves down into `services/` or
   `core/`. No feature imports the Supabase client or `http` directly.
2. Every external call site lives in a service class with a single responsibility.
   New third-party integration ⇒ new service + an ADR (§10).
3. Edge Functions stay **stateless**; no per-user state between invocations; secrets
   only in Fn env. Anything needing a secret is server-side, no exceptions.

**Data**
4. Every new table declares its RLS pattern **at design time**: family-isolated
   (`(select auth.uid()) = owner`) or shared-content (authed read; author/admin
   write; moderator via security-definer). There is no third pattern without an ADR.
5. Policy columns are indexed; the RLS coverage CI guard must stay green; shared
   tables get negative tests (non-author edit, non-moderator hide).
   > ✅ **Resolved 2026-08-13.** The guard previously detected tables by looking for
   > `owner_id` / `user_id`, which would have let forum tables keyed on `author_id`
   > ship **silently untested** while forcing `moderators` through a *family-isolation*
   > test that is wrong for it. It now requires **every** table in `public` to be
   > classified as family-isolated, shared-content or server-only **and** to have RLS
   > enabled. Unclassified tables, stale entries and RLS-off tables each fail the build.
6. Any table holding child data joins the delete-child cascade **in the same PR**
   that creates it, and the zero-residual test extends to it.
7. Realtime only for **`question_responses`** (the quiz reveal), always filtered to one
   family. ⟨corrected⟩ v1.0 also listed the wish wall; it is **not** in the publication.
   Adding a table to `supabase_realtime` requires an ADR.

**AI**
8. All generation flows through `AiRouter` (approved call sites only — the CI grep
   guard from the cost strategy). Safety pre-screen runs before rate limit; refer-out
   never depends on model availability; no child identifiers to any model.

**Subsystems**
9. The learning-games SPA is a sealed subsystem: bundled assets, zero network, talks
   to the app only via `MomzoBridge`. The tutoring classroom's Supabase project is
   permanently out of scope for the app.
10. Copy everywhere obeys Hard Rule #18 (warm, never shaming) — architecture includes
    error states and empty states.

---

## 8. Flutter module architecture (the shape of `app/`)

```
app/lib/
  core/        env · theme · routing · supabase client · push · ai (router + telemetry)
  models/      child · content_card · daily_card · activity
  services/    22 services — the only route outward
  features/
    <existing>/          ← FLAT. Grandfathered permanently (ADR 011)
      some_screen.dart

    <new feature>/       ← structured
      data/        repositories (call services; NO direct clients)
      widgets/     UI components
      screens/     routed pages
      state/       feature state (keep the app's existing state solution; do not
                   introduce a second state-management library — ADR required)
```

⟨corrected⟩ v1.0 implied every feature folder already had the four subfolders. **The 10
existing folders are flat and stay flat** — see ADR 011. New features (learning games,
content hub, forum) use the structure. v1.0 also listed a `kid_mode` gate and an
"analytics-free logger" in `core/`; **neither exists**. `core/ai/ai_telemetry.dart` is
the nearest thing to a logger and emits AI routing metadata only.

Conventions: feature folders are the unit of ownership; cross-feature UI goes to a
shared `widgets/` only when used by 3+ features.

**Routing — Target.** There is no router. Navigation is imperative `Navigator.push` with
inline `MaterialPageRoute`, and `core/routing/app_router.dart` holds a `Routes` class
that **nothing references** — dead code. A central router is the right destination, but
it is gated on the navigation decision in `Momzo_Expansion_Plan.md` §6 Q1 (5-tab
restructure vs. minimal change). Building one before that decision means building it
twice.

**State — Built.** No state-management package: `StatefulWidget` + `setState`, static
services, and three global `ValueNotifier`s (`ChildService.currentChild`,
`DailyService.readRevision`, `LibraryService.savedRevision`).

---

## 9. Extension protocol — adding any new feature

Run this checklist in order; it is the PR template for features:

1. **Name the boundary:** which tier(s) does it touch (app / Edge Fn / DB / external)?
   New external service ⇒ ADR first.
2. **Declare data:** new tables + RLS pattern (rule 4) + indexes + cascade membership
   (rule 6) + migration in `supabase/migrations`.
3. **Declare interfaces:** which service exposes it; Edge Fn contract if any.
4. **Walk the views:** does it change §2–§6? Update `docs/architecture.md` in the PR.
5. **Cost check:** any LLM call? → must route via AiRouter + appear in the approved
   call-site list; estimate per-user cost against the targets.
6. **Safety/tone check:** child data minimized; refer-out unaffected; copy warm.
7. **Tests:** RLS (positive + negative), idempotency where scheduled, on-device smoke.

---

## 10. ADR log (Architecture Decision Records)

Kept at [`docs/adr/`](docs/adr/); one page each: context → decision → consequences.
**Written 2026-08-13 — all eleven exist.**

| # | Decision | Why (short) |
|---|---|---|
| [001](docs/adr/001-flutter-supabase-edge-functions.md) | Flutter + Supabase + Edge Functions | one founder, one managed backend, RLS lets client talk to DB safely |
| [002](docs/adr/002-rls-everywhere-two-patterns.md) | RLS-everywhere, two patterns only | isolation by database, not app code |
| [003](docs/adr/003-mistral-generation-gemini-embeddings.md) | Mistral small→medium; Gemini embeddings | the Google key has **zero** generateContent quota; paid Mistral doesn't train on prompts |
| [004](docs/adr/004-grounded-ai-always-on-refer-out.md) | AI grounded + refer-out always-on | trust & child safety over capability; safety runs before every cost control |
| [005](docs/adr/005-supabase-free-tier-own-backups.md) | Free tier + own pg_dump + keep-warm | cost; documented upgrade triggers |
| [006](docs/adr/006-push-only-whatsapp-cancelled.md) | **Push-only; WhatsApp cancelled** | ⟨corrected⟩ v1.0 said "WhatsApp utility later". Task 29 was **cancelled** — one free channel, no template approval or per-message billing |
| [007](docs/adr/007-ai-provider-abstraction-on-device-later.md) | AiProvider/AiRouter abstraction now, on-device later | privacy/offline, not cost |
| [008](docs/adr/008-learning-games-webview-bundled.md) | Games via WebView + bundled dist + /play route | 22 working games; no rewrite; offline |
| [009](docs/adr/009-games-spa-sealed-subsystem.md) | Games SPA sealed (no Supabase in app copy) | classroom separation; privacy |
| [010](docs/adr/010-forum-shared-content-tables.md) | Forum = first shared-content tables + moderation | community decision; new RLS pattern |
| [011](docs/adr/011-grandfather-flat-feature-structure.md) | Grandfather the flat feature structure | 45-file move in a barely-tested app buys nothing visible |

New entries whenever rules 2, 4, or state-management/nav structure change.

---

## 11. Acceptance criteria (this plan is "implemented" when)

- ✅ **Done (2026-08-13).** [`docs/architecture.md`](docs/architecture.md) exists,
  containing the §2–§6 views reconciled against the code, with Built / Partial / Target
  status on every claim.
- ✅ **Done (2026-08-13).** [`docs/adr/`](docs/adr/) exists with **eleven** records —
  the ten backfilled, plus 011 for the flat-structure decision.
- ✅ **Done (2026-08-13).** `scripts/check_feature_imports.mjs` enforces rule 1, wired
  into the `app` CI job. It fails on any **new** violation, and also fails if an
  allowlisted file stops violating (so the list can't go stale). The 3 pre-existing
  violations — `home_screen`, `sign_in_screen`, `quiz_match_screen` — are **allowlisted
  with the fix each needs**, making the debt visible and bounded rather than blocking
  the guard. Retiring them needs a working Flutter toolchain to verify; see
  `docs/architecture.md` §10.
- ✅ **Done (2026-08-13).** The §9 checklist is the repo's PR template
  ([`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md)), including
  the checkbox tying boundary-changing PRs to a `docs/architecture.md` update.
- ⬜ **Outstanding.** One walkthrough proof: the next feature built (per the Expansion
  Plan) visibly follows §9, updates the diagrams, and adds its ADR if needed.

---

*End of plan. The diagrams say what the system is; the rules keep it that way; the
protocol makes every future feature pay its architectural rent up front.*
