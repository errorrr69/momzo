-- Momzo schema · fix: answer provenance must outlive the cached row
--
-- ai_messages.cached_answer_id served two jobs at once and could not do both:
--   (a) the LINK, so a thumbs-down can retire the cached answer behind it, and
--   (b) the FACT that this answer came from the cache, for analytics.
--
-- A thumbs-down deletes the cached_answers row, and ON DELETE SET NULL then wipes
-- the link — so every cached answer someone disliked quietly reappeared as
-- "freshly generated". The ai_answer_feedback split by from_cache was therefore
-- biased in the worst possible direction: it dropped exactly the evidence that
-- cached answers were underperforming.
--
-- Provenance is now recorded separately at write time and never nulled.

alter table public.ai_messages
  add column if not exists served_from_cache boolean not null default false;

comment on column public.ai_messages.served_from_cache is
  'True when this answer was SERVED from the semantic cache. Provenance only — '
  'never nulled, unlike cached_answer_id, which is a live FK used to retire a '
  'cached answer on a thumbs-down.';

-- Backfill what we can still infer: a surviving link means it came from, or went
-- into, the cache. Rows whose link was already nulled by a thumbs-down are
-- unrecoverable and stay false — a one-time, known gap rather than a silent one.
update public.ai_messages
   set served_from_cache = true
 where cached_answer_id is not null
   and served_from_cache = false;

create index if not exists idx_ai_messages_provenance
  on public.ai_messages (served_from_cache, created_at desc)
  where role = 'assistant';

-- Split on the durable column, not the FK.
create or replace view public.ai_answer_feedback with (security_invoker = true) as
select
  date_trunc('day', m.created_at)::date                     as day,
  m.served_from_cache                                       as from_cache,
  count(*)                                                  as answers,
  count(*) filter (where m.feedback is not null)            as rated,
  count(*) filter (where m.feedback = 1)                    as helpful,
  count(*) filter (where m.feedback = -1)                   as not_helpful,
  round(100.0 * count(*) filter (where m.feedback = 1)
        / greatest(count(*) filter (where m.feedback is not null), 1), 1) as helpful_pct,
  -- How many cached answers a thumbs-down has retired. This is the loop closing;
  -- if it climbs, the similarity threshold is too loose.
  count(*) filter (where m.feedback = -1 and m.served_from_cache)          as cache_retirements
from public.ai_messages m
where m.role = 'assistant'
group by 1, 2;
