-- The Circle — Momzo's forum (Expansion Plan §2).
--
-- The app's first genuinely SHARED-AUTHORED content. Until now every table was
-- either family-isolated or a catalog nobody could write. Here mothers write
-- rows other mothers read, which is a third pattern and the reason §2.3 asks for
-- it to be tested as carefully as the isolation suite.
--
-- The pattern, stated once:
--
--   SELECT  any authenticated user, provided the row is not hidden.
--   INSERT  author only — (select auth.uid()) = author_id.
--   UPDATE  author only, for their own words. Moderators may hide.
--   DELETE  author only.
--
-- Moderator power goes through public.is_moderator(), a `security definer`
-- function, because Build Guide §3.2 forbids a subquery inside a policy: a
-- membership lookup written as `uid in (select ...)` is both slower and harder to
-- reason about than a stable function call.
--
-- Hidden ≠ deleted. A hidden row stays readable by its AUTHOR and by moderators.
-- Auto-hide exists so three reports take something out of circulation quickly,
-- but a mother who wrote something hard and got reported must not simply find her
-- words gone with no trace — a human decides what happens next (§2.4).

-- Who moderates ------------------------------------------------------------------
create table public.moderators (
  user_id    uuid primary key references public.users (id) on delete cascade,
  added_at   timestamptz not null default now()
);

comment on table public.moderators is
  'Florie, initially. Membership is checked via public.is_moderator().';

-- Stable, indexed, and callable from a policy without a subquery.
-- `stable` (not `volatile`) so the planner can call it once per statement.
create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.moderators m where m.user_id = (select auth.uid())
  );
$$;

revoke execute on function public.is_moderator() from public;
grant execute on function public.is_moderator() to authenticated, service_role;

-- Forum identity -----------------------------------------------------------------
-- Deliberately NOT the account name (§2.4 privacy defaults). A mother picks what
-- the Circle calls her, and it defaults to nothing rather than to her real name —
-- there is no code path that can quietly fall back to `users.display_name`.
create table public.forum_profiles (
  user_id      uuid primary key references public.users (id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 2 and 24),
  avatar_emoji text not null default '💛',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger forum_profiles_set_updated_at
  before update on public.forum_profiles
  for each row execute function public.set_updated_at();

-- Structure ----------------------------------------------------------------------
create table public.forum_categories (
  id     uuid primary key default gen_random_uuid(),
  slug   text not null unique,
  title  text not null,
  blurb  text,
  sort   int not null default 0,
  active boolean not null default true
);

create table public.forum_threads (
  id               uuid primary key default gen_random_uuid(),
  category_id      uuid not null references public.forum_categories (id) on delete cascade,
  author_id        uuid not null references public.users (id) on delete cascade,
  title            text not null check (length(trim(title)) between 3 and 140),
  body             text not null check (length(trim(body)) between 1 and 4000),
  created_at       timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  reply_count      int not null default 0,
  reaction_count   int not null default 0,
  hidden           boolean not null default false,
  hidden_reason    text,
  pinned           boolean not null default false   -- the resources post (§2.4)
);

create table public.forum_replies (
  id             uuid primary key default gen_random_uuid(),
  thread_id      uuid not null references public.forum_threads (id) on delete cascade,
  author_id      uuid not null references public.users (id) on delete cascade,
  body           text not null check (length(trim(body)) between 1 and 4000),
  created_at     timestamptz not null default now(),
  reaction_count int not null default 0,
  hidden         boolean not null default false
);

-- Unlike post_reactions on the Content Hub, a forum reaction IS counted in
-- public. "Eleven other mothers felt this" is the Circle's whole point — it is
-- the you-are-not-alone signal, not a score about anybody. The count lives on the
-- parent row, maintained by trigger, so nobody needs to read anyone else's
-- reaction row to see it.
create table public.forum_reactions (
  id          uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('thread', 'reply')),
  target_id   uuid not null,
  user_id     uuid not null references public.users (id) on delete cascade,
  kind        text not null default 'heart' check (kind in ('heart')),
  created_at  timestamptz not null default now(),
  constraint forum_reactions_once unique (target_type, target_id, user_id, kind)
);

