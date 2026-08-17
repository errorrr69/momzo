-- Content Hub — Florie's posts, in the app (Expansion Plan §1).
--
-- Everything she publishes on Instagram/Facebook also lives here, so the app is
-- the calm home of all her content rather than only the personalized daily card.
-- The daily card stays the hero; this is the browsable library beside it.
--
-- Two tables, two RLS patterns — declared up front, per architecture rule 4:
--
--   social_posts    SHARED-CONTENT. Every signed-in parent reads it; none of
--                   them can write. Seeded by the service role, same as
--                   content_cards, activities and learning_games.
--   post_reactions  USER-ISOLATED. Her own 💛 and nobody else's.
--
-- Deliberately NOT here: a public reaction count. The plan asks only that
-- reactions "record per-user without double-counting", and a visible tally is a
-- different feature with a different cost — it needs a trigger-maintained
-- counter and a security-definer path for a client that cannot write the post
-- row, and it puts a popularity number on parenting advice. If Florie wants it
-- later it is one column and one trigger; it is not implied by a 💛.

-- The posts ---------------------------------------------------------------------
create table public.social_posts (
  id           uuid primary key default gen_random_uuid(),
  -- Idempotent re-seeding, same convention as content_cards.slug: the slug IS the
  -- identity, so re-running the seeder updates rather than duplicates.
  slug         text not null unique,
  title        text not null,
  body         text not null,                 -- markdown
  -- [{type:'image'|'video', url, alt}] — Supabase Storage paths in the public
  -- content bucket below. jsonb rather than a child table because the app only
  -- ever reads the whole list, in order, with the post.
  media        jsonb not null default '[]'::jsonb,
  post_type    text not null default 'tip'
                 check (post_type in ('carousel', 'tip', 'reel', 'article')),
  -- Same controlled vocabulary as content_cards where the topics overlap
  -- (00_CARD_SPEC §4), so a tag filter here means the same thing it means there.
  tags         text[] not null default '{}',
  source_url   text,                           -- the IG/FB original, when there is one
  published_at timestamptz not null default now(),
  published    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.social_posts is
  'Florie''s social content, mirrored in-app. Seeded by slug; service-role writes only.';

-- The feed's only ordering, and its only filter.
create index idx_social_posts_feed on public.social_posts (published_at desc)
  where published;
-- Policy column is `published`, covered above; tags need GIN for the filter chips.
create index idx_social_posts_tags on public.social_posts using gin (tags);

-- Her 💛 -----------------------------------------------------------------------
-- The unique constraint is the no-double-counting guarantee. Enforcing it in the
-- database rather than in the client means a double tap, a retry, or two devices
-- cannot produce two rows; the client's job is only to insert or delete.
create table public.post_reactions (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.social_posts (id) on delete cascade,
  user_id    uuid not null references public.users (id) on delete cascade,
  kind       text not null default 'heart' check (kind in ('heart')),
  created_at timestamptz not null default now(),
  constraint post_reactions_once unique (post_id, user_id, kind)
);

-- Policy column, and the "did I heart this" lookup the feed does per load.
create index idx_post_reactions_user on public.post_reactions (user_id, post_id);

-- Keep updated_at honest for the seeder's change detection.
create trigger social_posts_set_updated_at
  before update on public.social_posts
  for each row execute function public.set_updated_at();

-- RLS ---------------------------------------------------------------------------
alter table public.social_posts   enable row level security;
alter table public.post_reactions enable row level security;

-- Shared content: any signed-in parent may read a published post. No client
-- writes at all — an unpublished draft is not readable, and nothing in the app
-- can create, edit or unpublish one.
create policy social_posts_read on public.social_posts
  for select to authenticated using (published);

-- User-isolated, direct comparison, indexed (Hard Rules #1/#3).
-- No UPDATE policy: a heart is added or removed, never edited. Leaving it out
-- means there is no path to rewrite someone else's row even by mistake.
create policy post_reactions_select on public.post_reactions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy post_reactions_insert on public.post_reactions
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy post_reactions_delete on public.post_reactions
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Media -------------------------------------------------------------------------
-- Public-read, unlike family-media: this is content Florie already publishes on
-- Instagram, so signed URLs would add cost and latency to protect nothing. Writes
-- are service-role only — there is no storage policy granting `authenticated`
-- anything here, so the absence of a policy IS the write restriction.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('content-media', 'content-media', true, 10485760,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
