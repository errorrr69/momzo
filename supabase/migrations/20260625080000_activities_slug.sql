-- Momzo schema · 09 · Activities idempotent seeding support (Task 18)
-- A stable slug (derived from the source file + activity title) so the activity
-- seeder can UPSERT and re-run as the library grows, mirroring content_cards.
alter table public.activities
  add column if not exists slug text unique;
