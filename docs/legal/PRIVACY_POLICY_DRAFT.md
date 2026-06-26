# Momzo — Privacy Policy (DRAFT)

> ⚠️ **DRAFT — REQUIRES LAWYER REVIEW.** This is an engineering draft written to
> match what the app actually does (US / COPPA-oriented). It is **not legal advice**
> and must be reviewed by a qualified attorney before publication or launch.
>
> _Drafted: 2026-06-26 · Region: United States (COPPA). For an India (DPDP) or EU
> (GDPR-K) launch, this needs region-specific revision._

**Effective date:** _[to be set]_
**Operator:** _[Legal entity name + address]_ ("Momzo", "we", "us")
**Contact:** _[privacy@momzo.app — to be set]_

Momzo helps a parent spend a few cozy minutes a day understanding their child
better. It is designed for a **parent or legal guardian** to use, on behalf of their
child (ages 6–10). We take children's privacy seriously and built the product to
collect as little as possible.

## 1. Who uses Momzo
Momzo accounts are created and operated by a **parent or legal guardian** ("you").
The app is not directed to children for independent sign-up. Before any information
about a child is collected, we obtain **verifiable parental consent** (see §6).

## 2. Information we collect

**From you (the parent):**
- Account: email address and password (passwords are stored hashed by our auth
  provider; we never see them in plain text).
- Optional display name.
- Notification preferences and (if you opt in) a device push token.

**About your child (provided by you):**
- The child's **first name** (used only to personalize the app's wording on your
  screen — see §4; it is **never** sent to any AI provider).
- Age (6–10), and the temperament / things-they're-working-on you select.

**Activity you generate in the app:**
- Which daily cards you've read, activities you've marked done, and your responses
  to the "Question of the Day" (a parent answer and, where you enter it, the child's
  answer to the same question).
- Questions you ask the in-app expert and the answers shown to you.

**Technical / diagnostic:**
- Crash and error reports (via Sentry), **scrubbed of IP address and personal
  identifiers**.
- Standard server logs needed to operate the service (no message content; see §5).

We do **not** collect precise location, contacts, photos (no photo feature is
enabled), or device advertising identifiers, and we do **not** use tracking for ads.

## 3. We do not advertise to children or sell data
- **No advertising** is shown in Momzo, to you or your child.
- We do **not sell** personal information and do **not** share it for cross-context
  behavioral advertising.
- We never condition your child's participation on disclosing more information than
  is reasonably necessary.

## 4. How we use information
- To personalize the experience (e.g. age-appropriate daily cards and activities,
  and warm wording that may reference your child by the first name **on your own
  screen**).
- To answer your parenting questions using a curated, expert-reviewed knowledge base.
- To send the gentle reminders you've opted into.
- To keep the service secure, debug problems, and understand aggregate, non-identifying
  usage and cost.

**AI specifics (privacy-protective by design):** when you ask the expert a question,
we send the question plus non-identifying context (your child's **age, temperament,
and focus areas only**) to our AI providers. Your child's **name is never sent to any
AI model.** Our generation provider's paid API does **not** use the content to train
its models.

## 5. Service providers (processors)
We share the minimum necessary with vendors who process data on our behalf under
contract, not for their own purposes:

| Provider | Purpose | Notes |
|---|---|---|
| Supabase | Database, authentication, hosting, push delivery | Primary data store (US region) |
| Mistral AI | Generates expert answers | Paid API; **not used for training**; ~30-day abuse-monitoring retention |
| Google (Gemini) | Converts text to search vectors (embeddings) | Receives question text for retrieval; no child name |
| Firebase Cloud Messaging | Delivers push notifications | Device token only |
| Sentry | Crash/error diagnostics | IP-scrubbed; no message content or child identifiers |

_[Confirm each vendor's COPPA/DPA terms during legal review; list any others added later.]_

## 6. Verifiable parental consent
Before collecting information about your child, we present a clear notice and obtain
your **verifiable parental consent**. _[The specific method is described in the
consent plan and must meet COPPA's "reasonably calculated" standard — see
`CONSENT_PLAN.md`. The current build uses a parent attestation checkbox, which is
**not** sufficient for a US launch and is being upgraded.]_ You may **withdraw
consent at any time** by deleting your child's profile (§8), which stops further
collection and deletes the associated data.

## 7. Your rights as a parent
You can, at any time:
- **Review** the information we hold about your child (in-app and by request).
- **Delete** your child's profile and all associated data (§8).
- **Withdraw consent** and stop further collection.
- Contact us at _[privacy contact]_ with any request; we respond within _[X]_ days.

## 8. Data retention & deletion
- We keep data until you delete it or close your account.
- **"Delete my child"** removes the child's profile and all associated records
  (daily history, activity logs, AI conversations, question responses, etc.) from the
  live database in a single cascading operation.
- Encrypted backups are retained on a rolling **14-day** basis and then expire;
  deleted data ages out of backups within that window.
- Diagnostic/error data is retained per our providers' limits (e.g. Sentry's
  retention) and contains no child identifiers.

## 9. Security
- Every family's data is isolated by row-level security; one account cannot access
  another's records.
- Data is encrypted in transit (TLS). Sensitive keys (AI, push, admin) live only on
  the server, never in the app.
- Access to production data is limited and logged.
No method is 100% secure, but we work to protect your family's information.

## 10. Changes to this policy
If we make material changes, we will notify parents and obtain new consent where
required by law before applying changes to previously collected children's data.

## 11. Contact
Questions or requests: _[privacy@momzo.app / mailing address]_.

---
_This draft reflects the app's data practices as of 2026-06-26. Engineering owner to
keep it in sync with the actual data flows; legal owner to finalize wording, fill
bracketed items, and confirm COPPA (and any state-law, e.g. CCPA) obligations._
