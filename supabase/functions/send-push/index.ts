import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { getUser } from '../_shared/auth.ts';
import { loadServiceAccount, getAccessToken, sendToToken } from '../_shared/fcm.ts';

// send-push (Task 7): sends a push to the AUTHENTICATED user's own devices. This
// is the test/sender path; the scheduled reminder dispatcher (Task 20) reuses the
// same _shared/fcm helpers. Dead tokens are pruned so the table stays clean.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const startedAt = Date.now();
  const json = (status: number, body: Record<string, unknown>) =>
    new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  const user = await getUser(req);
  if (!user) return json(401, { ok: false, error: 'unauthorized' });

  let title = 'Momzo';
  let body = 'A little reminder to connect today. 💛';
  try {
    const b = await req.json();
    if (b?.title) title = String(b.title);
    if (b?.body) body = String(b.body);
  } catch { /* defaults */ }

  try {
    const sql = db();
    const tokens = await sql`select token from device_tokens where user_id = ${user.id}`;
    if (tokens.length === 0) {
      return json(200, { ok: true, sent: 0, failed: 0, note: 'no registered devices' });
    }

    const sa = loadServiceAccount();
    const accessToken = await getAccessToken(sa);

    let sent = 0;
    const dead: string[] = [];
    for (const { token } of tokens) {
      const r = await sendToToken(accessToken, sa.project_id, token, { title, body });
      if (r.ok) sent++;
      else if (r.error === 'UNREGISTERED' || r.error === 'INVALID_ARGUMENT' || r.status === 404) dead.push(token);
    }
    if (dead.length) await sql`delete from device_tokens where token = any(${dead})`;

    log.info('send_push_ok', { devices: tokens.length, sent, pruned: dead.length, duration_ms: Date.now() - startedAt });
    return json(200, { ok: true, sent, failed: tokens.length - sent, pruned: dead.length });
  } catch (e) {
    log.error('send_push_error', { duration_ms: Date.now() - startedAt, message: String(e) });
    return json(500, { ok: false });
  }
});
