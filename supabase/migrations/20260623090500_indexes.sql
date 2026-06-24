-- Momzo schema · 06 · Indexes (Hard Rule #1: index every policy-filtered column)
--
-- One btree per column an RLS policy filters on, so per-family queries stay <50ms and
-- use the index (Task 3 test). Plus a few hot-path indexes (FK lookups, the reminder
-- cron predicate) and the pgvector ANN index for RAG.

-- RLS owner_id / user_id filters ─────────────────────────────────────────────────
create index idx_children_owner            on public.children            (owner_id);
create index idx_daily_assignments_owner   on public.daily_assignments   (owner_id);
create index idx_activity_logs_owner       on public.activity_logs       (owner_id);
create index idx_ai_conversations_user     on public.ai_conversations    (user_id);
create index idx_ai_messages_owner         on public.ai_messages         (owner_id);
create index idx_question_responses_owner  on public.question_responses  (owner_id);
create index idx_wishes_owner              on public.wishes              (owner_id);
create index idx_scheduled_events_owner    on public.scheduled_events    (owner_id);
create index idx_reminders_user            on public.reminders           (user_id);
create index idx_milestones_owner          on public.milestones          (owner_id);
create index idx_family_members_user       on public.family_members      (user_id);

-- Hot-path / FK lookups commonly joined or filtered per child ─────────────────────
create index idx_daily_assignments_child   on public.daily_assignments   (child_id);
create index idx_activity_logs_child       on public.activity_logs       (child_id);
create index idx_ai_messages_conversation  on public.ai_messages         (conversation_id);
create index idx_question_responses_child  on public.question_responses  (child_id);
create index idx_wishes_child              on public.wishes              (child_id);
create index idx_scheduled_events_child    on public.scheduled_events    (child_id);
create index idx_milestones_child          on public.milestones          (child_id);
create index idx_content_embeddings_card   on public.content_embeddings  (card_id);

-- Reminder dispatch cron: WHERE sent_at IS NULL AND send_at <= now() (Hard Rule #13).
create index idx_reminders_due on public.reminders (send_at) where sent_at is null;

-- pgvector ANN index for RAG retrieval (cosine). HNSW builds fine on an empty table.
create index idx_content_embeddings_vec
  on public.content_embeddings
  using hnsw (embedding vector_cosine_ops);