create table public.forum_reports (
  id           uuid primary key default gen_random_uuid(),
  target_type  text not null check (target_type in ('thread', 'reply')),
  target_id    uuid not null,
  reporter_id  uuid not null references public.users (id) on delete cascade,
  -- 'needs_help' is the crisis-adjacent reason (§2.4). It is not a complaint
  -- about the author; it asks a human to look sooner.
  reason       text not null
                 check (reason in ('unkind', 'selling', 'identifying', 'needs_help', 'other')),
  note         text,
  created_at   timestamptz not null default now(),
  resolved     boolean not null default false,
  resolution   text,
  constraint forum_reports_once unique (target_type, target_id, reporter_id)
);

-- Indexes: every policy column, plus the two lists the app actually renders.
create index idx_forum_threads_feed on public.forum_threads (category_id, last_activity_at desc)
  where not hidden;
create index idx_forum_threads_author on public.forum_threads (author_id);
create index idx_forum_replies_thread on public.forum_replies (thread_id, created_at);
create index idx_forum_replies_author on public.forum_replies (author_id);
create index idx_forum_reactions_user on public.forum_reactions (user_id, target_type, target_id);
create index idx_forum_reactions_target on public.forum_reactions (target_type, target_id);
create index idx_forum_reports_open on public.forum_reports (created_at desc) where not resolved;
create index idx_forum_reports_target on public.forum_reports (target_type, target_id);

-- Counters and activity ----------------------------------------------------------
-- Maintained server-side because a client cannot be trusted to keep them honest
-- and, under these policies, cannot write another author's row at all.
create or replace function public.forum_touch_thread()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.forum_threads
       set reply_count = reply_count + 1, last_activity_at = now()
     where id = new.thread_id;
  elsif tg_op = 'DELETE' then
    update public.forum_threads
       set reply_count = greatest(reply_count - 1, 0)
     where id = old.thread_id;
  end if;
  return null;
end;
$$;

create trigger forum_replies_touch_thread
  after insert or delete on public.forum_replies
  for each row execute function public.forum_touch_thread();

create or replace function public.forum_count_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  delta int := case when tg_op = 'INSERT' then 1 else -1 end;
  t     text := coalesce(new.target_type, old.target_type);
  tid   uuid := coalesce(new.target_id, old.target_id);
begin
  if t = 'thread' then
    update public.forum_threads
       set reaction_count = greatest(reaction_count + delta, 0) where id = tid;
  else
    update public.forum_replies
       set reaction_count = greatest(reaction_count + delta, 0) where id = tid;
  end if;
  return null;
end;
$$;

create trigger forum_reactions_count
  after insert or delete on public.forum_reactions
  for each row execute function public.forum_count_reaction();

-- Auto-hide ----------------------------------------------------------------------
-- Three open reports take a row out of circulation pending review (§2.4). It
-- HIDES; it never deletes, and the author can still see their own words.
create or replace function public.forum_autohide()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  open_reports int;
  threshold constant int := 3;
begin
  select count(*) into open_reports
    from public.forum_reports r
   where r.target_type = new.target_type
     and r.target_id = new.target_id
     and not r.resolved;

  if open_reports >= threshold then
    -- Announce the server path to forum_guard_moderated_columns(). Transaction-
    -- local (the `true`), so it cannot leak into another statement.
    perform set_config('momzo.autohide', 'on', true);
    if new.target_type = 'thread' then
      update public.forum_threads
         set hidden = true,
             hidden_reason = coalesce(hidden_reason, 'Auto-hidden pending review')
       where id = new.target_id and not hidden;
    else
      update public.forum_replies set hidden = true
       where id = new.target_id and not hidden;
    end if;
    perform set_config('momzo.autohide', 'off', true);
  end if;
  return null;
end;
$$;

create trigger forum_reports_autohide
  after insert on public.forum_reports
  for each row execute function public.forum_autohide();

