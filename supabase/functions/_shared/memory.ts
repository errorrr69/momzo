// Per-family memory for the AI expert.
//
// Momzo's context comes in two tiers, and the split is what keeps the semantic
// answer cache (Cost Strategy §5) honest:
//
//   TIER A — BUCKET CONTEXT (shared, cacheable)
//     age band, focus goals, challenges, interests, temperament, the parent's
//     goals and time. Two families in the same bucket genuinely want the same
//     answer, which is exactly what makes one vetted answer reusable.
//
//   TIER B — PERSONAL CONTEXT (this family only, NOT cacheable)
//     the conversation so far, the parent's free-text notes, and what this family
//     has actually been doing lately. An answer shaped by any of these is about
//     one family and must never be stored in, or replaced by, a shared cache.
//
// So: a turn carrying Tier B context skips the cache in BOTH directions. That is
// a deliberate cost trade — richer answers where they matter, free answers where
// they don't — and it is measurable in ai_efficiency.semantic_cache_hit_pct.
//
// Privacy is unchanged: the child's NAME never enters any of this, and neither
// does anything another family wrote.

import type { db } from './db.ts';
import { log } from './log.ts';

/// How much of the conversation to replay. Three exchanges is enough for "what if
/// that doesn't work?" to make sense, and costs ~300 tokens — it sits below the
/// cache boundary, so it never disturbs the cached static prefix.
export const HISTORY_TURNS = 3;

/// Per-message clamp, so one enormous pasted message can't blow up the prompt.
const MAX_CHARS_PER_MESSAGE = 600;

/// Engagement is only worth mentioning once there is a real pattern. Below this,
/// a "you've been busy!" line would be noise — and the turn stays cacheable.
const MIN_ENGAGEMENT_EVENTS = 3;

export interface Memory {
  /// Replay of the conversation so far, oldest first. Empty on a first turn.
  history: { role: 'user' | 'assistant'; content: string }[];
  /// Tier B context lines (notes, recent engagement). Empty when there are none.
  personalLines: string[];
  /// True when this turn carries ANY Tier B context. The caller must skip the
  /// semantic cache — read and write — when this is true.
  isPersonal: boolean;
}

export const EMPTY_MEMORY: Memory = { history: [], personalLines: [], isPersonal: false };

/// The last few exchanges of a conversation, oldest first.
///
/// Refer-out turns are excluded on purpose: replaying a safety response as
/// context invites the model to treat the next ordinary question as safety-
/// adjacent, and the live classifier is the only thing that should make that
/// call. The message currently being answered has not been written yet, so
/// there is nothing to exclude at the tail.
export async function recentTurns(
  sql: ReturnType<typeof db>,
  conversationId: string,
  turns: number = HISTORY_TURNS,
): Promise<{ role: 'user' | 'assistant'; content: string }[]> {
  try {
    const rows = (await sql`
      select role, content, flagged
      from ai_messages
      where conversation_id = ${conversationId}
      order by created_at desc
      limit ${turns * 2}`) as unknown as
      { role: string; content: string; flagged: string | null }[];

    return rows
      .filter((r) => !r.flagged)
      .reverse()
      .map((r) => ({
        role: r.role === 'assistant' ? 'assistant' as const : 'user' as const,
        content: clamp(String(r.content)),
      }));
  } catch (e) {
    // No history is always safe — it just means a less contextual answer.
    log.warn('recent_turns_failed', { message: String(e) });
    return [];
  }
}

function clamp(s: string): string {
  return s.length <= MAX_CHARS_PER_MESSAGE ? s : `${s.slice(0, MAX_CHARS_PER_MESSAGE)}…`;
}

/// What this family has actually been doing lately, in one warm line.
///
/// The point is that the AI can reference her real effort ("you've been reading
/// about big feelings") instead of talking to her as a stranger every time. It
/// is coarse and count-based — no titles, no notes, no free text she wrote.
export async function engagementSummary(
  sql: ReturnType<typeof db>,
  ownerId: string,
  childId: string,
): Promise<string | null> {
  try {
    const [r] = (await sql`
      with reads as (
        select da.card_id
        from daily_assignments da
        where da.owner_id = ${ownerId} and da.child_id = ${childId}
          and da.read_at is not null
          and da.read_at > now() - interval '21 days'
      ),
      topics as (
        select unnest(cc.tags) as tag
        from reads r join content_cards cc on cc.id = r.card_id
      )
      select
        (select count(*) from reads)::int as reads,
        (select count(*) from activity_logs
          where owner_id = ${ownerId} and child_id = ${childId}
            and completed_at > now() - interval '21 days')::int as activities,
        (select count(*) from question_responses
          where owner_id = ${ownerId} and child_id = ${childId}
            and answered_at > now() - interval '21 days')::int as moments,
        (select array_agg(tag order by n desc)
           from (select tag, count(*) as n from topics group by tag
                 order by n desc limit 2) t)::text[] as top_tags`) as unknown as
      { reads: number; activities: number; moments: number; top_tags: string[] | null }[];

    if (!r) return null;
    const total = (r.reads ?? 0) + (r.activities ?? 0) + (r.moments ?? 0);
    if (total < MIN_ENGAGEMENT_EVENTS) return null;

    const parts: string[] = [];
    if (r.reads) parts.push(`read ${r.reads} daily card${r.reads === 1 ? '' : 's'}`);
    if (r.activities) parts.push(`logged ${r.activities} activit${r.activities === 1 ? 'y' : 'ies'}`);
    if (r.moments) parts.push(`shared ${r.moments} question${r.moments === 1 ? '' : 's'}`);

    const tags = (r.top_tags ?? []).filter(Boolean);
    const topic = tags.length ? ` Mostly around: ${tags.join(', ')}.` : '';
    return `In the last three weeks this parent has ${joinNaturally(parts)}.${topic} ` +
      `You may acknowledge this effort briefly if it is relevant — warmly, never as praise for compliance, ` +
      `and never as a nudge to do more.`;
  } catch (e) {
    log.warn('engagement_summary_failed', { message: String(e) });
    return null;
  }
}

function joinNaturally(parts: string[]): string {
  if (parts.length <= 1) return parts[0] ?? '';
  return `${parts.slice(0, -1).join(', ')} and ${parts[parts.length - 1]}`;
}

/// Assemble both tiers of personal memory for one turn.
export async function buildMemory(
  sql: ReturnType<typeof db>,
  opts: {
    ownerId: string;
    childId: string;
    conversationId: string;
    isNewConversation: boolean;
    notes: string | null;
  },
): Promise<Memory> {
  // A brand-new conversation has nothing to replay — skip the query entirely.
  const history = opts.isNewConversation
    ? []
    : await recentTurns(sql, opts.conversationId);

  const personalLines: string[] = [];

  // The parent's own free-text note about her child. It was collected at
  // onboarding and then silently dropped for months; it is the single most
  // specific thing she ever told us.
  const notes = (opts.notes ?? '').trim();
  if (notes) personalLines.push(`In the parent's own words: ${clamp(notes)}`);

  const engagement = await engagementSummary(sql, opts.ownerId, opts.childId);
  if (engagement) personalLines.push(engagement);

  return {
    history,
    personalLines,
    isPersonal: history.length > 0 || personalLines.length > 0,
  };
}
