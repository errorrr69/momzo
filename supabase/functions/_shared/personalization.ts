import { db } from './db.ts';
import { bucketKey } from './semcache.ts';

/// The single place that turns a family's profile into a NAME-FREE personalization
/// context for the cloud LLM (Onboarding & Personalization Spec §5 + §10). It also
/// VERIFIES OWNERSHIP — this is the isolation choke-point (§6.2): it returns null
/// when the child doesn't belong to the authenticated user, so a caller can never
/// get another family's context. Built fresh per request; never cached across users.

export interface Personalization {
  context: string;
  age: number;
  /// Coarse (age band | focus | challenge) key for the semantic answer cache
  /// (Cost Strategy §5). Contains no free text and no identifier.
  bucket: string;
  /// The child's name — returned for ONE purpose only: the cache-write guard,
  /// which refuses to store an answer that contains it. It must never reach a
  /// prompt, a log line, or a response body.
  guardName: string | null;
}

// slider key -> [low-end label, high-end label]
const TEMP_LABELS: Record<string, [string, string]> = {
  warmup: ['warms up slowly', 'dives right into new things'],
  energy: ['calm and cozy', 'high energy'],
  expressive: ['keeps feelings in', 'shows feelings openly'],
  social: ['happy playing alone', 'enjoys company'],
};

function temperamentPhrase(t: Record<string, unknown> | null): string {
  if (!t || typeof t !== 'object') return '';
  const parts: string[] = [];
  for (const [k, [lo, hi]] of Object.entries(TEMP_LABELS)) {
    const v = Number((t as Record<string, unknown>)[k]);
    if (Number.isFinite(v)) parts.push(v < 0.5 ? lo : hi);
  }
  return parts.join(', ');
}

const list = (a: unknown): string =>
  Array.isArray(a) && a.length ? (a as unknown[]).map(String).join(', ') : '';

export async function buildPersonalizationContext(
  sql: ReturnType<typeof db>,
  userId: string,
  childId: string,
): Promise<Personalization | null> {
  const rows = await sql`
    select c.owner_id, c.age, c.name, c.focus_goals, c.challenges, c.interests, c.temperament, c.notes,
           u.time_with_child, u.mom_goals
    from children c
    join users u on u.id = c.owner_id
    where c.id = ${childId}`;
  if (rows.length === 0) return null;
  const r = rows[0];
  if (r.owner_id !== userId) return null; // not the caller's child — reject (§6.2)

  const lines: string[] = [`Child: age ${r.age}.`];
  if (list(r.focus_goals)) lines.push(`Working on: ${list(r.focus_goals)}.`);
  if (list(r.challenges)) lines.push(`Tricky right now: ${list(r.challenges)}.`);
  if (list(r.interests)) lines.push(`Loves: ${list(r.interests)}.`);
  const temp = temperamentPhrase(r.temperament);
  if (temp) lines.push(`Temperament: ${temp}.`);
  if (list(r.mom_goals)) lines.push(`The parent wants to: ${list(r.mom_goals)}.`);
  if (r.time_with_child) lines.push(`The parent has about ${r.time_with_child} a day together.`);
  lines.push(
    'Personalize tone, examples, and suggestions to this child. Refer to the child as ' +
      '"your child" — never use a name. Do not diagnose. If anything suggests a clinical or ' +
      'safety concern, follow the refer-out guidance.',
  );

  return {
    context: lines.join('\n'),
    age: Number(r.age),
    bucket: bucketKey(Number(r.age), r.focus_goals ?? [], r.challenges ?? []),
    guardName: r.name ? String(r.name) : null,
  };
}
