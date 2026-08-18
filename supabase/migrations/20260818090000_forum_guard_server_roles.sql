-- Let the SERVER moderate (fixes 20260817120000_forum_circle.sql).
--
-- forum_guard_moderated_columns() stops a member changing `hidden`, `pinned` or
-- `hidden_reason` — RLS grants rows and not columns, so without it an author's
-- legitimate ownership of her row would also let her reverse a moderation
-- decision.
--
-- It was too broad. The guard applied to EVERY role, including `service_role`,
-- so a server-side moderation write was rejected as if it came from a member.
-- Nothing failed loudly: PostgREST reported the refusal in an error object the
-- caller was free to ignore, so the row simply stayed visible. It was found by
-- three forum tests that appeared to show hidden content leaking to other
-- members, when in fact the content had never been hidden at all.
--
-- The service role is not a user. It is the Edge Functions and the seeders, it
-- already bypasses RLS entirely, and a guard that blocks it protects nobody.

create or replace function public.forum_guard_moderated_columns()
returns trigger
language plpgsql
as $$
begin
  -- The server: service_role through PostgREST, or a direct owner connection
  -- (migrations, psql). Both already bypass RLS; this guard is about members.
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
  end if;

  if public.is_moderator() then
    return new;
  end if;

  -- The auto-hide trigger announces itself with a transaction-local key that no
  -- client can set through PostgREST.
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
