-- Momzo schema · 13 · Schedule the reminder dispatcher (Task 20)
-- pg_cron invokes the send-due-reminders Edge Function every 15 minutes via
-- pg_net. The cron secret is read from Vault at RUN time (set out-of-band, never
-- committed); the anon key is public (gateway apikey).
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
    url := 'https://nngjqhrxbhugnafyviqj.supabase.co/functions/v1/send-due-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uZ2pxaHJ4Ymh1Z25hZnl2aXFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMTI3NDIsImV4cCI6MjA5NzY4ODc0Mn0.Yn73VsznF0YPCxngW8AFc4b5Wti-mK7F09lBqjgH6a4',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
