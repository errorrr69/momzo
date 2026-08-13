# Momzo — System Architecture (living document)

_Last reconciled against the code: 2026-08-13._

This is the **living** architecture. `Momzo_Architecture_Plan.md` is the spec that
established it; this file is what the system actually is, and it is the file §9 of that
plan requires updating in the same PR as any change that alters a boundary, component,
or flow.

## Status tags

Every claim below carries one, so the document can never overstate what exists:

| Tag | Meaning |
|---|---|
| **Built** | True today, verified in the code |
| **Partial** | True with the stated caveat |
| **Target** | Agreed direction, not yet built — with what gates it |

Untagged prose is descriptive context, not a claim about implementation.

---

## 1. Conceptual view (system context)

```
                              ┌──────────────────────┐
                              │  Mom (primary user)  │
                              │  + child (kid mode)  │
                              └──────────┬───────────┘
                                         │ uses (HTTPS)
                                         ▼
  ┌─────────────┐  embeddings   ╔════════════════════╗   generation   ┌─────────────┐
  │ Gemini API  │◄──────────────║                    ║───────────────►│ Mistral API │
  │ embedding-  │   (HTTPS)     ║       MOMZO        ║    (HTTPS)     │ small→medium│
  │ 001 @ 768d  │               ║  (app + backend)   ║                └─────────────┘
  └─────────────┘               ║                    ║
  ┌─────────────┐   push        ║                    ║   errors       ┌─────────────┐
  │ Firebase    │◄──────────────║                    ║───────────────►│ Sentry      │
  │ FCM v1      │   (HTTPS)     ╚═════════╤══════════╝   (HTTPS)      │ PII-scrubbed│
  └─────────────┘                         │                           └─────────────┘
                                          │ contains (asset bundle, no network)
                                          ▼
                              ┌──────────────────────────┐
                              │ Learning-games SPA       │   ← Target
                              │ (bundled dist/, /play/*) │
                              └──────────────────────────┘

  OUTSIDE the boundary, never reachable from the app:
    Florie's tutoring classroom (games repo /teacher — its own Supabase project)
    Instagram / Facebook (content originates there; enters Momzo via seeding)
```

**Exactly four external services** — Gemini, Mistral, Firebase FCM, Sentry. **Built.**

Supabase is *inside* the system boundary (see §2), not an external dependency.

**WhatsApp is not part of this system.** It was cancelled (task 29); `nudge_channel` is
push-only. See ADR 006.

**The learning-games SPA ships inside the app with no network of its own.** **Target** —
gated on Expansion Plan Phase B.

---

## 2. Component view

### 2.1 The three tiers

```
┌────────────────────────────── FLUTTER APP ─────────────────────────────────┐
│  features/            10 folders, flat (see §7 — grandfathered)            │
│    activities · ai · bonding (+games) · daily · home · onboarding          │
│    reminders · shell · timeline · wishes                                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  services/            22 focused services — the ONLY route outward         │
│    auth · child · consent · onboarding · profile · daily · library         │
│    activity · ai · game · question · quiz · wish · scheduled_event         │
│    reminder · notification · memory · recap · media · deletion · stt · tts │
│  core/                ai · env · push · routing · supabase · theme · widgets│
│  models/              child · content_card · daily_card · activity          │
└──────────────┬──────────────────────────────────┬──────────────────────────┘
               │ supabase-dart (anon key + JWT)   │ HTTPS POST + JWT
               │ RLS enforced, :443               ▼
               │            ┌──────────── EDGE FUNCTIONS (Deno) ─────────────┐
               │            │ ai-chat              RAG + safety + cost       │
               │            │ generate-game-items  bonding-bank AI top-up    │
               │            │ delete-child         cascade erasure           │
               │            │ send-due-reminders   pg_cron invoked           │
               │            │ send-push            test sender               │
               │            │ hello-world          template / smoke test     │
               │            │  — hold ALL secrets; stateless;                │
               │            │    transaction pooler :6543, prepare off       │
               │            └──────────────┬─────────────────────────────────┘
               ▼                           ▼
┌───────────────────────── SUPABASE (Postgres 17) ───────────────────────────┐
│  25 tables — every one with RLS enabled                                    │
│                                                                            │
│  Family-isolated (18)  RLS: (select auth.uid()) = owner_id / user_id       │
│    users · children · consents · daily_assignments · activity_logs         │
│    ai_conversations · ai_messages · ai_usage · question_responses          │
│    wishes · scheduled_events · reminders · milestones · family_members     │
│    device_tokens · saved_cards · onboarding_state · game_play_history      │
│                                                                            │
│  Shared reference (5)  RLS: authenticated SELECT only, no client write     │
│    content_cards · activities · questions · games · game_items             │
│                                                                            │
│  Server-only (2)       RLS ON with ZERO policies — service_role only       │
│    content_embeddings · cached_answers                                     │
│                                                                            │
│  + Auth · Storage (family-media, private, signed URLs)                     │
│  + pgvector (HNSW cosine) · pg_cron (2 jobs) · pg_stat_statements          │
│  + Realtime: question_responses ONLY                                       │
└────────────────────────────────────────────────────────────────────────────┘
```

