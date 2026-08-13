# ADR 006 — Push-only notifications; WhatsApp cancelled

**Status:** Accepted · **supersedes** the original "push first, WhatsApp later" plan
**Decided:** June 2026 (push-first) · WhatsApp cancelled ~July 2026 (task 29)

## Context

The PRD (§7) and Build Guide (Hard Rules 11–12) planned two notification channels: FCM
push for Phase 1, and opt-in WhatsApp utility templates in Phase 2. WhatsApp was
attractive for an India-weighted audience, where it is the default messaging surface and
utility templates cost a fraction of a cent.

Push shipped first and worked: `pg_cron` dispatches a gentle daily nudge and due
reminders through an Edge Function, quiet-hours aware and idempotent, verified
delivering to a real device.

WhatsApp then had to justify itself against what it actually costs to run: a WhatsApp
Business Account, template pre-approval, a BSP or direct Cloud API integration, per-message
billing, and an opt-in flow — all to duplicate a channel that already works and is free.

## Decision

**Push only.** WhatsApp is cancelled, not deferred.

Task 29 is marked `cancelled`. The `nudge_channel` column exists but carries push only —
the onboarding migration removed WhatsApp from it. `whatsapp-send` was never built.
`WHATSAPP_TOKEN` and `WHATSAPP_PHONE_NUMBER_ID` remain in `supabase/.env.example` as
dead entries and should be removed.

## Consequences

**Good.** One notification path to build, test, and reason about. Idempotency has a
single implementation: check `sent_at`, send, then mark.

**Good.** Zero per-message cost. Notification volume never becomes a cost conversation.

**Good.** Hard Rule 12 (utility templates only, never marketing) is moot — there is no
channel where marketing messages were even possible.

**Cost.** Push requires the app to be installed and notifications permitted. A mother
who denies the permission is unreachable. That is accepted; the product is
deliberately non-nagging, and Hard Rule 18 forbids the kind of re-engagement pressure a
second channel would tempt.

**Reversible.** Nothing in the schema prevents adding a channel later —
`reminders.channel` already exists. Doing so would need a new ADR superseding this one,
and would reopen the template-approval and billing work this decision avoided.
