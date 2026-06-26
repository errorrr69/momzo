# Momzo — Build Status

_Last updated: 2026-06-25_

A warm Flutter + Supabase app that gives busy mothers of 6–10-year-olds a few cozy
minutes a day to understand their child better. This doc summarizes everything
built so far. The authoritative specs live in [`Momzo_PRD.md`](Momzo_PRD.md) and
[`Momzo_BuildGuide.md`](Momzo_BuildGuide.md); the build plan + task statuses live
in Taskmaster (`.taskmaster/`).

## Status at a glance

- **20 of 37 planned tasks done.**
- **Phase 0 (foundation): 9 / 10** — Sentry/observability (#8) now done; only the ship-readiness gate (#22) outstanding.
- **Phase 1 (core loop): complete** except #22 (pre-launch checklist).
- The full product runs **on a real Android device** (verified end-to-end, incl. push).
- Everything below is committed to git; secrets are git-ignored.

## Tech stack

| Layer | Choice |
|-------|--------|
| App | Flutter (single codebase; Android built & device-tested, iOS deferred) |
| Backend | Supabase (Postgres 17, Auth, Storage, Realtime, Edge Functions, pg_cron, pgvector) — **Free tier** |
| AI — embeddings | Google **Gemini** `gemini-embedding-001` (768-dim) |
| AI — generation | **Mistral** (`mistral-small` default → `mistral-medium` escalation) |
| Push | Firebase Cloud Messaging (FCM HTTP v1) |
| Project | Supabase ref `nngjqhrxbhugnafyviqj`; Firebase project `momzo-3a942`; Android package `app.momzo` |

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
- **RLS cross-family test harness** (`supabase/tests/`) — proves no family can read/write another's rows across all 14 family tables, plus a coverage guard that fails CI if a new table is added untested. **15/15 passing.**
- **Auth** — email sign-up/sign-in; profile upserted on first sign-in. (Google/Apple wired in code, disabled pending OAuth credentials.)
- **Edge Function scaffold** — shared pooled DB client, JWT verify, PII-free logging, CORS.
- **COPPA consent gate** — a `consents` record + a DB trigger that **blocks child creation until consent exists** (enforced server-side, can't be bypassed).
- **Delete-my-child-and-all-data** — ownership-checked Edge Function, transactional cascade across every table (+ best-effort Storage), verified zero residual rows.
- **FCM push** — Android client registers device tokens; server sends via service-account → Google OAuth → FCM v1. **Verified delivering to a real phone.**

### Core loop (Phase 1)
- **Onboarding → child profile** — welcome → sign-in → consent → child basics (name, age 6–10) → temperament/struggles → home. Age enforced by a DB check.
- **Daily card** — one age/struggle-targeted card per child per day, shown as a micro-read with the signature **"why it matters"** tie-in; "mark as read" recorded.
- **AI expert** (the heart of the app):
  - **Q&A** — embeds the question, retrieves top vetted chunks via pgvector, answers **only** from approved knowledge, **cites the source cards**.
  - **"Right now" situational mode** — a short, calm in-the-moment script.
  - **Refer-out safety** — every turn screened across 3 categories (self-harm/abuse, medical, developmental concern); warmly redirects to a professional, never diagnoses. Off-topic requests are scope-fenced.
  - **Cost controls** — cheap-by-default model routing, token caps, small-K retrieval, per-user rate limit; model + token usage logged for a cost dashboard.
- **Activities** — 62-activity library filtered by the time a mom has (5/15/30) + age + place; step-by-step detail; "we did it" logging (photo deferred to Storage).
- **Question of the Day** — 30 prompts; today's question is shared by parent + child, each answers, then a side-by-side reveal.
- **Gentle daily nudge + quiet hours** — pg_cron → Edge Function dispatches a kind daily nudge at the user's chosen slot, honors quiet hours, idempotent (never double-sends). No guilt/shame.
- **Tone** — every screen + server copy reviewed: no guilt, shame, or streak-pressure (Hard Rule #18).
- **App shell** — boots like a real app (auth-routed: returning users land in Home), with a working 5-tab bottom nav (Home · Learn · Ask · Together · Me).

### Knowledge base / content
- **67 content cards / 786 embeddings** seeded from expert articles (`knowledge base/`), feeding both daily cards and RAG.
- **62 activities** and **30 questions** seeded.
- All seeders are idempotent (slug-based) and re-runnable as content grows.

### Edge Functions deployed
`hello-world` (template) · `ai-chat` (RAG Q&A + situational + refer-out + routing) ·
`delete-child` (cascade erasure) · `send-push` (test/sender) · `send-due-reminders` (cron dispatcher).

---

## Verified

- RLS isolation suite: **15/15**, in CI.
- Per-feature backend smoke tests: auth, consent gate, child creation (age constraint), daily-card targeting + read, AI (grounded + citations + refer-out battery + cost routing), activities query + log, question reveal, push delivery, reminder dispatch (idempotency + quiet hours).
- **On-device (real Samsung phone):** boots to Home with real data; daily card read → `read_at` persisted; AI question → grounded answer + 3 citations persisted; activities list + detail; question of the day; FCM notification received. `flutter analyze`: 0 errors.
- Bugs found on-device and fixed: `WhyItMatters` layout crash; bottom nav overlapping the system bar; activity action bar behind the system bar.

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
- **iOS** push/build deferred (needs paid Apple Developer account + APNs).
- **Storage** buckets for photos not yet set up — when added, must be private + signed
  URLs + size-capped (#16).

## What's next

- **#22 Ship-readiness gate** — final pre-launch checklist (last Phase-1 task).
- **Phase 2** (#23–32): multiple children, bookmarks/library, know-each-other quiz + games, kid wish wall + kid mode, calendar, WhatsApp reminders, memory timeline, weekly recap, gentle streak.
- **Phase 3** (#33–37): co-parent sharing, audio letters, voice input, community, billing.

Sign-out + a manage/delete-child entry point should be added to the **Me** tab (the delete-child screen is built but currently has no in-app entry point).
