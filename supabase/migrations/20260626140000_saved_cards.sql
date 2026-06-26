-- Task 24: a parent's saved/bookmarked content cards (the personal library).
-- Owner-scoped (per parent, not per child); a read is useful across children.
create table public.saved_cards (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references public.users (id) on delete cascade,
  card_id    uuid not null references public.content_cards (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (owner_id, card_id)
);

alter table public.saved_cards enable row level security;
create policy saved_cards_owner_select on public.saved_cards
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy saved_cards_owner_insert on public.saved_cards
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy saved_cards_owner_delete on public.saved_cards
  for delete to authenticated using ((select auth.uid()) = owner_id);

create index idx_saved_cards_owner on public.saved_cards (owner_id);
