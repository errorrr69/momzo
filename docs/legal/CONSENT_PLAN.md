# Momzo — Parental Consent Level (US / COPPA)

> ⚠️ Engineering analysis + recommendation, **not legal advice.** Confirm with counsel.
> _Drafted 2026-06-26 · Region decision: **US first → COPPA applies.**_

## The gap
COPPA requires **verifiable parental consent (VPC)** before collecting personal
information from a child under 13 — and Momzo's users are parents of 6–10-year-olds.
The current build records a **parent attestation checkbox** ("I'm the parent and I
consent"). That is an *attestation*, **not** verifiable consent, and is **not
sufficient for a US launch**. A DB trigger already blocks child creation until a
consent row exists, so the *gate* is in place — only the **strength of the consent
method** needs upgrading.

## What COPPA accepts as "verifiable"
The method must be "reasonably calculated, in light of available technology" to ensure
the person consenting is the parent. Recognized methods include:

| Method | Friction | Notes |
|---|---|---|
| **Credit/debit card or online payment** with a transaction + notice | Low–Med | Easiest if billing exists; a nominal/refunded charge or an actual paid plan both qualify |
| Signed consent form (scan/photo upload or e-sign) | Med | "Print-and-send" / upload flow |
| Government-ID check (verify + delete) | High | Heavier; privacy-sensitive |
| Knowledge-based authentication (KBA) | Med | Dynamic, hard-to-guess questions |
| Video call / trained-personnel review | High | Manual, doesn't scale |
| **"Email-plus"** | Low | Email confirmation **plus** a second step (delay + follow-up, or a second confirmation). Allowed **only** when the child's data is **not disclosed to third parties** |

### ⚠️ Momzo-specific caveat on "email-plus"
"Email-plus" is the lowest-friction route, **but** it's only permitted when there is
**no disclosure of the child's information to third parties.** Momzo sends question
context (age/temperament/struggles — **never the name**) to AI providers (Mistral,
Google). Counsel must decide whether that processor relationship counts as
"disclosure" for email-plus eligibility. If it does, email-plus is **off the table**
and we need a stronger method (card/payment, signed form, or KBA).

## Recommendation
1. **Primary:** tie VPC to **payment** if/when billing is introduced — a card
   transaction with proper notice is a clean, scalable COPPA method and aligns with a
   future paid tier. (Billing is Phase 3 / deferred.)
2. **Before billing exists:** implement **signed-form upload** or **KBA** as the VPC
   method (both qualify regardless of the third-party-disclosure question), OR get
   counsel's sign-off that **email-plus** is acceptable given our processor setup.
3. Keep the existing DB consent gate; extend the `consents` record to capture the
   **method**, **timestamp**, **policy version**, and a verification reference.

## Implementation task plan (do NOT build this session)
1. **Decide the method** with counsel (recommend: KBA or signed-form pre-billing;
   payment-based once billing lands).
2. **Schema:** extend `consents` (already has `method`, `policy_version`) with
   `verified_at`, `verification_ref`, `verification_type`; keep the child-creation
   trigger requiring a *verified* consent (not just any row).
3. **Flow:** replace the attestation checkbox with the chosen VPC step; show the COPPA
   **direct notice** (what's collected, how used, parent rights) before consent.
4. **Parent dashboard:** review / withdraw consent + delete child (delete already
   exists; wire the entry point into the "Me" tab).
5. **Records:** retain consent records (method + timestamp) for audit.
6. **Re-consent:** on material policy changes, re-prompt before applying to existing
   child data.
7. **Revert dev shortcut:** turn OFF auth auto-confirm (Task 3) so the parent email is
   real and reachable — VPC + account recovery both depend on it.

## Done-for-now
- ✅ Region decision recorded (US/COPPA).
- ✅ Draft privacy policy (`PRIVACY_POLICY_DRAFT.md`) marked for legal review.
- ✅ Consent-level recommendation + task plan (this doc).
- ⛔ Stronger-consent implementation intentionally **not built** this pass (needs the
  method decision + counsel sign-off first).
