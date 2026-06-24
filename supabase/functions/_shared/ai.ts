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

export async function mistralChat(
  messages: ChatMsg[],
  opts: { model?: string; maxTokens?: number; temperature?: number } = {},
): Promise<string> {
  const key = Deno.env.get('MISTRAL_API_KEY');
  if (!key) throw new Error('MISTRAL_API_KEY not set');
  const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: opts.model ?? 'mistral-small-latest', // cheap default (Hard Rule #8)
      messages,
      max_tokens: opts.maxTokens ?? 450,           // cap tokens (Hard Rule #9)
      temperature: opts.temperature ?? 0.4,
    }),
  });
  if (!res.ok) throw new Error(`mistral failed: ${res.status}`);
  const j = await res.json();
  return (j.choices?.[0]?.message?.content ?? '').trim();
}

// Refer-out classifier (Hard Rule #7): a deterministic safety net for topics the
// app must NEVER advise on — route to professional help instead of an AI answer.
// Deliberately high-recall on genuine-risk language; nuance is handled by the
// system prompt ("never diagnose").
const REFER_OUT = [
  /suicid|kill (my|him|her|them)self|end (my|his|her) life|self[-\s]?harm|cutting (my|him|her)self/i,
  /\b(abuse|abused|molest|beat(s|en)? (him|her|them)|hitting (his|her) head)\b/i,
  /not breathing|won'?t wake|unconscious|seizure|overdose|swallowed|bleeding (a lot|badly)|emergency/i,
  /\b(diagnos|autis|adhd|bipolar|medication|dosage|prescri)/i,
];

export function referOutReason(question: string): string | null {
  for (const re of REFER_OUT) {
    if (re.test(question)) return 'refer_out';
  }
  return null;
}

export const REFER_OUT_MESSAGE =
  "This sounds really important — and it's beyond what I can safely help with here. "
  + "Please reach out to your child's doctor or a qualified professional, who can give "
  + "you proper guidance. If anyone is in immediate danger, contact your local emergency "
  + "services right away. You're doing the right thing by paying attention to this.";
