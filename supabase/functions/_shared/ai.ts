// Shared AI helpers for Edge Functions (Hard Rule #10: keys live ONLY here).
//   * embeddings  -> Gemini gemini-embedding-001 @ 768d (matches content_embeddings)
//   * generation  -> Mistral chat completions (cheap-by-default routing, #8)
// The GOOGLE key has 0 generateContent quota, so generation runs on Mistral.

export async function embedQuery(text: string): Promise<number[]> {
  const key = Deno.env.get('GOOGLE_API_KEY');
  if (!key) throw new Error('GOOGLE_API_KEY not set');
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${key}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'models/gemini-embedding-001',
        content: { parts: [{ text }] },
        outputDimensionality: 768,
      }),
    },
  );
  if (!res.ok) throw new Error(`embed failed: ${res.status}`);
  const j = await res.json();
  return j.embedding.values as number[];
}

export interface ChatMsg { role: 'system' | 'user' | 'assistant'; content: string }

// Cheap-by-default routing (Hard Rule #8). Most turns use SMALL; only low-retrieval-
// confidence or emotionally-sensitive turns escalate to MEDIUM.
export const MODEL_DEFAULT = 'mistral-small-latest';
export const MODEL_ESCALATE = 'mistral-medium-latest';

/// Cosine similarity below which retrieval counts as WEAK: the corpus has
/// nothing squarely on this question, so the answer leans on the model's general
/// knowledge rather than our vetted material. Two things hang off this:
///   * the model escalates (a harder question deserves the better model), and
///   * we stop showing citations, because a card that matched this poorly did
///     not source the answer, and presenting it as though it did is a false
///     claim of grounding — the one thing a parenting app must not fake.
export const WEAK_RETRIEVAL = 0.5;

export interface ChatUsage {
  prompt_tokens?: number;
  completion_tokens?: number;
  total_tokens?: number;
  prompt_tokens_details?: { cached_tokens?: number };
}
export interface ChatResult {
  text: string;
  usage: ChatUsage | null;
  /// Provider-reported cached prefix tokens (Cost Strategy §3). Billed at 10% of
  /// the input rate. 0 or absent means the prefix cache missed.
  cachedTokens: number;
}

export async function mistralChat(
  messages: ChatMsg[],
  opts: { model?: string; maxTokens?: number; temperature?: number; cacheKey?: string } = {},
): Promise<ChatResult> {
  const key = Deno.env.get('MISTRAL_API_KEY');
  if (!key) throw new Error('MISTRAL_API_KEY not set');
  const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: opts.model ?? MODEL_DEFAULT,
      messages,
      max_tokens: opts.maxTokens ?? 450,           // cap tokens (Hard Rule #9)
      temperature: opts.temperature ?? 0.4,
      // Prompt caching (Cost Strategy §3, Layer 2). Mistral's prefix cache is
      // opt-in via a stable key; ours is per-mode and SHARED across users, since
      // the static prefix is byte-identical for everyone. Cached prefix tokens
      // bill at 10% of the input rate.
      ...(opts.cacheKey ? { prompt_cache_key: opts.cacheKey } : {}),
    }),
  });
  if (!res.ok) throw new Error(`mistral failed: ${res.status}`);
  const j = await res.json();
  const usage: ChatUsage | null = j.usage ?? null;
  return {
    text: (j.choices?.[0]?.message?.content ?? '').trim(),
    usage,
    cachedTokens: Number(usage?.prompt_tokens_details?.cached_tokens ?? 0) || 0,
  };
}

// Emotionally-heavy (but not refer-out) topics worth a more careful model.
const SENSITIVE = /\b(divorce|separat|grief|griev|died|death|passed away|funeral|bully|bullied|bullying|trauma|scared|terrified|panic|nightmare|moving (house|away)|new baby|deployment)\b/i;
export function isSensitive(q: string): boolean { return SENSITIVE.test(q); }

