# ADR 004 — Grounded AI with an always-on refer-out screen

**Status:** Accepted · backfilled 2026-08-13
**Decided:** June 2026 (Build Guide §6 Hard Rules 6–7; PRD §6.3)

## Context

Momzo's AI answers questions from mothers about their children. Two risks dominate every
other consideration.

A general-purpose model will confidently produce parenting advice with no provenance —
plausible, unattributable, occasionally wrong. For a product whose entire premise is
escaping the low-trust ocean of social-media parenting content, that would be
self-defeating.

More seriously, some questions are not parenting questions. Disclosures of self-harm,
abuse, a medical emergency, or a genuine developmental concern will arrive. An AI that
answers those as though they were ordinary questions could do real harm.

## Decision

**Grounding.** Answers come only from vetted `content_cards` retrieved via pgvector, and
the response **cites the source cards**. The model is instructed to answer from the
supplied excerpts and established knowledge, not from open recall. The app renders the
citations as source chips beneath every answer.

**Refer-out.** A classifier runs on **every** AI turn across three categories — safety
(self-harm/abuse), medical, and developmental concern. On a signal, the app warmly
redirects to a professional and **does not advise**. It never diagnoses. Off-topic
requests are scope-fenced.

**Ordering is part of the decision.** The refer-out screen is regex-based, costs
nothing, and runs **before** the rate limiter and before the budget circuit breaker. The
code says so explicitly, and it is why the ordering must not be "optimised".

## Consequences

**Good.** Every answer is attributable to reviewed content. Trust is the product.

**Good — the property that matters.** Because refer-out is rule-based and runs first, a
mother in crisis reaches the safety path **even if she is over her rate limit, even if
the budget breaker has tripped, and even if Mistral is completely down.** Safety does
not depend on model availability or on the account being in good standing.

**Cost.** Answer quality is bounded by corpus quality. A thin corpus yields thin answers,
which is why 72 original book-note sets were written to ground it.

**Cost.** The classifier is tuned for high recall, so it will sometimes refer out on a
question that did not need it. That asymmetry is deliberate and correct.

**Constraint.** On-device generation may never bypass this. `AiRouter` routes every
red-risk request to the cloud, and a post-answer safety screen discards on-device output
that looks sensitive (ADR 007).
