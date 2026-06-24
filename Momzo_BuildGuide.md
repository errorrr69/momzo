# Momzo — Build Guide

**Version:** v1.0
**Date:** June 22, 2026
**Companion to:** `Momzo_PRD.md`
**Audience:** Claude Code (and Florie)

> Purpose: give Claude Code an unambiguous, launch-grade tech stack and the exact
> rules that keep Momzo stable and cheap as users grow. The PRD says *what* to build;
> this says *how*, and *what must never be done*. The "Hard Rules" in §6 are not
> suggestions — most production failures on this stack come from breaking one of them.

---

## Table of Contents

1. [Recommended stack & why](#1-recommended-stack--why)
2. [Architecture](#2-architecture)
3. [The three things that make apps fall over (and how we avoid them)](#3-the-three-things-that-make-apps-fall-over)
4. [Repository structure](#4-repository-structure)
5. [Environment & secrets](#5-environment--secrets)
6. [Hard Rules (Claude Code must follow these)](#6-hard-rules)
7. [Cost model at scale](#7-cost-model-at-scale)
8. [Build order with done-criteria](#8-build-order-with-done-criteria)
9. [Pre-launch checklist](#9-pre-launch-checklist)

---

## 1. Recommended stack & why

| Layer | Choice | Why this, for Momzo specifically |
|-------|--------|----------------------------------|
| Mobile | **Flutter (latest stable)** | One codebase for iOS + Android; you (Florie) already know Flutter/Dart well; it's a phone-first product. |
| Backend platform | **Supabase** | Managed Postgres + Auth + Storage + Realtime + Edge Functions + `pg_cron` + pgvector in one place. One founder can run it; it scales to 100k+ users if the rules below are followed. |
| DB | **PostgreSQL 15+** (via Supabase) | Relational data with strong integrity; RLS gives database-level security so the mobile client can talk to the DB directly and *safely*. |
| Server logic | **Supabase Edge Functions (Deno + TypeScript)** | Stateless, horizontally scalable, hold all secrets. Everything sensitive (LLM, WhatsApp) runs here. |
| AI default | **Gemini 3.5 Flash** | Cheap + fast; ideal for a RAG chat + short situational scripts. You already use Gemini elsewhere. |
| AI escalation | A stronger mid model (Claude Sonnet-class / GPT-mid) | Only for sensitive/low-confidence queries. Routed, so 90%+ of traffic stays cheap. |
| Embeddings / RAG | **pgvector** in Supabase | Keeps the knowledge base + vectors in the same DB; no extra vector service to run. |
| Push | **Firebase Cloud Messaging** | Free, reliable, native Flutter support. Primary reminder channel. |
| WhatsApp | **WhatsApp Cloud API** (utility templates) | The differentiator; cheap when categorized as utility. Add in Phase 2. |
| Scheduling | **`pg_cron` → Edge Function** | Built into Supabase; no separate scheduler infra. |
| Crash/error reporting | **Sentry** (Flutter + Edge Functions) | Catch issues before users report them. |
| Hosting | Supabase (backend); App/Play stores (app); Vercel (optional landing page) | |

**On the paid tier:** launch on **Supabase Pro, not Free.** Free projects pause on
inactivity and lack the daily backups + connection headroom you need in production.
This is the single cheapest insurance against an embarrassing outage.

---

## 2. Architecture

```
        ┌─────────────────────────────┐
        │      Flutter app (iOS/Android)
        │  - ordinary reads/writes ───────────────┐
        │  - kid mode (gated)                      │ (Supabase client SDK,
        │  - FCM push receiver                     │  RLS-protected, anon key)
        └──────────────┬──────────────┘            │
                       │ secrets-needing calls      ▼
                       │ (AI, WhatsApp, schedules)  ┌──────────────────────────┐
                       ▼                            │      Supabase            │
        ┌─────────────────────────────┐  transaction │  PostgreSQL 15 + RLS    │
        │  Edge Functions (Deno, TS)  │  pooler      │  + pgvector (RAG)        │
        │  - /ai-chat (RAG + route)   │◄────────────►│  + Storage (private)     │
        │  - /send-due-reminders      │  (port 6543) │  + Auth (JWT)            │
        │  - /whatsapp-send           │              │  + pg_cron               │
        │  hold ALL secret keys       │              └──────────────────────────┘
        └───────┬─────────────┬───────┘
                │             │
                ▼             ▼
        ┌────────────┐  ┌──────────────────┐
        │ LLM APIs   │  │ WhatsApp Cloud API│
        │ (Gemini /  │  │ (utility templates)│
        │  escalate) │  └──────────────────┘
        └────────────┘
                ▲
                │ FCM
        ┌────────────┐
        │  Firebase  │  push notifications
        └────────────┘
```

**Key principle:** the app reads/writes *its own family's data* directly against
Supabase (fast, RLS-protected). Anything that (a) needs a secret key, (b) calls a
paid third party, or (c) runs on a schedule, goes through an Edge Function. The app
never holds an LLM key, a WhatsApp token, or the service-role key.

---

## 3. The three things that make apps fall over

(And exactly how Momzo avoids each. These three cause the overwhelming majority of
"it worked in dev, it died at launch" stories on this stack.)

### 3.1 Connection exhaustion → use the transaction pooler

Postgres connections behave like persistent sockets; a serverless function that opens
a direct connection per invocation will exhaust the database fast under load. The fix
is a **server-side transaction pooler (Supabase Supavisor)**, which acts like a load
balancer for Postgres connections and lets the platform handle on the order of
**10,000 concurrent client connections** instead of the few hundred a direct
Postgres instance allows.

- **Edge Functions and any serverless/edge code → connect via the transaction pooler
  (port 6543), not a direct connection (port 5432).**
- **Transaction mode does not support prepared statements** — disable prepared
  statements in whatever client library connects, or you'll get errors under load.
- Direct connections (5432) are only for long-lived servers/VMs — which we don't have.
- On Pro, use the **dedicated pooler** for best latency.
- Don't raise the pool size recklessly: if you also use the auto REST API heavily,
  keep the pool at a sane fraction of max connections so Auth and other services keep
  headroom.

### 3.2 Bad Row-Level Security → secure *and* fast

RLS is what lets the mobile app query the database directly without leaking other
families' data — it adds an implicit `WHERE` to every query at the database level, so
even a bug in app code can't bypass it. But naive policies are both a security hole
*and* a performance cliff.

**Security:**
- **Enable RLS on every table in the public schema. No exceptions.** Without it, the
  anon key can read/write everything.
- **Never ship the `service_role` key to the client.** It bypasses RLS. Server-side
  (Edge Functions) only.

**Performance (this is where slow apps are born):**
- **Index every column an RLS policy filters on.** A policy like `user_id = auth.uid()`
  with a btree index on `user_id` can be **100x faster** on large tables than without.
- **Keep policies simple — prefer direct comparison over subqueries.**
  `USING (user_id = auth.uid())` is fast; `USING (user_id IN (SELECT ...))` is slow.
- **Wrap `auth.uid()` so it's evaluated once:** `USING ((select auth.uid()) = user_id)`.
- **Add the same filter in the query too**, not just the policy
  (`.eq('user_id', uid)`) — it lets Postgres use indexes more effectively.
- For the (Phase 2) co-parent/membership checks, use a **`security definer` function**
  for the membership lookup instead of a join-in-policy, and restructure
  `id IN (select ... where user = uid)` style rather than `uid IN (select ...)`.
- Verify with `EXPLAIN ANALYZE`: typical queries should stay **under 50ms**.

### 3.3 Realtime / notification overload → use it sparingly

Realtime subscriptions hold open WebSocket connections that count against connection
limits, and broadcasting every table change will overload them.

- **Only enable Realtime on tables that truly need live updates** (e.g. the
  mom↔child quiz reveal, the wish wall when both are live). It is **not** needed for
  daily cards, activities, or the AI chat.
- **Always filter subscriptions** to the specific family's rows; never subscribe to a
  whole table.
- Realtime subscriptions still respect RLS — make sure SELECT policies cover the rows
  you expect to receive.
- For most reminders, prefer scheduled push over realtime.

---

## 4. Repository structure

Monorepo, so the app and backend stay in lockstep:

```
momzo/
├─ app/                       # Flutter
│  ├─ lib/
│  │  ├─ features/            # one folder per feature (onboarding, daily, ai, activities, bonding, wishes, reminders, timeline)
│  │  ├─ core/                # supabase client, theme, routing, env, push
│  │  ├─ models/              # Dart models matching DB
│  │  └─ services/            # api wrappers (calls Edge Functions / Supabase)
│  └─ pubspec.yaml
├─ supabase/
│  ├─ migrations/             # SQL — schema + RLS policies + indexes (source of truth)
│  ├─ functions/              # Edge Functions (Deno)
│  │  ├─ ai-chat/             # RAG + model routing + guardrails
│  │  ├─ send-due-reminders/  # invoked by pg_cron
│  │  └─ whatsapp-send/       # utility-template sender
│  ├─ seed/                   # seed content_cards, activities, questions, embeddings
│  └─ config.toml
├─ docs/
│  ├─ Momzo_PRD.md
│  └─ Momzo_BuildGuide.md
└─ .github/workflows/         # CI: run migrations, deploy functions, test RLS
```

**Schema and RLS live in `supabase/migrations` as version-controlled SQL** — never
make schema changes by hand in the dashboard. Deploy with the Supabase CLI
(`supabase db push`, `supabase functions deploy`) via CI.

---

## 5. Environment & secrets

| Secret | Lives in | Never in |
|--------|----------|----------|
| Supabase anon key | Flutter app (safe — RLS protects data) | — |
| Supabase `service_role` key | Edge Function env only | the app, the repo, logs |
| LLM API key(s) | Edge Function env only | the app |
| WhatsApp Cloud API token | Edge Function env only | the app |
| FCM server key | Edge Function env / Firebase | the app |

- Use `.env` locally, Supabase Function secrets in prod; `.env` is git-ignored.
- Rotate keys periodically; use separate keys for dev and prod.
- No PII (child names, AI message bodies) in logs.

---

## 6. Hard Rules

Claude Code: treat these as constraints on every change. They directly implement the
PRD's stability, security, and child-safety requirements.

**Database & scale**
1. Enable RLS on **every** public table; add an index on every column any policy filters on.
2. Edge Functions connect via the **transaction pooler (6543)** with prepared statements **off**.
3. Keep RLS policies as direct comparisons; wrap `auth.uid()` in `(select auth.uid())`.
4. Realtime only on tables that need it, always filtered to one family.
5. `service_role` key is **server-side only**.

**AI**
6. The AI is **RAG-grounded** — answers come from vetted `content_cards`, not free
   model output; cite the source card(s) in the response.
7. The **refer-out / safety classifier runs on every AI turn**; on a safety, medical,
   or developmental-concern signal, the AI refers to a professional and does **not**
   advise. Never diagnose.
8. Route cheap-by-default (Gemini Flash); escalate only sensitive/low-confidence turns.
9. Cap `max_output_tokens`; cache the system prompt; per-user rate limit.
10. AI keys never leave the Edge Function.

**Notifications**
11. **Push first.** WhatsApp is Phase 2 and opt-in only.
12. WhatsApp messages are **pre-approved utility templates only** — never marketing.
13. Reminder sends are **idempotent**: check `sent_at` before sending; mark after.

**Privacy / child safety**
14. Child has **no independent account**; data is parent-owned + consent-based.
15. **No ads, no third-party tracking SDKs aimed at children**; collect minimal data;
    no precise location.
16. Photos/notes in **private** Storage buckets, served via signed URLs.
17. Implement **delete-my-child-and-all-data**.

**Tone**
18. No streak-shaming or guilt anywhere in copy or notifications. Celebrate small
    wins; never punish a miss.

**Process**
19. Schema/RLS changes go through `supabase/migrations` (version-controlled), never
    hand-edited in the dashboard.
20. Write an RLS test (a user must not be able to read another family's rows) before
    a feature touching family data is "done."

---

## 7. Cost model at scale

Rough monthly back-of-envelope so there are no billing surprises. Assumes an active
mom does ~10 AI turns/week and gets ~10 reminders/week, India-weighted.

| Item | At 1k MAU | At 10k MAU | At 100k MAU | Driver |
|------|-----------|------------|-------------|--------|
| Supabase | Pro (~$25 base) | Pro + compute add-on | Scale tier + compute/replicas | DB compute + connections |
| AI (Gemini Flash, RAG, capped + cached) | a few $ | tens of $ | low hundreds of $ | tokens × turns; cache + small-K retrieval keep it low |
| Push (FCM) | $0 | $0 | $0 | free |
| WhatsApp (utility, India, opt-in subset) | a few $ | tens of $ | low hundreds of $ | per delivered utility template; India ≈ fraction of a cent |
| Storage (photos) | negligible | low | moderate | optional photos; cap file size (e.g. 10MB) |
| Sentry / misc | free tier | low | moderate | |

**Levers if cost climbs:**
- AI: keep retrieval K small, cache the system prompt, route hard turns only;
  free-tier/cheaper models for non-sensitive traffic.
- WhatsApp: stay utility-categorized; keep it opt-in; lean on free push for most nudges.
- DB: add indexes before adding compute; denormalize hot read paths.

**Target unit economics:** AI < $0.10 / active user / month, total infra
comfortably under a small Momzo+ subscription price — so paid conversion funds growth.

---

## 8. Build order with done-criteria

Mirrors PRD §14. A phase isn't "done" until its criteria pass.

**Phase 0 — Foundation**
Auth; full schema + RLS + indexes in migrations; Edge Function scaffold; pooler
config; FCM; Sentry; CI deploys.
*Done when:* an authed user can sign in, RLS tests pass (no cross-family reads), a
hello-world Edge Function runs via the pooler, a test push arrives.

**Phase 1 — Core loop (P0)**
Onboarding + child profile → daily card + "why it matters" → grounded AI Q&A +
situational + safety escalation → activities w/ time filter + "did it" → shared
question of the day → gentle push nudge + quiet hours.
*Done when:* a real mom can onboard, read today's card, ask the AI a question and get
a grounded, cited answer (and a refer-out on a safety probe), filter+do an activity,
answer the daily question, and receive a gentle nudge. **Ship to a small group here.**

**Phase 2 — Completeness (P1)**
Know-each-other quiz + games → wish wall + scheduling + calendar → WhatsApp utility
reminders (opt-in) → memory timeline → milestones → weekly recap → save/library →
multiple children → gentle streak.
*Done when:* the full bonding + reminder + continuity experience works end-to-end,
WhatsApp templates are approved + sending, and cross-family RLS still holds.

**Phase 3 — Expansion (P2)**
Co-parent sharing (multi-member RLS via security-definer membership check) → audio
letters → voice input → (only if validated) small moderated community → billing.

---

## 9. Pre-launch checklist

- [ ] RLS enabled + tested on every table; indexes on all policy-filter columns
- [ ] `service_role` key absent from app + repo; secrets only in Function env
- [ ] Edge Functions on transaction pooler; prepared statements off
- [ ] AI grounded + cites sources; refer-out classifier verified on safety probes
- [ ] AI rate-limited + token-capped + system prompt cached; cost dashboard live
- [ ] Reminders idempotent; quiet hours honored; `pg_cron` job verified
- [ ] WhatsApp: WABA set up, **utility** templates approved, opt-in + opt-out working
- [ ] Privacy policy live; child-data consent flow; delete-all-data works; no child ads
- [ ] Private Storage buckets + signed URLs; file-size caps
- [ ] Sentry capturing app + function errors; `pg_stat_statements` on for slow queries
- [ ] Supabase on **Pro**; daily backups confirmed + a restore tested once
- [ ] Notification + nudge copy reviewed for tone (no guilt/shame)
- [ ] Load sanity check: simulate a few hundred concurrent users; watch the
      connection-pool graph stay well under the limit

---

*End of Build Guide. Build in phases, keep the Hard Rules intact, and Momzo will
stay fast, safe, and affordable as it grows.*
