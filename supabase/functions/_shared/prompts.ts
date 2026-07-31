// Prompt assembly for the AI expert (Cost Strategy §3, Layer 2 — prompt caching).
//
// Caching works on an EXACT TOKEN PREFIX match, so the prompt is assembled
// most-static -> most-variable:
//
//   1. system prompt            }
//   2. safety / refer-out rules } identical for every user, every request  <- CACHED
//   3. response format rules    }
//   ---------------- cache boundary ----------------
//   4. RAG excerpts             (varies by question)
//   5. personalization context  (varies by child — age/traits, NEVER the name)
//   6. the user's question      (varies)
//
// Everything above the boundary lives in STATIC_PREFIX and is byte-identical
// across users — asserted by prompts_test.ts. Nothing per-user may EVER be
// interpolated into it: one child's age in the prefix kills caching for everyone.
//
// Changing a prefix invalidates the cache globally, so it is versioned: bump
// PROMPT_VERSION in the same commit as any edit, deliberately.

export const PROMPT_VERSION = 'v1';

export type Mode = 'qa' | 'situational';

// --- shared blocks (2) safety and (3) response format -----------------------
// Kept as separate consts so an edit to one is visible in review, but they are
// concatenated into a single static string per mode.

const SAFETY_RULES =
  `SAFETY RULES (these override everything else):\n` +
  `- Never diagnose, never name a condition, never give medical or dosage advice.\n` +
  `- If anything hints at a safety, medical, or clinical-developmental concern, do not\n` +
  `  advise — warmly point the parent to their child's doctor or a qualified professional.\n` +
  `- Never suggest anything that could put a child at risk, and never anything punitive,\n` +
  `  shaming, or fear-based.\n` +
  `- Refer to the child only as "your child". You will never be given a name; do not ask\n` +
  `  for one and never invent one.\n`;

const FORMAT_RULES =
  `RESPONSE FORMAT:\n` +
  `- Ground your answer ONLY in (1) the EXCERPTS supplied below and (2) well-established,\n` +
  `  mainstream child-development knowledge. If the excerpts don't cover it and you are\n` +
  `  not confident, say so gently — never invent specifics.\n` +
  `- No preamble, no headings, no bullet-point dumps, no emoji spam.\n` +
  `- Plain, warm, everyday language a tired parent can act on.\n` +
  `- Never guilt, never shame, never imply she is failing.\n`;

const QA_ROLE =
  `You are Momzo, a warm, calm guide for a mother raising a young child (4–10).\n` +
  `You answer her parenting questions like a trusted friend who happens to know the\n` +
  `research: specific, kind, and short. Under 130 words.\n`;

const SITUATIONAL_ROLE =
  `You are Momzo, helping a mother THROUGH a hard moment that is happening RIGHT NOW.\n` +
  `Give a brief, calm script: 2–4 concrete things she can do or say in the next minute,\n` +
  `then ONE short reassuring line. Under 90 words.\n`;

/// The cached prefix. MUST NOT contain any per-user value.
export const STATIC_PREFIX: Record<Mode, string> = {
  qa: `${QA_ROLE}\n${SAFETY_RULES}\n${FORMAT_RULES}\n` +
    `The parent's CONTEXT (including the child's age) and the EXCERPTS follow in the\n` +
    `next message. Use them; do not repeat them back.\n`,
  situational: `${SITUATIONAL_ROLE}\n${SAFETY_RULES}\n${FORMAT_RULES}\n` +
    `The parent's CONTEXT (including the child's age) and the EXCERPTS follow in the\n` +
    `next message. Use them; do not repeat them back.\n`,
};

/// Stable per-mode cache key. Shared across ALL users on purpose — the prefix is
/// identical for everyone, so they should all hit the same cached blocks.
export function promptCacheKey(mode: Mode): string {
  return `momzo-${mode}-${PROMPT_VERSION}`;
}

/// Everything below the cache boundary, in one user message.
export function variableBlock(
  childContext: string,
  excerpts: string,
  question: string,
): string {
  return `CONTEXT:\n${childContext}\n\nEXCERPTS:\n${excerpts || '(none found)'}\n\n` +
    `QUESTION:\n${question}`;
}

export interface BuiltPrompt {
  messages: { role: 'system' | 'user'; content: string }[];
  cacheKey: string;
}

export function buildPrompt(
  mode: Mode,
  childContext: string,
  excerpts: string,
  question: string,
): BuiltPrompt {
  return {
    messages: [
      { role: 'system', content: STATIC_PREFIX[mode] },
      { role: 'user', content: variableBlock(childContext, excerpts, question) },
    ],
    cacheKey: promptCacheKey(mode),
  };
}
