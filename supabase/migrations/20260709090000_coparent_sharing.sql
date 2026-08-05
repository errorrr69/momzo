-- Momzo schema · Co-parent / caregiver sharing (Task 33, Phase 2/3)
--
-- Activates `family_members`: an owner can invite a co-parent / grandparent to a
-- child, and once they ACCEPT they can see and participate in that child's
-- surfaces (daily card, activities, shared questions, wishes, calendar, memories).
--
-- Membership access is resolved through a SECURITY DEFINER function (Hard Rule #3)
-- — never a join-in-policy — so RLS on child-scoped tables stays a fast, single
-- `child_id IN (select ...)` check backed by the existing child_id indexes, and
-- there's no policy recursion (the function bypasses RLS on children/family_members).
--
-- Guardrails: a co-parent can PARTICIPATE but cannot delete the child or edit its
-- core profile, and cannot remove/replace the owner. The owner alone holds
-- INSERT/UPDATE/DELETE on `children` and revoke rights on memberships.

-- ── Membership helpers (SECURITY DEFINER, RLS-bypassing, set search_path) ─────────

-- Child ids the current user may access: the ones they own, plus any where they
-- hold an ACTIVE membership. STABLE + uncorrelated so it's evaluated once per query.
create or replace function public.accessible_child_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select c.id
    from public.children c
   where c.owner_id = (select auth.uid())
  union
  select fm.child_id
    from public.family_members fm
   where fm.user_id = (select auth.uid())
     and fm.status = 'active'
$$;

-- True when the current user OWNS the given child (owner-only rights: delete, edit,
-- invite, revoke). Bypasses RLS so it's safe to call from family_members policies.
create or replace function public.is_child_owner(cid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.children c
     where c.id = cid and c.owner_id = (select auth.uid())
  )
$$;

revoke all on function public.accessible_child_ids() from public;
revoke all on function public.is_child_owner(uuid) from public;
grant execute on function public.accessible_child_ids() to authenticated;
grant execute on function public.is_child_owner(uuid) to authenticated;

-- ── children: members may VIEW; only the owner may create/edit/delete ─────────────
drop policy if exists children_owner_select on public.children;
create policy children_access_select on public.children for select to authenticated
  using (id in (select public.accessible_child_ids()));
-- insert / update / delete policies stay owner-only (unchanged) — a co-parent can
-- never create, re-profile, or delete the child.

-- ── Child-scoped tables: owner + active members may view AND participate ──────────
-- SELECT/UPDATE/DELETE gate on child access; INSERT additionally stamps the row with
-- the acting user's own uid as owner_id (so "who did it" stays truthful).
do $$
declare t text;
begin
  foreach t in array array[
    'daily_assignments','activity_logs','question_responses',
    'wishes','scheduled_events','milestones'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', t||'_owner_select', t);
    execute format('drop policy if exists %I on public.%I', t||'_owner_insert', t);
    execute format('drop policy if exists %I on public.%I', t||'_owner_update', t);
    execute format('drop policy if exists %I on public.%I', t||'_owner_delete', t);

    execute format($f$
      create policy %I on public.%I for select to authenticated
        using (child_id in (select public.accessible_child_ids()))
    $f$, t||'_member_select', t);

    execute format($f$
      create policy %I on public.%I for insert to authenticated
        with check (
          child_id in (select public.accessible_child_ids())
          and owner_id = (select auth.uid())
        )
    $f$, t||'_member_insert', t);

    execute format($f$
      create policy %I on public.%I for update to authenticated
        using (child_id in (select public.accessible_child_ids()))
        with check (child_id in (select public.accessible_child_ids()))
    $f$, t||'_member_update', t);

    execute format($f$
      create policy %I on public.%I for delete to authenticated
        using (child_id in (select public.accessible_child_ids()))
    $f$, t||'_member_delete', t);
  end loop;
end $$;

-- Note: ai_conversations, ai_messages, reminders, saved_cards, device_tokens,
-- game_play_history, onboarding_state, ai_usage, consents remain strictly per-user
-- (personal data — a co-parent gets their OWN AI chats / reminders, not the owner's).

-- ── family_members: invite / accept / revoke ─────────────────────────────────────
drop policy if exists family_members_self_select on public.family_members;

-- View your own membership rows, or (as the child's owner) every member of your child.
create policy family_members_select on public.family_members for select to authenticated
  using ((select auth.uid()) = user_id or public.is_child_owner(child_id));

-- Only the child's owner can add a membership row directly, and must mark themselves
-- as the inviter. (The normal path is the accept RPC below; this covers direct adds.)
create policy family_members_owner_insert on public.family_members for insert to authenticated
  with check (public.is_child_owner(child_id) and invited_by = (select auth.uid()));

-- An invited user can accept — flip only THEIR OWN row (e.g. invited -> active).
create policy family_members_self_update on public.family_members for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- The owner can revoke any membership on their child; a member can remove themselves.
create policy family_members_delete on public.family_members for delete to authenticated
  using (public.is_child_owner(child_id) or (select auth.uid()) = user_id);

-- One membership per (child, user); lets the accept RPC be idempotent.
alter table public.family_members
  add constraint family_members_child_user_uniq unique (child_id, user_id);

-- ── family_invites: a shareable one-time code the owner hands to a co-parent ──────
create table public.family_invites (
  id           uuid primary key default gen_random_uuid(),
  child_id     uuid not null references public.children (id) on delete cascade,
  -- Short, unguessable, single-use code. Derived from gen_random_uuid() (core, no
  -- pgcrypto dependency); the unique constraint guards the astronomically rare clash.
  code         text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 10),
  relationship text not null default 'coparent'
                 check (relationship in ('coparent','grandparent','parent')),
  invited_by   uuid not null references public.users (id) on delete cascade,
  accepted_by  uuid references public.users (id) on delete set null,
  accepted_at  timestamptz,
  expires_at   timestamptz not null default (now() + interval '7 days'),
  created_at   timestamptz not null default now()
);

alter table public.family_invites enable row level security;

-- Only the child's owner can create / see / revoke invites. The accepting co-parent
-- never reads the invite directly — they redeem it through accept_family_invite().
create policy family_invites_owner_insert on public.family_invites for insert to authenticated
  with check (public.is_child_owner(child_id) and invited_by = (select auth.uid()));
create policy family_invites_owner_select on public.family_invites for select to authenticated
  using (public.is_child_owner(child_id));
create policy family_invites_owner_delete on public.family_invites for delete to authenticated
  using (public.is_child_owner(child_id));

-- Redeem an invite code: creates (or re-confirms) an ACTIVE membership for the
-- caller and marks the invite used. SECURITY DEFINER so the invitee — who has no
-- direct rights on the invite or on someone else's child — can still join.
create or replace function public.accept_family_invite(invite_code text)
returns uuid
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  inv public.family_invites;
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select * into inv
    from public.family_invites
   where code = invite_code
     and accepted_by is null
     and expires_at > now()
   limit 1;

  if inv.id is null then
    raise exception 'invalid or expired invite';
  end if;

  -- The owner can't "join" their own child.
  if exists (select 1 from public.children c where c.id = inv.child_id and c.owner_id = uid) then
    raise exception 'you already own this child';
  end if;

  insert into public.family_members (child_id, user_id, relationship, invited_by, status)
       values (inv.child_id, uid, inv.relationship, inv.invited_by, 'active')
  on conflict (child_id, user_id)
       do update set status = 'active';

  update public.family_invites
     set accepted_by = uid, accepted_at = now()
   where id = inv.id;

  return inv.child_id;
end;
$$;

revoke all on function public.accept_family_invite(text) from public;
grant execute on function public.accept_family_invite(text) to authenticated;

-- ── Indexes (Hard Rule #1: index every policy-filtered column) ────────────────────
-- accessible_child_ids() filters family_members by (user_id, status); is_child_owner
-- uses the children PK. Invites are looked up by code (already unique) and child_id.
create index idx_family_members_user_status on public.family_members (user_id, status);
create index idx_family_members_child        on public.family_members (child_id);
create index idx_family_invites_child        on public.family_invites (child_id);
