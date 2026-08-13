# ADR 003 — Mistral for generation, Gemini for embeddings

**Status:** Accepted · backfilled 2026-08-13
**Decided:** June–July 2026 (superseded the original Gemini-only plan)

## Context

The original plan (`starting prompt.txt`, PRD §6.2) was Gemini for everything —
embeddings and generation — on the free tier.

That did not survive contact with reality: **the project's Google API key has a
`generateContent` quota of zero.** Embeddings were unaffected. Rather than wait on quota
or restructure around a different provider wholesale, generation moved to Mistral while
embeddings stayed on Gemini.

A second consideration made this more than a workaround. Momzo sends parenting questions
that may describe a real child. Mistral's **paid** La Plateforme API contractually does
not train on customer prompts. Its **free** tier is opted into training by default. The
provider choice therefore carries a billing requirement, not just an API key.

## Decision

- **Embeddings: Google Gemini `gemini-embedding-001`** at 768 dimensions, matching the
  `content_embeddings` vector column and the HNSW cosine index.
- **Generation: Mistral**, `mistral-small-latest` by default, escalating to
  `mistral-medium-latest` only when retrieval similarity is below 0.5 or the question
  screens as sensitive.
- Both keys live only in `supabase/functions/_shared/ai.ts`. A CI guard
  (`check_llm_call_sites.mjs`) fails the build if a provider key or endpoint appears
  anywhere else, or if a new function calls generation outside `ai-chat` and
  `generate-game-items`.

## Consequences

**Good.** Measured cost is roughly **1–2¢ per active user per month** against a $0.10
target; even an all-medium worst case reaches only ~5.6¢. Cost is not a constraint on
product decisions at this stage.

**Good.** Cheap-by-default routing means quality escalation is a deliberate, observable
event rather than a default.

**Cost.** Two providers means two failure modes and two dashboards. Mistral being down
degrades to the semantic cache and a warm retry message; the refer-out path is
regex-based and unaffected (ADR 004).

**Open — launch blocker.** The Mistral account **must be confirmed to be on the paid
plan** before real families use the app, or prompts describing children become training
data. Zero Data Retention is available and worth requesting. Tracked in
`docs/AI_COST_AND_PRIVACY.md`.

**Note.** The `content_embeddings` table comment still names `text-embedding-004` from
the original plan. The dimensionality is identical, so it is a documentation artefact
rather than a defect.
