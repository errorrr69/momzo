-- Momzo schema · 05 · Row-Level Security (Hard Rules #1 + #3)
--
-- RLS is enabled on EVERY public table — no exceptions (Hard Rule #1). Policies are
-- DIRECT comparisons with auth.uid() wrapped in (select ...) so it's evaluated once
-- per query, not per row (Hard Rule #3). No IN-subqueries / joins in policies.
--
-- DESIGN NOTE (deliberate, rule-driven — flag for Florie):
--   PRD §8 does not list owner_id on child-scoped tables (daily_assignments, wishes,
--   etc.). We ADDED a denormalized owner_id to each so their policy can stay a direct
--   comparison `(select auth.uid()) = owner_id` backed by a btree index — the only way
--   to satisfy Hard Rule #3 + the <50ms target without a join. The Build Guide
--   explicitly defers true membership lookups (co-parents) to a P2 security-definer
--   function; until then, single-owner == owner_id is correct and fast.
--
--   GLOBAL reference tables (content_cards, content_embeddings, activities, questions)
--   are written only by service_role/seed (which BYPASSES RLS). Clients get SELECT
--   only; content_embeddings has RLS on with NO client policy at all (server-only).

-- ── users ──────────────────────────────────────────────────────────────────────
alter table public.users enable row level security;
create policy users_self_select on public.users for select to authenticated using ((select auth.uid()) = id);
create policy users_self_insert on public.users for insert to authenticated with check ((select auth.uid()) = id);
create policy users_self_update on public.users for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy users_self_delete on public.users for delete to authenticated using ((select auth.uid()) = id);

-- ── children ───────────────────────────────────────────────────────────────────
alter table public.children enable row level security;
create policy children_owner_select on public.children for select to authenticated using ((select auth.uid()) = owner_id);
create policy children_owner_insert on public.children for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy children_owner_update on public.children for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy children_owner_delete on public.children for delete to authenticated using ((select auth.uid()) = owner_id);

-- ── daily_assignments ──────────────────────────────────────────────────────────
alter table public.daily_assignments enable row level security;
create policy daily_assignments_owner_select on public.daily_assignments for select to authenticated using ((select auth.uid()) = owner_id);
create policy daily_assignments_owner_insert on public.daily_assignments for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy daily_assignments_owner_update on public.daily_assignments for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy daily_assignments_owner_delete on public.daily_assignments for delete to authenticated using ((select auth.uid()) = owner_id);

-- ── activity_logs ──────────────────────────────────────────────────────────────
alter table public.activity_logs enable row level security;
create policy activity_logs_owner_select on public.activity_logs for select to authenticated using ((select auth.uid()) = owner_id);
create policy activity_logs_owner_insert on public.activity_logs for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy activity_logs_owner_update on public.activity_logs for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy activity_logs_owner_delete on public.activity_logs for delete to authenticated using ((select auth.uid()) = owner_id);

-- ── ai_conversations (user_id is the owner) ──────────────────────────────────────
alter table public.ai_conversations enable row level security;
create policy ai_conversations_owner_select on public.ai_conversations for select to authenticated using ((select auth.uid()) = user_id);
create policy ai_conversations_owner_insert on public.ai_conversations for insert to authenticated with check ((select auth.uid()) = user_id);
create policy ai_conversations_owner_update on public.ai_conversations for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy ai_conversations_owner_delete on public.ai_conversations for delete to authenticated using ((select auth.uid()) = user_id);

-- ── ai_messages ─────────────────────────────────────────────────────────────────
alter table public.ai_messages enable row level security;
create policy ai_messages_owner_select on public.ai_messages for select to authenticated using ((select auth.uid()) = owner_id);
create policy ai_messages_owner_insert on public.ai_messages for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy ai_messages_owner_update on public.ai_messages for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy ai_messages_owner_delete on public.ai_messages for delete to authenticated using ((select auth.uid()) = owner_id);

-- ── question_responses ───────────────────────────────────────────────────────────
alter table public.question_responses enable row level security;
create policy question_responses_owner_select on public.question_responses for select to authenticated using ((select auth.uid()) = owner_id);
create policy question_responses_owner_insert on public.question_responses for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy question_responses_owner_update on public.question_responses for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy question_responses_owner_delete on public.question_responses for delete to authenticated using ((select auth.uid()) = owner_id);

-- ── wishes ───────────────────────────────────────────────────────────────────────
alter table public.wishes enable row level security;
create policy wishes_owner_select on public.wishes for select to authenticated using ((select auth.uid()) = owner_id);
create policy wishes_owner_insert on public.wishes for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy wishes_owner_update on public.wishes for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy wishes_owner_delete on public.wishes for delete to authenticated using ((select auth.uid()) = owner_id);

-- ── scheduled_events ─────────────────────────────────────────────────────────────
alter table public.scheduled_events enable row level security;
create policy scheduled_events_owner_select on public.scheduled_events for select to authenticated using ((select auth.uid()) = owner_id);
create policy scheduled_events_owner_insert on public.scheduled_events for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy scheduled_events_owner_update on public.scheduled_events for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy scheduled_events_owner_delete on public.scheduled_events for delete to authenticated using ((select auth.uid()) = owner_id);

-- ── reminders (user_id is the owner) ─────────────────────────────────────────────
alter table public.reminders enable row level security;
create policy reminders_owner_select on public.reminders for select to authenticated using ((select auth.uid()) = user_id);
create policy reminders_owner_insert on public.reminders for insert to authenticated with check ((select auth.uid()) = user_id);
create policy reminders_owner_update on public.reminders for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy reminders_owner_delete on public.reminders for delete to authenticated using ((select auth.uid()) = user_id);

-- ── milestones ───────────────────────────────────────────────────────────────────
alter table public.milestones enable row level security;
create policy milestones_owner_select on public.milestones for select to authenticated using ((select auth.uid()) = owner_id);
create policy milestones_owner_insert on public.milestones for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy milestones_owner_update on public.milestones for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy milestones_owner_delete on public.milestones for delete to authenticated using ((select auth.uid()) = owner_id);

-- ── family_members (P2 — Phase 1: self-only visibility) ──────────────────────────
alter table public.family_members enable row level security;
create policy family_members_self_select on public.family_members for select to authenticated using ((select auth.uid()) = user_id);
-- No client insert/update/delete in Phase 1; co-parent invite flow (and membership-
-- based access to the shared child) is built in P2 via a security-definer function.

-- ── GLOBAL reference content: SELECT-only for authed clients; writes via service_role
alter table public.content_cards enable row level security;
create policy content_cards_read_published on public.content_cards for select to authenticated using (published);

alter table public.activities enable row level security;
create policy activities_read_all on public.activities for select to authenticated using (true);

alter table public.questions enable row level security;
create policy questions_read_all on public.questions for select to authenticated using (true);

-- content_embeddings: RLS ON, NO client policy → clients get nothing; the RAG Edge
-- Function reads it via service_role (which bypasses RLS). Server-only by design.
alter table public.content_embeddings enable row level security;
