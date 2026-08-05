// Momzo "lesson forge" — turns raw source articles into ORIGINAL, structured,
// mom-readable lessons following the Momzo lesson skeleton (docs: "lessons structure.txt").
//
// Build-time generation, NOT runtime: the app just renders fields, so reads are
// instant and free. Every word is ours — the source article only decides WHICH
// ideas a lesson covers (facts/ideas aren't copyrightable; expression is).
//
// Per-age variants: each source yields one lesson per age band, because advice
// for a 6-year-old and a 10-year-old needs different words and examples.
//
// Usage:
//   node forge_lessons.mjs --pilot                 # the 8-article pilot set
//   node forge_lessons.mjs --file "<path>"         # one source
//   node forge_lessons.mjs --all                   # every non-book source
//   env: FORGE_MODEL (default gemini-2.5-flash), OUT_DIR
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync } from 'node:fs';
import { join, extname, basename } from 'node:path';

function parseEnv(p) {
  const o = {};
  let t; try { t = readFileSync(p, 'utf8'); } catch { return o; }
  for (const r of t.split(/\r?\n/)) {
    const l = r.trim(); if (!l || l.startsWith('#')) continue;
    const e = l.indexOf('='); if (e === -1) continue;
    let v = l.slice(e + 1).trim();
    if (v.startsWith('"')) v = v.slice(1, v.indexOf('"', 1));
    o[l.slice(0, e).trim()] = v;
  }
  return o;
}
const env = parseEnv('D:/momzo/supabase/.env');
const GKEY = env.GOOGLE_API_KEY;
const MODEL = process.env.FORGE_MODEL || 'gemini-2.5-flash';
const OUT_DIR = process.env.OUT_DIR || 'D:/momzo/planning/lesson-drafts';
const REPO = 'D:/momzo';

// Age bands. Momzo is positioned for 6-10; a 6-year-old and a 10-year-old need
// genuinely different examples, so each source produces one lesson per band.
const AGE_BANDS = [
  { key: '6-7', min: 6, max: 7, note: 'Just started school. Concrete thinkers. Big feelings arrive fast and physically. Still very much wants your approval and closeness.' },
  { key: '8-10', min: 8, max: 10, note: 'More logical and able to reason about fairness. Friendships and being embarrassed matter enormously. Starting to want privacy and independence, and can talk things through.' },
];

// The pilot set — deliberately spread across categories so the voice gets tested
// on behaviour, emotions, screens, social friction and self-worth.
const PILOT = [
  'knowledge base/behaviour-/behaviour/why kids lie - tips to stop it.txt',
  'knowledge base/behaviour-/behaviour/why kids act out.txt',
  'knowledge base/behaviour-/behaviour/tantrums vs meltdowns.txt',
  'knowledge base/behaviour-/behaviour/why kids have problems with transition.txt',
  'knowledge base/behaviour-/behaviour/is it tattling or telling.txt',
  'knowledge base/emotional development 2/emotional development (1)/Understanding Anger.txt',
  'knowledge base/emotional development/emotional development/Building Blocks for Healthy Self Esteem.txt',
  'knowledge base/Preschoolers (4-7)/digital-world-and-kids/kids-and-screen-time-the-5cs-of-screen-time.md',
];

const SCHEMA = {
  type: 'object',
  required: ['title', 'tldr', 'scene', 'whats_going_on', 'skip_these', 'try_this',
    'activity', 'remember', 'full_read', 'problem_tags', 'mother_need_tags', 'minutes'],
  properties: {
    title: { type: 'string', description: 'A MOMENT in her words, not a topic label. Max 60 chars.' },
    tldr: { type: 'string', description: 'The 30-second version: the ENTIRE lesson in 2-3 short sentences, 45-70 words. Open with the specific insight, never with a generic opener like "Kids sometimes..." or "It is normal for children to...". State what is really going on, then what to do about it.' },
    scene: { type: 'array', minItems: 3, maxItems: 3, items: { type: 'string' },
      description: 'ONE single recognisable moment told in 3 short beats. Beat 1: what the child does/says (use a real quote). Beat 2: what she notices or knows. Beat 3: the bind she is in — two bad options. NOT a list of separate examples.' },
    whats_going_on: { type: 'array', minItems: 2, maxItems: 3, items: { type: 'string' },
      description: 'Max 3 short points on what is really happening. One sentence each.' },
    skip_these: { type: 'array', minItems: 2, maxItems: 4, items: { type: 'string' }, description: 'What not to do. Short phrases, not lectures.' },
    try_this: { type: 'array', minItems: 2, maxItems: 4, items: { type: 'string' }, description: 'What to do instead. Include at least one exact sentence she can say, in quotes.' },
    activity: {
      type: 'object', required: ['name', 'steps', 'why_it_works'],
      properties: {
        name: { type: 'string', description: 'A short, warm, named ritual, e.g. "The Real Win".' },
        steps: { type: 'array', minItems: 2, maxItems: 4, items: { type: 'string' } },
        why_it_works: { type: 'string', description: 'ONE sentence.' },
      },
    },
    remember: { type: 'string', description: 'A REFRAME that corrects what she probably thinks is happening — it must change how she reads her child\'s behaviour, and must NOT encourage or compliment her parenting. Under 20 words. VARY THE SHAPE: do not always use "They\'re not X, they\'re Y". Other good shapes: a single sharp observation ("The shouting is the last step, not the first."); naming the real need ("What he wants is for you to stay."); or speaking to her directly ("You are not failing at bedtime. Bedtime is just hard."). Use natural contractions (they\'re, don\'t, isn\'t) — never stiff "they are not".' },
    full_read: { type: 'string', description: 'The optional deeper read for a mother who wants more: 300-450 words of ORIGINAL plain prose in 3-5 short paragraphs, separated by blank lines. No headings, no bullet points, no invented statistics, no named experts.' },
    problem_tags: { type: 'array', items: { type: 'string' }, description: "Lowercase kebab-case problems this solves, e.g. 'lying','back-talk','sibling-fights','bedtime-battles'." },
    mother_need_tags: { type: 'array', items: { type: 'string' }, description: "Lowercase kebab-case, what the MOTHER needs, e.g. 'losing-my-temper','feeling-guilty','no-time','being-ignored'." },
    minutes: { type: 'integer', description: 'Honest read time for the structured part: 2, 3 or 4.' },
  },
};

