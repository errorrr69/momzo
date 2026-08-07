// Prompt-shape guarantees.
//
// prompts.ts has referred to this file since it was written; these are the
// assertions it was promising. Two separate concerns are pinned here:
//
//   1. CACHING — the static prefix must stay byte-identical for every user, or
//      Layer 2 of the cost strategy quietly stops working and input tokens bill
//      at full rate for everyone.
//
//   2. ANSWER SHAPE — the format rules must keep permitting a list when the
//      question is genuinely a list. v2 forbade bullets outright ("no
//      bullet-point dumps"), which read as a tidy instruction and produced a
//      real bug: "give me some maths activities" came back as one dense
//      paragraph with four separate activities buried inside it. The fix is
//      conditional, so it is easy to "simplify" back into an absolute ban.
//      These tests exist to stop that.
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { STATIC_PREFIX, PROMPT_VERSION, promptCacheKey, buildPrompt } from './prompts.ts';

/// The prefix is hard-wrapped for readability, so a phrase we assert on may be
/// split across lines. Match against a single-spaced copy: we care that the rule
/// is present, not how it happens to be wrapped today.
const flat = (s: string) => s.replace(/\s+/g, ' ');
const PREFIXES = Object.entries(STATIC_PREFIX).map(([mode, p]) => [mode, flat(p)] as const);

Deno.test('a list is permitted when the question asks for several things', () => {
  for (const [mode, prefix] of PREFIXES) {
    assert(
      /one item per line/i.test(prefix),
      `${mode}: the prefix no longer explains how to lay out a list`,
    );
    assert(
      /- "/.test(prefix),
      `${mode}: the prefix no longer specifies the "- " item marker`,
    );
    assert(
      !/no bullet[- ]point dumps/i.test(prefix),
      `${mode}: the blanket bullet ban is back — this is the v2 bug that flattened `
        + `"give me some maths activities" into one paragraph`,
    );
  }
});

Deno.test('prose stays the default, and lists stay off emotional questions', () => {
  for (const [mode, prefix] of PREFIXES) {
    assert(
      /DEFAULT: warm, flowing prose/i.test(prefix),
      `${mode}: prose is no longer the default — every answer will become a menu`,
    );
    assert(
      /ONE idea, explained kindly/i.test(prefix),
      `${mode}: nothing stops a one-idea answer being padded into a list`,
    );
    assert(
      /describes a problem, a worry, or something that just happened, answer with ONE idea/i.test(prefix),
      `${mode}: a parent describing a hard moment could now be answered with a menu`,
    );
    assert(
      /EXPLICITLY asked for several things/i.test(prefix),
      `${mode}: the list trigger is no longer "she asked for several" — the model `
        + `will decide for itself and turn every answer into a list`,
    );
  }
});

Deno.test('plain text only — both clients render text, not markdown', () => {
  // The Flutter app draws answers in a Text widget and the website in a
  // white-space:pre-wrap bubble. Neither parses markdown, so "**bold**" would
  // reach the parent with the asterisks showing.
  for (const [mode, prefix] of PREFIXES) {
    assert(/no markdown headings/i.test(prefix), `${mode}: markdown headings are no longer forbidden`);
    assert(/\*\*bold\*\*/.test(prefix), `${mode}: bold markdown is no longer forbidden`);
    assert(/no numbered lists/i.test(prefix), `${mode}: numbered lists are no longer forbidden`);
  }
});

Deno.test('the cache key is versioned, so a format change invalidates cleanly', () => {
  assertEquals(promptCacheKey('qa'), `momzo-qa-${PROMPT_VERSION}`);
  assertEquals(promptCacheKey('situational'), `momzo-situational-${PROMPT_VERSION}`);
  // The two modes must never share a key: their prefixes differ, so a shared key
  // would have the provider serving one mode's cached blocks to the other.
  assert(promptCacheKey('qa') !== promptCacheKey('situational'));
});

Deno.test('answer-shape rules live ABOVE the cache boundary', () => {
  // Format guidance is identical for every parent, so it belongs in the cached
  // prefix. Slipping it into the variable block would make every request pay
  // full price for tokens that never change.
  const built = buildPrompt('qa', {
    childContext: 'Child: age 7.',
    excerpts: 'some excerpt',
    question: 'can you give me some maths activities',
  });
  assertEquals(built.messages.length, 2);
  assert(/one item per line/i.test(flat(built.messages[0].content)), 'shape rules must be in the cached prefix');
  assert(!/one item per line/i.test(flat(built.messages[1].content)), 'shape rules leaked into the per-request block');
});
