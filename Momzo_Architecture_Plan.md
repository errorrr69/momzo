# Momzo — System Architecture Plan

**Version:** v1.0 · August 2026
**For:** Claude Code (implement + maintain) · **Companions:** `Momzo_BuildGuide.md`,
`Momzo_Expansion_Plan.md`, `Momzo_AI_Cost_Strategy.md`, `Momzo_OnDevice_AI_Strategy.md`,
`BUILD_STATUS.md`
**Framework:** the five architecture views from standard system-design practice
(conceptual · component · deployment · sequence · data-flow), plus the enforcement
rules that keep them true as features grow.

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
   ┌──────────────┐   utility templates  ┌═══════════════════┐   push (FCM)   ┌───────────┐
   │ WhatsApp     │◄─────────(later)─────║                   ║───────────────►│ Firebase  │
   │ Cloud API    │                      ║      MOMZO        ║                │ Cloud Msg │
   └──────────────┘                      ║  (app + backend)  ║                └───────────┘
   ┌──────────────┐   embeddings (HTTPS) ║                   ║  gen (HTTPS)  ┌───────────┐
   │ Gemini API   │◄─────────────────────║                   ║──────────────►│ Mistral   │
   │ (embeddings) │                      ╚═══════╤═══════════╝               │ small→med │
   └──────────────┘                              │                           └───────────┘
                                                 │ contains (asset bundle, no network)
                                                 ▼
                                   ┌─────────────────────────┐
                                   │ Learning-games SPA       │
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

---

## 3. Component view

### 3.1 The system's three tiers

```
┌─────────────────────────── FLUTTER APP ───────────────────────────────┐
│  features/            (one folder per feature — see §8)               │
│    onboarding · daily · ai · activities · bonding · learning_games    │
│    wishes · calendar · reminders · timeline · content_hub · forum · me│
│  ────────────────────────────────────────────────────────────────────  │
│  services/            (the ONLY way features reach the outside)       │
│    SupabaseService    → direct DB reads/writes (anon key, RLS-guarded)│
│    AiService          → calls ai-chat Edge Fn (AiProvider/AiRouter)   │
│    NotificationService→ FCM token mgmt, local display                 │
│    GamesBridgeService → WebView host + MomzoBridge channel            │
│  core/                (theme, routing, env, supabase client, kid-mode)│
│  models/              (Dart mirrors of DB rows)                       │
└───────────────┬───────────────────────────────┬───────────────────────┘
                │ Supabase client SDK           │ HTTPS (JWT)
                │ (RLS enforced, port 443)      ▼
                │              ┌─────────── EDGE FUNCTIONS ─────────────┐
                │              │ ai-chat (RAG + route + refer-out+cache)│
                │              │ send-due-reminders (pg_cron invoked)   │
                │              │ whatsapp-send (later) · delete-child   │
                │              │ generate-game-items (batched top-up)   │
                │              │  — hold ALL secrets; stateless;        │
                │              │    pooler :6543, prepared stmts off    │
                │              └───────────────┬────────────────────────┘
                ▼                              ▼
┌────────────────────────────── SUPABASE (Postgres 17) ─────────────────┐
│  Family-isolated tables (RLS: owner = auth.uid)                        │
│    children, daily_assignments, activity_logs, ai_conversations,      │
│    ai_messages, question_responses, wishes, scheduled_events,         │
│    reminders, milestones, game_play_sessions, ai_usage                │
│  Shared-content tables (RLS: authed read / author or admin write)     │
│    content_cards(+embeddings), activities, questions, game_items,     │
│    learning_games, social_posts, forum_* , cached_answers             │
│  + Auth · Storage (private buckets/signed URLs; public: social media) │
│  + pg_cron · pgvector · Realtime (quiz reveal + wish wall ONLY)       │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Interfaces (the contracts between components)

| Interface | Protocol / shape | Rule |
|---|---|---|
| features → services | Dart method calls | Features NEVER import supabase/http clients directly |
| app → Supabase | supabase-dart over HTTPS, anon key + JWT | Only family-isolated + shared-read tables; RLS is the guard |
| app → Edge Functions | HTTPS POST, JWT in header | Anything needing a secret or heavier logic |
| Edge Fn → Postgres | transaction pooler :6543, prepared statements off | Never direct :5432 |
| Edge Fn → Mistral/Gemini | HTTPS, keys in Fn env | Static-prefix prompt ordering (cost strategy §3) |
| WebView SPA → app | `MomzoBridge` JS channel, JSON events | One-way telemetry; no PII; no network in SPA |
| pg_cron → send-due-reminders | scheduled invoke | Idempotent via `sent_at` |

---

## 4. Deployment view

```
  MOM'S PHONE                          SUPABASE CLOUD (Free tier — see notes)
