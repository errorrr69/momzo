import { corsHeaders } from '../_shared/cors.ts';
import { db } from '../_shared/db.ts';
import { log } from '../_shared/log.ts';
import { captureError } from '../_shared/sentry.ts';
import { getUser } from '../_shared/auth.ts';
import { breakerState, isRateLimited, recordUsage, LIMIT_MESSAGE } from '../_shared/aicost.ts';

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
  'finish-the-sentence': {
    itemType: 'prompt',
    prompt: (band, n, excl) =>
      `Generate ${n} OPEN, POSITIVE sentence stems for a ${BAND[band]} to finish (exactly one blank "___" each). Never lead to a sad or negative answer. Respond JSON: {"items":[{"stem"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.stem ? norm(it.stem) : null,
    safe: (it) => String(it.stem),
    row: (it) => ({ stem: String(it.stem).includes('___') ? String(it.stem) : `${String(it.stem)} ___` }),
  },
  'emoji-decode': {
    itemType: 'emoji_puzzle',
    prompt: (band, n, excl) =>
      `Generate ${n} emoji puzzles for a ${BAND[band]}. ${band === 'A' ? 'EXACTLY ONE emoji each (no sequences).' : band === 'B' ? 'EXACTLY TWO emojis each.' : 'EXACTLY THREE emojis each.'} The answer must be a GENERIC everyday concept — NEVER a copyrighted title, character, brand, movie, or specific IP. Respond JSON: {"items":[{"emojis","answer","hint"}]} where hint is a gentle clue. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.answer ? norm(it.answer) : null,
    safe: (it) => `${it.answer} ${it.hint}`,
    row: (it) => ({ emojis: String(it.emojis), answer: String(it.answer), hint: String(it.hint ?? '') }),
  },
  'hot-seat': {
    itemType: 'question',
    prompt: (band, n, excl) =>
      `Generate ${n} rapid-fire "hot seat" questions for a ${BAND[band]}, each answerable in 1–3 seconds (favourites or this-or-that). Light and fun, no deep/reflective ones, no data-fishing. Respond JSON: {"items":[{"question"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.question ? norm(it.question) : null,
    safe: (it) => String(it.question),
    row: (it) => ({ question: String(it.question), quick: true }),
  },
  'time-machine': {
    itemType: 'pair',
    prompt: (band, n, excl) =>
      `Generate ${n} gentle prompt PAIRS for a ${BAND[band]} and their grown-up. Each pair: parentPrompt looks BACK to the grown-up's childhood, childPrompt looks FORWARD to the child growing up. Warm, never sad/loss. Respond JSON: {"items":[{"parentPrompt","childPrompt"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.parentPrompt && it.childPrompt ? `${norm(it.parentPrompt)}|${norm(it.childPrompt)}` : null,
    safe: (it) => `${it.parentPrompt} ${it.childPrompt}`,
    row: (it) => ({ parentPrompt: String(it.parentPrompt), childPrompt: String(it.childPrompt) }),
  },
  'memory-lane': {
    itemType: 'prompt',
    prompt: (band, n, excl) =>
      `Generate ${n} prompts pointing at POSITIVE shared memories for a ${BAND[band]} and their family. Open to any family shape/budget ("a time we laughed", not "a holiday"). Never a sad time or a time in trouble. Respond JSON: {"items":[{"prompt"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.prompt ? norm(it.prompt) : null,
    safe: (it) => String(it.prompt),
    row: (it) => ({ prompt: String(it.prompt) }),
  },
  'gratitude-swap': {
    itemType: 'prompt',
    prompt: (band, n, excl) =>
      `Generate ${n} warm prompts for a ${BAND[band]} and their grown-up to each share something they are GRATEFUL FOR ABOUT THE OTHER. Only warmth — never "something you'd change", never about appearance/looks. Bedtime-soft. Respond JSON: {"items":[{"prompt"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.prompt ? norm(it.prompt) : null,
    safe: (it) => String(it.prompt),
    row: (it) => ({ prompt: String(it.prompt) }),
  },
  'charades': {
    itemType: 'action',
    prompt: (band, n, excl) =>
      `Generate ${n} charades prompts a ${BAND[band]} can physically act out safely indoors (no jumping off things, no rough/scary actions). Each with one fitting emoji. Cheerful. Respond JSON: {"items":[{"actPrompt","emojiHint"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.actPrompt ? norm(it.actPrompt) : null,
    safe: (it) => String(it.actPrompt),
    row: (it) => ({ actPrompt: String(it.actPrompt), emojiHint: String(it.emojiHint ?? '🎭') }),
  },
  'drawing-telephone': {
    itemType: 'action',
    prompt: (band, n, excl) =>
      `Generate ${n} drawing prompts for a ${BAND[band]}: ${band === 'A' ? 'single concrete nouns (a cat, the sun)' : band === 'B' ? 'noun + adjective (a happy dog, a big tree)' : 'fun mini-scenes (a cat on a skateboard)'}. All drawable by a child, cheerful, never scary/complex. Respond JSON: {"items":[{"drawPrompt"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.drawPrompt ? norm(it.drawPrompt) : null,
    safe: (it) => String(it.drawPrompt),
    row: (it) => ({ drawPrompt: String(it.drawPrompt) }),
  },
  'simon-says': {
    itemType: 'action',
    prompt: (band, n, excl) =>
      `Generate ${n} simple, safe, indoor "Simon Says" body-action commands for a ${BAND[band]} (touch your nose, clap twice). No risky moves. Respond JSON: {"items":[{"command"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.command ? norm(it.command) : null,
    safe: (it) => String(it.command),
    row: (it) => ({ command: String(it.command), isSimonSays: true }),
  },
  'mirror-me': {
    itemType: 'action',
    prompt: (band, n, excl) =>
      `Generate ${n} gentle "starter move" ideas for a ${BAND[band]} to lead and have the other mirror (slow wave, big stretch). Safe, indoor, gentle. Respond JSON: {"items":[{"moveIdea"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.moveIdea ? norm(it.moveIdea) : null,
    safe: (it) => String(it.moveIdea),
    row: (it) => ({ moveIdea: String(it.moveIdea) }),
  },
  'guess-my-answer': {
    itemType: 'question',
    prompt: (band, n, excl) =>
      `Generate ${n} fun "predict what they'll say" questions for a ${BAND[band]} and their grown-up, where there is no wrong answer (opinions/choices/hypotheticals). Respond JSON: {"items":[{"question"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.question ? norm(it.question) : null,
    safe: (it) => String(it.question),
    row: (it) => ({ question: String(it.question), mode: 'open' }),
  },
  'story-builder': {
    itemType: 'story_seed',
    prompt: (band, n, excl) =>
      `Generate ${n} warm, funny, child-safe story STARTERS for a ${BAND[band]} (friendly animals/adventures, no peril/scary). Each a single opening line ending with "…". Respond JSON: {"items":[{"starter"}]}. Exclude (already used): ${excl.join(' | ')}`,
    key: (it) => it.starter ? norm(it.starter) : null,
    safe: (it) => String(it.starter),
    row: (it) => ({ starter: String(it.starter), twists: ['suddenly it started raining jelly!', 'a friendly dragon appeared', 'they found a magic door', 'everything turned upside down'] }),
  },
};

function norm(s: unknown): string {
  return String(s).toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();
}

const TOPUP_MODEL = 'mistral-small-latest';

interface GenResult {
  items: Record<string, unknown>[];
  promptTokens: number;
  completionTokens: number;
}

async function genItems(prompt: string): Promise<GenResult> {
  const empty: GenResult = { items: [], promptTokens: 0, completionTokens: 0 };
  const key = Deno.env.get('MISTRAL_API_KEY');
  if (!key) return empty;
  const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: TOPUP_MODEL,
      messages: [{ role: 'user', content: prompt }],
      response_format: { type: 'json_object' },
      max_tokens: 1600, // enough for ~20 items without truncating the JSON
      temperature: 0.8,
    }),
  });
  if (!res.ok) return empty;
  try {
    const j = await res.json();
    const obj = JSON.parse(j.choices?.[0]?.message?.content ?? '{}');
    const items = Array.isArray(obj.items) ? obj.items : (Array.isArray(obj) ? obj : []);
    return {
      items,
      promptTokens: Number(j.usage?.prompt_tokens ?? 0) || 0,
      completionTokens: Number(j.usage?.completion_tokens ?? 0) || 0,
    };
  } catch {
    return empty;
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
    // Attribute usage to the FAMILY (the child's owner), not the caller — the
    // top-up limit in Cost Strategy §4 is per family, and a coparent shares it.
    const familyId = child[0].owner_id as string;

    // Cost controls (Cost Strategy §4/§9). Bank top-ups are the most expendable
    // AI spend in the product: they are batched, globally shared, and a family
    // with an unexhausted bank never needs one. So they are also the FIRST thing
    // the budget breaker stops — at the soft threshold, before Q&A degrades.
    if (await isRateLimited(sql, familyId, 'game_items')) {
      await recordUsage(sql, { ownerId: familyId, mode: 'game_items', billable: false, rateLimited: true, latencyMs: Date.now() - startedAt });
      log.warn('game_topup_rate_limited', { game: gameSlug, band });
      return json(200, { ok: true, added: 0, generated: 0, limited: true, message: LIMIT_MESSAGE.game_items });
    }
    const breaker = await breakerState(sql);
    if (breaker !== 'ok') {
      await recordUsage(sql, { ownerId: familyId, mode: 'game_items', billable: false, breakerState: breaker, latencyMs: Date.now() - startedAt });
      log.warn('game_topup_breaker_skipped', { game: gameSlug, band, breaker });
      return json(200, { ok: true, added: 0, generated: 0, limited: true, message: LIMIT_MESSAGE.game_items });
    }

    const existing = await sql`
      select payload from game_items where game_slug = ${gameSlug} and band = ${band} and active = true`;
    const seen = new Set<string>();
    for (const e of existing) { const k = cfg.key(e.payload); if (k) seen.add(k); }

    // Always batched (Cost Strategy §2): ~20 items per call, written to the GLOBAL
    // bank. Never one item per play.
    const TARGET_ADD = 20;
    const inserted: Record<string, unknown>[] = [];
    let gen = 0;
    let promptTokens = 0;
    let completionTokens = 0;
    for (let round = 0; round < 3 && inserted.length < TARGET_ADD; round++) {
      const { items, promptTokens: pt, completionTokens: ct } =
        await genItems(cfg.prompt(band, TARGET_ADD, [...seen].slice(-40)));
      gen += items.length;
      promptTokens += pt;
      completionTokens += ct;
      for (const it of items) {
        const k = cfg.key(it);
        if (!k || seen.has(k)) continue;
        if (BLOCK.test(cfg.safe(it))) continue; // child-safety filter (§1.4)
        seen.add(k);
        const payload = cfg.row(it);
        await sql`
          insert into game_items (game_slug, band, item_type, payload, source)
          values (${gameSlug}, ${band}, ${cfg.itemType},
                  ${sql.json(payload as unknown as Parameters<typeof sql.json>[0])}, 'ai')`;
        inserted.push(payload);
        if (inserted.length >= TARGET_ADD) break;
      }
    }

    await recordUsage(sql, {
      ownerId: familyId,
      mode: 'game_items',
      model: TOPUP_MODEL,
      promptTokens,
      completionTokens,
      breakerState: breaker,
      latencyMs: Date.now() - startedAt,
    });

    log.info('game_topup_ok', {
      game: gameSlug, band, added: inserted.length, generated: gen,
      prompt_tokens: promptTokens, completion_tokens: completionTokens,
      duration_ms: Date.now() - startedAt,
    });
    return json(200, { ok: true, added: inserted.length, generated: gen });
  } catch (e) {
    log.error('game_topup_error', { duration_ms: Date.now() - startedAt, message: String(e) });
    captureError(e, { fn: 'generate-game-items' });
    return json(500, { ok: false });
  }
});
