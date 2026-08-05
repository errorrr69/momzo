# Momzo — AI Cost & Scaling Strategy

### Implementation guide for keeping AI costs near zero at scale

**Version:** v1.0 · June 2026
**For:** Claude Code · **Companion to:** `Momzo_BuildGuide.md` (§6 Hard Rules), `Momzo_PRD.md` (§6 AI Layer), `Momzo_OnDevice_AI_Strategy.md`
**Status:** Layers 1–3 are launch-relevant. Layers 4–5 are scale optimizations. Layer 6 is post-launch.

---

## 0. What this delivers

Six cost layers, ordered by **actual impact**, with implementation detail and acceptance
criteria for each:

1. **Precomputation** — audit + guard what's already won (biggest lever, mostly done)
2. **Prompt caching** — cheap to add, meaningful savings
3. **Rate limiting** — caps worst-case cost forever
4. **Semantic answer cache** — big win at scale
5. **Model routing** — verify + tune (already built)
6. **On-device** — later, for privacy/offline, *not* cost

**Read this first:** Momzo does **not** have an AI cost problem. The architecture already
precomputes nearly everything. This guide is about *keeping* it that way as features grow,
and capping the worst case. Do not over-engineer these layers or trade safety for cents.

---

## 1. The cost model (targets to build against)

**Current model rates** (verify against provider docs at build time — these move):

| Model | Input / 1M | Output / 1M |
|---|---|---|
| Mistral Small (default) | ~$0.10 | ~$0.30 |
| Mistral Medium (escalation) | ~$0.40 | ~$2.00 |

**A single AI expert turn:**
- Input ≈ **2,000 tokens** (system prompt ~800 + 3 RAG chunks ~750 + personalization context ~150 + short history ~300)
- Output ≈ **250 tokens** (short, warm, capped by design)

**Math:**
```
Small turn:    2000 × $0.10/1M  +  250 × $0.30/1M   = $0.000275
Medium turn:   2000 × $0.40/1M  +  250 × $2.00/1M   = $0.0013
Blended (90/10 split)                                = $0.00038 / turn
Per active user/month (≈43 turns)                    = $0.016  ← ~1.6 cents
```

**Targets (fail the build if exceeded):**

| Metric | Target | Hard ceiling |
|---|---|---|
| Cost per AI turn (blended) | ≤ $0.0005 | $0.001 |
| Cost per active user / month | ≤ $0.05 | $0.10 |
| Escalation rate (→ Medium) | ≤ 10% | 20% |
| Worst-case single user / month | ≤ $0.15 | $0.30 |

**Scale check:** 1k users ≈ $16/mo · 10k ≈ $160/mo · 100k ≈ $1,600/mo.

---

## 2. Layer 1 — Precomputation (audit + guard)

**Status: mostly done. This layer is about not losing it.**

The reason Momzo is cheap is that almost nothing calls an LLM per user:

| Surface | Cost model | Rule |
|---|---|---|
| Daily cards | Precomputed static content, **rule-based selection** | Never generate per user |
| Activities | Static library + filters | Never generate per user |
| Bonding games | Static banks (see games spec §1.3) | AI top-up only when a bank runs low, **batched** |
| Personalization context | Built from DB columns, no LLM | Never "ask the AI to summarize the child" |
| AI expert Q&A | **The only real per-user LLM cost** | Optimize here |

### Implementation
- **Add a CI guard** that fails if a new LLM call site is introduced outside the approved
  list (`ai-chat`, `situational`, `generate-game-items`). A simple lint/grep rule over
  the Edge Functions directory is enough. Any new call site must be a deliberate,
  reviewed decision.
- **Game top-ups must be batched** — generate ~20 items per call, written to
  `game_items`, never one-at-a-time per play.
- **Never** use an LLM for: selecting a daily card, ranking activities, formatting text,
  building the personalization context, or classifying anything a rule can classify.

