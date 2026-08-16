# Momzo — Daily Read Cards: Spec & Style Guide

**Band:** Ages 5–6 · **Count:** 90 cards (≈3 months of daily content)
**Companion file:** `momzo_daily_cards_5_6.json` (seedable)

---

## 1. Why these cards exist

They replace book/PDF excerpts in the knowledge base. That matters for two reasons:

1. **Legal.** Pasting text from books and PDFs into a commercial app reproduces
   copyrighted material. The *ideas* in child development are free to teach; the
   *wording* is not. Every card here is written from scratch.
2. **Product.** Book prose is written for a reader in an armchair. These are written
   for a tired mom at 9pm who has about two minutes.

They feed **two** surfaces: the daily read card **and** the AI expert's RAG corpus.
Seeding these means the AI starts citing Momzo's own material instead of books.

---

## 2. Card schema

| Field | Limit | Purpose |
|---|---|---|
| `slug` | kebab-case | stable id → idempotent re-seeding |
| `title` | ≤ 8 words | warm, plain, no jargon |
| `summary` | 2–3 lines (~30 words) | the at-a-glance |
| `why_it_matters` | ~40 words | ties to a behavior she actually sees at home |
| `main_read` | **120–180 words** | the teaching — ONE idea only |
| `activity` | ~50 words | one thing to try, inside an existing routine |
| `category` | 1 of 7 | see §3 |
| `subtopic` | short | finer grain |
| `age_min` / `age_max` | 5 / 6 | targeting |
| `tags[]` | controlled vocab | **must match onboarding vocabulary** (§4) |
| `concept_basis` | internal | which established concept it teaches (QA only, never shown) |

**Total ≈ 250–280 words per card.** Under two minutes at a tired reading pace,
leaving room for the activity inside the five-minute promise. The word caps are what
keep it that way — without them, cards drift long.

---

## 3. Categories (7)

| Category | Covers |
|---|---|
| `big-feelings` | meltdowns, frustration, worries, anger, emotional vocabulary |
| `focus-attention` | attention span, listening, transitions, impulse control |
| `confidence-independence` | self-belief, trying hard things, doing it themselves |
| `connection-bonding` | special time, rituals, repair, real conversation |
| `learning-curiosity` | early reading, early maths, wonder, love of learning |
| `getting-along` | sharing, friendships, siblings, kindness, perspective-taking |
| `everyday-routines` | sleep, mornings, meals, screens, tidying, car time |

---

## 4. Tag vocabulary (controlled — must match onboarding)

Targeting works by matching `children.focus_goals` / `children.challenges` against
card `tags`. **If the tag vocabulary drifts, targeting silently fails.**

```
big-feelings · meltdowns · frustration · worries · anger
focus · listening · transitions · high-energy
confidence · independence · self-belief
connection · bonding · rituals
learning · curiosity · reading · numbers
sharing · friendships · siblings · kindness · shy-warm-up
sleep · mornings · mealtimes · screens · tidying
```

---

## 5. Voice rules (non-negotiable)

1. **Never name her worry.** No "guilt," "good enough," "not doing enough,"
   "failing," "overwhelmed." Not even to reassure. Lift without labelling.
2. **Short sentences. Plain words.** If a technical term appears, it's explained in
   the same breath, in everyday language.
3. **One idea per card.** No lists of five things. Depth over breadth.
4. **The activity fits a routine that already exists** — dinner, bath, car, bedtime,
   walking to school. Never "set aside 30 minutes."
5. **Never diagnose.** No labels on the child. Concerns route to the refer-out path.
6. **Compare the child only to themselves.** No peers, no percentiles, no "should
   be able to by now."
7. **End warm.** The last line leaves her feeling capable, never behind.
8. **Give her the actual words.** Scripts in quotes beat abstract advice.

---

## 6. Evidence stance

Cards teach well-established developmental concepts. Where popular parenting advice
has been revised, the cards follow the evidence, not the trend. Three examples:

- **Growth mindset:** taught as *strategy and process*, not "praise effort, not
  intelligence." Independent replications failed to reproduce the harm-from-
  intelligence-praise finding, and meta-analytic effects are small (r ≈ 0.10, larger
  for lower-achieving children). What holds up: believing *strategic* effort — with
  better methods, feedback, and help-seeking — leads to growth. Cards never do
  effort-cheerleading ("you can do anything if you try!"), which is the documented
  misapplication.
- **Attention span:** normalized at roughly 12–18 minutes for this age, so cards
  reassure rather than alarm.
- **Co-regulation:** well-supported (a calm adult measurably influences a child's
  stress response), and framed so it never implies constant availability — successful
  co-regulation does not require constant attention.

`concept_basis` records the underlying concept per card so the library can be audited.

---

## 7. Display structure (app side)

The app renders every card the same way, so the mom's eye learns the shape:

```
TITLE
summary                          ← 2–3 lines, largest body text
──────────────────────────────
WHY THIS MATTERS FOR [CHILD]     ← coral tinted callout (existing component)
why_it_matters
──────────────────────────────
main_read                        ← the teaching
──────────────────────────────
TRY THIS TONIGHT                 ← sage tinted card
activity
```

No card carries its own layout. Text only in the data; structure lives in the app.

---

## 8. Coverage (90 cards, ages 5–6)

| Category | Cards |
|---|---|
| big-feelings | 16 |
| focus-attention | 12 |
| confidence-independence | 13 |
| connection-bonding | 13 |
| learning-curiosity | 13 |
| getting-along | 12 |
| everyday-routines | 11 |

90 cards = ~3 months before any repeat. Coverage matters more than raw count: every
profile combination (goal × challenge) has something good to serve.

---

## 9. Seeding notes for Claude Code

- Seed into `content_cards` via the existing **slug-based idempotent seeder**.
  Re-running changes nothing.
- Chunk + embed each card for pgvector (`content_embeddings`) so the AI expert cites
  these instead of book text. **Remove the old book/PDF-derived rows** in the same
  migration, and run the corpus integrity check afterwards (no orphaned
  `cited_card_ids` or `daily_assignments`).
- `concept_basis` is internal — never render it.
- Daily selection stays **rule-based** (age + tag match against the child's profile,
  least-recently-shown first). No LLM in the selection path.
