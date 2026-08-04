# Shared Edge Function helpers

Reusable Deno/TypeScript utilities for all Edge Functions (pooled DB client on
port 6543 with prepared statements off, JWT verification, no-PII logging).
Scaffolded in Task 6; consumed by ai-chat (Task 14), send-due-reminders
(Task 20), and whatsapp-send (Task 29).

| Module | What it owns |
|---|---|
| `db.ts` | Pooled Postgres client (transaction pooler, prepared statements off) |
| `auth.ts` | JWT verification |
| `cors.ts` / `log.ts` / `sentry.ts` | Response headers, PII-free structured logs, error capture |
| `ai.ts` | **The only place provider keys live.** Embeddings, Mistral chat, refer-out classifier |
| `personalization.ts` | Ownership choke-point + the NAME-FREE personalization context and cache bucket |
| `prompts.ts` | Prompt assembly. Static, byte-identical cached prefix ⟶ variable block |
| `aicost.ts` | Rate limits, cost estimation, PII-free telemetry, budget circuit breaker |
| `semcache.ts` | Semantic answer cache (bucketed pgvector lookup + write-through) |
| `memory.ts` | Per-family memory: conversation replay, the parent's notes, recent engagement |

## AI cost layers

`prompts.ts`, `aicost.ts` and `semcache.ts` implement `Momzo_AI_Cost_Strategy.md`.
Three things must never be "optimised" away:

1. **The refer-out screen runs before every cost control.** A rate-limited parent,
   or one arriving while the budget breaker is tripped, still gets the full
   refer-out response. The ordering in `ai-chat/index.ts` is a safety property.
2. **Nothing per-user may enter `STATIC_PREFIX`.** One child's age in the prefix
   makes it unique per family and destroys prompt caching for everyone. Bump
   `PROMPT_VERSION` in the same commit as any prefix edit.
3. **Telemetry stays PII-free.** `ai_usage` has no column that could hold a
   question, an answer or a child's name — keep it that way.

Config (Function secrets, all optional with safe defaults):

| Env | Default | Effect |
|---|---|---|
| `AI_DAILY_BUDGET_USD` | `25` | Hard breaker: stop non-essential AI above this rolling-24h spend |
| `AI_SOFT_BUDGET_FACTOR` | `3` | Soft breaker: alert above this multiple of the 30-day daily average |
| `AI_SOFT_BUDGET_FLOOR_USD` | `1` | Don't soft-alert on low-volume noise |
| `AI_SEMANTIC_CACHE_THRESHOLD` | `0.95` | Cosine similarity to serve a cached answer. Loosen slowly |
| `AI_SEMANTIC_CACHE` | `on` | Set `off` to disable the answer cache entirely |

## Memory tiers — and why the cache stays honest

`memory.ts` splits a family's context in two, and the split is what lets a shared
answer cache coexist with genuinely personal answers:

- **Tier A — bucket context** (`personalization.ts`): age band, focus goals,
  challenges, interests, temperament, the parent's goals and time. Two families in
  the same bucket want the same answer, which is what makes one vetted answer
  reusable.
- **Tier B — personal context** (`memory.ts`): the conversation so far, the
  parent's free-text notes, and what this family has actually been doing lately.

**A turn carrying any Tier B context skips the semantic cache in both
directions** — it is neither served from it nor written to it. An answer shaped by
one family's notes must never reach another family, and a shared answer must never
be passed off as one that remembered her.

That is a deliberate cost trade, and it is measurable: `ai_efficiency`
(`semantic_cache_hit_pct`) shows what it costs, `ai_answer_feedback`
(`helpful_pct`, split by `from_cache`) shows what it buys. First questions with no
notes and little activity stay cacheable, which is where the hit rate lives anyway
— follow-ups were never good cache candidates.

Engagement context is gated: it appears only once a family has ≥3 logged events in
21 days, so quiet and brand-new families stay cacheable.

## Feedback

`rate_ai_answer(message_id, rating)` is the only write path — a narrow
SECURITY DEFINER function, because a thumbs-down must delete from
`cached_answers`, which the app must never touch. It does its own ownership check.
A 👎 retires the cached answer behind that message so one unhelpful answer cannot
keep being served; a 👍 leaves it in place.

Tests: `deno test --allow-env supabase/functions/_shared/` (pure logic) and
`supabase/tests/ai_cost.test.mjs` + `ai_memory.test.mjs` (database behaviour).
