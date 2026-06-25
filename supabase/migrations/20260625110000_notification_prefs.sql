-- Momzo schema · 12 · Notification prefs for the gentle daily nudge (Task 20)
-- quiet_hours already exists (jsonb {start,end} as local hours). We add the nudge
-- toggle, a coarse time slot, and a reliable UTC offset (set by the app) so the
-- server can compute the user's local time without IANA tz names.
alter table public.users
  add column if not exists daily_nudge       boolean not null default true,
  add column if not exists nudge_slot        text not null default 'morning',
  add column if not exists tz_offset_minutes int;

-- Guard the slot values (morning≈09:00, noon≈13:00, evening≈19:00 local).
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'users_nudge_slot_chk') then
    alter table public.users add constraint users_nudge_slot_chk
      check (nudge_slot in ('morning', 'noon', 'evening'));
  end if;
end $$;
