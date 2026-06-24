-- Momzo schema · 01 · Extensions + shared helpers
-- Hard Rule #19: all schema/RLS lives here as version-controlled SQL, never the dashboard.
--
-- This file sets up the building blocks every later migration reuses:
--   * pgvector        — RAG embeddings live in the same DB (Build Guide §2).
--   * set_updated_at  — a trigger fn so every table keeps updated_at fresh.

create extension if not exists vector;

-- Touch updated_at on every UPDATE. Attached per-table in the schema migrations.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