-- Who may change WHICH columns ---------------------------------------------------
-- RLS grants access to rows, never to columns. Under the update policies below an
-- author legitimately owns her row, which without this guard would also let her
-- clear `hidden` and reverse a moderation decision, or hand herself a `pinned`
-- thread, or invent a reaction_count.
--
-- So: an author may edit her own title and body. Everything else on the row is
-- the moderator's or the server's.
create or replace function public.forum_guard_moderated_columns()
returns trigger
language plpgsql
as $$
begin
  if public.is_moderator() then
    return new;
  end if;

  -- The auto-hide trigger is the server acting, not a user, and it legitimately
  -- sets `hidden`. It announces itself with a transaction-local key that no
  -- client can set through PostgREST, rather than the guard trying to infer
  -- intent from the call path. Counter and activity writes need no exemption:
  -- they never touch a moderated column.
  if coalesce(current_setting('momzo.autohide', true), '') = 'on' then
    return new;
  end if;

  if new.hidden is distinct from old.hidden then
    raise exception 'only a moderator can hide or restore a post'
      using errcode = 'check_violation';
  end if;

  if tg_table_name = 'forum_threads' then
    if new.hidden_reason is distinct from old.hidden_reason
       or new.pinned is distinct from old.pinned then
      raise exception 'only a moderator can pin or annotate a post'
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

create trigger forum_threads_guard_columns
  before update on public.forum_threads
  for each row execute function public.forum_guard_moderated_columns();

create trigger forum_replies_guard_columns
  before update on public.forum_replies
  for each row execute function public.forum_guard_moderated_columns();

-- RLS ----------------------------------------------------------------------------
alter table public.moderators       enable row level security;
alter table public.forum_profiles   enable row level security;
alter table public.forum_categories enable row level security;
alter table public.forum_threads    enable row level security;
alter table public.forum_replies    enable row level security;
alter table public.forum_reactions  enable row level security;
alter table public.forum_reports    enable row level security;

-- moderators: a member may see that they are one (the app needs to know whether
-- to show the queue). Nobody may add themselves — membership is service-role only.
create policy moderators_self on public.moderators
  for select to authenticated using ((select auth.uid()) = user_id);

-- Categories: shared-content catalog.
create policy forum_categories_read on public.forum_categories
  for select to authenticated using (active);

-- Profiles: readable by everyone, because a thread has to show who wrote it.
-- This is the display name she chose, never her account name.
create policy forum_profiles_read on public.forum_profiles
  for select to authenticated using (true);
create policy forum_profiles_insert on public.forum_profiles
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy forum_profiles_update on public.forum_profiles
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Threads.
create policy forum_threads_read on public.forum_threads
  for select to authenticated
  using (not hidden or (select auth.uid()) = author_id or public.is_moderator());
create policy forum_threads_insert on public.forum_threads
  for insert to authenticated with check ((select auth.uid()) = author_id);
-- Author edits her own words; a moderator may hide. Which COLUMNS each may touch
-- is enforced by forum_guard_moderated_columns() below, because RLS chooses rows
-- and never columns — a WITH CHECK that passes on author_id would happily let an
-- author clear her own `hidden` flag and undo a moderation decision.
create policy forum_threads_update on public.forum_threads
  for update to authenticated
  using ((select auth.uid()) = author_id or public.is_moderator())
  with check ((select auth.uid()) = author_id or public.is_moderator());
create policy forum_threads_delete on public.forum_threads
  for delete to authenticated using ((select auth.uid()) = author_id);

-- Replies.
create policy forum_replies_read on public.forum_replies
  for select to authenticated
  using (not hidden or (select auth.uid()) = author_id or public.is_moderator());
create policy forum_replies_insert on public.forum_replies
  for insert to authenticated with check ((select auth.uid()) = author_id);
create policy forum_replies_update on public.forum_replies
  for update to authenticated
  using ((select auth.uid()) = author_id or public.is_moderator())
  with check ((select auth.uid()) = author_id or public.is_moderator());
create policy forum_replies_delete on public.forum_replies
  for delete to authenticated using ((select auth.uid()) = author_id);

-- Reactions: hers alone to read and write. The public number lives on the parent
-- row, so nobody needs to see who hearted what.
create policy forum_reactions_select on public.forum_reactions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy forum_reactions_insert on public.forum_reactions
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy forum_reactions_delete on public.forum_reactions
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Reports: she may file one and see her own; moderators see all and resolve them.
-- No DELETE for anyone — a report is a record, and letting a reporter withdraw it
-- silently would let three people hide something and then vanish the evidence.
create policy forum_reports_select on public.forum_reports
  for select to authenticated
  using ((select auth.uid()) = reporter_id or public.is_moderator());
create policy forum_reports_insert on public.forum_reports
  for insert to authenticated with check ((select auth.uid()) = reporter_id);
create policy forum_reports_update on public.forum_reports
  for update to authenticated using (public.is_moderator())
  with check (public.is_moderator());
