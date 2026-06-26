-- Task 4 (observability): AI cost telemetry + slow-query support.

-- ai_usage — one row per generated AI turn, written by the ai-chat Edge Function
-- (service role). PII-FREE: only owner_id (for RLS), the mode/model, and token
-- counts. No question text, no answer, no child identifier. Feeds the cost view.
create table public.ai_usage (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null references public.users (id) on delete cascade,
  conversation_id   uuid references public.ai_conversations (id) on delete set null,
  mode              text not null,                         -- 'qa' | 'situational'
  model             text not null,                         -- e.g. mistral-small-latest
  escalated         boolean not null default false,
  prompt_tokens     int,
  completion_tokens int,
  created_at        timestamptz not null default now()
);

-- RLS: append-only telemetry, owner-scoped reads (a parent can see only their own
-- usage; the cost dashboard runs as service role and sees all).
alter table public.ai_usage enable row level security;
create policy ai_usage_owner_select on public.ai_usage
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy ai_usage_owner_insert on public.ai_usage
  for insert to authenticated with check ((select auth.uid()) = owner_id);

create index idx_ai_usage_owner   on public.ai_usage (owner_id);
create index idx_ai_usage_created on public.ai_usage (created_at);

-- Cost rollup by day + model. Mistral rates per 1M tokens: small 0.10 in / 0.30 out,
-- medium 0.40 in / 2.00 out. security_invoker so RLS applies (parent sees own;
-- service role sees all).
create view public.ai_cost_summary with (security_invoker = true) as
select
  date_trunc('day', created_at)::date as day,
  model,
  count(*)                            as turns,
  coalesce(sum(prompt_tokens), 0)     as prompt_tokens,
  coalesce(sum(completion_tokens), 0) as completion_tokens,
  round(sum(
    case when model ilike '%medium%'
      then coalesce(prompt_tokens, 0) * 0.40 / 1e6 + coalesce(completion_tokens, 0) * 2.00 / 1e6
      else coalesce(prompt_tokens, 0) * 0.10 / 1e6 + coalesce(completion_tokens, 0) * 0.30 / 1e6
    end)::numeric, 6)                 as est_cost_usd
from public.ai_usage
group by 1, 2
order by 1 desc, 2;

-- Slow-query analysis (Task 4). Idempotent; on Supabase the extension lives in the
-- dedicated `extensions` schema and is usually preloaded already.
create extension if not exists pg_stat_statements with schema extensions;
