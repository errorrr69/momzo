// AI cost control (Cost Strategy §4 Layer 3, §8 telemetry, §9 circuit breaker).
//
// THE ONE RULE THAT OVERRIDES EVERYTHING HERE: safety is never traded for cost.
// The refer-out screen runs BEFORE any check in this file, and neither a rate
// limit nor a tripped breaker may ever suppress a refer-out response.
//
// Everything is enforced server-side. The client is never trusted.

// `db` is imported for its TYPE only — this module never opens a connection of
// its own, and staying type-only keeps it unit-testable without a database.
import type { db } from './db.ts';
import { log } from './log.ts';

// ---------------------------------------------------------------------------
// Rate limits (§4) — a ceiling, not a budget. A parent in normal use never
// comes close. Deliberately generous; tune with real data.
// ---------------------------------------------------------------------------
export const LIMITS: Record<string, number> = {
  qa: 30,           // expert Q&A, rolling 24h, per user
  situational: 15,  // in-the-moment help, rolling 24h, per user
  game_items: 5,    // AI bank top-up batches, rolling 24h, per family
};

// KNOWN SPEC CONFLICT, recorded here rather than papered over:
// Cost Strategy §1 sets a "worst-case single user / month" hard ceiling of $0.30,
// but the §4 limits above allow 30 Q&A + 15 situational turns a day. At the target
// 10% escalation rate that is ~$0.55/month — roughly 2x the §1 ceiling. The §4
// limits are kept because they are the explicit, user-facing number and §4 says to
// tune them with real data; the ceiling below is the honest figure they imply.
// Tightening Q&A to ~12/day would bring it under $0.30 — a product call, not a
// silent one. aicost_test.ts asserts against this constant so it can never drift
// upward unnoticed.
export const WORST_CASE_MONTHLY_USD = 0.60;

// Hard Rule #18 copy: warm, no shame, no counters, no cost language. Rotated by
// mode so it never reads like a canned error.
export const LIMIT_MESSAGE: Record<string, string> = {
  qa: "Let's pick this up a little later today — I'll be right here. 💛",
  situational:
    "We've covered a lot together today. I'll be ready again in a few hours — "
    + "and you've got this right now. 💛",
  game_items: "Let's play with the ones we've got for now — I'll have fresh ideas ready later. 💛",
};

// Shown when the budget breaker has tripped. Same tone rules: never mention cost.
export const BREAKER_MESSAGE =
  "I'm just catching my breath — give me a little while and I'll be right back with you. 💛";

// ---------------------------------------------------------------------------
// Cost model (§1). Rates are per 1M tokens and MOVE — they live here, in one
// place, and are overridable by env so a price change is a config change.
// Cached prefix tokens bill at 10% of the input rate (Mistral prompt caching).
// ---------------------------------------------------------------------------
interface Rate { in: number; out: number }
const DEFAULT_RATES: Record<string, Rate> = {
  'mistral-small-latest': { in: 0.10, out: 0.30 },
  'mistral-medium-latest': { in: 0.40, out: 2.00 },
};
const CACHED_INPUT_DISCOUNT = 0.10;

function rateFor(model: string): Rate {
  return DEFAULT_RATES[model]
    ?? (model.includes('medium') ? DEFAULT_RATES['mistral-medium-latest'] : DEFAULT_RATES['mistral-small-latest']);
}

export function estimateCostUsd(
  model: string | null,
  promptTokens: number | null,
  completionTokens: number | null,
  cachedTokens: number | null = 0,
): number {
  if (!model) return 0;
  const r = rateFor(model);
  const cached = Math.max(0, cachedTokens ?? 0);
  const fresh = Math.max(0, (promptTokens ?? 0) - cached);
  const out = Math.max(0, completionTokens ?? 0);
  return (fresh * r.in + cached * r.in * CACHED_INPUT_DISCOUNT + out * r.out) / 1e6;
}

// ---------------------------------------------------------------------------
// Telemetry (§8). PII-FREE: never pass question text, answer text, a child name,
// or any free text the parent wrote. Non-fatal by design — a metrics write must
// never be able to fail a parent's answer.
// ---------------------------------------------------------------------------
export interface UsageRow {
  ownerId: string;
  conversationId?: string | null;
  mode: string;                 // 'qa' | 'situational' | 'game_items'
  model?: string | null;        // null on the free paths
  billable?: boolean;           // did this actually call a model?
  escalated?: boolean;
  promptTokens?: number | null;
  completionTokens?: number | null;
  cachedTokens?: number | null;
  promptCacheHit?: boolean;
  semanticCacheHit?: boolean;
  referOut?: boolean;
  rateLimited?: boolean;
  breakerState?: BreakerState;
  latencyMs?: number;
  source?: 'cloud' | 'on_device';
}

