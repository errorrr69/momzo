-- Momzo schema · 11 · Question-of-the-day seeding support (Task 19)
-- Stable slug so the question seeder can UPSERT and re-run as the bank grows.
alter table public.questions
  add column if not exists slug text unique;
