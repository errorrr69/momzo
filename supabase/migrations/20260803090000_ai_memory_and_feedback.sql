-- Momzo schema · AI memory + feedback loop
--
-- Three gaps this closes:
--   1. Conversation memory  — ai_messages was write-only; nothing ever read it
--                             back, so a follow-up question reached the model with
--                             no idea what it was following up on. Needs an index
--                             that supports "last N turns of this conversation".
--   2. Answer feedback      — there was no signal at all about whether an answer
--                             helped. A thumbs on each answer is the only way to
--                             know, and the only thing in the product that can
--                             actually learn.
--   3. Closing the loop     — a thumbs-down on an answer that came from (or went
--                             into) the semantic cache removes it, so one bad
--                             cached answer can't be served to thousands.
--
-- Hard rules honoured: RLS + index on everything; the rating path is a narrow
-- SECURITY DEFINER function rather than a broad table grant; no PII added.

-- ---------------------------------------------------------------------------
-- 1) ai_messages: feedback + the link back to the cache
-- ---------------------------------------------------------------------------
alter table public.ai_messages
  add column if not exists feedback    smallint,     -- +1 helpful, -1 not, null unrated
  add column if not exists feedback_at timestamptz,
  -- The cached_answers row this answer was served FROM, or written TO. Either
  -- way a thumbs-down should retire it. ON DELETE SET NULL so the 90-day TTL
  -- sweep never touches the conversation history.
  add column if not exists cached_answer_id uuid
    references public.cached_answers (id) on delete set null;

alter table public.ai_messages
  drop constraint if exists ai_messages_feedback_check;
alter table public.ai_messages
  add constraint ai_messages_feedback_check check (feedback is null or feedback in (-1, 1));

-- History fetch: "the last N messages of this conversation, newest first".
create index if not exists idx_ai_messages_conversation_created
  on public.ai_messages (conversation_id, created_at desc);

-- Monitoring: which answers get rated, and how.
create index if not exists idx_ai_messages_feedback
  on public.ai_messages (feedback, created_at desc) where feedback is not null;

-- ---------------------------------------------------------------------------
-- 2) rate_ai_answer — the only way the app writes feedback
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER for one specific reason: a thumbs-down must be able to delete
-- the offending row from cached_answers, which is service-role-only and which the
-- parent must never be able to read or write directly. The function therefore
-- does its own ownership check and touches nothing else.
create or replace function public.rate_ai_answer(
  p_message_id uuid,
  p_rating     smallint
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner  uuid;
  v_role   text;
  v_cached uuid;
begin
  if p_rating is not null and p_rating not in (-1, 1) then
    raise exception 'rating must be -1, 1 or null';
  end if;

  select owner_id, role, cached_answer_id
    into v_owner, v_role, v_cached
  from public.ai_messages
  where id = p_message_id;

  if v_owner is null then
    raise exception 'message not found';
  end if;
  -- Ownership check, done here because SECURITY DEFINER bypasses RLS.
  if v_owner <> auth.uid() then
    raise exception 'forbidden';
  end if;
  if v_role <> 'assistant' then
    raise exception 'only an answer can be rated';
  end if;

  update public.ai_messages
     set feedback    = p_rating,
         feedback_at = case when p_rating is null then null else now() end
   where id = p_message_id;

  -- Close the loop: retire a cached answer someone found unhelpful, so it is
  -- never served to another family. Cheap to regenerate, expensive to keep wrong.
  if p_rating = -1 and v_cached is not null then
    delete from public.cached_answers where id = v_cached;
  end if;
end;
$$;

revoke execute on function public.rate_ai_answer(uuid, smallint) from anon;
grant execute on function public.rate_ai_answer(uuid, smallint) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Feedback dashboard
-- ---------------------------------------------------------------------------
-- Answer quality by day, split by how the answer was produced. security_invoker
-- so a parent sees only their own; the dashboard runs as service role.
create or replace view public.ai_answer_feedback with (security_invoker = true) as
select
  date_trunc('day', m.created_at)::date                     as day,
  (m.cached_answer_id is not null)                          as from_cache,
  count(*)                                                  as answers,
  count(*) filter (where m.feedback is not null)            as rated,
  count(*) filter (where m.feedback = 1)                    as helpful,
  count(*) filter (where m.feedback = -1)                   as not_helpful,
  round(100.0 * count(*) filter (where m.feedback = 1)
        / greatest(count(*) filter (where m.feedback is not null), 1), 1) as helpful_pct
from public.ai_messages m
where m.role = 'assistant'
group by 1, 2;
