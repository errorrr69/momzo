# Momzo — AI Cost & Privacy (Task 5)

_Last updated: 2026-06-26 · Stack (locked): Mistral generation (small→medium) + Gemini embeddings._

## a. Cost per active user / month vs the < $0.10 target

**Finding: comfortably under target — ~1–2¢/user/month typical, ≤ ~5.6¢ worst case.** ✅

Per-turn token shape (from `ai-chat`): retrieval `match_content_cards(…, 6)` → ~6 excerpts +
system/grounding + question ≈ **~2,000 input tokens**; output capped at **450** (Q&A) / **280**
(situational), answers target <130 words ≈ **~250 output tokens**. Query embedding is one tiny
Gemini call (~30 tokens) — negligible.

At Mistral rates (Small $0.10/$0.30, Medium $0.40/$2.00 per 1M in/out) and the PRD's ~10
turns/week (~43/month):

| Scenario | Cost / turn | Cost / user / month (43 turns) |
|---|---|---|
| All **Small** (default) | ~$0.00028 | **~$0.012** (1.2¢) |
| 20% escalate to **Medium** | ~$0.00048 | **~$0.021** (2.1¢) |
| Worst case: **all Medium** | ~$0.0013 | **~$0.056** (5.6¢) |

Even the worst case is below $0.10. **No model change needed.** Cost controls already in place:
Small-by-default routing, K=6 retrieval, output caps (280/450), and a 40-req/hour per-user rate
limit. (If usage ever drifts up, the first lever is tightening escalation, not changing models.)

> Note: real usage logs are minimal pre-launch (PII-free token counts are emitted to Edge Function
> logs as `ai_chat_ok`), so this is a config-grounded estimate; re-check against real logs after launch.

## b. Does Mistral train on our prompts?

**No — on the paid La Plateforme API, customer prompts/outputs are NOT used for training by
default** (contractual). Inputs/outputs are retained ~30 rolling days for abuse monitoring, then
deleted; training only happens if you explicitly opt in. **Caveat: the *free* tier (Le Chat free)
is opted *in* to training by default.**

**Action items:**
1. **Confirm Momzo's Mistral account is on the paid/pay-as-you-go API plan** (not a free tier), so
   the no-training guarantee applies. (Pre-launch checklist item.)
2. **Optional but recommended for child-adjacent data: request Zero Data Retention (ZDR)** so even
   the 30-day abuse-monitoring copy isn't retained.

Sources:
- [Mistral — Can I opt out of data being used for training?](https://help.mistral.ai/en/articles/455207-can-i-opt-out-of-my-input-or-output-data-being-used-for-training)
- [Mistral — Do you use my data to train your models?](https://help.mistral.ai/en/articles/347617-do-you-use-my-user-data-to-train-your-artificial-intelligence-models)
- [Mistral — Zero Data Retention (ZDR)](https://help.mistral.ai/en/articles/347612-can-i-activate-zero-data-retention-zdr)
- [Mistral Privacy Policy](https://legal.mistral.ai/terms/privacy-policy)

## Code-verified: no child identifier reaches the LLM ✅

`supabase/functions/ai-chat/index.ts`:
- The child query selects **only** `owner_id, age, temperament, struggles` — **`name` is never even
  fetched** (line ~57).
- The LLM context is `Child context — age N; temperament: …; working on: …` — **no name** (line ~110).
- The system prompt instructs the model to call the child **"your child" (never use a name)** (line ~117).

So the app **never** sends the child's name or any identifier to Mistral. The only residual vector
is a parent *typing* the name into their own question (free text we don't inject); acceptable, and
mitigated by the paid-tier no-training guarantee above.
