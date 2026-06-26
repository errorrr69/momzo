import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { getUser } from '../_shared/auth.ts';
import { captureError } from '../_shared/sentry.ts';

// Template Edge Function (Task 6). Every later function — ai-chat, send-due-
// reminders, whatsapp-send — copies this shape:
//   1. CORS preflight
//   2. optional/required JWT check (getUser)
//   3. a pooled DB round-trip via the 6543 transaction pooler (Hard Rule #2)
//   4. PII-free structured logs
//   5. JSON response
//
// hello-world keeps auth OPTIONAL so it returns 200 as a smoke test; real
// functions will reject unauthenticated callers.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const startedAt = Date.now();
  try {
    // Observability self-test (Task 4): GET ?boom=1 throws so we can confirm the
    // error reaches Sentry. No auth needed; carries no PII.
    if (new URL(req.url).searchParams.get('boom')) {
      throw new Error('Sentry test error — hello-world ?boom=1');
    }
    // Prove the pooled DB path works: a trivial round-trip through 6543.
    const sql = db();
    const [{ now }] = await sql`select now() as now`;

    const user = await getUser(req); // optional here

    log.info('hello_world_ok', {
      authed: user !== null,
      duration_ms: Date.now() - startedAt,
    });

    return new Response(
      JSON.stringify({ ok: true, db_time: now, authed: user !== null }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    log.error('hello_world_error', {
      duration_ms: Date.now() - startedAt,
      message: String(e), // internal error text only — no user data
    });
    captureError(e, { fn: 'hello-world' });
    return new Response(JSON.stringify({ ok: false }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
