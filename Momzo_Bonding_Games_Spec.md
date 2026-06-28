# Momzo — Together & Bonding Games

### AI Rulebook & Content Spec

**Version:** v1.0 · June 2026
**For:** Claude Code (build) · **Companion to:** `Momzo_PRD.md`, `Momzo_BuildGuide.md`
**Scope:** The mini-games on the **Together & Bonding** page. 19 games, each adapted
across three age bands, presented as fun flashcards.

---

## 0. How to use this doc

This is the design + content spec for the bonding games. It plugs into Momzo's
existing architecture — **do not build a separate AI stack for it.**

- **Generation** reuses the existing Mistral pipeline + the **refer-out safety screen
  and scope-fence** already built for the AI expert. Every AI-generated game item
  passes the same child-safety screening before it can ever reach a child.
- **Data** lives in Supabase with **RLS on every new table** (Hard Rule #1), scoped to
  the family, exactly like the rest of the app.
- **Tone** follows Hard Rule #18 — warm, never shaming, no "loser," no pressure.
- Games render as **flashcards**; each game carries one feature accent (Bonding =
  **Lavender `#A593D6`** per the design guide), with playful per-game variation allowed.

**The two things this doc exists to nail:**
1. **Age-banding** — the same game plays very differently for a 4-year-old and a
   10-year-old. Every game below specifies all three bands.
2. **Anti-repetition** — families will replay these often; §1.3 defines the system
   that stops questions/actions repeating too soon.

---

## 1. Global rules (apply to ALL games)

### 1.1 The three age bands

The child's age (already on the profile) selects the band automatically. If a family
has two children of different ages playing, use the **younger** child's band.

| | **Band A · 4–5** | **Band B · 6–7** | **Band C · 8–10** |
|---|---|---|---|
| Reading | Pre/early reader — **parent reads aloud** (or TTS) | Early reader — short text + TTS option | Reads independently |
| Vocabulary | Very simple, concrete, everyday | Simple, some feeling-words | Richer, can handle nuance |
| Abstraction | Concrete only (things they can see/touch) | Light abstraction ("happy," "kind") | Can do hypotheticals, "why," strategy |
| Round length | 2–4 items, no timer | 4–6 items, gentle/optional timer | 6–10 items, timer ok if they like it |
| Answer length | One word / point / gesture | A sentence | A few sentences, reasons |
| Win framing | No scoring — pure play | "Matches," celebrated softly | Light scoring ok, still connection-first |
| Device | Parent operates it | Shared, parent helps | Child can drive |

**Band rule for the AI:** when generating or selecting any item, it is told the band
and must produce content a child *in that band* can understand and answer happily. If
an item only works for older kids, it must not be served to Band A.

### 1.2 Reading & audio

- **Default:** parent reads the card aloud. All copy is written to be read aloud
  naturally.
- **"Tap to hear 🔊":** every card has an on-device text-to-speech button
  (`flutter_tts`, free, offline — **no AI, no per-use cost**). Especially valuable for
  Band A pre-readers, who can then play with less adult reading.
- Do **not** use paid cloud/AI TTS for this feature; the system voice is sufficient.
- Band A cards keep text minimal so a glance is enough for the parent.

### 1.3 Anti-repetition system (core requirement)

A **hybrid bank + top-up** model. The goal: a family can play a game many times before
seeing anything twice, and never feel "we just had this."

**A. Static seed banks (primary).** Every game ships with a pre-written content bank,
**per band**. These are free, instant, safe, and predictable. Target sizes:

- Question/prompt games: **≥ 40 items per band** at launch (so ~10 sessions of 4 before
  any reuse for Band A; more for older).
- Action/creative games (charades, drawing words, etc.): **≥ 30 items per band.**

**B. AI top-up (secondary).** When a family has seen most of a bank (e.g. **< 25%
unseen remaining**), the AI generates a fresh batch for *that family*, and **must be
passed the list of recently used item IDs/texts to exclude.** Generated items:
- are screened by the existing child-safety filter,
- are de-duplicated against the bank + the family's history (fuzzy match, not just
  exact),
