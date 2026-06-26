import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { getUser } from '../_shared/auth.ts';
import { captureError } from '../_shared/sentry.ts';

// Delete a child profile and ALL associated data (Task 10, Hard Rule #17 — COPPA
// right to erasure). Server-side so it's reliable and auditable; the DB work runs
// in ONE transaction so we never leave orphans.
//
// Security: requires a valid JWT AND verifies the caller OWNS the child before
// deleting — service_role bypasses RLS, so this explicit check is what stops a
// parent from deleting another family's child.
//
// Cascade: deleting the `children` row cascades daily_assignments, activity_logs,
// question_responses, wishes, scheduled_events (-> reminders), milestones, and
// family_members via ON DELETE CASCADE. ai_conversations reference the child as
// nullable context (ON DELETE SET NULL), so we delete those explicitly first
// (their ai_messages cascade via conversation_id).
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const startedAt = Date.now();
  const json = (status: number, body: Record<string, unknown>) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  const user = await getUser(req);
  if (!user) return json(401, { ok: false, error: 'unauthorized' });

  let childId: string | undefined;
  try {
    childId = (await req.json())?.child_id;
  } catch {
    /* handled below */
  }
  if (!childId) return json(400, { ok: false, error: 'child_id required' });

  try {
    const sql = db();

    const outcome = await sql.begin(async (tx) => {
      const owner = await tx`select owner_id from children where id = ${childId}`;
      if (owner.length === 0) return { status: 404 as const };
      if (owner[0].owner_id !== user.id) return { status: 403 as const };

      // Capture private Storage paths before the rows vanish (Hard Rule #16).
      const photos = await tx`
        select photo_url from activity_logs where child_id = ${childId} and photo_url is not null
        union all
        select photo_url from milestones where child_id = ${childId} and photo_url is not null`;

      await tx`delete from ai_conversations where child_id = ${childId}`;
      await tx`delete from children where id = ${childId}`;

      return { status: 200 as const, photos: photos.map((p: { photo_url: string }) => p.photo_url) };
    });

    if (outcome.status !== 200) {
      log.warn('delete_child_denied', { status: outcome.status, duration_ms: Date.now() - startedAt });
      return json(outcome.status, { ok: false });
    }

    const storageRemoved = await purgeStorage(outcome.photos);

    log.info('delete_child_ok', {
      photos_removed: storageRemoved,
      duration_ms: Date.now() - startedAt,
    });
    return json(200, { ok: true, photos_removed: storageRemoved });
  } catch (e) {
    log.error('delete_child_error', { duration_ms: Date.now() - startedAt, message: String(e) });
    captureError(e, { fn: 'delete-child' });
    return json(500, { ok: false });
  }
});

// Best-effort removal of the child's private media. The Storage bucket/path
// convention is finalized by the Storage task; until then this no-ops cleanly if
// the bucket doesn't exist. Returns how many objects were removed.
async function purgeStorage(paths: string[]): Promise<number> {
  if (!paths || paths.length === 0) return 0;
  const bucket = Deno.env.get('MEDIA_BUCKET') ?? 'family-media';
  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    // Accept either bare storage paths or full public URLs.
    const keys = paths.map((p) => p.replace(/^.*\/object\/(?:public|sign)\/[^/]+\//, ''));
    const { data, error } = await admin.storage.from(bucket).remove(keys);
    if (error) {
      log.warn('delete_child_storage_skip', { reason: 'remove_failed' });
      return 0;
    }
    return data?.length ?? 0;
  } catch {
    log.warn('delete_child_storage_skip', { reason: 'bucket_unavailable' });
    return 0;
  }
}
