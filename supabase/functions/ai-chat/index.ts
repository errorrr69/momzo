import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { captureError } from '../_shared/sentry.ts';
import { getUser } from '../_shared/auth.ts';
import {
  embedQuery, mistralChat, referOutReason, REFER_OUT_MESSAGE,
  MODEL_DEFAULT, MODEL_ESCALATE, isSensitive, WEAK_RETRIEVAL,
} from '../_shared/ai.ts';
import { buildPersonalizationContext } from '../_shared/personalization.ts';
import { buildPrompt, type Mode } from '../_shared/prompts.ts';
import {
  breakerState, isRateLimited, recordUsage, BREAKER_MESSAGE, LIMIT_MESSAGE,
} from '../_shared/aicost.ts';
import { lookupCachedAnswer, storeCachedAnswer } from '../_shared/semcache.ts';
import { buildMemory } from '../_shared/memory.ts';

// ai-chat (Task 14): RAG-grounded parenting Q&A.
//   1. require a valid JWT; verify the caller owns the child
//   2. refer-out classifier on EVERY turn (Hard Rule #7) — never diagnose
//   3. rate limit + budget breaker (Cost Strategy §4/§9) — AFTER the safety screen
//   4. embed the question (Gemini) -> semantic answer cache (§5), else top-K chunks
//   5. answer ONLY from those excerpts + established knowledge (Hard Rule #6),
//      via Mistral with a cached static prefix (§3); cite the source cards
//   6. persist ai_conversations / ai_messages + a PII-free ai_usage row (§8)
//
// Privacy (Hard Rule #10 + COPPA): keys stay in this function; the child's NAME is
// never sent to the LLM — only age/temperament/struggles.
//
// COST ORDERING IS A SAFETY PROPERTY: the refer-out screen is cheap (regex) and
// runs before the rate-limit check and before the breaker, so a mother in a hard
// moment can never hit a cost-shaped wall. Do not reorder these blocks.
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

  let question = '';
  let childId = '';
  let conversationId: string | null = null;
  let mode: Mode = 'qa';
  try {
    const b = await req.json();
    question = (b?.question ?? '').toString().trim();
    childId = (b?.child_id ?? '').toString();
    conversationId = b?.conversation_id ?? null;
    mode = b?.mode === 'situational' ? 'situational' : 'qa';
  } catch { /* validated below */ }
  if (!question || !childId) return json(400, { ok: false, error: 'question and child_id required' });

  try {
    const sql = db();

    // Ownership check + NAME-FREE personalization context, built in one place
    // (the isolation choke-point). Returns null if the child isn't the caller's.
    const pers = await buildPersonalizationContext(sql, user.id, childId);
    if (!pers) return json(403, { ok: false, error: 'forbidden' });

    // Reuse an owned conversation, else open a new one.
    if (conversationId) {
      const c = await sql`select user_id from ai_conversations where id = ${conversationId}`;
      if (c.length === 0 || c[0].user_id !== user.id) conversationId = null;
    }
    const isNewConversation = !conversationId;
    if (!conversationId) {
      const [c] = await sql`
        insert into ai_conversations (user_id, child_id, mode)
        values (${user.id}, ${childId}, ${mode}) returning id`;
      conversationId = c.id;
    }

    // ---- 1. SAFETY FIRST (Hard Rule #7) ------------------------------------
    // Runs before every cost control. A rate-limited user, or one arriving while
    // the budget breaker is tripped, STILL gets the full refer-out response.
    const flagged = referOutReason(question);
    if (flagged) {
      await persist(sql, user.id, conversationId!, question, REFER_OUT_MESSAGE, [], flagged);
      await recordUsage(sql, {
        ownerId: user.id, conversationId, mode, billable: false, referOut: true,
        latencyMs: Date.now() - startedAt,
      });
      log.info('ai_chat_refer_out', { duration_ms: Date.now() - startedAt });
      return json(200, { ok: true, conversation_id: conversationId, answer: REFER_OUT_MESSAGE, citations: [], flagged });
    }

    // ---- 2. Rate limit (Cost Strategy §4) ----------------------------------
    // Server-side only, counted from ai_usage's billable rows over a rolling 24h.
    // The copy is warm and carries no counter, no reset nag, no cost language.
    if (await isRateLimited(sql, user.id, mode)) {
      await recordUsage(sql, {
        ownerId: user.id, conversationId, mode, billable: false, rateLimited: true,
        latencyMs: Date.now() - startedAt,
      });
      log.warn('ai_chat_rate_limited', { mode, duration_ms: Date.now() - startedAt });
      return json(200, {
        ok: true, conversation_id: conversationId,
        answer: LIMIT_MESSAGE[mode], citations: [], flagged: null, limited: true,
      });
    }

    const breaker = await breakerState(sql);

    // ---- 3. Personal memory (Tier B) ---------------------------------------
    // The conversation so far, the parent's own notes, and what this family has
    // actually been doing. Any of these makes the turn about ONE family, which
    // makes it ineligible for the shared answer cache — in both directions.
    const memory = await buildMemory(sql, {
      ownerId: user.id,
      childId,
      conversationId: conversationId!,
      isNewConversation,
      notes: pers.notes,
    });

    // ---- 4. Retrieval + semantic answer cache (§5) -------------------------
    // The embedding is needed for RAG anyway, so the cache lookup is free.
    const emb = await embedQuery(question);
    const lit = `[${emb.join(',')}]`;

    // Q&A only, and only for a turn with no personal context. Situational answers
    // are of-the-moment and are never cached.
    const cacheEligible = mode === 'qa' && !memory.isPersonal;
    if (cacheEligible) {
      const hit = await lookupCachedAnswer(sql, lit, pers.bucket);
      if (hit) {
        const cites = await titlesFor(sql, hit.citedCardIds);
        const ids = await persist(
          sql, user.id, conversationId!, question, hit.answer, hit.citedCardIds, null,
          hit.id, /* servedFromCache */ true);
        await recordUsage(sql, {
          ownerId: user.id, conversationId, mode, billable: false, semanticCacheHit: true,
          breakerState: breaker, latencyMs: Date.now() - startedAt,
        });
        log.info('ai_chat_cache_hit', {
          mode, similarity: Number(hit.similarity.toFixed(3)), duration_ms: Date.now() - startedAt,
        });
        return json(200, {
          ok: true, conversation_id: conversationId, answer: hit.answer,
          citations: cites, flagged: null, cached: true, message_id: ids.assistantId,
        });
      }
    }

    // ---- 5. Budget breaker (§9) --------------------------------------------
    // Cache miss + tripped breaker: degrade warmly rather than generate. Safety
    // already returned above, so nothing urgent is being turned away here.
    if (breaker === 'hard') {
      await recordUsage(sql, {
        ownerId: user.id, conversationId, mode, billable: false,
        breakerState: breaker, latencyMs: Date.now() - startedAt,
      });
      log.error('ai_chat_breaker_degraded', { mode, duration_ms: Date.now() - startedAt });
      return json(200, {
        ok: true, conversation_id: conversationId, answer: BREAKER_MESSAGE,
        citations: [], flagged: null, limited: true,
      });
    }

    // Retrieve top-K vetted chunks.
    const hits = (await sql`
      select card_id, title, chunk, similarity
      from match_content_cards(${lit}::vector(768), 6)`) as unknown as
      { card_id: string; title: string; chunk: string; similarity: number }[];

    // Distinct cards (cited), and a context block for grounding.
    // Only chunks that actually matched are citable: every excerpt still goes to
    // the model as context, but a card below WEAK_RETRIEVAL did not source the
    // answer and must not be shown as if it had. A question the corpus does not
    // cover now returns zero citations rather than three plausible-looking ones.
    const seen = new Set<string>();
    const citations: { card_id: string; title: string }[] = [];
    for (const h of hits) {
      if (Number(h.similarity) < WEAK_RETRIEVAL) continue;
      if (!seen.has(h.card_id)) { seen.add(h.card_id); citations.push({ card_id: h.card_id, title: h.title }); }
    }
    const topCitations = citations.slice(0, 3);
    const excerpts = hits.map((h, i) => `[${i + 1}] (${h.title})\n${h.chunk}`).join('\n\n');

    // ---- 6. Generate, with the cached static prefix (§3) --------------------
    // buildPrompt keeps the byte-identical prefix in message 0 and everything
    // per-user in message 1, so the prefix cache hits across all users.
    const { messages, cacheKey } = buildPrompt(mode, {
      childContext: pers.context,
      excerpts,
      question,
      personalLines: memory.personalLines,
      history: memory.history,
    });

    // Cheap-by-default routing (Hard Rule #8): escalate only when retrieval is weak
    // or the topic is emotionally sensitive (Q&A only; situational stays short+cheap).
    const topSim = hits.length ? Math.max(...hits.map((h) => Number(h.similarity))) : 0;
    const escalate = mode === 'qa' && (topSim < WEAK_RETRIEVAL || isSensitive(question));
    const model = escalate ? MODEL_ESCALATE : MODEL_DEFAULT;

    const { text: answer, usage, cachedTokens } = await mistralChat(messages, {
      model, maxTokens: mode === 'situational' ? 280 : 450, temperature: 0.4, cacheKey,
    });

    // Write through to the semantic cache — only for a turn that was eligible to
    // read from it. An answer shaped by this family's notes, history or recent
    // activity is about them, and must never be served to anyone else. Also
    // never a flagged turn (we returned above), and only if the answer is
    // provably free of the child's name.
    let cachedId: string | null = null;
    if (cacheEligible && answer) {
      cachedId = await storeCachedAnswer(sql, {
        question,
        embeddingLiteral: lit,
        bucket: pers.bucket,
        answer,
        citedCardIds: topCitations.map((c) => c.card_id),
        model,
        childName: pers.guardName,
      });
    }

    // Persist AFTER the cache write, so the assistant message can point at the
    // cached row it produced — a thumbs-down then retires that row for everyone.
    const ids = await persist(
      sql, user.id, conversationId!, question, answer,
      topCitations.map((c) => c.card_id), null, cachedId);

    // PII-free cost telemetry (§8). Non-fatal so a metrics write can never fail
    // a parent's answer. Feeds ai_cost_summary / ai_cost_per_active_user.
    await recordUsage(sql, {
      ownerId: user.id,
      conversationId,
      mode,
      model,
      escalated: escalate,
      promptTokens: usage?.prompt_tokens ?? null,
      completionTokens: usage?.completion_tokens ?? null,
      cachedTokens,
      promptCacheHit: cachedTokens > 0,
      breakerState: breaker,
      latencyMs: Date.now() - startedAt,
    });

    log.info('ai_chat_ok', {
      mode,
      model,
      escalated: escalate,
      top_similarity: Number(topSim.toFixed(3)),
      prompt_tokens: usage?.prompt_tokens ?? null,
      completion_tokens: usage?.completion_tokens ?? null,
      cached_tokens: cachedTokens,
      prompt_cache_hit: cachedTokens > 0,
      cached_write: cachedId !== null,
      cache_eligible: cacheEligible,
      history_turns: memory.history.length,
      personal_context: memory.personalLines.length,
      chunks: hits.length,
      cited: topCitations.length,
      breaker,
      duration_ms: Date.now() - startedAt,
    });
    return json(200, {
      ok: true, conversation_id: conversationId, answer, citations: topCitations,
      flagged: null, model, message_id: ids.assistantId,
    });
  } catch (e) {
    log.error('ai_chat_error', { duration_ms: Date.now() - startedAt, message: String(e) });
    captureError(e, { fn: 'ai-chat' });
    return json(500, { ok: false });
  }
});

