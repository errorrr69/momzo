-- Momzo schema · 13 · Schedule the reminder dispatcher (Task 20)
-- pg_cron invokes the send-due-reminders Edge Function every 15 minutes via
-- pg_net.
--
-- EVERYTHING environment-specific is read from Vault at RUN time. This migration
-- used to hardcode the project URL and anon key, which meant that rebuilding into
-- a new Supabase project scheduled a job pointing at the OLD project — failing
-- quietly every 15 minutes, with reminders simply never arriving. Nothing in here
-- names a project any more.
--
-- Requires three Vault secrets (set out-of-band, never committed):
--   project_url  e.g. https://<ref>.supabase.co
--   anon_key     the gateway apikey (public by design, but not hardcoded here)
--   cron_secret  shared with the function's CRON_SECRET env var
--
-- If any is missing the POST is a no-op rather than a wrong call: url resolves to
-- NULL and net.http_post does nothing. Wrong-and-quiet was the old failure mode;
-- absent-and-quiet is the safer one.
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Re-running this migration shouldn't pile up duplicate schedules.
select cron.unschedule('send-due-reminders')
where exists (select 1 from cron.job where jobname = 'send-due-reminders');

select cron.schedule(
  'send-due-reminders',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/send-due-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key'),
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