export async function recordUsage(sql: ReturnType<typeof db>, u: UsageRow): Promise<void> {
  const billable = u.billable ?? Boolean(u.model);
  const cost = billable
    ? estimateCostUsd(u.model ?? null, u.promptTokens ?? 0, u.completionTokens ?? 0, u.cachedTokens ?? 0)
    : 0;
  try {
    await sql`
      insert into ai_usage (
        owner_id, conversation_id, mode, model, source, billable, escalated,
        prompt_tokens, completion_tokens, cached_tokens,
        prompt_cache_hit, semantic_cache_hit, refer_out, rate_limited,
        breaker_state, latency_ms, estimated_cost_usd
      ) values (
        ${u.ownerId}, ${u.conversationId ?? null}, ${u.mode}, ${u.model ?? null},
        ${u.source ?? 'cloud'}, ${billable}, ${u.escalated ?? false},
        ${u.promptTokens ?? null}, ${u.completionTokens ?? null}, ${u.cachedTokens ?? null},
        ${u.promptCacheHit ?? false}, ${u.semanticCacheHit ?? false},
        ${u.referOut ?? false}, ${u.rateLimited ?? false},
        ${u.breakerState ?? 'ok'}, ${u.latencyMs ?? null}, ${cost}
      )`;
  } catch (e) {
    log.warn('ai_usage_insert_failed', { message: String(e) });
  }
}

// ---------------------------------------------------------------------------
// Rate limiting (§4). Counts BILLABLE rows only — refer-out, cache hits and
// previous limit responses cost nothing and must not count against her.
// ---------------------------------------------------------------------------
export async function isRateLimited(
  sql: ReturnType<typeof db>,
  ownerId: string,
  mode: string,
): Promise<boolean> {
  const limit = LIMITS[mode];
  if (!limit) return false;
  const [{ count }] = await sql`
    select count(*)::int as count from ai_usage
    where owner_id = ${ownerId} and mode = ${mode} and billable
      and created_at > now() - interval '24 hours'`;
  return count >= limit;
}

// ---------------------------------------------------------------------------
// Budget circuit breaker (§9). A solo-founder safety net against a bug or abuse
// causing runaway spend. Thresholds are config, not hard-coded.
//
//   soft  -> rolling 24h spend > SOFT_FACTOR x the 30-day daily average: alert
//   hard  -> rolling 24h spend > AI_DAILY_BUDGET_USD: stop non-essential AI
//
// The refer-out safety path is NEVER disabled by the breaker.
// ---------------------------------------------------------------------------
export type BreakerState = 'ok' | 'soft' | 'hard';

function envNum(name: string, fallback: number): number {
  const v = Number(Deno.env.get(name));
  return Number.isFinite(v) && v > 0 ? v : fallback;
}

// One isolate-local read per minute: the breaker must be cheap enough to run on
// every request without becoming a cost of its own.
let cached: { state: BreakerState; at: number } | null = null;
const TTL_MS = 60_000;

export async function breakerState(sql: ReturnType<typeof db>): Promise<BreakerState> {
  const now = Date.now();
  if (cached && now - cached.at < TTL_MS) return cached.state;

  let state: BreakerState = 'ok';
  try {
    const hardCap = envNum('AI_DAILY_BUDGET_USD', 25);
    const softFactor = envNum('AI_SOFT_BUDGET_FACTOR', 3);
    const softFloor = envNum('AI_SOFT_BUDGET_FLOOR_USD', 1); // don't alert on noise at low volume

    const [r] = await sql`select spend_24h_usd, avg_daily_30d_usd from ai_spend_24h`;
    const spend = Number(r?.spend_24h_usd ?? 0);
    const avg = Number(r?.avg_daily_30d_usd ?? 0);

    if (spend >= hardCap) {
      state = 'hard';
      log.error('ai_budget_breaker_hard', { spend_24h_usd: spend, cap_usd: hardCap });
    } else if (spend > softFloor && avg > 0 && spend > softFactor * avg) {
      state = 'soft';
      log.warn('ai_budget_breaker_soft', { spend_24h_usd: spend, avg_daily_30d_usd: avg, factor: softFactor });
    }
  } catch (e) {
    // Never let the breaker itself break the product — fail open.
    log.warn('ai_budget_breaker_failed', { message: String(e) });
  }

  cached = { state, at: now };
  return state;
}

/// Test seam: forget the memoized breaker reading.
export function resetBreakerCache(): void { cached = null; }
