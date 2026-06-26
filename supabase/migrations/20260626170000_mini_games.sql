-- Together mini-games engine (v1). A global game catalog + content banks (read by
-- any signed-in parent, like content_cards/activities), and a family-scoped play
-- history for anti-repetition (RLS, Hard Rule #1).

-- Catalog of games shown in the gallery.
create table public.games (
  slug       text primary key,
  title      text not null,
  emoji      text,
  subtitle   text,
  type       text not null,                 -- choose_one | question | ...
  min_band   text not null default 'A' check (min_band in ('A', 'B', 'C')),
  accent     text,                          -- hex accent for the deck card
  rounds_a   int not null default 3,
  rounds_b   int not null default 5,
  rounds_c   int not null default 6,
  playable   boolean not null default false,
  sort       int not null default 0,
  created_at timestamptz not null default now()
);

-- Content banks, per game per age band.
create table public.game_items (
  id         uuid primary key default gen_random_uuid(),
  game_slug  text not null references public.games (slug) on delete cascade,
  band       text not null check (band in ('A', 'B', 'C')),
  item_type  text not null,
  payload    jsonb not null,
  source     text not null default 'seed' check (source in ('seed', 'ai')),
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
create index idx_game_items_lookup on public.game_items (game_slug, band, active);

-- Anti-repeat ledger: every item shown to a family, per game.
create table public.game_play_history (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references public.users (id) on delete cascade,
  child_id   uuid not null references public.children (id) on delete cascade,
  game_slug  text not null,
  item_id    uuid not null references public.game_items (id) on delete cascade,
  shown_at   timestamptz not null default now()
);
create index idx_gph_lookup on public.game_play_history (owner_id, child_id, game_slug, shown_at);

-- RLS --------------------------------------------------------------------------
alter table public.games enable row level security;
alter table public.game_items enable row level security;
alter table public.game_play_history enable row level security;

-- Global reference data: any signed-in parent may read; writes are service-role only.
create policy games_read on public.games
  for select to authenticated using (true);
create policy game_items_read on public.game_items
  for select to authenticated using (true);

-- Family-scoped history: owner-only (Hard Rule #1).
create policy gph_owner_select on public.game_play_history
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy gph_owner_insert on public.game_play_history
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy gph_owner_delete on public.game_play_history
  for delete to authenticated using ((select auth.uid()) = owner_id);
