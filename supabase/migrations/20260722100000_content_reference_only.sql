-- Momzo schema · Reference-only content (distilled book notes)
--
-- Adds content_cards.reference_only: original expert notes distilled from reference
-- books that must GROUND the AI (RAG) but never surface to a parent as a daily card
-- or in the browse library.
--
-- Why this shape works:
--   * match_content_cards() filters only on `published` and is run by the ai-chat
--     Edge Function via the service role (which bypasses RLS) — so reference_only
--     cards (published = true) stay fully retrievable for grounding.
--   * The client read policy is the single gate for every in-app read surface
--     (daily_service, library_service + its tag list). Tightening it to
--     `published and not reference_only` hides book notes from all of them at once,
--     with no app-side changes.

alter table public.content_cards
  add column if not exists reference_only boolean not null default false;

-- Clients (authenticated app) may read published cards that are NOT reference-only.
-- The service role (RAG) is unaffected — it bypasses RLS.
drop policy if exists content_cards_read_published on public.content_cards;
create policy content_cards_read_published on public.content_cards
  for select to authenticated using (published and not reference_only);

create index if not exists idx_content_cards_reference_only
  on public.content_cards (reference_only);