### Acceptance
- A grep/lint check enumerates every LLM call site and matches the approved list.
- Playing any game 50× triggers **zero** LLM calls while the bank has unseen items.
- Loading Home / Learn / Activities triggers zero LLM calls.

---

## 3. Layer 2 — Prompt caching

**The single easiest saving.** Most of every request is identical across all users: the
system prompt, the safety instructions, the response-format rules.

### The critical detail: prompt ordering
Caching works on an **exact prefix match**. Anything variable placed early destroys the
cache for everything after it. So the prompt must be assembled **most-static → most-variable**:

```
1. System prompt          (identical for every user, every request)   ← CACHE THIS
2. Safety / refer-out rules   (identical)                             ← CACHE THIS
3. Response format rules      (identical)                             ← CACHE THIS
--- cache boundary ---
4. RAG chunks             (varies by question)
5. Personalization context (varies by child — age/traits, NEVER the name)
6. Conversation history    (varies)
7. The user's question     (varies)
```

**Do not** interpolate the child's age, name, or any per-user value into the system
prompt — that would make it unique per user and kill caching entirely. Per-user values
belong in the personalization context block, *after* the cache boundary.

### Implementation
- Verify the provider's current caching mechanism and requirements in their API docs
  (automatic prefix caching vs. explicit cache markers vs. minimum token thresholds —
  this varies by provider and changes; **do not assume**).
- Keep the static prefix **stable**. Any edit to the system prompt invalidates the cache
  globally, so version it and change it deliberately, not casually.
- Log `cache_hit` (bool) per request so the hit rate is measurable.

### Acceptance
- The static prefix is byte-identical across two requests from two different users
  (assert this in a test).
- Cache-hit rate is visible in telemetry and exceeds **80%** in steady state.
- No child name or per-user value appears anywhere in the static prefix.

---

## 4. Layer 3 — Rate limiting (the worst-case cap)

**Purpose:** make the maximum possible cost of any single user knowable and bounded.
In normal use a mom will never come close.

### Limits
| Mode | Limit | Window |
|---|---|---|
| Expert Q&A | **30 questions** | rolling 24h, per user |
| Situational "right now" | **15 requests** | rolling 24h, per user |
| Game AI top-up | **5 batches** | rolling 24h, per family |

Start here; tune with real data. These are deliberately generous — they're a ceiling, not
a budget.

### Non-negotiable safety rules
> These override cost control. Cheapness never blocks care.

1. **The refer-out safety screen ALWAYS runs**, even when a user is rate-limited. If a
   rate-limited user submits a question containing a safety signal (self-harm, abuse,
   medical, developmental concern), the system **must still return the warm refer-out
   response**. A mom in a hard moment must never hit a paywall-shaped wall.
2. The safety pre-screen is cheap (rules + light classifier) — it runs **before** the
   rate-limit check, not after.
3. Rate-limit responses never shame, never imply overuse, never mention cost.

### Copy (Hard Rule #18 — warm, no shame)
- ✅ *"Let's pick this up a little later today — I'll be right here. 💛"*
- ✅ *"We've covered a lot together today. I'll be ready again in a few hours."*
- ❌ *"You've exceeded your daily limit."* / *"Too many requests."* / anything implying
  she asked too much.

Show the reset time softly if at all. Never a counter, never "X of 30 used" — that turns
a safety net into a scoreboard.

### Implementation
- Enforce **server-side in the Edge Function**. Never trust the client.
- Count from an indexed `ai_usage` table (or count `ai_messages` with a
  `(user_id, created_at)` index). Prefer a small dedicated counter table — cheaper to read.
- RLS on the table, scoped to the owner.

### Acceptance
- 31st question in 24h returns the warm limit message, not an error.
- A rate-limited user submitting a safety-flagged question **still receives the full
  refer-out response** (explicit test).
