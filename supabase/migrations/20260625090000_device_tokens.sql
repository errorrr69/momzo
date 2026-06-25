-- Momzo schema · 10 · FCM device tokens (Task 7)
-- Stores each signed-in device's push token so the server can send reminders.
-- RLS self-only; the FCM server key never touches this table (it lives in the
-- send Edge Function). A token is unique to a device — on conflict we re-point it
-- to the current user (handles reinstalls / account switches).
create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  token      text not null unique,
  platform   text,                                   -- 'android' | 'ios'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger device_tokens_set_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

create index idx_device_tokens_user on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;
create policy device_tokens_self_select on public.device_tokens
  for select to authenticated using ((select auth.uid()) = user_id);
create policy device_tokens_self_insert on public.device_tokens
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy device_tokens_self_update on public.device_tokens
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy device_tokens_self_delete on public.device_tokens
  for delete to authenticated using ((select auth.uid()) = user_id);
