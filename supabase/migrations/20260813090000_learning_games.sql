-- Momzo Learning Games (Expansion Plan §3.5).
--
-- Florie's 22 foundational-learning games, played by a mother and child together
-- in the app. The games themselves are a bundled web app in a WebView; Postgres
-- holds only the catalog and what happened.
--
-- Two tables, two different RLS patterns — declared up front, per architecture
-- rule 4:
--
--   learning_games       SHARED-CONTENT. A catalog every signed-in parent reads
--                        and none of them can write. Seeded by the service role.
--   game_play_sessions   FAMILY-ISOLATED. Child data: owner-only, and it joins
--                        the delete-child cascade in this same migration
--                        (rule 6), not in a follow-up.
--
-- Naming note: the mini-games engine already owns `games` / `game_items` /
-- `game_play_history` (the bonding games in the Together tab). These are a
-- different product surface, so they get their own `learning_` prefix rather
-- than overloading those. Keyed by slug for the same reason `games` is: the slug
-- IS the identifier the games app uses (its GameId), so a separate uuid would be
-- a second name for one thing.

-- Catalog -----------------------------------------------------------------------
create table public.learning_games (
  slug        text primary key,               -- matches the games app's GameId
  title       text not null,
  -- DISPLAY category, deliberately not the games repo's own three. Florie shelves
  -- these four; re-shelving a game is a data change, never a code change.
  category    text not null check (category in ('maths', 'reading', 'feelings', 'focus')),
  -- Every game ships 5–6 today. Adding a band later is an insert, not a migration.
  age_min     int  not null default 5,
  age_max     int  not null default 6,
  skill_tags  text[] not null default '{}',   -- e.g. {number-pairs, decoding, working-memory}
  ladder_key  text,                           -- reading games map to the repo's ReadingStage order
  ladder_step int,
  entry_path  text not null,                  -- '/play/<slug>' — the abstraction that
                                              -- would absorb a hosted build later
  thumbnail   text,
  active      boolean not null default true,
  sort        int not null default 0,
  created_at  timestamptz not null default now(),
  constraint learning_games_age_range check (age_min <= age_max)
);
create index idx_learning_games_shelf on public.learning_games (category, sort)
  where active;

-- What happened -----------------------------------------------------------------
-- One row per game opened. `progress` holds the raw bridge payloads as sent
-- (Expansion Plan §3.4) so the dashboard can read only what it understands today
-- and more later, without a migration.
--
-- Minimum collection by design: no free text, no audio, no camera. The games have
-- no text entry, so the only strings here are the child's own in-game choices
-- ("Chose belly breathing"), which summary.ts already produces.
create table public.game_play_sessions (
  id           uuid primary key default gen_random_uuid(),
  -- The account that was driving. Named owner_id, not user_id, to match every
  -- other family table so the RLS policy stays a direct comparison (rule 4).
  owner_id     uuid not null references public.users (id) on delete cascade,
  -- THE cascade membership. Deleting a child erases their play history with them,
  -- via Postgres — delete-child needs no change (it deletes the children row and
  -- lets the FKs do the rest).
  child_id     uuid not null references public.children (id) on delete cascade,
  game_slug    text not null references public.learning_games (slug) on delete cascade,
  started_at   timestamptz not null default now(),
  ended_at     timestamptz,
  duration_sec int,
  completed    boolean not null default false,
  progress     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

comment on column public.game_play_sessions.progress is
  'Raw MomzoBridge payloads (round_result / session_summary). PII-free by '
  'contract: game slug, outcome buckets, counts, timings, and the child''s own '
  'in-game choices. Never a name, never free text.';

-- Policy column, and the dashboard's hot path (Expansion Plan §3.5).
create index idx_gps_owner on public.game_play_sessions (owner_id);
create index idx_gps_child_recent on public.game_play_sessions (child_id, started_at desc);

-- RLS ---------------------------------------------------------------------------
alter table public.learning_games enable row level security;
alter table public.game_play_sessions enable row level security;

-- Shared content: any signed-in parent may read an active game. No client writes —
-- the catalog is seeded by the service role, like content_cards and activities.
create policy learning_games_read on public.learning_games
  for select to authenticated using (active);

-- Family-isolated: owner-only, direct comparison, indexed (Hard Rules #1/#3).
create policy gps_owner_select on public.game_play_sessions
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy gps_owner_insert on public.game_play_sessions
  for insert to authenticated with check ((select auth.uid()) = owner_id);
-- Update exists because a session is written twice: once when the game opens, and
-- again with the summary when it closes.
create policy gps_owner_update on public.game_play_sessions
  for update to authenticated using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy gps_owner_delete on public.game_play_sessions
  for delete to authenticated using ((select auth.uid()) = owner_id);
