-- Momzo schema · 08 · Content corpus support (Task 11)
--
-- Adds idempotency + retrieval support for the seeded knowledge base:
--   * content_cards.slug  — a stable identity derived from the source file path,
--     so the ingest script can UPSERT (re-run as the corpus grows) without dupes.
--   * match_content_cards() — pgvector similarity search used to verify seeding
--     now, and reused by the RAG ai-chat function later (Task 14).

alter table public.content_cards
  add column if not exists slug text unique;

-- Nearest published cards to a query embedding (cosine distance via the HNSW index).
-- Returns chunk-level hits (a card can appear more than once); callers dedupe.
create or replace function public.match_content_cards(
  query_embedding vector(768),
  match_count int default 5
)
returns table (card_id uuid, title text, chunk text, similarity float)
language sql
stable
as $$
  select c.id, c.title, e.chunk, 1 - (e.embedding <=> query_embedding) as similarity
  from public.content_embeddings e
  join public.content_cards c on c.id = e.card_id
  where c.published
  order by e.embedding <=> query_embedding
  limit match_count;
$$;
