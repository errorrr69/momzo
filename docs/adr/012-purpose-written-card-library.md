# ADR 012 — Replace the scraped corpus with a purpose-written card library

**Status:** Accepted · 16 Aug 2026
**Supersedes:** the ingest half of ADR 004 (grounding stays; the source of truth changes)

## Context

The knowledge base was built by ingesting files under `knowledge base/`. That
produced 124 cards, and they were not one kind of thing:

| Rows | `source` | Origin | What it actually was |
|---|---|---|---|
| 67 | `curated` | article folders (`.txt`, `.md`) | **verbatim third-party text** |
| 57 | `Momzo expert notes` | `books/` | original prose, `reference_only` |

The 67 were the problem. One begins mid-word — `"ne of the first real life
lessons…"` — which is what a copy-paste that clipped a character looks like.
Several quote named clinicians and name four commercial books. Four of the source
files carry a `> Source: <url>` header; the rest carry nothing. Reproducing that in
a paid app is copyright infringement, and no amount of RAG framing changes it.

They were also wrong for the product. The corpus was targeted 3–10, the prose was
written for a reader in an armchair, and the sample we pulled during the audit was
about **sleep-training an infant** — reachable, today, by a mother of a
five-year-old.

Replacing them needed a library that could serve both surfaces at once, because
the daily card and the AI's grounding corpus have always been the same table.

## Decision

**1. The daily library is 90 purpose-written cards (ages 5–6), specified by
`00_CARD_SPEC.md`.** Original text, one idea per card, ~250–280 words, written to a
fixed five-part structure: `title → summary → why_it_matters → main_read →
activity`. Seeded by `build_daily_cards.mjs`, idempotent by slug.

**2. Structure moves into the schema.** The old shape was `body` plus fields the AI
derived from it later (`hook`, `quick_points`, `try_this`). Those are dropped. When
cards are written to a structure, the structure belongs in columns, not in a
read-time reconstruction — and the app stops needing a markdown/CMS-debris
stripper it only ever needed because the text was scraped.

**3. The 57 reference notes stay.** They live under `books/`, so "delete the
book-derived corpus" reads as including them, and it should not. They are original
wording that teaches the concepts rather than reproducing anyone's prose; they are
`reference_only`, so no parent has ever seen one; and they cover ages 7–10, which
the new 5–6 library does not. Deleting them would cost real grounding to fix a
problem they do not have.

**4. `concept_basis` is enforced private by column privilege, not convention.** It
records which established concept a card teaches, for auditing (spec §6). RLS
cannot express "not this column" — a policy chooses rows. So the table-level
`SELECT` grant is revoked from `authenticated` and re-granted column by column,
omitting this one.

**5. The two vocabularies are guarded on both sides.** Card `tags` are constrained
in the database (`content_cards_tags_vocab`); the onboarding→tag mapping is pinned
by `app/test/daily_targeting_test.dart`.

**6. Selection ranks by match STRENGTH.** Rule-based as always — age window, tag
overlap, least-recently-shown — but ordering counts *how many* of her tags a card
carries.

## Consequences

**Good.**
- No third-party text remains in the product. The AI cites Momzo's own material:
  verified end-to-end, the top retrieval hit is a new card on every question tried,
  and a live `ai-chat` answer cited three of them.
- The daily card and the library reader now render the identical structure, because
  both consume the same five columns.
- `select=*` on `content_cards` now fails for a signed-in client. That is
  deliberate: it converts a silent leak into a loud error, and it is why every app
  query was rewritten to an explicit column list.
- Deleting a card purges any cached AI answer citing it — the existing
  `trg_purge_cached_answers` trigger did this automatically for all 67.

**Costs and limits, honestly.**
- **The library is ages 5–6 only.** 90 cards ≈ 3 months before a repeat, for that
  band alone. A 7-year-old's parent now falls through to `reference_only`-excluded
  emptiness on the daily surface. Bands 7–8 and 9–10 have to be written before those
  ages can be sold to.
- Six cards run 112–119 words against a 120-word floor. The seeder warns rather
  than fails: length is a content note, not a data fault.
- A card edit is a seeder run, not a deploy — but adding a *column* is still a
  migration plus an app release.
- `match_content_cards` can still return a `reference_only` note, so a citation
  chip can point at a card the parent cannot open. Pre-existing, unchanged here,
  and worth fixing when citations become tappable.

## Alternatives rejected

- **Rewrite the 67 in place.** Same words, laundered, is the same risk; and it
  keeps a 3–10 corpus we do not want.
- **Keep them `reference_only` so only the AI sees them.** Reproduction is
  reproduction whether or not it is displayed, and the AI would still paraphrase
  from copyrighted wording.
- **Delete the 57 as well.** Would have left the AI grounded on 90 cards covering
  one two-year band, and thrown away original work to solve someone else's problem.
- **Keep `body` alongside `main_read`.** Two plausible homes for the teaching text
  is how a schema rots.