// Refer-out classifier (Hard Rules #7 / PRD §6.3): a deterministic safety net that
// runs on EVERY turn. On genuine safety / medical / clinical-developmental signals
// the app refers to a professional instead of advising or diagnosing. Tuned for
// high recall on real risk, but NOT on ordinary parenting questions ("is it normal
// that he's shy", "won't share") — those get a grounded answer. The system prompt
// is the softer second layer ("never diagnose").
// Every pattern here is pinned by a probe in safety_test.ts, in BOTH directions:
// a risk phrasing that must match, and a near-miss ordinary question that must
// not. Widen these freely, but add the probe first — the precision cases exist
// because an over-broad pattern silently turns Momzo into a wall of referrals.
const REFER_OUT: Record<string, RegExp[]> = {
  // (a) child-safety / self-harm / abuse
  safety: [
    // Suicidal ideation, named directly.
    /suicid|kill(s|ing)? (my|him|her|them)self|end(s|ing)? (my|his|her|their) life|self[-\s]?harm|harm (him|her|them)self/i,
    // Not wanting to be alive. Parents and children rarely say "suicidal" — this
    // is the phrasing that actually arrives.
    /(does ?n'?t|do ?n'?t|doesnt|dont|did ?n'?t|not) want(ing)? to (be here|live|be alive)|want(s|ing)? to (die|disappear)|wish(es|ed)? (he|she|they|i) (was|were)n'?t (here|alive|born)/i,
    // The commonest euphemism of all: sleep that doesn't end.
    /(never|not) wake up|sleep forever|go to sleep and never/i,
    // Burden ideation — "everyone would be happier without me".
    /better off (without (me|him|her|them|us)|dead)|(everyone|we|they|you|people) (would|'d) be (happier|better off)/i,
    // Cutting and other self-injury. Body parts are enumerated so "cutting her
    // hair" and "cutting his sandwich" stay ordinary questions.
    /cut(s|ting)? (him|her|them|my)self|cut(s|ting)? (his|her|their|my) (arm|arms|wrist|wrists|leg|legs|thigh|thighs|skin)|cuts? on (his|her|their|my) (arm|arms|wrist|wrists|leg|legs|thigh|thighs)|burn(s|ing)? (him|her|them|my)self/i,
    // Deliberate self-hurt only. Bare "hurt himself" is excluded on purpose:
    // "he fell off his bike and hurt himself" is a comfort question, not a crisis.
    /(want(s|ing)? to|trying to|tried to|threaten(s|ed|ing)? to|going to|plans? to) hurt (him|her|them|my)self/i,
    /hurt(s|ing)? (him|her|them|my)self (on purpose|deliberately|intentionally)|keeps? hurting (him|her|them|my)self/i,
    // abuse: named terms
    /\b(abuse|abused|abusing|molest|sexually|neglect(ed|ing)?|shaken baby|hitting (his|her|the) head)\b/i,
    // abuse: an adult described hitting/beating the child
    /\b(i|we|my (partner|husband|wife|boyfriend|girlfriend|mom|mum|mother|dad|father|stepdad|stepmom|in[- ]?law)) (hit|hits|hitting|beat|beats|beating|slap|slaps|spank|spanks|punch|punches|whip|whips|hurt|hurts) (him|her|them|the (kid|child|baby|boy|girl))\b/i,
  ],
  // (b) medical emergency / clinical
  medical: [
    /not breathing|won'?t wake|unconscious|seizure|convuls|overdose|swallowed (a|some|something)|poison|bleeding (a lot|badly|heavily)|high fever|won'?t stop (crying|vomiting)|emergency|chok(e|ing)/i,
    /\b(medication|dosage|how much (medicine|tylenol|ibuprofen)|prescri|antibiotic)\b/i,
  ],
  // (c) clinical / developmental concern (seeking a diagnosis) — NOT casual worry.
  // "Should I be worried that he's shy" used to land here and be refused; it is
  // the single most common shape of question Momzo exists to answer, so the
  // trigger is now a named clinical term rather than the word "worried".
  developmental: [
    /\b(autis|asperger|adhd|on the spectrum|bipolar|ocd|disorder|developmental delay|speech delay|global delay|regress|not (talk|speak|walk)ing at all|isn'?t (talking|speaking|walking) (yet|at all)|behind on (his|her|their)? ?(milestones|development)|something (is )?wrong with (him|her|my))/i,
  ],
};

// Returns the category ('safety' | 'medical' | 'developmental') or null.
export function referOutReason(question: string): string | null {
  for (const [category, patterns] of Object.entries(REFER_OUT)) {
    if (patterns.some((re) => re.test(question))) return category;
  }
  return null;
}

export const REFER_OUT_MESSAGE =
  "This sounds really important — and it's beyond what I can safely help with here. "
  + "Please reach out to your child's doctor or a qualified professional, who can give "
  + "you proper guidance. If anyone is in immediate danger, contact your local emergency "
  + "services right away. You're doing the right thing by paying attention to this.";
