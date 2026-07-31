-- Momzo schema · AI Cost & Scaling Strategy (Momzo_AI_Cost_Strategy.md)
--
-- Implements the storage side of:
--   Layer 3  rate limiting        -> ai_usage becomes the rolling-window counter
--   Layer 4  semantic answer cache-> cached_answers + match/purge functions
--   Layer 8  telemetry            -> ai_usage widened into the PII-free request log
--   Layer 9  budget circuit breaker-> ai_spend_24h view read by the Edge Function
--
-- Hard rules honoured here: RLS + index on every new table; PII-free telemetry
-- (no question text, no answer text on ai_usage, no child identifiers anywhere);
-- cached answers are global but bucketed and name-free.

-- ---------------------------------------------------------------------------
-- 1) ai_usage: the single AI request log (strategy §8's `ai_request_log`)
-- ---------------------------------------------------------------------------
-- We widen the existing table rather than adding a second, overlapping one.
-- A row is now written for EVERY AI request, including the ones that cost
-- nothing (refer-out, rate-limited, semantic cache hit) — `billable` marks the
-- ones that actually hit a model, and is what the rate limiter counts.

-- model is null on the free paths (refer-out / rate-limited / cache hit).
alter table public.ai_usage alter column model drop not null;

alter table public.ai_usage
  add column if not exists source             text    not null default 'cloud',   -- 'cloud' | 'on_device'
  add column if not exists billable           boolean not null default true,      -- did this turn call a model?
  add column if not exists prompt_cache_hit   boolean not null default false,
  add column if not exists cached_tokens      int,                                -- provider-reported cached prefix tokens
  add column if not exists semantic_cache_hit boolean not null default false,
  add column if not exists refer_out          boolean not null default false,
  add column if not exists rate_limited       boolean not null default false,
  add column if not exists breaker_state      text    not null default 'ok',      -- 'ok' | 'soft' | 'hard'
  add column if not exists latency_ms         int,
  add column if not exists estimated_cost_usd numeric(14, 8) not null default 0;

comment on table public.ai_usage is
  'PII-free AI request log. NEVER store question text, answer text, child names or '
  'any free text the user wrote. owner_id is an FK for per-user aggregation only.';

-- The rate limiter's hot path: count billable rows for one owner, one mode, last 24h.
create index if not exists idx_ai_usage_owner_mode_created
  on public.ai_usage (owner_id, mode, created_at desc) where billable;

-- The circuit breaker's hot path: rolling spend over all users.
create index if not exists idx_ai_usage_created_cost
  on public.ai_usage (created_at desc) where billable;

-- ---------------------------------------------------------------------------
-- 2) cached_answers — Layer 4 semantic answer cache
-- ---------------------------------------------------------------------------
-- GLOBAL, not per-family: an answer is only ever written here after it passed the
-- output screen and was proven name-free, so it carries no personal data. The key
-- is (question embedding, personalization bucket) so an answer written for an
-- 8-year-old's family is never served to the parent of a 4-year-old.
create table if not exists public.cached_answers (
  id                 uuid primary key default gen_random_uuid(),
  question_text      text        not null,          -- the canonical question that produced it
  question_embedding vector(768) not null,          -- same model/dims as content_embeddings
  bucket_key         text        not null,          -- age_band|focus_goal|challenge
  answer_text        text        not null,
  cited_card_ids     uuid[]      not null default '{}',
  model              text,                          -- which model produced it (monitoring)
  hit_count          int         not null default 0,
  created_at         timestamptz not null default now(),
  expires_at         timestamptz not null default now() + interval '90 days'
);

-- RLS on, with NO policies for authenticated/anon: this table is service-role
-- only (the Edge Function reaches it over the pooler). The app never reads it.
alter table public.cached_answers enable row level security;

create index if not exists idx_cached_answers_bucket
  on public.cached_answers (bucket_key, expires_at);
create index if not exists idx_cached_answers_expires
  on public.cached_answers (expires_at);
-- Vector index (cosine) mirroring content_embeddings' setup.
create index if not exists idx_cached_answers_embedding
  on public.cached_answers using hnsw (question_embedding vector_cosine_ops);

-- Nearest unexpired cached answer WITHIN a bucket. Returns at most one row and
-- only above the caller's similarity threshold (start strict — 0.95 — per §5).
create or replace function public.match_cached_answer(
  query_embedding vector(768),
  bucket text,
  min_similarity float default 0.95
)
returns table (id uuid, answer_text text, cited_card_ids uuid[], similarity float)
language sql
stable
as $$
  select a.id, a.answer_text, a.cited_card_ids,
         1 - (a.question_embedding <=> query_embedding) as similarity
  from public.cached_answers a
  where a.bucket_key = bucket
    and a.expires_at > now()
    and 1 - (a.question_embedding <=> query_embedding) >= min_similarity
  order by a.question_embedding <=> query_embedding
  limit 1;
$$;

