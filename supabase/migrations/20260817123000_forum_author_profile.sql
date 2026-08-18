-- A post in the Circle must carry a Circle identity (Expansion Plan §2.4).
--
-- Two things at once, and the second is the reason to do it in the database:
--
--  1. PostgREST can only embed across a foreign key. Without one, the app would
--     have to fetch profiles separately and stitch them on, which works right up
--     until someone forgets and a screen falls back to whatever name it can find.
--
--  2. §2.4 makes the forum name a CHOICE — a display name and an emoji, never the
--     account name. A foreign key to forum_profiles means there is no code path,
--     present or future, that can create a post for an account which never made
--     that choice. The UI already asks; this makes the asking load-bearing.
--
-- author_id keeps its existing reference to users as well. Both hold: the row
-- belongs to a real account AND to a chosen Circle identity.

alter table public.forum_threads
  add constraint forum_threads_author_profile_fkey
  foreign key (author_id) references public.forum_profiles (user_id)
  on delete cascade;

alter table public.forum_replies
  add constraint forum_replies_author_profile_fkey
  foreign key (author_id) references public.forum_profiles (user_id)
  on delete cascade;