// The gold standard: the exact form we want, written by hand. Given as FORM only.
const GOLD = `TITLE: When your child tells a story that definitely didn't happen

THE 30-SECOND VERSION:
Kids who brag or make up glory stories usually aren't lying at you — they're trying to feel impressive. Don't correct it harshly, and don't feed it with lots of questions. Stay warm, gently steer back to something real, and build up the true stuff instead.

SOUND FAMILIAR?
Your six-year-old comes home buzzing. "I scored the winning goal and the whole class carried me around!"
You know there wasn't a game today.
So you're stuck between two bad options: call it out ("that's not true") and watch their face fall — or play along with a pile of follow-up questions you both know are pretend.

WHAT'S ACTUALLY GOING ON
It's usually not about deceiving you. It's a bid to be admired.
These stories often come from feeling small. The story is the child they wish they were.
It's a different thing from lying to hide a mistake — that's a fear problem, and it needs a different response.

SKIP THESE
Calling it a lie, especially sharply
Piling on follow-up questions (that's attention — you're accidentally rewarding it)
Punishing it. This kind of story isn't hurting anyone

TRY THIS INSTEAD
Stay warm, don't make a thing of it
Gently steer to something real: "Sounds like a fun day — what did you actually play at break?"
Take the hint. They want to feel impressive to you. Give them that somewhere real.

TRY TONIGHT: "The Real Win"
At bedtime, you each share one true thing you were proud of today. You go first — and pick something small and ordinary on purpose: "I got through a hard email I'd been putting off."
Then them. If they reach for a big made-up one, nudge gently: "What's a small real one?"
WHY IT WORKS: it teaches that ordinary, true things are worth being proud of — so they stop needing to invent enormous ones to feel worthy of your attention.

REMEMBER: They're not lying to fool you. They're reaching for you.`;

const SYSTEM = `You write lessons for Momzo, an app for mothers. Your reader is tired, standing in a kitchen, on her phone, with about three minutes.

THE ONE RULE THAT MATTERS MOST: give her the whole lesson in the first three lines. She must be able to stop reading after 15 seconds and still have gotten something real and usable.

ABSOLUTE RULES:
1. ORIGINAL WORDING ONLY. The source article tells you WHICH ideas to cover. Every sentence is yours. Never copy phrasing or sentence structure. Never name or quote experts, clinicians, doctors, studies, institutions or publications. Never invent statistics. Strip every image caption, photo description, web menu, byline and "read more" fragment out of the source — those are scraping artifacts, not content.
2. Warm, plain, direct. Short sentences. No jargon, no clinical or diagnostic language, no therapy-speak ("hold space", "validate their experience"). Write like a wise, unshockable friend — never like a textbook or a parenting expert on stage.
3. NEVER shame the mother. No "many parents make the mistake of". Assume she is doing her best in a hard job. No guilt, ever.
4. Be concrete. Real quotes she'd actually say out loud. Real moments from family life — shoes, homework, the car, bedtime, the dinner table.
5. Never diagnose. Never imply a child has a disorder. If something genuinely warrants outside help, mention it once, plainly and calmly.
6. No cliches: not "every child is different", not "trust your instincts", not "this too shall pass", not "it's a journey not a destination".
7. BANNED PHRASES — never write any of these, or anything like them: "makes all the difference", "one step/breath at a time", "brick by brick", "will last a lifetime", "navigate their inner world", "strongest bridge", "find their voice", "be their safe place", "equipping them with skills". These are greeting-card filler. Every closing line must say something specific and true about THIS behaviour, not something warm and general about parenting.
8. Never compliment or reassure the mother about her parenting. She wants to understand her child, not be praised.
9. Write with natural contractions throughout — "they're", "don't", "isn't", "you'll". Never the stiff full forms ("they are not", "do not", "it is") except for deliberate emphasis. She should hear a voice, not a document.

FORM: copy the SHAPE of the gold-standard example exactly — its rhythm, its brevity, its use of real quoted speech. Do NOT copy its content or reuse its scenario unless the source is genuinely about the same thing.`;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function gen(prompt, tries = 6) {
  for (let i = 0; i < tries; i++) {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GKEY}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: 'application/json', responseSchema: SCHEMA, temperature: 0.8 },
        }) });
    if (res.status === 429 || res.status >= 500) { await sleep(8000 * (i + 1)); continue; }
    const j = await res.json();
    if (!res.ok) throw new Error(`${res.status} ${JSON.stringify(j).slice(0, 300)}`);
    const txt = j.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!txt) { await sleep(4000); continue; }
    return JSON.parse(txt);
  }
  throw new Error('generation failed after retries');
}

