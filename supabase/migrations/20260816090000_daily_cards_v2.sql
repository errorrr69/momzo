-- Momzo schema · Daily read cards v2 (00_CARD_SPEC.md)
--
-- The card library moves from "an article with a body" to a fixed five-part
-- structure the app renders identically every time (spec §7):
--
--   title → summary → why_it_matters → main_read → activity
--
-- Why the shape changed. The old corpus was scraped article text, so a card was
-- just `body` plus whatever the AI could later derive from it (`hook`,
-- `quick_points`, `try_this`). The new cards are written to the structure, so the
-- structure belongs in the schema rather than being reconstructed at read time.
--
-- Column mapping, old -> new:
--   body         -> main_read   (the teaching; one idea, 120-180 words)
--   hook         -> summary     (the at-a-glance, 2-3 lines)
--   try_this     -> activity    (one thing to try inside an existing routine)
--   quick_points -> dropped     (no equivalent in the fixed structure)
--
-- The three superseded columns are backfilled and then dropped: nothing reads
-- them after the app changes that land with this migration, and leaving them
-- would give a future writer two plausible places to put the teaching text.
--
-- concept_basis is INTERNAL. It records which established developmental concept a
-- card teaches so the library can be audited (spec §6), and it must never reach a
-- parent. Enforced structurally at the bottom of this file, not by convention.

alter table public.content_cards
  add column if not exists summary       text,   -- §2 at-a-glance, ~30 words
  add column if not exists main_read     text,   -- §2 the teaching, 120-180 words
  add column if not exists activity      text,   -- §2 "try this tonight", ~50 words
  add column if not exists category      text,   -- §3 one of seven
  add column if not exists subtopic      text,   -- §2 finer grain within a category
  add column if not exists concept_basis text;   -- §6 internal QA only — never rendered

-- Backfill before dropping, so the 57 reference-only notes that survive this
-- change keep their text. `is null` guards make the backfill re-runnable.
update public.content_cards set main_read = body     where main_read is null and body     is not null;
update public.content_cards set summary   = hook     where summary   is null and hook     is not null;
update public.content_cards set activity  = try_this where activity  is null and try_this is not null;

alter table public.content_cards
  drop column if exists body,
  drop column if exists hook,
  drop column if exists quick_points,
  drop column if exists try_this;

-- Category is a closed set (spec §3). A typo here would silently create an eighth
-- shelf that nothing browses, so the database refuses it rather than storing it.
-- The tag-vocabulary guard is the sibling of this one and lands in the follow-up
-- migration, once the old corpus (which carries the old tags) is gone.
alter table public.content_cards
  drop constraint if exists content_cards_category_valid;
alter table public.content_cards
  add constraint content_cards_category_valid check (
    category is null or category in (
      'big-feelings', 'focus-attention', 'confidence-independence',
      'connection-bonding', 'learning-curiosity', 'getting-along',
      'everyday-routines'
    )
  );

create index if not exists idx_content_cards_category on public.content_cards (category);

-- ---------------------------------------------------------------------------
-- concept_basis must never be returned to a client.
--
-- RLS cannot express this: a policy decides which ROWS you see, never which
-- columns. Column privileges can, and they are checked by the database itself,
-- so no future select — app code, a new screen, a hand-written PostgREST call —
-- can leak the field by accident.
--
-- A table-level GRANT covers every column including ones added later, so the
-- table-level grant has to go first; a column-level REVOKE cannot punch a hole
-- in it. Re-granting column by column is what makes the omission meaningful.
--
-- Practical consequence: `select=*` on content_cards now FAILS for a signed-in
-- client rather than quietly including the field. That is the intended design —
-- it turns a silent leak into a loud error — and every app select was rewritten
-- to an explicit column list in the same change.
--
-- service_role keeps full table access: the RAG path and the seeders legitimately
-- read and write concept_basis server-side.
revoke select on public.content_cards from anon, authenticated;

grant select (
  id, slug, title, summary, why_it_matters, main_read, activity,
  category, subtopic, age_min, age_max, tags, source, slides,
  published, reference_only, created_at, updated_at
) on public.content_cards to authenticated;

grant select on public.content_cards to service_role;
