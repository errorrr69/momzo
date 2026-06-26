-- Learn redesign: structured "quick read" fields so the topic reader can show
-- scannable pieces (a hook, a 3-point quick version, and a "try this tonight")
-- instead of one intimidating wall of text. Generated from each card's body via
-- the AI pipeline (Mistral), like why_it_matters. Falls back to body if empty.
alter table public.content_cards
  add column if not exists hook         text,
  add column if not exists quick_points text[] not null default '{}',
  add column if not exists try_this     text;