- The limit cannot be bypassed by a modified client.
- Copy passes a tone review — no shame, no counters, no cost language.

---

## 5. Layer 4 — Semantic answer cache

**The big win at scale.** Thousands of moms ask essentially the same questions ("how do I
handle tantrums?", "why won't he listen?"). Serve one vetted answer instead of generating
thousands.

### The core design problem: answers are personalized
A cached answer for an anxious 8-year-old must **not** be served to the mom of a
boisterous 5-year-old. So the cache key is **not** just the question — it's the question
**plus a personalization bucket**.

```
cache_key = (question_embedding, personalization_bucket)

personalization_bucket = age_band (4-5 | 6-7 | 8-10)
                       + primary focus_goal
                       + primary challenge tag
```

Coarse buckets keep the hit rate useful while ensuring the answer actually fits the child.

### Lookup flow
```
1. Embed the incoming question (already done for RAG — reuse it, no extra cost).
2. Query cached_answers via pgvector, filtered to the same personalization_bucket.
3. If cosine similarity ≥ THRESHOLD → serve the cached answer.
4. Else → generate normally, then write the result to the cache.
```

### Rules
- **Start strict: threshold 0.95.** Loosen gradually (0.93, 0.92) while monitoring quality.
  A wrong-but-confident cached answer is worse than paying $0.0003.
- **NEVER cache** a question that triggered the refer-out screen. Every safety-adjacent
  question gets fresh, full handling — no exceptions.
- **Never cache** situational "right now" responses. Those are in-the-moment and specific.
- Only cache answers that **passed** the output safety screen.
- **TTL: 90 days.** Content and guidance evolve.
- **Invalidate on content change:** when `content_cards` are re-seeded or edited, purge
  cached answers whose `cited_card_ids` reference changed cards. (Ties into the corpus
  integrity check.)
- Cached answers are **global, not per-family** — but because they're bucketed and
  name-free, they contain no personal data. Verify this: a cached answer must never
  contain a child's name or any family-specific detail.

### Data model
```sql
cached_answers
  id                uuid PK
  question_text     text            -- the canonical question that produced it
  question_embedding vector         -- pgvector, indexed (ivfflat/hnsw)
  bucket_key        text            -- age_band|focus|challenge, indexed
  answer_text       text
  cited_card_ids    uuid[]
  hit_count         int             -- for monitoring value
  created_at        timestamptz
  expires_at        timestamptz     -- created_at + 90d
```
Index on `(bucket_key)` and a vector index on `question_embedding`.

### Acceptance
- Two structurally identical questions from two different families in the same bucket →
  second one is served from cache with **zero** LLM tokens.
- The same question from a *different* bucket → generates fresh (test this explicitly).
- A refer-out-flagged question is **never** written to or served from the cache.
- No cached answer contains a child's name or family-identifying detail.
- Cache hit rate is visible in telemetry.

---

## 6. Layer 5 — Model routing (verify + tune)

**Already built.** This layer is verification, not new work.

### Verify
- Default is Mistral Small; escalation to Medium only on: sensitive/emotional topics,
  low retrieval confidence, or output-quality failure.
- **Measure the actual escalation rate.** Target ≤ 10%. If it creeps above 20%, the
  escalation trigger is too loose — tighten it (and report before changing).
- Confirm `max_output_tokens` is capped (~300) and small-K retrieval (K=3) is in place.

### Acceptance
- Telemetry shows the routing split (small vs. medium) and the escalation rate.
- A battery of 20 ordinary questions escalates ≤ 2 of them.
- A battery of sensitive questions escalates (or routes to refer-out) 100% of the time.

---

## 7. Layer 6 — On-device (post-launch)

See **`Momzo_OnDevice_AI_Strategy.md`** for the full spec. Summary for this doc:

- Build the `AIProvider` abstraction now; the on-device implementation comes later.
- **The reason is privacy and offline use, NOT cost.** There is no cost problem to solve —
  see §1. Do not justify on-device work on cost grounds.
- Rollout order: games → situational → easy expert Q&A. Safety screen always runs.

---

## 8. Telemetry & cost dashboard

You cannot manage what you can't see. Log **per AI request** (PII-free):

```
ai_request_log
  id, created_at
  task              -- 'expert_qa' | 'situational' | 'game_items'
  model             -- 'mistral-small' | 'mistral-medium'
  source            -- 'cloud' | 'on_device'   (future)
  input_tokens, output_tokens
  prompt_cache_hit  bool
  semantic_cache_hit bool
  escalated         bool
  refer_out         bool
  latency_ms
  estimated_cost_usd
  user_id           -- FK only, for per-user aggregation. NO message content.
```

**Never log:** question text, answer text, child name, or any free-text the user wrote.

### Required views
- **Cost per active user per month** (the headline number vs. the §1 target).
- **Daily total spend** with a 30-day trend.
- **Cache hit rates** (prompt + semantic) and **escalation rate**.
- **Top 10 heaviest users** by turn count — to sanity-check the rate limit is sized right.

### Acceptance
- The dashboard returns real numbers from real traffic.
- Cost per active user is computable and under target.
- No PII appears in any log row (explicit test).

---

## 9. Budget circuit breaker

A safety net for a solo founder — protects against a bug or abuse causing runaway spend.

- Track **rolling 24h estimated spend** from `ai_request_log`.
- **Soft threshold** (e.g. 3× the 30-day daily average): log a warning + alert.
- **Hard threshold** (a configurable daily cap): stop non-essential AI —
  game top-ups first, then expert Q&A degrades to the semantic cache + a warm
  "I'll be back shortly" message.
- **The refer-out safety path is NEVER disabled by the circuit breaker.** Safety responses
  run regardless of budget state.
- Thresholds live in config, not hard-coded.

### Acceptance
- Simulating high spend triggers the soft alert and then the hard degradation, in order.
- With the breaker tripped, a safety-flagged question **still** returns the refer-out
  response.

---

## 10. Hard rules for this work

1. **Safety is never traded for cost.** The refer-out screen runs on every turn regardless
   of rate limits, cache state, or budget breaker.
2. **Never cache or rate-limit away a safety response.**
3. **No PII in telemetry** — no question text, answer text, or child names.
4. **No child identifiers to any model**, cached or live (existing rule, unchanged).
5. **RLS + index** on every new table (`ai_usage`, `cached_answers`, `ai_request_log`).
6. **All cost copy follows Hard Rule #18** — warm, never shaming, never mentions cost or
   limits as failure.
7. **Server-side enforcement only.** Rate limits and routing are never client-trusted.
8. **Start strict, loosen with data** — especially the semantic cache threshold.

---

## 11. Build order & acceptance

**Phase A (launch-relevant):**
1. Layer 1 audit + CI guard on LLM call sites
2. Layer 2 prompt caching (prompt re-ordering + cache verification)
3. Layer 3 rate limiting (+ the safety-always-runs test)
4. Layer 8 telemetry + the cost-per-user view

*Done when:* cost per active user is measurable and under $0.05, cache-hit rate > 80%,
rate limit enforced server-side, and a rate-limited safety question still gets refer-out.

**Phase B (scale):**
5. Layer 4 semantic answer cache (start at 0.95 threshold)
6. Layer 5 routing verification + tuning
7. Layer 9 budget circuit breaker

*Done when:* semantic cache serves repeat questions with zero tokens, bucket isolation is
proven by test, escalation rate ≤ 10%, and the breaker degrades gracefully without ever
disabling safety.

**Phase C (post-launch):** Layer 6 on-device, per the on-device strategy doc.

---

*End of guide. The architecture already made AI a rounding error — these layers keep it
that way as Momzo grows, and cap the worst case forever. Never trade a safety response
for a fraction of a cent.*