**Built**, except: `family_members` is a P2 stub (table + FKs exist; Phase-1 RLS allows
only self-row SELECT), and the co-parent work that would activate it sits on an unmerged
branch.

### 2.2 Why two tables have RLS with no policies

`content_embeddings` and `cached_answers` are reachable **only** by the service role
inside Edge Functions. RLS is enabled with no policy at all, so an anon or authenticated
client gets zero rows by construction rather than by a policy that could be written
wrong. This is deliberate and must not be "fixed". **Built.**

### 2.3 Edge Function shared modules

`_shared/`: `db` (pooled client) · `auth` (JWT verify with the **anon** key, never
service_role) · `cors` · `log` (PII-free structured lines) · `sentry` · `ai` (**the only
place provider keys live**) · `personalization` (ownership choke-point) · `prompts`
(cached static prefix) · `aicost` (limits, cost math, breaker) · `semcache` · `memory` ·
`fcm`. **Built.**

### 2.4 Interfaces

| Interface | Protocol / shape | Rule |
|---|---|---|
| features → services | Dart method calls | Features never import supabase/http directly — **enforced in CI** by `scripts/check_feature_imports.mjs`. **Partial: 3 of 45 files predate the rule** (`home_screen`, `sign_in_screen`, `quiz_match_screen`) and are allowlisted with the fix each needs |
| app → Supabase | supabase-dart over HTTPS, anon key + JWT | Family-isolated + shared-read tables only; RLS is the guard. **Built** |
| app → Edge Functions | HTTPS POST, JWT header | Anything needing a secret or heavier logic. **Built** |
| Edge Fn → Postgres | transaction pooler :6543, `prepare: false`, max 5 | Never direct :5432 (except the backup job's `pg_dump`, which requires :5432). **Built** |
| Edge Fn → Mistral/Gemini | HTTPS, keys in Fn env | Static-prefix prompt ordering for cache hits. **Built** |
| WebView SPA → app | `MomzoBridge` JS channel, JSON | One-way telemetry; no PII; no network in SPA. **Target** |
| pg_cron → Edge Fn | scheduled invoke + `x-cron-secret` | Idempotent via `sent_at`. **Built** |

---

## 3. Deployment view

```
  MOM'S PHONE (Android)                 SUPABASE CLOUD (Free tier, us-west-1)
┌────────────────────────┐            ┌──────────────────────────────────────┐
│ Momzo Flutter app      │ HTTPS 443  │ Postgres 17 + pgvector + pg_cron     │
│  ├ Supabase SDK        │───────────►│ Supavisor transaction pooler (:6543) │
│  │   (session persist) │            │ Edge Functions (Deno, stateless)     │
│  ├ bundled games dist/ │  ← Target  │ Auth · Storage · Realtime            │
│  └ FCM receiver        │            └──────┬──────────┬──────────┬─────────┘
└───────────┬────────────┘                   │          │          │
            │ FCM                            ▼          ▼          ▼
      ┌─────────────┐              ┌──────────┐ ┌──────────┐ ┌──────────┐
      │ Firebase    │              │ Mistral  │ │ Gemini   │ │ Sentry   │
      └─────────────┘              └──────────┘ └──────────┘ └──────────┘

  CI/CD (GitHub Actions):
    ci.yml       app analyze · edge fn guards + deno tests · RLS + integrity suites
                 migrate/deploy job is MANUAL trigger only
    backup.yml   daily 03:17 UTC pg_dump via SESSION pooler :5432 → GH artifact, 14d
    keep-warm.yml  every 8h — Free-tier pause mitigation
```

**Session storage:** the Supabase Flutter SDK persists the auth session itself.
`flutter_secure_storage` is **not** a dependency. **Built.**

**iOS:** no `ios/` target exists. Android only. **Built (as a constraint).**

**Two pg_cron jobs. Built:**

| Job | Schedule | Purpose |
|---|---|---|
| `send-due-reminders` | `*/15 * * * *` | Daily nudge + due reminders, quiet-hours aware |
| `purge-expired-cached-answers` | `17 4 * * *` | Expire semantic-cache rows |

### Single points of failure, named honestly

- **Supabase project** — mitigated by the nightly off-platform dump + documented restore
  (`docs/OPERATIONS.md`); upgrade triggers are written down.
- **Mistral API** — degrades to the semantic cache plus a warm retry message. The
  refer-out path is **regex-based and never depends on the model being up**, which is
  the property that matters.

---

## 4. Sequence views

### 4.1 AI expert question — safety and cost path

Ordering here is a **safety property, not a style choice**. The refer-out screen is
cheap and runs before every cost control, so a mother in a hard moment can never hit a
rate limit or budget wall. Do not reorder. **Built.**

```
Mom → App        types question (child_id attached)
App → ai-chat    POST {question, child_id, mode} + JWT
ai-chat          verify JWT → OWNERSHIP CHECK (child belongs to caller, else 403)
ai-chat          REFER-OUT SCREEN (regex, 3 categories)
                   └─ flagged → warm refer-out copy ─────────────────► App (STOP)
ai-chat          rate limit (qa 30 / situational 15 per rolling 24h)
                   └─ over → warm "later today" copy ───────────────► App (STOP)
ai-chat          build memory (≤3 turns history, notes, engagement)
ai-chat          embed question (Gemini) → semantic cache lookup
                   (only when mode=qa AND memory is not personal)
                   └─ hit ≥0.95 similarity → cached answer ─────────► App (STOP)
ai-chat          budget breaker
                   └─ hard → warm breaker copy ────────────────────► App (STOP)
ai-chat          pgvector: match_content_cards(embedding, K=6)
                   → dedupe → cite at most 3 cards
ai-chat          build prompt (cached static prefix + variable block, NAME-FREE)
ai-chat          Mistral small → medium if (topSim < 0.5 OR question is sensitive)
                   maxTokens: 280 situational / 450 qa
ai-chat          cache write (refused if the answer contains the child's name)
                 → persist ai_messages → record PII-free ai_usage row
App ← answer + citations + message_id → renders with source chips + 👍/👎
```

**Retrieval is K=6, narrowed to at most 3 citations.** (`ai-chat/index.ts:170,179`)

**The child's name is never fetched for this call**, let alone sent. Answers therefore
say "your child". **Built.**

> **Target:** re-inserting the child's name into the answer client-side is specified in
> the Onboarding & Personalization spec but **is not implemented** — no substitution
> happens anywhere in the AI screens. The name appears only in surrounding UI chrome.

### 4.2 Reminder dispatch — idempotency. **Built.**

```
pg_cron (*/15) → send-due-reminders   (auth: x-cron-secret header, not a JWT)
Fn → DB   SELECT reminders WHERE send_at ≤ now() AND sent_at IS NULL
          AND channel = 'push' AND quiet hours honored (tz_offset_minutes)
Fn → FCM  send per reminder; prune dead tokens (UNREGISTERED / INVALID_ARGUMENT)
Fn → DB   UPDATE sent_at   ← marked AFTER the send
Any failure → row stays unsent → the next run picks it up. Never double-sends.
```

The daily nudge is separately idempotent: it checks for an existing `reminders` row
since the user's local midnight before creating one.

### 4.3 Learning-game session — bridge and isolation. **Target** (Expansion Phase B).

```
Mom → App   opens a game (a child aged 5–6 is selected)
App         WebView loads bundled /play/<slug>   — NO network, NO Supabase in the SPA
SPA         createRound() → GameStage → mom drives Again / Easier / Harder / Next
SPA → App   MomzoBridge: round_result{bucket, responseTimeMs} … session_summary{…}
App → DB    INSERT game_play_sessions (family-isolated RLS, jsonb payload)
App killed  → session still logged by open/close time; summary is optional
Dashboard   reads sessions → SQL-only insights, child vs. their OWN past only
```

No auto-progression: the software never advances the child — the mother does. This
mirrors the games repo's own pedagogy (`mastery.ts`).

---

## 5. Data-flow view (privacy lens)

```
SOURCES                PROCESSES                          STORES
─────────────────────────────────────────────────────────────────────────────────
Mom's answers ──────► onboarding intake ────────────────► children  (RLS,
                      (resumable, 8 steps)                 consent-gated by trigger)
                                                          onboarding_state

Profile edits ──────► profile update ───────────────────► children.focus_goals /
                      (Me tab)                             challenges / interests /
                                                           temperament (jsonb)

Question text ──────► [refer-out screen]                ► ai_messages (content)
                      → [name-free context]               ai_usage (NO text, NO PII)
                      → [cache bucket: age band +         cached_answers (GLOBAL —
                         primary goal + challenge]         write refused if the answer
                                                           contains the child's name)

Activity photo ─────► size-capped upload (10 MB,        ► Storage: family-media
                      image mime allowlist)               PRIVATE, per-user folder,
                                                          served via signed URLs

Game play ──────────► bridge events (no names)  Target  ► game_play_sessions

DESTRUCTION
  delete-child → ownership check → single transaction →
    DELETE ai_conversations (child_id)   ← explicit: its FK is SET NULL, not CASCADE
    DELETE children                      ← everything else cascades from here
  → best-effort Storage purge → verified zero residual rows

NEVER FLOWS
  child's name → any LLM          one family's rows → another family
  app data → the tutoring classroom DB          message content → logs or telemetry
```

**Built**, except `game_play_sessions` (**Target**).

**Any new table holding child data joins the cascade in the same PR that creates it.**
In practice this means declaring `child_id … references children(id) on delete cascade`
— the Edge Function needs no change — and extending the zero-residual test.

---

## 6. Architectural rules

Binding, additive to Build Guide §6.

**Layering**
1. Dependencies run one way: `features → services → core`. A feature never imports
   another feature's internals, nor the Supabase/http client directly.
   **Partial — 3 known violations, listed in §2.4.**
2. Every external call site lives in a service with a single responsibility. A new
   third-party integration means a new service **and** an ADR.
3. Edge Functions stay stateless. Secrets live only in function env. Anything needing a
   secret is server-side, no exceptions. **Built.**

**Data**

4. Every new table declares its RLS pattern at design time: **family-isolated** or
   **shared-content**. No third pattern without an ADR.
5. Policy columns are indexed; the RLS coverage guard stays green; shared tables get
   **negative** tests (non-author cannot edit, non-moderator cannot hide).
   > **Resolved 2026-08-13.** The guard no longer infers a table's pattern from its
   > column names. It requires **every** table in `public` to be classified into
   > exactly one of `FAMILY_TABLES` / `SHARED_TABLES` / `SERVER_ONLY_TABLES` **and** to
   > have RLS enabled — so a forum table keyed on `author_id` cannot ship untested, and
   > `moderators` cannot be forced through the wrong test. The five shared reference
   > tables now carry real write-denial tests, which they previously lacked entirely.
   > Forum tables join `SHARED_TABLES` when Phase E adds them.
6. Any table holding child data joins the delete-child cascade in the same PR, and the
   zero-residual test extends to it.
7. Realtime is enabled for **`question_responses` only**, filtered to one family. Adding
   a table to the publication requires an ADR.

**AI**

8. All generation flows through `AiRouter`, and only from approved call sites — enforced
   in CI by `check_llm_call_sites.mjs`. The safety screen runs before any cost control;
   refer-out never depends on model availability; no child identifiers reach any model.
   **Built.**

**Subsystems**

9. The learning-games SPA is sealed: bundled assets, zero network, and it talks to the
   app only through `MomzoBridge`. The tutoring classroom's Supabase project is
   permanently out of scope. **Target.**
10. Copy everywhere obeys Hard Rule #18 — warm, never shaming. That includes error and
    empty states.

---

## 7. Flutter module structure

```
app/lib/
  core/       env · theme · routing · supabase client · push · ai (router + telemetry)
  models/     child · content_card · daily_card · activity
  services/   22 services — the only route outward
  features/
    <existing>/          ← FLAT. Grandfathered permanently (ADR 011)
      some_screen.dart

    <new feature>/       ← structured
      data/       repositories (call services; never a client directly)
      widgets/    UI components
      screens/    routed pages
      state/      feature state
```

**The flat structure of the 10 existing feature folders is permanent** (ADR 011). New
features — learning games, content hub, forum — use the four-subfolder shape. Mixed
structure is the accepted, recorded trade: churn across 45 files in a barely-tested app
buys nothing a reader can see.

**Routing. Target.** There is no router. Navigation is imperative `Navigator.push` with
inline `MaterialPageRoute`, and `core/routing/app_router.dart` contains a `Routes` class
that **nothing references** — dead code. A central router is the right destination, but
it is gated on the navigation decision in Expansion Plan §6 Q1 (5-tab restructure vs.
minimal change); building one before that decision would mean building it twice.

**State.** No state-management package. `StatefulWidget` + `setState`, static services,
and three global `ValueNotifier`s (`ChildService.currentChild`,
`DailyService.readRevision`, `LibraryService.savedRevision`). **Introducing a second
state solution requires an ADR.** **Built.**

**Logging.** There is no general app logger. `core/ai/ai_telemetry.dart` emits PII-free
AI routing metadata to `developer.log`; wiring a real sink is outstanding.
**Partial.**

---

## 8. Extension protocol

The checklist for adding any feature — this is the PR template for feature work:

1. **Name the boundary** — which tiers does it touch (app / Edge Fn / DB / external)? A
   new external service means an ADR first.
2. **Declare data** — new tables, RLS pattern (rule 4), indexes, cascade membership
   (rule 6), migration in `supabase/migrations`.
3. **Declare interfaces** — which service exposes it; the Edge Function contract if any.
4. **Walk the views** — does it change §1–§5? Update this file in the same PR.
5. **Cost check** — any LLM call routes via `AiRouter` and appears in the approved
   call-site list; estimate per-user cost against the targets.
6. **Safety and tone** — child data minimised; refer-out unaffected; copy warm.
7. **Tests** — RLS positive *and* negative; idempotency where scheduled; on-device smoke.

---

## 9. Decision log

Full records in [`docs/adr/`](adr/). Summary:

| # | Decision |
|---|---|
| [001](adr/001-flutter-supabase-edge-functions.md) | Flutter + Supabase + Edge Functions |
| [002](adr/002-rls-everywhere-two-patterns.md) | RLS everywhere, two patterns only |
| [003](adr/003-mistral-generation-gemini-embeddings.md) | Mistral generation, Gemini embeddings |
| [004](adr/004-grounded-ai-always-on-refer-out.md) | Grounded AI + always-on refer-out |
| [005](adr/005-supabase-free-tier-own-backups.md) | Free tier + own `pg_dump` + keep-warm |
| [006](adr/006-push-only-whatsapp-cancelled.md) | Push-only; WhatsApp cancelled |
| [007](adr/007-ai-provider-abstraction-on-device-later.md) | `AiProvider`/`AiRouter` now, on-device later |
| [008](adr/008-learning-games-webview-bundled.md) | Learning games via WebView + bundled `dist/` |
| [009](adr/009-games-spa-sealed-subsystem.md) | Games SPA sealed — no Supabase in the app's copy |
| [010](adr/010-forum-shared-content-tables.md) | Forum introduces shared-content tables |
| [011](adr/011-grandfather-flat-feature-structure.md) | Grandfather the flat feature structure |

---

## 10. Known gaps

Recorded so they are decisions, not surprises. Fuller detail in `docs/BUILD_STATUS.md`.

| Gap | Where |
|---|---|
| ~~RLS coverage guard is not pattern-aware~~ — **resolved 2026-08-13** | rule 5 above |
| 3 feature files import Supabase directly — allowlisted, not blocking. Each needs: `home_screen` → move the `users.display_name` query to `ProfileService`; `sign_in_screen` → `AuthService` should expose its own error/provider types; `quiz_match_screen` → `QuizService` should own unsubscribe. **Needs a Flutter toolchain to verify** | §2.4 |
| No central router; `app_router.dart` is dead code | §7 |
| Child's name is never re-inserted into AI answers, though specified | §4.1 |
| No kid-mode gate — the wish wall's lock badge is only a back button | — |
| Push tokens register but no message handler exists | — |
| Nothing writes `milestones`, though the timeline reads it | — |
| CI does not run `flutter test`; only 2 test files exist | §3 |
| ~57 silent `catch (_)` blocks fall back to sample data on failure | — |
