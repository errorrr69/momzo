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

export interface ChatResult { text: string; usage: { prompt_tokens?: number; completion_tokens?: number; total_tokens?: number } | null }

export async function mistralChat(
  messages: ChatMsg[],
  opts: { model?: string; maxTokens?: number; temperature?: number } = {},
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
    }),
  });
  if (!res.ok) throw new Error(`mistral failed: ${res.status}`);
  const j = await res.json();
  return { text: (j.choices?.[0]?.message?.content ?? '').trim(), usage: j.usage ?? null };
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
const REFER_OUT: Record<string, RegExp[]> = {
  // (a) child-safety / self-harm / abuse
  safety: [
    // self-harm / suicidal ideation — incl. third-person and "doesn't want to be here"
    /suicid|kill (my|him|her|them)self|end (my|his|her|their) life|self[-\s]?harm|hurt (him|her|them|my)self|cutting (him|her|my)self|harm (him|her|them)self|want(s|ing)? to (die|disappear)|(does ?n'?t|do ?n'?t|doesnt|dont|not) want(ing)? to (be here|live|be alive)|wish(es|ed)? (he|she|they|i) (was|were)n'?t (here|alive|born)|better off (without|dead)/i,
    // abuse: named terms
    /\b(abuse|abused|abusing|molest|sexually|neglect|shaken baby|hitting (his|her|the) head)\b/i,
    // abuse: an adult described hitting/beating the child
    /\b(i|we|my (partner|husband|wife|boyfriend|girlfriend|mom|mum|mother|dad|father|stepdad|stepmom|in[- ]?law)) (hit|hits|hitting|beat|beats|beating|slap|slaps|spank|spanks|punch|punches|whip|whips|hurt|hurts) (him|her|them|the (kid|child|baby|boy|girl))\b/i,
  ],
  // (b) medical emergency / clinical
  medical: [
    /not breathing|won'?t wake|unconscious|seizure|convuls|overdose|swallowed (a|some|something)|poison|bleeding (a lot|badly|heavily)|high fever|won'?t stop (crying|vomiting)|emergency|chok(e|ing)/i,
    /\b(medication|dosage|how much (medicine|tylenol|ibuprofen)|prescri|antibiotic)\b/i,
  ],
  // (c) clinical / developmental concern (seeking a diagnosis) — NOT casual "is this normal"
  developmental: [
    /\b(autis|asperger|adhd|on the spectrum|bipolar|ocd|disorder|developmental delay|speech delay|global delay|regress|not (talk|speak|walk)ing at all|isn'?t (talking|speaking|walking) (yet|at all)|behind on (his|her|their)? ?(milestones|development)|should i (be )?(worried|concerned) (that|about|he|she)|something (is )?wrong with (him|her|my))/i,
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
