-- Momzo schema · 02 · Identity & profile (PRD §8: users, children)
-- RLS + indexes for these tables live in the dedicated 05/06 migrations.

-- users — profile that extends Supabase auth.users (id == auth.users.id).
create table public.users (
  id              uuid primary key references auth.users (id) on delete cascade,
  display_name    text,
  role            text not null default 'parent',          -- reserved for future roles
  whatsapp_number text,                                    -- E.164, nullable
  whatsapp_opt_in boolean not null default false,
  timezone        text,                                    -- for scheduling / quiet hours
  quiet_hours     jsonb,                                   -- { "start": "21:00", "end": "07:00" }
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- children — owned by the creating parent. The child has NO independent account
-- (PRD §9, Hard Rule #14); owner_id is the single source of access truth in Phase 1.
create table public.children (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.users (id) on delete cascade,
  name        text not null,
  age         int  not null check (age between 6 and 10),  -- PRD §8: 6–10 only
  temperament text[] not null default '{}',                -- e.g. {shy, anxious}
  struggles   text[] not null default '{}',                -- current focus areas
  avatar      text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger children_set_updated_at
  before update on public.children
  for each row execute function public.set_updated_at();
