# Reference-book notes — build tracker

**Goal:** distil 25 reference books into ORIGINAL, detailed Momzo-voice notes that ground
the AI (RAG). One-time build. Notes live in `knowledge base/books/<slug>/*.md`, get
`reference_only: true` (RAG-only, never a daily card), `source: "Momzo expert notes"`.

**Hard rules for every note (non-negotiable):**
- **Original wording only.** The book informs *which concepts* to cover; every sentence is
  ours. No copying, no close paraphrase, no mirroring the book's structure/examples.
  Extracted book text (`.book-extract/`, gitignored) is transient input, never committed.
- **Detailed & complete.** The AI must have full, expert understanding — mechanisms +
  ages + concrete parent actions, not thin summaries.
- **Momzo voice:** warm, no-guilt, practical, for mothers of 6–10s. Grounded in
  development; never clinical/diagnostic.
- After a batch: run `cd supabase/seed && node build_corpus.mjs` (apply the
  `reference_only` migration first). Idempotent — safe to re-run as notes grow.

## Consolidation decision (books 5–15)
The developmental textbooks/handbooks (Berk, Feldman, Hurlock, HCP V1/V2/V4 + Social-Emotional,
Cambridge Encyclopedia, Blackwell Handbook, Cowie's From Birth to Sixteen) all teach the SAME
science. Writing a separate note set per book would flood the RAG corpus with near-duplicate
chunks and degrade retrieval. Instead they feed ONE consolidated corpus in
`books/child-development/`, organised by developmental domain + theory, focused on middle
childhood (6–10). Books 5–15 are marked ✅ collectively once that corpus is complete.

## Status legend: ⬜ pending · 🟡 in progress · ✅ done

| # | Book (author) | slug dir | Priority | Status |
|---|---|---|---|---|
| 1 | Gentle Discipline (Ockwell-Smith) | gentle-discipline | HIGH | ✅ 12/12 |
| 2 | Positive Discipline for Preschoolers (Nelsen) | positive-discipline | HIGH | ✅ 8/8 |
| 3 | ADHD Workbook for Kids (Snowden) | adhd-focus-regulation | HIGH | ✅ 6/6 |
| 4 | TODDLER 2-in-1 (Karp) | early-discipline-foundations | MED | ✅ 3/3 (lean) |
| 5 | Child Development (Berk) | → child-development | HIGH | ✅ consolidated |
| 6 | Child Development (Feldman) | → child-development | HIGH | ✅ consolidated |
| 7 | Child Development (Hurlock) | → child-development | MED | ✅ consolidated |
| 8 | Blackwell Handbook of Early Childhood Development | → child-development | HIGH | ✅ consolidated |
| 9 | Cambridge Encyclopedia of Child Development | → child-development | HIGH | ✅ consolidated |
| 10 | Handbook of Child Psychology V1 — Theoretical Models | → child-development | MED | ✅ consolidated |
| 11 | Handbook of Child Psychology V2 — Cognition/Perception/Language | → child-development | HIGH | ✅ consolidated |
| 12 | Handbook of Child Psychology V4 — In Practice | → child-development | MED | ✅ consolidated |
| 13 | Handbook of Child Psychology — Social/Emotional/Personality | → child-development | HIGH | ✅ consolidated |
| 14 | From Birth to Sixteen Years (Cowie) | → child-development | HIGH | ✅ consolidated |
| 15 | Annotated instructor's manual (Berk) | → child-development | LOW | ✅ consolidated |
| 16 | How Children Learn (Holt) | how-children-learn | HIGH | ✅ 4/4 |
| 17 | Play=Learning (Singer) | play-and-learning | HIGH | ✅ 2/2 |
| 18 | 100 Ideas for Teaching PSED (Thwaites) | → life-skills | MED | ✅ consolidated |
| 19 | 1001 Teaching Tips | → life-skills | MED | ✅ consolidated |
| 20 | 101 More Life Skills Games (Badegruber) | → life-skills | MED | ✅ consolidated |
| 21 | How to Manage Spelling Successfully (Ott) | → school-skills | LOW | ✅ |
| 22 | How To Teach Your Baby Math (Doman) | → school-skills | LOW | ✅ |
| 23 | Mattering in Early Childhood | → mattering | MED | ✅ |
| 24 | 11 Ways to Develop a Sense of Mattering | → mattering | MED | ✅ |
| 25 | The Importance of Stability in the Developmental Environment | → mattering | MED | ✅ |

**🎉 ALL 25 BOOKS DONE.** Next step: apply the `reference_only` migration, then run `cd supabase/seed && node build_corpus.mjs` to embed.

## Developmental science (books 5–15 combined) — ✅ DONE (15 notes)
Consolidated corpus in `books/child-development/`. Done:
- ✅ how-development-works
- ✅ major-theories-of-child-development
- ✅ cognitive-development-6-to-10
- ✅ physical-and-brain-development-6-to-10
- ✅ language-and-communication-6-to-10
Done (cont.):
- ✅ emotional-development-6-to-10
- ✅ social-development-and-friendships
- ✅ moral-development-and-conscience
- ✅ self-concept-and-self-esteem
Done (cont.):
- ✅ play-and-its-role-in-development
- ✅ parenting-styles-and-their-effects
- ✅ gender-development
- ✅ milestones-overview-middle-childhood
Done (final 2):
- ✅ risk-resilience-and-individual-differences
- ✅ school-learning-and-motivation

## Early foundations / temperament (book 4) — done (lean, carry-forward)
- ✅ understanding-your-childs-temperament
- ✅ the-security-foundation-consistency-and-predictability
- ✅ the-sensitive-or-spirited-child

## ADHD / focus & regulation (book 3) — done
- ✅ understanding-focus-attention-and-the-active-child
- ✅ executive-function-the-brains-management-system
- ✅ helping-a-distractible-child-focus-and-follow-through
- ✅ organization-and-time-management-for-kids
- ✅ self-regulation-impulse-control-and-big-feelings
- ✅ focus-sleep-movement-and-food

## Positive Discipline (book 2) — planned note set
- ✅ the-mistaken-goals-behind-misbehaviour
- ✅ encouragement-versus-praise
- ✅ natural-and-logical-consequences
- ✅ family-meetings
- ✅ kind-and-firm-connection-before-correction
- ✅ routines-and-limited-choices
- ✅ mistakes-as-opportunities-the-3-Rs-of-recovery
- ✅ taking-time-for-training

## Gentle Discipline (book 1) — planned note set
- ✅ when-your-child-wont-listen-or-refuses
- ✅ why-children-misbehave-and-the-brain
- ✅ why-punishment-and-rewards-backfire
- ✅ handling-rudeness-and-back-talk
- ✅ handling-aggression-and-destructive-behaviour
- ✅ whining-sulking-and-big-emotions
- ✅ sibling-rivalry
- ✅ lying-and-honesty
- ✅ building-confidence-and-self-esteem
- ✅ keeping-your-own-cool-parental-triggers
- ✅ setting-limits-with-connection
- ✅ repair-after-conflict
