-- Momzo schema · 03 · Content & learning (PRD §8)
-- Two kinds of table here:
--   GLOBAL content (content_cards, content_embeddings, activities) — shared reference
--     data, written only by service_role/seed, read by all authed parents.
--   FAMILY-scoped (daily_assignments, activity_logs) — carry a denormalized owner_id
--     so RLS stays a direct comparison (Hard Rule #3); see the RLS migration for why.

-- content_cards — daily reads/slides AND the RAG knowledge source.
create table public.content_cards (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  body           text,                                     -- markdown
  slides         jsonb,                                    -- optional carousel [{image,text}]
  age_min        int,
  age_max        int,
  tags           text[] not null default '{}',             -- topics / struggles addressed
  why_it_matters text,                                     -- the "behavior at home" tie-in
  source         text,                                     -- attribution for trust (Hard Rule #6)
  published      boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create trigger content_cards_set_updated_at
  before update on public.content_cards
  for each row execute function public.set_updated_at();

-- content_embeddings — pgvector chunks for RAG retrieval.
-- NOTE: vector(768) matches Gemini text-embedding-004 (768 dims). If the embedding
-- model changes, this dimension must change with it (and the data be re-embedded).
create table public.content_embeddings (
  id         uuid primary key default gen_random_uuid(),
  card_id    uuid not null references public.content_cards (id) on delete cascade,
  chunk      text not null,
  embedding  vector(768),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger content_embeddings_set_updated_at
  before update on public.content_embeddings
  for each row execute function public.set_updated_at();

-- daily_assignments — which card a given child sees on a given day (family-scoped).
create table public.daily_assignments (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references public.users (id) on delete cascade,
  child_id   uuid not null references public.children (id) on delete cascade,
  card_id    uuid not null references public.content_cards (id) on delete cascade,
  date       date not null,
  read_at    timestamptz,
  saved      boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (child_id, date)                                  -- one assignment per child per day
);

create trigger daily_assignments_set_updated_at
  before update on public.daily_assignments
  for each row execute function public.set_updated_at();

-- activities — global activity library (shared reference data).
create table public.activities (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  steps        jsonb,                                      -- ordered steps
  skill        text,                                       -- focus/regulation/confidence/motor
  age_min      int,
  age_max      int,
  duration_min int,                                        -- 5 / 15 / 30 buckets
  location     text[] not null default '{}',               -- indoor/outdoor/car/kitchen
  materials    text[] not null default '{}',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger activities_set_updated_at
  before update on public.activities
  for each row execute function public.set_updated_at();

-- activity_logs — a parent recording that an activity was done with a child.
create table public.activity_logs (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null references public.users (id) on delete cascade,
  child_id     uuid not null references public.children (id) on delete cascade,
  activity_id  uuid references public.activities (id) on delete set null,
  user_id      uuid references public.users (id) on delete set null,  -- who did it
  completed_at timestamptz not null default now(),
  photo_url    text,                                       -- private Storage, signed URL (Hard Rule #16)
  note         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger activity_logs_set_updated_at
  before update on public.activity_logs
  for each row execute function public.set_updated_at();
