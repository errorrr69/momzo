// Semantic answer cache (Cost Strategy §5, Layer 4).
//
// Thousands of parents ask essentially the same question. Serve one vetted answer
// instead of generating thousands — but ONLY to a family the answer actually fits.
//
// The cache key is (question embedding, personalization bucket), never the
// question alone: an answer written for an anxious 8-year-old must not reach the
// parent of a boisterous 4-year-old.
//
// Never cached, no exceptions:
//   * anything that tripped the refer-out screen (§5 rules, Hard Rule #2 here)
//   * situational "right now" responses — those are of the moment
//   * anything containing a child's name or a family-specific detail

import type { db } from './db.ts';
import { log } from './log.ts';

/// Start strict and loosen with data. A wrong-but-confident cached answer is far
/// worse than paying $0.0003.
export const SIMILARITY_THRESHOLD = Number(Deno.env.get('AI_SEMANTIC_CACHE_THRESHOLD')) || 0.95;

export const CACHE_ENABLED = (Deno.env.get('AI_SEMANTIC_CACHE') ?? 'on') !== 'off';

// --- bucketing -------------------------------------------------------------

export function ageBand(age: number): string {
  if (age <= 5) return '4-5';
  if (age <= 7) return '6-7';
  return '8-10';
}

const norm = (s: unknown): string =>
  String(s ?? '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

/// age_band | primary focus goal | primary challenge. Coarse on purpose: fine
/// buckets would make the hit rate useless, coarse ones keep the answer a fit.
export function bucketKey(age: number, focusGoals: unknown[], challenges: unknown[]): string {
  const focus = norm(Array.isArray(focusGoals) ? focusGoals[0] : '') || 'none';
  const challenge = norm(Array.isArray(challenges) ? challenges[0] : '') || 'none';
  return `${ageBand(age)}|${focus}|${challenge}`;
}

// --- lookup / write --------------------------------------------------------

export interface CacheHit {
  id: string;
  answer: string;
  citedCardIds: string[];
  similarity: number;
}

/// Reuses the embedding already computed for RAG — a lookup costs no extra tokens.
export async function lookupCachedAnswer(
  sql: ReturnType<typeof db>,
  embeddingLiteral: string,
  bucket: string,
): Promise<CacheHit | null> {
  if (!CACHE_ENABLED) return null;
  try {
    const rows = await sql`
      select id, answer_text, cited_card_ids, similarity
      from match_cached_answer(${embeddingLiteral}::vector(768), ${bucket}, ${SIMILARITY_THRESHOLD})`;
    if (rows.length === 0) return null;
    const r = rows[0];
    // Monitoring only — tells us which cached answers are actually earning their keep.
    await sql`update cached_answers set hit_count = hit_count + 1 where id = ${r.id}`;
    return {
      id: r.id,
      answer: r.answer_text,
      citedCardIds: (r.cited_card_ids ?? []) as string[],
      similarity: Number(r.similarity),
    };
  } catch (e) {
    // A cache miss is always safe. Never fail a parent's answer over the cache.
    log.warn('semantic_cache_lookup_failed', { message: String(e) });
    return null;
  }
}

/// Guard: a cached answer is global, so it must be provably free of anything
/// family-specific before it can be written. We never send the name to the model,
/// so this should never fire — it is the belt to that braces.
export function isNameFree(answer: string, childName: string | null): boolean {
  if (!childName) return true;
  const name = childName.trim();
  if (name.length < 2) return true;
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return !new RegExp(`\\b${escaped}\\b`, 'i').test(answer);
}

export interface CacheWrite {
  question: string;
  embeddingLiteral: string;
  bucket: string;
  answer: string;
  citedCardIds: string[];
  model: string;
  childName: string | null;
}

/// Write-through after a fresh generation. Callers must have already established
/// that the turn was NOT refer-out flagged and NOT situational.
export async function storeCachedAnswer(
  sql: ReturnType<typeof db>,
  w: CacheWrite,
): Promise<boolean> {
  if (!CACHE_ENABLED) return false;
  if (!w.answer || w.answer.length < 40) return false;      // nothing worth reusing
  if (!isNameFree(w.answer, w.childName)) {
    log.warn('semantic_cache_write_blocked', { reason: 'name_leak' });
    return false;
  }
  try {
    const cited = `{${w.citedCardIds.join(',')}}`;
    await sql`
      insert into cached_answers
        (question_text, question_embedding, bucket_key, answer_text, cited_card_ids, model)
      values
        (${w.question}, ${w.embeddingLiteral}::vector(768), ${w.bucket}, ${w.answer},
         ${cited}::uuid[], ${w.model})`;
    return true;
  } catch (e) {
    log.warn('semantic_cache_write_failed', { message: String(e) });
    return false;
  }
}