// Titles for a cached answer's stored card ids, so a cache hit renders the same
// citation chips a fresh answer does.
async function titlesFor(
  sql: ReturnType<typeof db>,
  cardIds: string[],
): Promise<{ card_id: string; title: string }[]> {
  if (cardIds.length === 0) return [];
  const lit = `{${cardIds.join(',')}}`;
  const rows = (await sql`
    select id as card_id, title from content_cards where id = any(${lit}::uuid[]) and published`
  ) as unknown as { card_id: string; title: string }[];
  return rows.map((r) => ({ card_id: r.card_id, title: r.title }));
}

// Persist the user turn + the assistant turn (owner_id denormalized for RLS).
// Returns the assistant message id so the app can attach a rating to it, and
// so `recentTurns` has something to replay on the next question.
async function persist(
  sql: ReturnType<typeof db>,
  ownerId: string,
  conversationId: string,
  question: string,
  answer: string,
  citedCardIds: string[],
  flagged: string | null,
  // The cached_answers row to retire if she thumbs this down. Live FK — it is
  // nulled when that row is deleted.
  cachedAnswerId: string | null = null,
  // Durable provenance: was this answer SERVED from the cache? Recorded
  // separately because the FK above disappears the moment the loop closes.
  servedFromCache = false,
): Promise<{ assistantId: string }> {
  await sql`
    insert into ai_messages (owner_id, conversation_id, role, content)
    values (${ownerId}, ${conversationId}, 'user', ${question})`;
  const citedLit = `{${citedCardIds.join(',')}}`;
  const [a] = (await sql`
    insert into ai_messages
      (owner_id, conversation_id, role, content, cited_card_ids, flagged,
       cached_answer_id, served_from_cache)
    values
      (${ownerId}, ${conversationId}, 'assistant', ${answer}, ${citedLit}::uuid[],
       ${flagged}, ${cachedAnswerId}, ${servedFromCache})
    returning id`) as unknown as { id: string }[];
  return { assistantId: a.id };
}
