import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { loadServiceAccount, getAccessToken, sendToToken } from '../_shared/fcm.ts';

// send-due-reminders (Task 20): invoked by pg_cron every ~15 min. Two jobs:
//   1. generate + send the gentle daily nudge for opted-in users at their slot
//   2. dispatch any due event reminders (send_at <= now, not yet sent)
// Both honor quiet hours (Hard Rule #18 tone, no pings) and are idempotent via
// sent_at (Hard Rule #13). Auth is a shared CRON_SECRET (no user JWT).
//
// Local time without IANA: users.tz_offset_minutes (set by the app) -> local =
// now + offset.

const SLOT_HOUR: Record<string, number> = { morning: 9, noon: 13, evening: 19 };

const NUDGE = {
  title: 'Momzo 💛',
  body: 'A few cozy minutes with your little one today? Your daily moment is ready.',
};
const REMINDER = { title: 'Momzo 💛', body: 'A gentle reminder for something you planned. 🌿' };

function inQuietHours(localHour: number, qh: { start?: number; end?: number } | null): boolean {
  if (!qh || qh.start == null || qh.end == null || qh.start === qh.end) return false;
  const { start, end } = qh;
  return start < end ? localHour >= start && localHour < end : localHour >= start || localHour < end;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const json = (s: number, b: Record<string, unknown>) =>
    new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  if (req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) {
    return json(401, { ok: false, error: 'unauthorized' });
  }

  const startedAt = Date.now();
  try {
    const sql = db();
    const sa = loadServiceAccount();
    const accessToken = await getAccessToken(sa);
    const nowMs = Date.now();

    async function pushToUser(userId: string, msg: { title: string; body: string }): Promise<number> {
      const toks = await sql`select token from device_tokens where user_id = ${userId}`;
      let sent = 0;
      const dead: string[] = [];
      for (const { token } of toks) {
        const r = await sendToToken(accessToken, sa.project_id, token, msg);
        if (r.ok) sent++;
        else if (r.error === 'UNREGISTERED' || r.error === 'INVALID_ARGUMENT' || r.status === 404) dead.push(token);
      }
      if (dead.length) await sql`delete from device_tokens where token = any(${dead})`;
      return sent;
    }

    // ---- 1. daily nudge ----
    let nudges = 0;
    const users = await sql`
      select id, nudge_slot, tz_offset_minutes, quiet_hours
      from users where daily_nudge = true and tz_offset_minutes is not null`;
    for (const u of users) {
      const offset = u.tz_offset_minutes as number;
      const local = new Date(nowMs + offset * 60000);
      const localHour = local.getUTCHours();
      if (localHour !== (SLOT_HOUR[u.nudge_slot] ?? 9)) continue;
      if (inQuietHours(localHour, u.quiet_hours)) continue;

      // Already nudged today (local)? (idempotency)
      const localMidnightUtc = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - offset * 60000);
      const already = await sql`
        select 1 from reminders
        where user_id = ${u.id} and type = 'nudge' and sent_at >= ${localMidnightUtc.toISOString()} limit 1`;
      if (already.length) continue;

      const sent = await pushToUser(u.id, NUDGE);
      // Mark as sent regardless of device count so we never re-send today.
      await sql`insert into reminders (user_id, type, channel, send_at, sent_at) values (${u.id}, 'nudge', 'push', now(), now())`;
      if (sent > 0) nudges++;
    }

    // ---- 2. due event reminders ----
    let reminders = 0;
    const due = await sql`
      select r.id, r.user_id, u.quiet_hours, u.tz_offset_minutes
      from reminders r join users u on u.id = r.user_id
      where r.sent_at is null and r.channel = 'push' and r.send_at <= now()`;
    for (const r of due) {
      const offset = (r.tz_offset_minutes as number) ?? 0;
      const localHour = new Date(nowMs + offset * 60000).getUTCHours();
      if (inQuietHours(localHour, r.quiet_hours)) continue; // hold until quiet hours pass
      await pushToUser(r.user_id, REMINDER);
      await sql`update reminders set sent_at = now() where id = ${r.id}`;
      reminders++;
    }

    log.info('reminders_run', { nudges, reminders, duration_ms: Date.now() - startedAt });
    return json(200, { ok: true, nudges, reminders });
  } catch (e) {
    log.error('reminders_error', { duration_ms: Date.now() - startedAt, message: String(e) });
    return json(500, { ok: false });
  }
});
