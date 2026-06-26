import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { captureError } from '../_shared/sentry.ts';
import { getUser } from '../_shared/auth.ts';
import {
  embedQuery, mistralChat, referOutReason, REFER_OUT_MESSAGE,
  MODEL_DEFAULT, MODEL_ESCALATE, isSensitive,
} from '../_shared/ai.ts';

// Per-user soft rate limit (Hard Rule #9): abuse/cost guard. Refer-out is exempt
// (safety always gets through) — only the LLM-generating path is limited.
const RATE_LIMIT_PER_HOUR = 40;
const RATE_LIMIT_MESSAGE =
  "You've asked a lot in the last hour — I love that you're so engaged! Let's take a "
  + "short breather and pick this back up in a little while. 💛";

// ai-chat (Task 14): RAG-grounded parenting Q&A.
//   1. require a valid JWT; verify the caller owns the child
//   2. refer-out classifier on EVERY turn (Hard Rule #7) — never diagnose
//   3. embed the question (Gemini) -> retrieve top-K vetted chunks (pgvector)
//   4. answer ONLY from those excerpts + established knowledge (Hard Rule #6),
//      via Mistral (Hard Rule #8/#9); cite the source cards
//   5. persist ai_conversations / ai_messages with cited_card_ids
//
// Privacy (Hard Rule #10 + COPPA): keys stay in this function; the child's NAME is
// never sent to the LLM — only age/temperament/struggles.
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
  let mode = 'qa';
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

    // Ownership + child context (NO name leaves this function).
    const child = await sql`
      select owner_id, age, temperament, struggles from children where id = ${childId}`;
    if (child.length === 0) return json(404, { ok: false, error: 'child not found' });
    if (child[0].owner_id !== user.id) return json(403, { ok: false, error: 'forbidden' });
    const { age, temperament, struggles } = child[0];

    // Reuse an owned conversation, else open a new one.
    if (conversationId) {
      const c = await sql`select user_id from ai_conversations where id = ${conversationId}`;
      if (c.length === 0 || c[0].user_id !== user.id) conversationId = null;
    }
    if (!conversationId) {
      const [c] = await sql`
        insert into ai_conversations (user_id, child_id, mode)
        values (${user.id}, ${childId}, ${mode}) returning id`;
      conversationId = c.id;
    }

    // Refer-out safety net (Hard Rule #7): short-circuit before any AI advice.
    const flagged = referOutReason(question);
    if (flagged) {
      await persist(sql, user.id, conversationId!, question, REFER_OUT_MESSAGE, [], flagged);
      log.info('ai_chat_refer_out', { duration_ms: Date.now() - startedAt });
      return json(200, { ok: true, conversation_id: conversationId, answer: REFER_OUT_MESSAGE, citations: [], flagged });
    }

    // Per-user rate limit (after refer-out, so safety is never blocked).
    const [{ count }] = await sql`
      select count(*)::int as count from ai_messages
      where owner_id = ${user.id} and role = 'user'
        and created_at > now() - interval '1 hour'`;
    if (count >= RATE_LIMIT_PER_HOUR) {
      log.warn('ai_chat_rate_limited', { count, duration_ms: Date.now() - startedAt });
      return json(200, { ok: true, conversation_id: conversationId, answer: RATE_LIMIT_MESSAGE, citations: [], flagged: null });
    }

    // Retrieve top-K vetted chunks.
    const emb = await embedQuery(question);
    const lit = `[${emb.join(',')}]`;
    const hits = await sql`
      select card_id, title, chunk, similarity
      from match_content_cards(${lit}::vector(768), 6)`;

    // Distinct cards (cited), and a context block for grounding.
    const seen = new Set<string>();
    const citations: { card_id: string; title: string }[] = [];
    for (const h of hits) {
      if (!seen.has(h.card_id)) { seen.add(h.card_id); citations.push({ card_id: h.card_id, title: h.title }); }
    }
    const topCitations = citations.slice(0, 3);
    const excerpts = hits.map((h: { title: string; chunk: string }, i: number) =>
      `[${i + 1}] (${h.title})\n${h.chunk}`).join('\n\n');

    const childCtx =
      `Child context — age ${age}; temperament: ${fmt(temperament)}; working on: ${fmt(struggles)}.`;
    const grounding =
      `Use ONLY: (1) the excerpts below from vetted parenting guides, and (2) well-established, ` +
      `mainstream child-development knowledge. If the excerpts don't cover it and you're not ` +
      `confident, say so gently — never invent specifics. Never diagnose or give medical advice; ` +
      `suggest a professional for those. No guilt or shame, never imply she's failing. Refer to ` +
      `the child as "your child" (never use a name).`;

    const system = mode === 'situational'
      // In-the-moment: a SHORT calm script she can act on in the next minute (#9 short cap).
      ? `You are Momzo, helping a mother THROUGH a hard moment happening RIGHT NOW with her ` +
        `${age}-year-old. Give a brief, calm script: 2–4 concrete steps she can do or say in the ` +
        `next minute. Plain and warm, no preamble, under 90 words; end with ONE short reassuring ` +
        `line. ${grounding}\n\n${childCtx}\n\nEXCERPTS:\n${excerpts || '(none found)'}`
      : `You are Momzo, a warm, calm guide for the mother of a ${age}-year-old child. ${grounding} ` +
        `Warm and concrete, under 130 words.\n\n${childCtx}\n\nEXCERPTS:\n${excerpts || '(none found)'}`;

    // Cheap-by-default routing (Hard Rule #8): escalate only when retrieval is weak
    // or the topic is emotionally sensitive (Q&A only; situational stays short+cheap).
    const topSim = hits.length ? Math.max(...hits.map((h: { similarity: number }) => Number(h.similarity))) : 0;
    const escalate = mode === 'qa' && (topSim < 0.5 || isSensitive(question));
    const model = escalate ? MODEL_ESCALATE : MODEL_DEFAULT;

    const { text: answer, usage } = await mistralChat(
      [{ role: 'system', content: system }, { role: 'user', content: question }],
      { model, maxTokens: mode === 'situational' ? 280 : 450, temperature: 0.4 },
    );

    await persist(sql, user.id, conversationId!, question, answer, topCitations.map((c) => c.card_id), null);

    // Cost telemetry to ai_usage (Task 4) — PII-free; non-fatal so a metrics write
    // can never fail a user's answer. Feeds the ai_cost_summary view.
    try {
      await sql`
        insert into ai_usage (owner_id, conversation_id, mode, model, escalated, prompt_tokens, completion_tokens)
        values (${user.id}, ${conversationId}, ${mode}, ${model}, ${escalate},
                ${usage?.prompt_tokens ?? null}, ${usage?.completion_tokens ?? null})`;
    } catch (e) {
      log.warn('ai_usage_insert_failed', { message: String(e) });
    }

    // Cost-dashboard feed (Task 8): model + token usage, no PII.
    log.info('ai_chat_ok', {
      mode,
      model,
      escalated: escalate,
      top_similarity: Number(topSim.toFixed(3)),
      prompt_tokens: usage?.prompt_tokens ?? null,
      completion_tokens: usage?.completion_tokens ?? null,
      chunks: hits.length,
      cited: topCitations.length,
      duration_ms: Date.now() - startedAt,
    });
    return json(200, { ok: true, conversation_id: conversationId, answer, citations: topCitations, flagged: null, model });
  } catch (e) {
    log.error('ai_chat_error', { duration_ms: Date.now() - startedAt, message: String(e) });
    captureError(e, { fn: 'ai-chat' });
    return json(500, { ok: false });
  }
});

function fmt(arr: unknown): string {
  return Array.isArray(arr) && arr.length ? arr.join(', ') : 'not specified';
}

// Persist the user turn + the assistant turn (owner_id denormalized for RLS).
async function persist(
  sql: ReturnType<typeof db>,
  ownerId: string,
  conversationId: string,
  question: string,
  answer: string,
  citedCardIds: string[],
  flagged: string | null,
) {
  await sql`
    insert into ai_messages (owner_id, conversation_id, role, content)
    values (${ownerId}, ${conversationId}, 'user', ${question})`;
  const citedLit = `{${citedCardIds.join(',')}}`;
  await sql`
    insert into ai_messages (owner_id, conversation_id, role, content, cited_card_ids, flagged)
    values (${ownerId}, ${conversationId}, 'assistant', ${answer}, ${citedLit}::uuid[], ${flagged})`;
}