-- Defence in depth: RLS already returns zero rows to the app inside this
-- security-invoker function, but the app has no business calling it at all.
revoke execute on function public.match_cached_answer(vector, text, float)
  from anon, authenticated;

-- Invalidate on content change (§5): if a cited card is edited or removed, every
-- cached answer grounded in it is dropped so guidance never goes stale.
create or replace function public.purge_cached_answers_for_card()
returns trigger
language plpgsql
as $$
begin
  delete from public.cached_answers
  where cited_card_ids && array[old.id]::uuid[];
  return null;
end;
$$;

drop trigger if exists trg_purge_cached_answers on public.content_cards;
create trigger trg_purge_cached_answers
  after update or delete on public.content_cards
  for each row execute function public.purge_cached_answers_for_card();

-- TTL sweep. Cheap and idempotent; the match function already filters on
-- expires_at, so this is only about not growing the table forever.
select cron.unschedule('purge-expired-cached-answers')
where exists (select 1 from cron.job where jobname = 'purge-expired-cached-answers');

select cron.schedule(
  'purge-expired-cached-answers',
  '17 4 * * *',
  $$ delete from public.cached_answers where expires_at < now() $$
);

-- ---------------------------------------------------------------------------
-- 3) Cost dashboard views (§8 "required views")
-- ---------------------------------------------------------------------------
-- All security_invoker: a parent sees only their own rows via RLS; the dashboard
-- runs as service role and sees everything.

-- Replaces the earlier day/model rollup — now uses the per-row cost we store.
drop view if exists public.ai_cost_summary;
create view public.ai_cost_summary with (security_invoker = true) as
select
  date_trunc('day', created_at)::date       as day,
  coalesce(model, 'none')                   as model,
  count(*)                                  as requests,
  count(*) filter (where billable)          as billable_turns,
  coalesce(sum(prompt_tokens), 0)           as prompt_tokens,
  coalesce(sum(completion_tokens), 0)       as completion_tokens,
  coalesce(sum(cached_tokens), 0)           as cached_tokens,
  round(coalesce(sum(estimated_cost_usd), 0), 6) as est_cost_usd
from public.ai_usage
group by 1, 2;

-- Headline number: cost per ACTIVE user per month (target ≤ $0.05, ceiling $0.10).
create or replace view public.ai_cost_per_active_user with (security_invoker = true) as
select
  date_trunc('month', created_at)::date               as month,
  count(distinct owner_id)                            as active_users,
  count(*) filter (where billable)                    as billable_turns,
  round(coalesce(sum(estimated_cost_usd), 0), 6)      as total_cost_usd,
  round(coalesce(sum(estimated_cost_usd), 0)
        / greatest(count(distinct owner_id), 1), 6)   as cost_per_active_user_usd
from public.ai_usage
group by 1;

-- Daily spend with the 30-day trend the breaker's soft threshold is derived from.
create or replace view public.ai_daily_spend with (security_invoker = true) as
select
  date_trunc('day', created_at)::date            as day,
  count(*)                                       as requests,
  round(coalesce(sum(estimated_cost_usd), 0), 6) as spend_usd
from public.ai_usage
group by 1;

-- Cache hit rates + escalation rate (§3 / §6 acceptance).
create or replace view public.ai_efficiency with (security_invoker = true) as
select
  date_trunc('day', created_at)::date as day,
  count(*)                            as requests,
  round(100.0 * count(*) filter (where semantic_cache_hit)
        / greatest(count(*), 1), 1)   as semantic_cache_hit_pct,
  round(100.0 * count(*) filter (where prompt_cache_hit and billable)
        / greatest(count(*) filter (where billable), 1), 1) as prompt_cache_hit_pct,
  round(100.0 * count(*) filter (where escalated)
        / greatest(count(*) filter (where billable), 1), 1) as escalation_pct,
  round(100.0 * count(*) filter (where refer_out)
        / greatest(count(*), 1), 1)   as refer_out_pct,
  count(*) filter (where rate_limited) as rate_limited
from public.ai_usage
group by 1;

-- Top 10 heaviest users over 30 days — sanity-checks that the rate limit is sized
-- right. owner_id only, no content.
create or replace view public.ai_top_users with (security_invoker = true) as
select
  owner_id,
  count(*) filter (where billable)                as turns,
  round(coalesce(sum(estimated_cost_usd), 0), 6)  as spend_usd,
  max(created_at)                                 as last_seen
from public.ai_usage
where created_at > now() - interval '30 days'
group by owner_id
order by turns desc
limit 10;

-- Rolling 24h spend + the 30-day daily average the soft threshold multiplies.
-- Read by the Edge Function's circuit breaker (service role).
create or replace view public.ai_spend_24h with (security_invoker = true) as
select
  coalesce(sum(estimated_cost_usd) filter (where created_at > now() - interval '24 hours'), 0)::numeric
    as spend_24h_usd,
  (coalesce(sum(estimated_cost_usd) filter (where created_at > now() - interval '30 days'), 0) / 30.0)::numeric
    as avg_daily_30d_usd
from public.ai_usage;
