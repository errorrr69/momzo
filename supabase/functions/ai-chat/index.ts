import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { getUser } from '../_shared/auth.ts';
import { embedQuery, mistralChat, referOutReason, REFER_OUT_MESSAGE } from '../_shared/ai.ts';

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
  try {
    const b = await req.json();
    question = (b?.question ?? '').toString().trim();
    childId = (b?.child_id ?? '').toString();
    conversationId = b?.conversation_id ?? null;
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
        values (${user.id}, ${childId}, 'qa') returning id`;
      conversationId = c.id;
    }

    // Refer-out safety net (Hard Rule #7): short-circuit before any AI advice.
    const flagged = referOutReason(question);
    if (flagged) {
      await persist(sql, user.id, conversationId!, question, REFER_OUT_MESSAGE, [], flagged);
      log.info('ai_chat_refer_out', { duration_ms: Date.now() - startedAt });
      return json(200, { ok: true, conversation_id: conversationId, answer: REFER_OUT_MESSAGE, citations: [], flagged });
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

    const system =
      `You are Momzo, a warm, calm guide for the mother of a ${age}-year-old child. ` +
      `Use ONLY: (1) the excerpts below from vetted parenting guides, and (2) well-established, ` +
      `mainstream child-development knowledge. If the excerpts don't cover it and you're not ` +
      `confident, say so gently — never invent specifics. Never diagnose or give medical advice; ` +
      `suggest a professional for those. Warm and concrete, under 130 words, no guilt or shame, ` +
      `never imply she's failing. Refer to the child as "your child" (never use a name).\n\n` +
      `Child context — age ${age}; temperament: ${fmt(temperament)}; working on: ${fmt(struggles)}.\n\n` +
      `EXCERPTS:\n${excerpts || '(none found)'}`;

    const answer = await mistralChat(
      [{ role: 'system', content: system }, { role: 'user', content: question }],
      { maxTokens: 450, temperature: 0.4 },
    );

    await persist(sql, user.id, conversationId!, question, answer, topCitations.map((c) => c.card_id), null);

    log.info('ai_chat_ok', {
      chunks: hits.length,
      cited: topCitations.length,
      duration_ms: Date.now() - startedAt,
    });
    return json(200, { ok: true, conversation_id: conversationId, answer, citations: topCitations, flagged: null });
  } catch (e) {
    log.error('ai_chat_error', { duration_ms: Date.now() - startedAt, message: String(e) });
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