function cleanSource(raw) {
  // Drop obvious scraping artifacts before the model ever sees them.
  return raw.split(/\r?\n/)
    .filter((l) => {
      const t = l.trim();
      if (!t) return true;
      if (/^(A|An|The)\s+(joyful|smiling|young|little|happy|group of|mother|father|woman|man|boy|girl|child|toddler|pregnant)\b.*\.$/i.test(t)) return false; // image alt-text
      if (/^(Read more|Click here|Subscribe|Related:|Photo:|Advertisement|Share this|Last Updated|Print|Email)/i.test(t)) return false;
      if (/^https?:\/\//.test(t)) return false;
      return true;
    })
    .join('\n')
    .slice(0, 14000);
}

async function forge(relPath, band) {
  const raw = readFileSync(join(REPO, relPath), 'utf8');
  const src = cleanSource(raw);
  const prompt = `${SYSTEM}

=== GOLD-STANDARD EXAMPLE (copy this FORM, not this content) ===
${GOLD}
=== END EXAMPLE ===

WRITE FOR THIS CHILD: a ${band.key} year old.
What that age is like: ${band.note}
Every example, quote and activity must fit a ${band.key} year old specifically. Do not write generically for "children".

SOURCE MATERIAL — use it only to decide which ideas the lesson covers. Do not copy any of its wording:
"""
${src}
"""

Write one Momzo lesson.`;
  const out = await gen(prompt);
  return { ...out, age_min: band.min, age_max: band.max, age_band: band.key, source_path: relPath };
}

// ---- main ----
const args = process.argv.slice(2);
let sources = [];
if (args.includes('--pilot')) sources = PILOT;
else if (args.includes('--file')) sources = [args[args.indexOf('--file') + 1].replace(/\\/g, '/').replace(`${REPO}/`, '')];
else if (args.includes('--all')) {
  const walk = (d) => readdirSync(d).flatMap((n) => {
    const p = join(d, n);
    if (statSync(p).isDirectory()) return /books|activities|questions|mini-games/i.test(n) ? [] : walk(p);
    return ['.md', '.txt'].includes(extname(p).toLowerCase()) ? [p.replace(/\\/g, '/').replace(`${REPO}/`, '')] : [];
  });
  sources = walk(join(REPO, 'knowledge base'));
} else { console.error('need --pilot | --file <path> | --all'); process.exit(1); }

// Batch a slice of the source list (SLICE="start,end") so long runs can be done in
// foreground-safe chunks without losing completed work — every lesson is written
// to its own file as it lands, so re-running only redoes what's missing.
if (process.env.SLICE) {
  const [a, b] = process.env.SLICE.split(',').map(Number);
  sources = sources.slice(a, b);
}
if (process.env.SKIP_EXISTING === '1') {
  sources = sources.filter((rel) => !AGE_BANDS.every((band) => {
    const f = `${basename(rel).replace(/\.(md|txt)$/i, '').toLowerCase().replace(/[^a-z0-9]+/g, '-')}--${band.key}.json`;
    try { statSync(join(OUT_DIR, f)); return true; } catch { return false; }
  }));
}

mkdirSync(OUT_DIR, { recursive: true });
console.log(`Forging ${sources.length} source(s) x ${AGE_BANDS.length} age band(s) with ${MODEL}\n`);

const results = [];
for (const rel of sources) {
  for (const band of AGE_BANDS) {
    const label = `${basename(rel).replace(/\.(md|txt)$/i, '')} [${band.key}]`;
    try {
      const lesson = await forge(rel, band);
      results.push(lesson);
      const fname = `${basename(rel).replace(/\.(md|txt)$/i, '').toLowerCase().replace(/[^a-z0-9]+/g, '-')}--${band.key}.json`;
      writeFileSync(join(OUT_DIR, fname), JSON.stringify(lesson, null, 2));
      console.log(`✓ ${label}\n    "${lesson.title}"`);
    } catch (e) {
      console.log(`✗ ${label}: ${e.message}`);
    }
    await sleep(2500); // free-tier friendly
  }
}
writeFileSync(join(OUT_DIR, '_all.json'), JSON.stringify(results, null, 2));
console.log(`\nDone. ${results.length} lesson(s) -> ${OUT_DIR}`);
