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
//   6. personal memory          (notes + recent engagement; this family only)
//   7. conversation so far      (varies)
//   8. the user's question      (varies)
//
// Everything above the boundary lives in STATIC_PREFIX and is byte-identical
// across users — asserted by prompts_test.ts. Nothing per-user may EVER be
// interpolated into it: one child's age in the prefix kills caching for everyone.
//
// Changing a prefix invalidates the cache globally, so it is versioned: bump
// PROMPT_VERSION in the same commit as any edit, deliberately.

// v2: the prefix now describes the ABOUT THIS FAMILY and EARLIER IN THIS
// CONVERSATION sections. Bump this whenever a prefix changes — it invalidates the
// provider's cached blocks globally, so it must be a deliberate act.
export const PROMPT_VERSION = 'v2';

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

// How to use the sections that follow the cache boundary. Static for everyone —
// it describes the SHAPE of the input, never its content.
const INPUT_RULES =
  `THE NEXT MESSAGE contains, in order and each optional:\n` +
  `- CONTEXT: this child's age and profile. Use it; never repeat it back.\n` +
  `- ABOUT THIS FAMILY: the parent's own words about her child, and what she has\n` +
  `  actually been doing lately. Let it shape your answer. You may acknowledge her\n` +
  `  effort in passing, warmly — never as praise for compliance, never as a nudge to\n` +
  `  do more, never as a summary of her stats.\n` +
  `- EXCERPTS: vetted source material. Ground your answer in it.\n` +
  `- EARLIER IN THIS CONVERSATION: what was already said. Treat the new question as\n` +
  `  a continuation — resolve "that", "it" and "he" against it, and do not repeat\n` +
  `  advice you have already given. If she says something did not work, do not\n` +
  `  suggest it again.\n` +
  `- QUESTION: what to answer now.\n`;

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
  qa: `${QA_ROLE}\n${SAFETY_RULES}\n${FORMAT_RULES}\n${INPUT_RULES}`,
  situational: `${SITUATIONAL_ROLE}\n${SAFETY_RULES}\n${FORMAT_RULES}\n${INPUT_RULES}`,
};

/// Stable per-mode cache key. Shared across ALL users on purpose — the prefix is
/// identical for everyone, so they should all hit the same cached blocks.
export function promptCacheKey(mode: Mode): string {
  return `momzo-${mode}-${PROMPT_VERSION}`;
}

export interface VariableParts {
  childContext: string;
  excerpts: string;
  question: string;
  /// Tier B personal context (notes, recent engagement). See memory.ts.
  personalLines?: string[];
  /// The conversation so far, oldest first.
  history?: { role: 'user' | 'assistant'; content: string }[];
}

/// Everything below the cache boundary, in one user message.
///
/// The history is folded in as a transcript rather than sent as real alternating
/// chat turns, for two reasons: it keeps the message shape fixed at exactly two
/// messages (so the cached prefix is always message 0), and it sidesteps
/// providers that reject non-alternating roles.
export function variableBlock(p: VariableParts): string {
  const blocks: string[] = [`CONTEXT:\n${p.childContext}`];

  if (p.personalLines?.length) {
    blocks.push(`ABOUT THIS FAMILY:\n${p.personalLines.join('\n')}`);
  }

  blocks.push(`EXCERPTS:\n${p.excerpts || '(none found)'}`);

  if (p.history?.length) {
    const transcript = p.history
      .map((m) => `${m.role === 'assistant' ? 'Momzo' : 'Parent'}: ${m.content}`)
      .join('\n');
    blocks.push(`EARLIER IN THIS CONVERSATION:\n${transcript}`);
  }

  blocks.push(`QUESTION:\n${p.question}`);
  return blocks.join('\n\n');
}

export interface BuiltPrompt {
  messages: { role: 'system' | 'user'; content: string }[];
  cacheKey: string;
}

export function buildPrompt(mode: Mode, parts: VariableParts): BuiltPrompt {
  return {
    messages: [
      { role: 'system', content: STATIC_PREFIX[mode] },
      { role: 'user', content: variableBlock(parts) },
    ],
    cacheKey: promptCacheKey(mode),
  };
}
