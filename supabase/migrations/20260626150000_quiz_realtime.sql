-- Task 25: live "know each other" quiz reveal.
-- Enable Supabase Realtime on question_responses ONLY (Hard Rule #4 — Realtime is
-- scoped to the single table that needs it). RLS on the table (owner_id = uid)
-- already restricts delivered change events to the subscriber's own family, so
-- cross-family rows are never broadcast.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'question_responses'
  ) then
    alter publication supabase_realtime add table public.question_responses;
  end if;
end $$;
