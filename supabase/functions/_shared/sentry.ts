// Task 4: error reporting for Edge Functions, PII-scrubbed (COPPA / Hard Rule #10).
// No-op if SENTRY_DSN isn't set (local/dev). We only ever send the error + a few
// non-PII tags — never request bodies, user info, question/answer text, or any
// child identifier.
import * as Sentry from 'npm:@sentry/deno';

let inited = false;
function ensureInit(): boolean {
  const dsn = Deno.env.get('SENTRY_DSN');
  if (!dsn) return false;
  if (inited) return true;
  Sentry.init({
    dsn,
    tracesSampleRate: 0,
    sendDefaultPii: false,
    environment: Deno.env.get('SENTRY_ENV') ?? 'production',
    beforeSend(event) {
      // Defense-in-depth scrub: drop anything that could carry PII.
      delete event.request;
      delete event.user;
      delete event.extra;
      if (event.contexts) delete event.contexts.body;
      return event;
    },
  });
  inited = true;
  return true;
}

/** Report an error to Sentry with non-PII tags. Never throws. */
export function captureError(err: unknown, tags?: Record<string, string>): void {
  try {
    if (!ensureInit()) return;
    Sentry.captureException(err, tags ? { tags } : undefined);
  } catch {
    // Telemetry must never break a request.
  }
}
