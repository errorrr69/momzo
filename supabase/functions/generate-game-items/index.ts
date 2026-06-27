import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { captureError } from '../_shared/sentry.ts';
import { getUser } from '../_shared/auth.ts';

// AI top-up for the mini-game banks (games spec §1.3.B). When a family has seen most
// of a game's bank, the app calls this to generate a fresh batch via Mistral. Items
// are child-safety filtered (§1.4) + de-duped, then written into the GLOBAL bank so
// every family reuses them (keeps Mistral cost near zero). Secrets stay server-side.

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

const BLOCK =
  /\b(die|died|death|dead|kill|kills|killed|blood|weapon|gun|knife|war|hate|hates|ugly|fat|stupid|dumb|idiot|scary|nightmare|drown|hurt|sick|hospital|divorce|money|rich|poor|prettiest|smartest|religion|god|sexy|kiss)\b/i;

const BAND: Record<string, string> = {
  A: '4–5 year old (very simple, concrete, everyday words)',
  B: '6–7 year old (simple, some feeling words, light imagination)',
  C: '8–10 year old (richer, can handle hypotheticals and "why")',
};

const GAMES: Record<string, {
  itemType: string;
  prompt: (band: string, n: number, excl: string[]) => string;
  key: (it: Record<string, unknown>) => string | null;
  safe: (it: Record<string, unknown>) => string;
  row: (it: Record<string, unknown>) => Record<string, unknown>;
}> = {
  'would-you-rather': {
    itemType: 'pair',
    prompt: (band, n, excl) =>
      `Generate ${n} fun "would you rather" pairs for a ${BAND[band]}. Both options must be APPEALING and SAFE — never fear, harm, losing a person/pet, scary, gross, or adult themes. Respond JSON: {"items":[{"optionA","emojiA","optionB","emojiB"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.optionA && it.optionB ? `${norm(it.optionA)}|${norm(it.optionB)}` : null,
    safe: (it) => `${it.optionA} ${it.optionB}`,
    row: (it) => ({ optionA: String(it.optionA), emojiA: String(it.emojiA ?? '✨'), optionB: String(it.optionB), emojiB: String(it.emojiB ?? '✨'), askWhy: false }),
  },
  'get-to-know-you': {
    itemType: 'question',
    prompt: (band, n, excl) =>
      `Generate ${n} warm "get to know you" questions for a ${BAND[band]}, answerable by BOTH parent and child. Categories: favourite, feeling, dream, us. No data-fishing (no address/school/location), nothing embarrassing or comparative. Respond JSON: {"items":[{"question","category"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.question ? norm(it.question) : null,
    safe: (it) => String(it.question),
    row: (it) => ({ question: String(it.question), category: ['favourite', 'feeling', 'dream', 'us'].includes(String(it.category)) ? it.category : 'us' }),
  },
};

function norm(s: unknown): string {
  return String(s).toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();
}

async function genItems(prompt: string): Promise<Record<string, unknown>[]> {
  const key = Deno.env.get('MISTRAL_API_KEY');
  if (!key) return [];
  const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: 'mistral-small-latest',
      messages: [{ role: 'user', content: prompt }],
      response_format: { type: 'json_object' },
      max_tokens: 1600, // enough for ~20 items without truncating the JSON
      temperature: 0.8,
    }),
  });
  if (!res.ok) return [];
  try {
    const obj = JSON.parse((await res.json()).choices?.[0]?.message?.content ?? '{}');
    return Array.isArray(obj.items) ? obj.items : (Array.isArray(obj) ? obj : []);
  } catch {
    return [];
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const startedAt = Date.now();
  const user = await getUser(req);
  if (!user) return json(401, { ok: false, error: 'unauthorized' });

  let gameSlug = '', childId = '';
  try {
    const b = await req.json();
    gameSlug = (b?.game_slug ?? '').toString();
    childId = (b?.child_id ?? '').toString();
  } catch { /* ignore */ }
  const cfg = GAMES[gameSlug];
  if (!cfg || !childId) return json(400, { ok: false, error: 'valid game_slug and child_id required' });

  try {
    const sql = db();
    const child = await sql`select owner_id, age from children where id = ${childId}`;
    if (child.length === 0) return json(404, { ok: false, error: 'child not found' });
    if (child[0].owner_id !== user.id) return json(403, { ok: false, error: 'forbidden' });
    const band = child[0].age <= 5 ? 'A' : (child[0].age <= 7 ? 'B' : 'C');

    const existing = await sql`
      select payload from game_items where game_slug = ${gameSlug} and band = ${band} and active = true`;
    const seen = new Set<string>();
    for (const e of existing) { const k = cfg.key(e.payload); if (k) seen.add(k); }

    const TARGET_ADD = 20;
    const inserted: Record<string, unknown>[] = [];
    let gen = 0;
    for (let round = 0; round < 3 && inserted.length < TARGET_ADD; round++) {
      const items = await genItems(cfg.prompt(band, TARGET_ADD, [...seen].slice(-40)));
      gen += items.length;
      for (const it of items) {
        const k = cfg.key(it);
        if (!k || seen.has(k)) continue;
        if (BLOCK.test(cfg.safe(it))) continue; // child-safety filter (§1.4)
        seen.add(k);
        const payload = cfg.row(it);
        await sql`
          insert into game_items (game_slug, band, item_type, payload, source)
          values (${gameSlug}, ${band}, ${cfg.itemType}, ${JSON.stringify(payload)}::jsonb, 'ai')`;
        inserted.push(payload);
        if (inserted.length >= TARGET_ADD) break;
      }
    }

    log.info('game_topup_ok', { game: gameSlug, band, added: inserted.length, generated: gen, duration_ms: Date.now() - startedAt });
    return json(200, { ok: true, added: inserted.length, generated: gen });
  } catch (e) {
    log.error('game_topup_error', { duration_ms: Date.now() - startedAt, message: String(e) });
    captureError(e, { fn: 'generate-game-items' });
    return json(500, { ok: false });
  }
});
