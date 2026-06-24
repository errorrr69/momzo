-- Momzo schema · 04 · AI, bonding, scheduling (PRD §8)
-- Family-scoped tables carry a denormalized owner_id for direct-comparison RLS.
-- questions is GLOBAL reference data (like content_cards/activities).

-- ai_conversations — a parent's chat thread, optionally about one child.
-- user_id IS the owner, so its RLS policy compares user_id directly.
create table public.ai_conversations (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  child_id   uuid references public.children (id) on delete set null,   -- context
  mode       text not null default 'qa' check (mode in ('qa','situational')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger ai_conversations_set_updated_at
  before update on public.ai_conversations
  for each row execute function public.set_updated_at();

-- ai_messages — turns within a conversation. owner_id denormalized from the parent
-- so the policy is a direct comparison (no join to ai_conversations).
-- Hard Rules #6 (cite sources) / #7 (refer-out flag) surface via cited_card_ids / flagged.
create table public.ai_messages (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references public.users (id) on delete cascade,
  conversation_id uuid not null references public.ai_conversations (id) on delete cascade,
  role            text not null check (role in ('user','assistant')),
  content         text not null,
  cited_card_ids  uuid[] not null default '{}',            -- source display (Hard Rule #6)
  flagged         text,                                    -- e.g. 'refer_out' (Hard Rule #7)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create trigger ai_messages_set_updated_at
  before update on public.ai_messages
  for each row execute function public.set_updated_at();

-- questions — global question/quiz bank (shared reference data).
create table public.questions (
  id         uuid primary key default gen_random_uuid(),
  type       text not null check (type in ('daily','know_each_other','game')),
  prompt     text not null,
  options    jsonb,
  age_min    int,
  age_max    int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger questions_set_updated_at
  before update on public.questions
  for each row execute function public.set_updated_at();

-- question_responses — a parent's or child's answer (family-scoped).
create table public.question_responses (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.users (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  child_id    uuid not null references public.children (id) on delete cascade,
  respondent  text not null check (respondent in ('parent','child')),
  answer      jsonb,
  answered_at timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger question_responses_set_updated_at
  before update on public.question_responses
  for each row execute function public.set_updated_at();

-- wishes — the kid wish wall (child or parent created; family-scoped).
create table public.wishes (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references public.users (id) on delete cascade,
  child_id   uuid not null references public.children (id) on delete cascade,
  text       text not null,
  created_by text not null default 'child' check (created_by in ('child','parent')),
  status     text not null default 'open' check (status in ('open','scheduled','done')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger wishes_set_updated_at
  before update on public.wishes
  for each row execute function public.set_updated_at();

-- scheduled_events — calendar entries, optionally from a wish or activity (family-scoped).
create table public.scheduled_events (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.users (id) on delete cascade,
  child_id    uuid not null references public.children (id) on delete cascade,
  wish_id     uuid references public.wishes (id) on delete set null,
  activity_id uuid references public.activities (id) on delete set null,
  title       text not null,
  starts_at   timestamptz not null,
  tip         text,                                        -- "how to make it special"
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger scheduled_events_set_updated_at
  before update on public.scheduled_events
  for each row execute function public.set_updated_at();

-- reminders — scheduled nudges. sent_at gives idempotency (Hard Rule #13).
-- user_id IS the owner, so its RLS policy compares user_id directly.
create table public.reminders (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users (id) on delete cascade,
  event_id      uuid references public.scheduled_events (id) on delete cascade,
  type          text not null check (type in ('nudge','activity','playdate','recap')),
  channel       text not null default 'push' check (channel in ('push','whatsapp')),
  send_at       timestamptz not null,
  sent_at       timestamptz,                               -- null until sent (idempotency)
  template_name text,                                      -- WhatsApp utility template (Hard Rule #12)
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create trigger reminders_set_updated_at
  before update on public.reminders
  for each row execute function public.set_updated_at();

-- milestones — memory-keeping moments (family-scoped).
create table public.milestones (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references public.users (id) on delete cascade,
  child_id   uuid not null references public.children (id) on delete cascade,
  title      text not null,
  note       text,
  photo_url  text,                                         -- private Storage, signed URL (Hard Rule #16)
  date       date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger milestones_set_updated_at
  before update on public.milestones
  for each row execute function public.set_updated_at();

-- family_members — co-parent sharing. P2 feature; table exists now so FKs are stable,
-- but Phase 1 RLS only lets a user see their OWN membership row. The real membership-
-- based access (security-definer fn) is deferred to P2 (Build Guide, Hard Rule #3).
create table public.family_members (
  id           uuid primary key default gen_random_uuid(),
  child_id     uuid not null references public.children (id) on delete cascade,
  user_id      uuid not null references public.users (id) on delete cascade,
  relationship text not null default 'parent' check (relationship in ('parent','coparent','grandparent')),
  invited_by   uuid references public.users (id) on delete set null,
  status       text not null default 'invited' check (status in ('invited','active')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger family_members_set_updated_at
  before update on public.family_members
  for each row execute function public.set_updated_at();
