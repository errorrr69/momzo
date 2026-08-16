-- Momzo content · Remove the scraped article corpus
--
-- Runs AFTER build_daily_cards.mjs has seeded and embedded the 90 replacement
-- cards. Ordering matters: this migration is only safe once the new library is
-- live, or it would empty the daily surface and shrink the RAG corpus to the
-- reference notes alone.
--
-- WHAT GOES: the 67 rows with source = 'curated'. These were ingested from .txt
-- and .md files under `knowledge base/` that hold verbatim third-party article
-- text — one begins mid-word, several quote named clinicians and name commercial
-- books, and only four carry any attribution at all. Reproducing that in a paid
-- app is the copyright problem this whole change exists to fix. They are also
-- off-band: the corpus was targeted 3-10 and includes infant sleep training.
--
-- WHAT STAYS: the 57 rows with source = 'Momzo expert notes' (reference_only).
-- Despite living under `knowledge base/books/`, these are ORIGINAL prose written
-- in Momzo's voice — they teach the concepts, they do not reproduce the wording.
-- They are reference_only, so no parent has ever seen them; they exist purely to
-- ground the AI, and they cover ages the new 5-6 library does not. Deleting them
-- would cost real grounding to fix a problem they do not have.
--
-- `source` is the discriminator rather than the slug prefix because it is what the
-- ingest actually stamped, and it agrees exactly with folder origin: 67 curated,
-- 57 expert notes, no row ambiguous.
--
-- No explicit BEGIN/COMMIT here: both `supabase db push` and apply_migrations.mjs
-- run each file inside a transaction already, and an inner COMMIT would end the
-- outer one early — committing the deletes before the ledger write that records
-- them. The four steps below are atomic because the runner makes them so.

-- 1. Citations. content_embeddings and saved_cards cascade on delete; an ID sitting
--    inside ai_messages.cited_card_ids is a plain uuid[] and cascades to nothing, so
--    it is the one reference that can actually dangle.
--
--    Strip removed ids from the array instead of deleting the message: the mother's
--    conversation history is hers, and an answer that cited four cards is still a
--    real answer if one citation is retired. There are zero such rows today; this
--    is written to be correct whenever it runs, not just tonight.
update public.ai_messages m
set cited_card_ids = coalesce(
      (select array_agg(x)
         from unnest(m.cited_card_ids) as x
        where x in (select id from public.content_cards where source is distinct from 'curated')),
      '{}'::uuid[]
    )
where m.cited_card_ids is not null
  and exists (
    select 1 from unnest(m.cited_card_ids) as x
     where x in (select id from public.content_cards where source = 'curated')
  );

-- 2. Daily assignments. The FK is ON DELETE CASCADE, so doing nothing would let
--    these vanish silently — correct in the database, invisible in review. Clearing
--    them explicitly says it out loud.
--
--    Clearing rather than re-pointing, deliberately: both rows are UNREAD
--    (read_at is null), so nothing is lost, and the app re-assigns on next open
--    through the rule-based path that targets age AND the child's tags. Re-pointing
--    here would have to guess at that targeting in SQL — duplicating selection logic
--    in a second place — and would hand the mother an untargeted card. Clearing
--    gives her a matched one instead.
delete from public.daily_assignments
where card_id in (select id from public.content_cards where source = 'curated');

-- 3. The corpus itself. content_embeddings.card_id and saved_cards.card_id are both
--    ON DELETE CASCADE, so the vectors and any bookmarks go with the cards.
delete from public.content_cards where source = 'curated';

-- 4. Now that the old tags are gone, close the vocabulary.
--
--    Spec §4 is blunt about this: targeting matches children.focus_goals /
--    challenges against card tags, and if the vocabulary drifts, targeting fails
--    SILENTLY — the query still runs, matches nothing, and falls through to an
--    untargeted card. Nobody sees an error; the product just quietly stops being
--    personalised. A check constraint converts that silence into a write failure.
--
--    reference_only rows are exempt: they carry the older RAG tag set, they are
--    never targeted, and retagging them would be churn with no reader.
alter table public.content_cards
  drop constraint if exists content_cards_tags_vocab;
alter table public.content_cards
  add constraint content_cards_tags_vocab check (
    reference_only or tags <@ array[
      'big-feelings', 'meltdowns', 'frustration', 'worries', 'anger',
      'focus', 'listening', 'transitions', 'high-energy',
      'confidence', 'independence', 'self-belief',
      'connection', 'bonding', 'rituals',
      'learning', 'curiosity', 'reading', 'numbers',
      'sharing', 'friendships', 'siblings', 'kindness', 'shy-warm-up',
      'sleep', 'mornings', 'mealtimes', 'screens', 'tidying'
    ]::text[]
  );
