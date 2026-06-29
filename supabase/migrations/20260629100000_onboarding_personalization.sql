-- Onboarding & personalization rebuild (Onboarding & Personalization Spec §4).
-- Replaces the children temperament/struggles fields with the richer profile shape,
-- widens age to 4–10, adds profile fields to users, and adds onboarding_state for
-- resumability. EXISTING DATA IS MIGRATED, not dropped:
--   old "what you'd love help with" (struggles) -> focus_goals
--   old temperament tags                         -> attributes.legacy_temperament
-- RLS + index on the new table (Hard Rule #1).

-- 1) children: widen age 4–10, add the new typed + flexible columns ------------
alter table public.children drop constraint if exists children_age_check;
alter table public.children add constraint children_age_check check (age between 4 and 10);

alter table public.children
  add column if not exists focus_goals text[] not null default '{}',  -- Q3
  add column if not exists challenges  text[] not null default '{}',  -- Q4 (everyday tags, not labels)
  add column if not exists interests   text[] not null default '{}',  -- Q5
  add column if not exists notes       text,                          -- "something else…" free text
  add column if not exists attributes  jsonb not null default '{}'::jsonb; -- Part B optional depth

-- migrate existing rows before dropping the old columns
update public.children
  set focus_goals = struggles,
      attributes  = jsonb_set(attributes, '{legacy_temperament}', to_jsonb(temperament), true);

alter table public.children drop column if exists temperament;
alter table public.children drop column if exists struggles;

-- temperament is now jsonb sliders (Q6). Default + seed existing rows to neutral.
alter table public.children add column temperament jsonb not null default '{}'::jsonb;
update public.children
  set temperament = '{"warmup":0.5,"energy":0.5,"expressive":0.5,"social":0.5}'::jsonb
  where temperament = '{}'::jsonb;

-- 2) users: profile fields (Onboarding Spec §4 profiles) -----------------------
alter table public.users
  add column if not exists time_with_child text,                      -- Q2 bucket
  add column if not exists mom_goals       text[] not null default '{}', -- Q8
  add column if not exists daily_nudge_time time,                     -- Q7
  add column if not exists nudge_channel   text not null default 'push'; -- push only (WhatsApp removed)
-- (quiet_hours already exists on users)

-- 3) onboarding_state: resumability + versioning -------------------------------
create table public.onboarding_state (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete cascade,
  child_id     uuid references public.children (id) on delete set null,
  step         int  not null default 0,          -- last completed step (resume here)
  completed    boolean not null default false,
  version      int  not null default 1,          -- re-ask deltas if core questions change
  completed_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger onboarding_state_set_updated_at
  before update on public.onboarding_state
  for each row execute function public.set_updated_at();

create index idx_onboarding_state_user on public.onboarding_state (user_id);

alter table public.onboarding_state enable row level security;
create policy onboarding_state_owner_select on public.onboarding_state
  for select to authenticated using ((select auth.uid()) = user_id);
create policy onboarding_state_owner_insert on public.onboarding_state
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy onboarding_state_owner_update on public.onboarding_state
  for update to authenticated using ((select auth.uid()) = user_id);
create policy onboarding_state_owner_delete on public.onboarding_state
  for delete to authenticated using ((select auth.uid()) = user_id);