- are written into the bank so they're reused efficiently, not regenerated each time
  (keeps Mistral cost near zero).

**C. History tracking.** A `game_play_history` row records every item shown to a
family, per game. Selection rules:
- **Never** repeat an item while unseen items remain in the family's pool.
- Once the pool is exhausted, apply a **cooldown**: an item can't reappear until at
  least **N other items** of that game have been shown since
  (N = 20 for questions, 15 for actions), then reintroduce oldest-seen first.
- Shuffle within the eligible set so order also varies.

**D. Cost guard.** Static banks carry the load; AI top-up is the exception, batched
(generate ~20 at a time, not 1), and cached in the bank. This keeps games inside the
PRD's AI-cost target.

### 1.4 Child-safety & tone (AI must follow)

Beyond the inherited refer-out/scope-fence screen:

- **Age-appropriate always.** No violence, scary themes, death, romance, adult topics,
  money/wealth comparisons, religion/politics, or anything frightening.
- **Body- and self-image safe.** Never about weight, looks-as-judgment, "prettiest,"
  dieting, etc.
- **No comparison that can wound.** Never "who's smarter/better," never pit child vs
  sibling/friend, never imply a child is lacking.
- **Family-shape neutral.** Don't assume two parents, a dad, siblings, pets, a house,
  travel, or money. Use "your grown-up / family" framings; offer outs ("…or someone you
  love").
- **Kindness-locked games** (Compliment Toss, Gratitude Swap) generate **only** warm,
  genuine, specific kindness — never backhanded, never appearance-based.
- **Gentle on "wrong."** No harsh buzzers, no "WRONG," no losing framing. A miss is
  "ooh, so close!" — a chance to learn each other.
- **No data fishing.** Questions never solicit home address, school name, passwords,
  location, or anything a child shouldn't share.
- **Stop anytime.** Every game can be exited without penalty or guilt.

### 1.5 Session shape

- Default session is **short** (≈ 5–8 min). Each game states a default round size per
  band.
- Clear **start card → rounds → warm closing card.** The closer always affirms the
  *connection*, never a score ("You two are getting to know each other 💜").
- Never nag to continue; never punish stopping early.

### 1.6 Scoring philosophy

Connection over competition. Where a game has a "score," it's framed as **matches /
moments**, both players are celebrated, and there is no leaderboard, streak-pressure,
or loss state.

### 1.7 Shared data model

Pseudo-schema; **RLS on all, scoped to family.** Integrate with existing tables.

```
games               — catalog of the 19 games (slug, title, type, min_band, accent, default_rounds)
game_items          — the content banks
   id, game_slug, band ('A'|'B'|'C'), item_type, payload(jsonb), source('seed'|'ai'), active
game_sessions       — one play session
   id, family_id, child_id, game_slug, started_at, ended_at, round_count
game_responses      — answers given in a session (for reveal/scoring; minimal retention)
   id, session_id, item_id, respondent('parent'|'child'), answer(jsonb), created_at
game_play_history   — anti-repeat ledger
   id, family_id, game_slug, item_id, shown_at
```

- `payload` shape varies by `item_type` (question, pair, prompt, action, emoji_puzzle,
  story_seed, etc.) — defined per game below.
- Keep `game_responses` retention short; it exists for the reveal, not a permanent log.

---

## 2. The games

Each game uses the same template: **Goal · Format · Per-band play · AI rules · Content
template + seed bank · Anti-repeat.** Seed samples show the pattern and tone — Claude
Code should expand each to the §1.3 target bank size, per band, before launch.

---

### 2.1 Would You Rather

**Goal:** spark laughter and reveal preferences. **Type:** choose-one. **Default
rounds:** A 3 · B 5 · C 6.

**Per band**
- **A (4–5):** two concrete, silly, both-fun options. No "bad" option. "Would you
  rather be a puppy or a kitten?"
- **B (6–7):** add gentle imagination. "Would you rather fly like a bird or be invisible?"
- **C (8–10):** add fun dilemmas + a "why?" follow-up. "Would you rather have a robot
  that does homework or one that tidies your room? Why?"

**AI rules**
- Both options must be **appealing** (no trap/gross-out for A; mild silliness ok C).
- Never fear, harm, or "lose a person/pet" dilemmas.
- For C, may append one "why?" — keep optional.
- Exclude recently-shown pairs (whole pair is the item).

**Content template:** `payload = { optionA, optionB, askWhy(bool) }`

**Seed bank (sample)**
- A: puppy / kitten · ice cream / cake · be a fish / be a bird · jump in leaves / build
  a sandcastle · be very tall / very tiny · have a balloon / a bubble · sun / rain to
  play in · red car / blue car.
- B: fly / be invisible · talk to animals / breathe underwater · have a pet dragon /
  a pet unicorn · always be warm / always be cool · giant pizza / giant cookie ·
  bouncy castle / treehouse.
- C: stop time / teleport · robot for homework / robot for chores · be a famous
  inventor / a famous explorer · only summer / only winter · super strength / super
  speed · live in a treehouse / a houseboat (+ why).

**Anti-repeat:** pair-level history; cooldown N=20.

---

### 2.2 Get-to-Know-You Questions

**Goal:** learn each other's favourites, dreams, little likes. **Type:** open
question, both answer. **Default rounds:** A 3 · B 5 · C 6.

**Per band**
- **A:** favourites they can name — colour, food, animal, toy.
- **B:** add feelings + simple dreams — "what makes you happy?", "what do you want to
  learn?"
- **C:** add reflection — "what are you proud of?", "what do you wish we did more?"

**AI rules**
- One clear question per card, answerable by **both** parent and child.
- No data-fishing (§1.4). No questions that can embarrass.
- Mix categories so a session isn't all "favourites."

**Content template:** `payload = { question, category }` (favourite | feeling | dream |
us)

**Seed bank (sample)** — favourite colour · favourite food · favourite animal ·
favourite game · favourite song · what makes you laugh · what makes you feel cosy ·
something you're good at · something you'd love to learn · favourite thing we do
together · a place that feels happy · what you want to be when you grow up · best part
of today · something that makes you feel brave · your happiest memory of us.

**Anti-repeat:** question-level history; cooldown N=20. (Overlaps with Question of the
Day bank — share the pool but track separately so a QotD doesn't feel repeated here.)

---

### 2.3 Finish the Sentence

**Goal:** easy self-expression via a sentence stem. **Type:** complete-the-stem, both
answer. **Default rounds:** A 3 · B 4 · C 6.

**Per band**
- **A:** concrete stems — "My favourite snack is ___", "I love to play ___."
- **B:** feeling stems — "I feel happiest when ___", "I feel brave when ___."
- **C:** reflective stems — "I wish we could ___", "Something I'm proud of is ___",
  "I feel most like myself when ___."

**AI rules**
- Stem must be **open and positive** — never lead to a sad/negative completion as the
  expected answer (avoid "I feel scared when ___" for A/B; ok gently for C only if
  framed as sharing, not probing).
- Keep one blank per stem.

**Content template:** `payload = { stem }`

**Seed bank (sample)** — "I feel happy when ___" · "My favourite thing about weekends
is ___" · "I feel proud when ___" · "Something that makes me giggle is ___" · "I love
it when we ___" · "If I had a magic wish it would be ___" · "I feel cosy when ___" ·
"The best part of my day is ___" · "I feel brave when ___" · "I wish we could ___
together."

**Anti-repeat:** stem-level; cooldown N=20.

---

### 2.4 Two Truths & a Lie  *(Band C core; adapted for younger)*

**Goal:** playful guessing about each other. **Type:** spot-the-odd-one. **Default
rounds:** A 2 · B 3 · C 4.

**Per band**
- **A — "Two Real, One Silly":** the concept of lying is too abstract. Instead: say two
  true things and one **obviously pretend/silly** thing ("I have a dog… I like apples…
  I can fly to the moon!"). Child spots the silly one. Pure giggle.
- **B — "Two True, One Made-Up":** simple, kind made-ups only (no mean tricks). Provide
  **prompt scaffolds** so the child can build their three statements.
- **C — classic:** each says two truths + one believable lie; the other guesses.

**AI rules**
- The AI doesn't generate the statements (those are personal) — it generates
  **scaffold prompts / categories** to help players build theirs, plus the round
  framing.
- Never encourage hurtful or scary "lies"; keep it light.
- Celebrate the guess gently whether right or wrong.

**Content template:** `payload = { mode('silly'|'simple'|'classic'), scaffold }` where
scaffold = a hint like "think about: a food you like, a place you've been, an animal."

**Seed bank (sample scaffolds)** — "a food, a colour, an animal" · "something you can
do, somewhere you've been, a favourite toy" · "a game you like, a snack, a superpower
you wish you had" · "two real favourites + one you make up."

**Anti-repeat:** scaffold-level; small bank fine (N=15) since statements are personal.

---

### 2.5 Hot Seat

**Goal:** rapid, joyful rapid-fire about one person. **Type:** quick questions to one
player, then swap. **Default rounds (questions):** A 4, no timer · B 6, optional 60s ·
C 8, optional 60s.

**Per band**
- **A:** 4 easy favourites, **no timer** (timers stress little ones). Parent in the
  seat first to model.
- **B:** 6 quick ones, optional gentle timer the child can choose.
- **C:** 8, optional timer, can include "this or that" speed rounds.

**AI rules**
- Questions must be **answerable in 1–3 seconds** (favourites, this-or-that).
- Always offer a no-timer option; timer is a toy, never a fail condition.
- Pull from quick-answer subset (not deep/reflective).

**Content template:** `payload = { question, quick:true }`

**Seed bank (sample)** — favourite colour? · cats or dogs? · sweet or salty? · summer
or winter? · favourite fruit? · best superhero? · pizza topping? · favourite season? ·
beach or mountains? · pancakes or waffles? · favourite ice cream? · morning or night?

**Anti-repeat:** question-level; cooldown N=20; keep timed-quick pool separate from
deep questions.

---

### 2.6 Time Machine

**Goal:** connect across ages — parent shares their childhood, child imagines growing
up. **Type:** paired prompt. **Default rounds:** A 2 · B 3 · C 4.

**Per band**
- **A:** very concrete — "What did you play when you were little, Mum?" / "What's your
  favourite toy now?"
- **B:** add simple imagination — "What was your favourite game at my age?" / "What do
  you think you'll like when you're big?"
- **C:** add reflection — "What were you scared of at my age?" / "What do you hope is
  true about you at 20?"

**AI rules**
- Prompts come in **gentle pairs** (one looking back for the parent, one looking forward
  for the child).
- Keep nostalgia warm; avoid loss/sad framing for younger bands.

**Content template:** `payload = { parentPrompt, childPrompt }`

**Seed bank (sample)** — back: "favourite game as a kid?" / forward: "a game you'll
teach your kids?" · back: "what made you laugh at my age?" / forward: "what do you
think will make you laugh when you're big?" · back: "your best friend as a child?" /
forward: "what kind of friend do you want to be?"

**Anti-repeat:** pair-level; cooldown N=20.

---

### 2.7 How Well Do You Know Me?

**Goal:** the flagship — both answer the **same** question (one about the child, one
about the parent), then reveal to see if they matched. **Type:** predict + reveal,
lightly scored. **Default rounds:** A 3 · B 4 · C 5.

**Flow:** Card asks e.g. "What's [child]'s favourite snack?" → **parent guesses**,
**child answers about themselves** → reveal side-by-side → match = a shared 💜. Then a
card about the parent → child guesses, parent answers → reveal. Alternate.

**Per band**
- **A:** concrete favourites only; celebrate every reveal, matched or not.
- **B:** favourites + simple feelings ("what makes [child] laugh?").
- **C:** add deeper ("what is [child] most proud of?", "what does [child] worry about?")
  — framed kindly.

**AI rules**
- Each item is a **single attribute** both can answer about the same person.
- Use the child's name (from profile) in copy.
- Reveal tone: matches celebrated; misses are "now you know!" — **never** "you got it
  wrong about your child" (that can sting a parent).
- Deeper/feeling questions only for B/C, and always gentle.

**Content template:** `payload = { about:'child'|'parent', attribute }`

**Seed bank (sample attributes)** — favourite snack · favourite colour · favourite
animal · favourite game · what makes them laugh · their happiest place · favourite song
· what they're good at · favourite thing to do on a weekend · (C) what they're proud of
· (C) what they'd wish for.

**Anti-repeat:** attribute-level, tracked separately for about-child vs about-parent;
cooldown N=20.

---

### 2.8 Guess My Answer

**Goal:** predict what the other will say, then compare. **Type:** predict + reveal.
**Default rounds:** A 3 · B 4 · C 5.

(Sibling of 2.7, but for *opinions/choices* rather than fixed facts.)

**Per band**
- **A:** "Which will Mum pick — apple or banana?" (visible either/or).
- **B:** open but easy — "What will [child] say is the best day of the week?"
- **C:** add fun hypotheticals — "If we got a pet, what will Mum say we should get?"

**AI rules**
- Prediction questions where there's no wrong answer.
- For A, prefer either/or so a 4-year-old can predict concretely.
- Celebrate near-misses; emphasise "you guessed how they think!"

**Content template:** `payload = { question, mode('either_or'|'open'), options? }`

**Seed bank (sample)** — apple or banana? · park or playground? · which colour will
they pick? · best day of the week? · ideal pet? · dream holiday spot? · favourite
dinner if they chose? · cartoon or storybook?

**Anti-repeat:** question-level; cooldown N=20.

---

### 2.9 Memory Lane

**Goal:** relive shared happy moments together. **Type:** memory prompt, both share.
**Default rounds:** A 2 · B 3 · C 4.

**Per band**
- **A:** very recent, concrete — "What did we do that was fun this week?"
- **B:** "What's a fun day we had together?"
- **C:** "What's a memory of us that always makes you smile? Why?"

**AI rules**
- Prompts point at **positive shared memories**; never "a sad time" or "a time you were
  in trouble."
- Open enough that any family (any shape, any budget) has an answer — "a time we
  laughed," not "a holiday/trip."

**Content template:** `payload = { prompt }`

**Seed bank (sample)** — "a time we laughed really hard" · "something fun we did this
week" · "a yummy thing we made or ate together" · "a silly thing that happened" · "a
time you felt really happy with me" · "our favourite thing to do at home" · "a time we
helped someone together."

**Anti-repeat:** prompt-level; cooldown N=20.

---

### 2.10 Drawing Telephone

**Goal:** creative giggles — one describes, the other draws (or vice versa). **Type:**
describe ↔ draw with a word/phrase card. **Default rounds:** A 2 · B 3 · C 4.

**Per band**
- **A:** single concrete nouns — "a cat," "the sun," "a banana."
- **B:** noun + adjective — "a happy dog," "a big tree."
- **C:** mini-scenes — "a cat riding a skateboard," "a robot eating ice cream."

**AI rules**
- The card supplies the **secret word/phrase** to draw; difficulty by band.
- All prompts must be **drawable by a child** and cheerful (no scary/complex things).
- Needs paper/screen to draw — show a "grab paper ✏️" hint.

**Content template:** `payload = { drawPrompt, band }`

**Seed bank (sample)** — A: cat · sun · ball · flower · fish · star · apple · house ·
dog · tree. B: happy dog · big balloon · sleepy cat · tall tree · funny hat · rainy
cloud. C: cat on a skateboard · robot eating ice cream · dog flying a kite · dancing
banana · penguin in a hat.

**Anti-repeat:** prompt-level; cooldown N=15.

---

### 2.11 Story Builder

**Goal:** co-create a silly story, one line each. **Type:** alternating story, seeded
by a starter. **Default rounds (lines):** A 4 · B 6 · C 8.

**Per band**
- **A:** parent leads most; child adds a word or short line; starter is simple.
- **B:** alternate full lines; AI may offer a "what happens next?" nudge.
- **C:** alternate; optional twist cards ("suddenly… add a dragon!").

**AI rules**
- Provide a **story starter** + optional **twist prompts**; the family writes the story.
- Starters are warm, funny, child-safe (friendly animals, adventures — no peril/scary).
- AI doesn't write the whole story; it sparks and (optionally) nudges.

**Content template:** `payload = { starter, twists[] }`

**Seed bank (sample starters)** — "Once upon a time, a tiny mouse found a giant
cheese…" · "One morning, [child] woke up and the cat could talk…" · "Deep in a
friendly forest lived a bear who loved to bake…" · "A little cloud wanted to learn to
dance…" *(twists: "suddenly it started raining jelly!", "a friendly dragon appeared",
"they found a magic door").*

**Anti-repeat:** starter-level; cooldown N=15; twists drawn fresh each session.

---

### 2.12 Emoji Decode

**Goal:** guess the thing from emoji clues. **Type:** puzzle + guess. **Default
rounds:** A 3 · B 4 · C 5.

**Per band**
- **A:** **single-emoji feelings/things** — 🐶 = dog, 😀 = happy. (Sequences are too
  hard.)
- **B:** 2-emoji simple combos — 🌧️☂️ = rainy day, 🎂🎉 = birthday.
- **C:** 3-emoji titles/phrases — 🦁👑 = Lion King-ish, 🍫🏭 = chocolate factory
  (use generic, **not** copyrighted titles — see rules).

**AI rules**
- **No copyrighted titles/characters** as answers (no specific movies, brands, IP).
  Use generic concepts ("a chocolate factory," "a superhero," "a birthday party").
- Band A = one emoji only; never sequences.
- Give a gentle hint option after a miss.

**Content template:** `payload = { emojis, answer, hint, band }`

**Seed bank (sample)** — A: 🐶→dog · 🍎→apple · ☀️→sun · 😀→happy · 🌧️→rain · ⭐→star.
B: 🌧️☂️→rainy day · 🎂🎉→birthday · 🍦😋→ice cream treat · 🐱😴→sleepy cat. C:
🦸‍♂️🏙️→a superhero in the city · 🍫🏭→a chocolate factory · 🚀🌕→a trip to the moon ·
🦖🌳→dinosaurs in the jungle.

**Anti-repeat:** puzzle-level; cooldown N=20.

---

### 2.13 Charades / Act It Out

**Goal:** act and guess — big movement, big laughs. **Type:** action card, one mimes,
other guesses. **Default rounds:** A 3 · B 4 · C 5.

**Per band**
- **A:** simple animals/actions — "hop like a bunny," "be a sleepy cat."
- **B:** add everyday actions — "brushing teeth," "a happy puppy," "a chef cooking."
- **C:** add scenes/feelings — "an astronaut on the moon," "someone who just won a
  prize."

**AI rules**
- Prompts must be **physically actable by a child**, safe (no jumping off things, no
  rough actions), and cheerful.
- Picture/emoji on the card helps pre-readers (pair with TTS).
- No scary or violent actions.

**Content template:** `payload = { actPrompt, emojiHint, band }`

**Seed bank (sample)** — A: bunny hop 🐰 · sleepy cat 😴 · flying bird 🐦 · stomping
elephant 🐘 · wiggly fish 🐟. B: brushing teeth 🪥 · happy puppy 🐶 · chef cooking 👩‍🍳
· watering plants 🪴 · superhero pose 🦸. C: astronaut walking 🚀 · robot dancing 🤖 ·
juggler 🤹 · someone very surprised 😲 · a cat chasing a butterfly 🦋.

**Anti-repeat:** prompt-level; cooldown N=15.

---

### 2.14 Gratitude Swap  *(calm / pre-bed)*

**Goal:** each names something they're grateful for **about the other**. **Type:**
warm prompt, both share. **Default rounds:** A 2 · B 2 · C 3.

**Per band**
- **A:** "Say one thing you love about Mum." (simple, concrete)
- **B:** "One thing you're thankful for about each other today."
- **C:** add specificity — "a way they helped you this week."

**AI rules — kindness-locked (§1.4)**
- Prompts elicit **only warmth and gratitude.** Never "something you'd change," never
  critical.
- Keep it about **character/kindness/moments**, never appearance.
- Short, soft, bedtime-suitable.

**Content template:** `payload = { prompt }`

**Seed bank (sample)** — "one thing you love about each other" · "something kind they
did" · "a way they make you smile" · "something you're thankful for today" · "a moment
you felt happy together" · (C) "a way they helped you this week" · (C) "something they
do that makes home feel cosy."

**Anti-repeat:** prompt-level; cooldown N=15.

---

### 2.15 Compliment Toss  *(calm)*

**Goal:** give each other a genuine, specific compliment. **Type:** compliment prompt,
back and forth. **Default rounds:** A 2 · B 3 · C 3.

**Per band**
- **A:** "Tell Mum something nice!" (open, easy)
- **B:** prompt a *kind-action* compliment — "say something kind they did."
- **C:** prompt *character* compliments — "something brave/kind/funny about them."

**AI rules — kindness-locked**
- Compliments are about **who they are and what they do**, never looks/weight.
- Provide a **starter scaffold** if a child is stuck ("You are really good at…", "I
  love how you…").
- Genuine + specific over generic; never backhanded.

**Content template:** `payload = { scaffold, focus('kind'|'brave'|'funny'|'helpful'|'open') }`

**Seed bank (sample scaffolds)** — "I love how you ___" · "You are really good at ___"
· "You always make me feel ___" · "Something brave about you is ___" · "You're so kind
when you ___" · "My favourite thing about you is ___."

**Anti-repeat:** scaffold-level; small bank fine (N=12).

---

### 2.16 Mood Check-in  *(calm / reflective)*

**Goal:** name feelings together and talk gently. **Type:** pick-a-feeling card +
optional talk. **Default rounds:** A 1 · B 2 · C 2.

**Per band**
- **A:** pick from **3–4 big feelings with faces** (happy / sad / sleepy / excited);
  parent gently asks "what made you feel that?"
- **B:** 5–6 feelings; one gentle follow-up.
- **C:** wider feeling words (proud, nervous, calm, frustrated); "want to tell me about
  it?"

**AI rules — extra care**
- This is the one game closest to real emotion. If a child surfaces something
  distressing, the **existing refer-out logic applies** — the app gently encourages
  talking to the grown-up and, if serious, points the parent to support. Never probes.
- Always optional to elaborate; "just picking a face is enough."
- Feeling sets are visual (emoji/faces) for pre-readers.

**Content template:** `payload = { feelingSet[], gentleFollowUp }`

**Seed bank (sample feeling sets)** — A: 😀 happy · 😢 sad · 😴 sleepy · 🤩 excited. B:
+ 😌 calm · 😟 worried. C: + 😤 frustrated · 😳 nervous · 🥰 loved · 😎 proud.
Follow-ups: "what made you feel that?" · "want to tell me more?" · "what would help
right now?"

**Anti-repeat:** rotate follow-ups; feeling sets are stable (that's fine — it's a tool,
not a quiz).

---

### 2.17 Dance Freeze  *(active / quick)*

**Goal:** move, laugh, freeze. **Type:** action rounds (music optional). **Default
rounds:** A 4 · B 5 · C 5.

**Per band**
- **A:** "Dance, then FREEZE!" with simple moves named ("wiggle like jelly").
- **B:** add move prompts ("dance like a robot, then freeze").
- **C:** add silly themes ("dance like you're underwater").

**AI rules**
- Supplies a **move/theme** per round; all safe, indoor, no equipment, no jumping off
  furniture.
- Pure fun; no elimination/"out" (no losing).

**Content template:** `payload = { moveTheme }`

**Seed bank (sample)** — wiggle like jelly · dance like a robot 🤖 · float like
underwater 🌊 · stomp like a dino 🦕 · flap like a bird 🐦 · spin like a top · tiptoe
like a cat · bounce like a kangaroo.

**Anti-repeat:** theme-level; cooldown N=15.

---

### 2.18 Simon Says  *(active / quick)*

**Goal:** classic listen-and-do giggles. **Type:** command rounds. **Default rounds:**
A 5 · B 6 · C 8.

**Per band**
- **A:** simple body actions, slow — "touch your nose," "clap twice." Gentle, no real
  "out."
- **B:** standard pace; mild trick rounds.
- **C:** faster, trickier "Simon says" vs not.

**AI rules**
- Commands are **safe, doable indoors**, no risky moves.
- For A, drop the elimination sting — it's "oops, giggle, keep going."

**Content template:** `payload = { command, isSimonSays(bool) }` (the app decides
phrasing/trickiness by band)

**Seed bank (sample)** — touch your nose · clap your hands · hop on one foot · pat your
head · wiggle your fingers · touch your toes · spin around · make a funny face · give a
high five · stomp your feet · blink three times · give yourself a hug.

**Anti-repeat:** command-level; cooldown N=15.

---

### 2.19 Mirror Me  *(active / quick)*

**Goal:** copy each other's movements — silent, silly, connecting. **Type:** lead &
mirror, then swap. **Default rounds:** A 3 · B 4 · C 4.

**Per band**
- **A:** parent leads simple slow moves; child mirrors; then child leads.
- **B:** add a starter move card to spark ideas.
- **C:** add a "slow-motion" or "freeze and swap" twist.

**AI rules**
- May supply **starter move ideas** for whoever leads; safe, indoor, gentle.
- Emphasise watching each other closely — that *is* the bonding.

**Content template:** `payload = { moveIdea }`

**Seed bank (sample)** — slow wave 👋 · big stretch 🙆 · silly face 😝 · march in place
· slow-motion jump · gentle sway · shoulder shrug · draw a circle in the air · tiptoe
steps · blow a pretend bubble.

**Anti-repeat:** move-level; cooldown N=15.

---

## 3. Build notes for Claude Code

- **Reuse, don't rebuild:** generation + safety screening go through the existing
  Mistral + refer-out pipeline. Add a thin `generate-game-items` Edge Function that
  takes `{ game_slug, band, exclude_ids[] }`, returns screened, de-duplicated items,
  and **writes them into `game_items`** (so they're cached, not regenerated).
- **Seed first:** load every game's static bank (all three bands) via an idempotent,
  slug-based seeder before any AI top-up path is needed. Hit the §1.3 target sizes.
- **RLS + indexes** on all new tables (Hard Rules #1, §3.2); index `game_play_history`
  on `(family_id, game_slug)`.
- **Selection service** (shared by all games): given `(family_id, game_slug, band,
  count)` → returns unseen items first, applies cooldown, shuffles, triggers AI top-up
  when the unseen pool drops below threshold.
- **Safety is non-negotiable:** no game item — seed or generated — reaches a child
  without passing the child-safety screen. Kindness-locked games (2.14, 2.15) and Mood
  Check-in (2.16) get the strictest treatment.
- **Tone pass:** all copy reviewed against Hard Rule #18 — playful, warm, no losing/
  shame framing, gentle on misses.
- **Flashcard UI:** Bonding accent (Lavender), big tap targets, "tap to hear 🔊" on
  every card, clear start/round/closer, exit-anytime.

---

*End of rulebook. Seed the banks, wire the selection + anti-repeat service, route
generation through the existing safe AI pipeline, and these 19 games will stay fresh,
safe, and joyful across many plays for every age from 4 to 10.*