┌───────────────────────┐            ┌─────────────────────────────────────┐
│ Momzo Flutter app     │  HTTPS 443 │ Postgres 17 + pgvector + pg_cron    │
│  ├ bundled games dist/│───────────►│ Supavisor pooler (:6543)            │
│  ├ flutter_secure_    │            │ Edge Functions (Deno, stateless)    │
│  │   storage (tokens) │            │ Auth · Storage · Realtime           │
│  └ FCM receiver       │            └───────┬─────────────┬───────────────┘
└──────────┬────────────┘                    │ HTTPS       │ HTTPS
           │ FCM                             ▼             ▼
     ┌─────────────┐                 ┌────────────┐  ┌────────────┐
     │ Firebase    │                 │ Mistral API │  │ Gemini API │
     │ (push)      │                 └────────────┘  └────────────┘
     └─────────────┘
  CI/CD: GitHub Actions → supabase db push · functions deploy · RLS suite
         + nightly pg_dump → off-platform storage (Free-tier backup)
         + keep-warm ping (Free-tier pause mitigation)
```

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
ai-chat: embed question (Gemini) → semantic cache lookup (bucketed)
   ├─ hit → cached answer ─────────────────────────────► App (STOP)
ai-chat: pgvector retrieve (K=3) → build name-free context
ai-chat: Mistral small (→medium if sensitive/low-confidence)
ai-chat: OUTPUT SAFETY SCREEN → persist msg + usage log → cache write
App ← answer + cited_card_ids → renders with child's name re-inserted CLIENT-side
```

### 5.2 Reminder dispatch (idempotency)
```
pg_cron (every 5 min) → send-due-reminders Fn
Fn → DB: SELECT reminders WHERE send_at ≤ now AND sent_at IS NULL
        AND user quiet-hours honored (timezone-aware)
Fn → FCM (and later WhatsApp utility template) per reminder
Fn → DB: UPDATE sent_at  (mark AFTER send; retried run re-sends only unsent)
Any step fails → row stays unsent → next cron picks it up. Never double-send.
```

### 5.3 Learning-game session (bridge + isolation)
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
Mom's answers ──► Onboarding intake ───────────────► children (RLS, consent-gated)
Weekly check-in ─► profile update ─────────────────► children.challenges/interests
Question text ──► [safety screen]→[name-free ctx]──► ai_messages (min. retention)
                        │                            ai_request_log (NO content, NO PII)
Game play ──────► bridge events (no names) ────────► game_play_sessions
Photos (later) ─► size-capped upload ──────────────► Storage PRIVATE bucket (signed URLs)
Forum posts ────► [display-name identity] ─────────► forum_* (SHARED store — no child
                                                     full names by rule; report path)
DESTRUCTION: delete-child → transactional cascade across EVERY family store
             (incl. game_play_sessions) → verified zero residual rows
NEVER FLOWS: child name → any LLM · family rows → another family ·
             app data → tutoring classroom DB · analytics content → logs
```

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
6. Any table holding child data joins the delete-child cascade **in the same PR**
   that creates it, and the zero-residual test extends to it.
7. Realtime only for the quiz reveal + wish wall, always filtered to one family.

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
  core/        env, theme, router, supabase client, kid_mode gate, analytics-free logger
  models/      one file per table family; fromJson/toJson mirrors of SQL
  services/    supabase_service, ai_service, notification_service, games_bridge_service
  features/
    <feature>/
      data/        repositories (call services; NO direct clients)
      widgets/     UI components
      screens/     routed pages
      state/       feature state (keep the app's existing state solution; do not
                   introduce a second state-management library — ADR required)
```
Conventions: feature folders are the unit of ownership; cross-feature UI goes to a
shared `widgets/` only when used by 3+ features; routing is declared centrally in
`core/router` so navigation structure (tabs) has one home.

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

Keep at `docs/adr/NNN-title.md`; one page each: context → decision → consequences.
Seed it with the decisions already made (backfill these):

| # | Decision | Why (short) |
|---|---|---|
| 001 | Flutter + Supabase + Edge Functions | one founder, one managed backend, RLS lets client talk to DB safely |
| 002 | RLS-everywhere, two patterns only | isolation by database, not app code |
| 003 | Mistral small→medium; Gemini embeddings | cost + quota reality; grounded RAG |
| 004 | AI grounded + refer-out always-on | trust & child safety over capability |
| 005 | Free tier + own pg_dump + keep-warm | cost; documented upgrade triggers |
| 006 | Push-first; WhatsApp utility later | free channel validates the loop |
| 007 | AiProvider/AiRouter abstraction now, on-device later | privacy/offline, not cost |
| 008 | Games via WebView + bundled dist + /play route | 22 working games; no rewrite; offline |
| 009 | Games SPA sealed (no Supabase in app copy) | classroom separation; privacy |
| 010 | Forum = first shared-content tables + moderation | community decision; new RLS pattern |

New entries whenever rules 2, 4, or state-management/nav structure change.

---

## 11. Acceptance criteria (this plan is "implemented" when)

- `docs/architecture.md` exists in the repo containing §2–§6 diagrams, and CI has a
  reminder check (a PR-template checkbox is sufficient) tying boundary-changing PRs
  to a diagram update.
- `docs/adr/` exists with the ten backfilled ADRs.
- A lint/CI check enforces rule 1 (no `supabase`/`http` imports under `features/`)
  and the existing guards stay green (RLS coverage, LLM call sites).
- The §9 checklist is the repo's PR template for feature work.
- One walkthrough proof: the next feature built (per the Expansion Plan) visibly
  follows §9, updates the diagrams, and adds its ADR if needed.

---

*End of plan. The diagrams say what the system is; the rules keep it that way; the
protocol makes every future feature pay its architectural rent up front.*
