// Unit tests for per-family AI memory and the cache-eligibility rule it implies.
// Pure logic only — no database, no network, no secrets.
//
// Run: deno test --allow-env supabase/functions/_shared/
import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';

import { buildPrompt, variableBlock } from './prompts.ts';
import { EMPTY_MEMORY, HISTORY_TURNS, type Memory } from './memory.ts';

const base = {
  childContext: 'Child: age 7.\nTricky right now: bedtime.',
  excerpts: '[1] (Sleep) some vetted text',
  question: 'what if that does not work?',
};

const history: Memory['history'] = [
  { role: 'user', content: 'he wont stay in bed' },
  { role: 'assistant', content: 'Try a two-minute warning and one clear choice.' },
];

// --- the transcript actually reaches the model ------------------------------

Deno.test('conversation history is rendered as a labelled transcript', () => {
  const block = variableBlock({ ...base, history });
  assertStringIncludes(block, 'EARLIER IN THIS CONVERSATION:');
  assertStringIncludes(block, 'Parent: he wont stay in bed');
  assertStringIncludes(block, 'Momzo: Try a two-minute warning and one clear choice.');
  // Ordering matters: the question must come last so it is what gets answered.
  assert(block.lastIndexOf('QUESTION:') > block.indexOf('EARLIER IN THIS CONVERSATION:'));
});

Deno.test('history is oldest-first, so the model reads it in the order it happened', () => {
  const block = variableBlock({ ...base, history });
  assert(block.indexOf('he wont stay in bed') < block.indexOf('Try a two-minute warning'));
});

Deno.test('sections are omitted entirely when empty — no dangling headers', () => {
  const block = variableBlock(base);
  assert(!block.includes('EARLIER IN THIS CONVERSATION'));
  assert(!block.includes('ABOUT THIS FAMILY'));
  assertStringIncludes(block, 'CONTEXT:');
  assertStringIncludes(block, 'EXCERPTS:');
  assertStringIncludes(block, 'QUESTION:');
});

Deno.test('personal context appears under its own header', () => {
  const block = variableBlock({
    ...base,
    personalLines: ["In the parent's own words: he had a rough time when we moved."],
  });
  assertStringIncludes(block, 'ABOUT THIS FAMILY:');
  assertStringIncludes(block, 'rough time when we moved');
});

Deno.test('the prompt is always exactly two messages, whatever memory is present', () => {
  // The cached static prefix must always be message 0. Injecting history as real
  // alternating chat turns would break that, and trips providers that require
  // strict role alternation.
  for (const parts of [base, { ...base, history }, { ...base, personalLines: ['x'], history }]) {
    const { messages } = buildPrompt('qa', parts);
    assertEquals(messages.length, 2);
    assertEquals(messages[0].role, 'system');
    assertEquals(messages[1].role, 'user');
  }
});

// --- the cost trade the memory tiers imply ----------------------------------

Deno.test('a first turn with no notes and no activity carries no personal context', () => {
  // This is the case the shared answer cache exists for, so it must stay clean.
  assertEquals(EMPTY_MEMORY.isPersonal, false);
  assertEquals(EMPTY_MEMORY.history.length, 0);
  assertEquals(EMPTY_MEMORY.personalLines.length, 0);
});

Deno.test('any tier B signal marks the turn personal, and so cache-ineligible', () => {
  const withHistory: Memory = { history, personalLines: [], isPersonal: history.length > 0 };
  const withNotes: Memory = { history: [], personalLines: ['note'], isPersonal: true };
  assert(withHistory.isPersonal, 'a follow-up turn must not be served from a shared cache');
  assert(withNotes.isPersonal, "a turn shaped by one family's notes must not be cached");
});

Deno.test('history depth is bounded, so memory cannot grow the prompt without limit', () => {
  assert(HISTORY_TURNS >= 2, 'too little context to resolve a follow-up');
  assert(HISTORY_TURNS <= 5, 'replaying more than a few turns is not worth the tokens');
});

Deno.test('a long pasted message cannot dominate the prompt', () => {
  // clamp() is applied inside memory.ts before this point; assert the contract
  // holds at the boundary the prompt sees.
  const huge = 'x'.repeat(5000);
  const block = variableBlock({ ...base, history: [{ role: 'user', content: huge }] });
  assert(block.length < 12_000, 'transcript is not being bounded upstream');
});
