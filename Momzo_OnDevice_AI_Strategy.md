# Momzo — On-Device AI Strategy

### Hybrid (on-device + cloud) AI spec

**Version:** v1.0 · June 2026
**For:** Claude Code · **Companion to:** `Momzo_PRD.md` (§6 AI Layer), `Momzo_BuildGuide.md` (§6 Hard Rules)
**Status:** **Post-launch (Phase 2+). Not a launch blocker.** Build the *abstraction* now;
build the on-device *implementation* after the core cloud path is live and proven.

---

## 0. TL;DR for Claude Code

- Ship v1 on the **single cloud path** (Mistral + RAG + refer-out). It works on 100% of
  phones and keeps the safety-critical expert grounded. **Do not** make on-device a
  dependency for launch.
- **Now (Phase 1):** build the app behind a clean `AIProvider` abstraction with one
  `CloudProvider` implementation, so on-device drops in later with no refactor.
- **Later (Phase 2+):** add `OnDeviceProvider` + a capability check + the routing rules
  in §4. Roll it out **games first** (lowest risk), expert last.
- **Always, regardless of which brain answers:** the refer-out safety screen runs
  (Hard Rule #7). On-device never bypasses safety.

**Why we're doing this:** not for cost (Mistral grounded RAG is already near-zero) but
for **privacy** (child-related questions never leave the phone) and **offline** use.
Go in knowing the trade is *more engineering + two code paths* in exchange for *privacy
+ offline + truly $0 marginal cost* — not "simpler" or "much cheaper."

---

## 1. Core principle: split by risk, not one switch

"On-device AI" is **not** a single toggle. Route each AI task by **how much harm a bad
answer could do**, then by **device capability** and **answer confidence**. A silly
game question and a question about a child's distress are not the same risk and must not
share one policy.

Three routing classes:

| Class | Meaning | Default brain |
|-------|---------|---------------|
| **Green** | Low stakes; a weak answer is harmless | On-device if capable, else cloud |
| **Amber** | Medium stakes; tone/quality matters | On-device *only if confident*, else cloud |
| **Red** | High stakes; safety-critical | **Always cloud + full guardrails** |

---

## 2. Feature-by-feature routing table

This is the authoritative mapping. Each AI surface is assigned a class.

| AI surface | Class | On-device? | Reasoning |
|------------|-------|-----------|-----------|
| **Bonding game item top-up** (questions, prompts, charades cards, etc.) | 🟢 Green | **Yes** — preferred | Static banks already carry the load (see games spec §1.3); top-ups are low-stakes and benefit from being free + offline. Start here. |
| **Situational "right now" scripts** | 🟡 Amber | Yes, with cloud fallback | In-the-moment calming scripts; useful offline. If retrieval/confidence is weak or the topic is sensitive → cloud. |
| **AI expert Q&A** | 🟡→🔴 | Only easy, well-covered, high-confidence questions | The safety-critical heart. Default cloud; on-device only when retrieval is confident *and* the question is non-sensitive. Anything emotional, ambiguous, or low-confidence → cloud. |
| **Refer-out / safety screening** | 🔴 Red | Screening runs **always**; sensitive cases → cloud | Never skipped, never weakened, whichever brain answered. See §5. |
| **Embeddings / RAG retrieval** | n/a | Stays as-is (cloud embeddings, pgvector) | Retrieval is cheap and already built; not the thing on-device is for. |
| **Daily card selection** | n/a | No AI needed | Rule-based targeting by age/struggle; not a generation task. |

**Rollout order when we build it:** games → situational → expert (most cautious last).

---

## 3. Capability detection (the real "onboarding" step)

There is **no "connect your phone's AI" / permission flow.** These are OS developer
APIs the app *calls* — nothing to connect. What we do instead:

### 3.1 Silent capability probe (first run + cached)
On first launch (and re-checked on OS update), the app determines an
`OnDeviceCapability`:

```
enum OnDeviceCapability { available, unavailable, unknown }
```

- **iOS:** available iff the device supports **Apple Intelligence** and is on **iOS 26+**
  with the **Foundation Models** framework present and the model ready
  (Apple exposes availability/readiness states — handle "downloading" and "not enabled"
  as `unavailable` for now, recheck later).
- **Android:** available iff an OS-provided on-device GenAI API is present and the model
  is ready — i.e. **Gemini Nano via ML Kit GenAI** on supported devices. Treat
  feature-availability + model-downloaded as the gate.
- Cache the result; re-probe on app update / OS version change.

### 3.2 The only user-facing bit
- On capable iPhones, Apple Intelligence is usually on by default. If a feature would
  benefit and it's off, we may show **one** gentle, optional hint ("You can enable
  Apple Intelligence in Settings for faster, private answers") — never a blocker, never
  nagging.
- On non-capable phones: **show nothing.** The app silently uses cloud. The mom never
  sees a downgrade message.

### 3.3 Device floors (for planning — verify at build time)
> These expand over time as devices turn over. Verify current support lists when you
> build this; don't hard-code model names.

- **iOS on-device (Foundation Models):** iOS 26+ **and** an Apple-Intelligence-capable
  iPhone (roughly iPhone 15 Pro and newer). Base iPhone 15 and older → cloud.
- **Android on-device (Gemini Nano / ML Kit GenAI):** recent flagships (e.g. Pixel 8+,
  Galaxy S24+ class). Mid-range and budget → cloud.
- **Realistic US coverage at launch:** roughly half to two-thirds of users on-device-
  capable, rising over time. **Plan for the cloud fallback to serve a large minority
  permanently.**

### 3.4 What NOT to do
- ❌ **Do not bundle a Gemma model via MediaPipe/AI Edge** for the consumer app — model
  files are ~1–4GB+ and will wreck install conversion for a busy mom. Use **OS-provided
  models only** (zero app-size cost). (MediaPipe/Gemma is fine for internal experiments,
  not the shipped app.)
- ❌ Do not make any feature *require* on-device.
- ❌ Do not show capability-downgrade messaging to non-capable users.

---

## 4. The `AIProvider` abstraction (build this in Phase 1)

So on-device drops in later with no refactor, route **all** generation through one
interface today. The app talks to the interface; the router picks the implementation.

### 4.1 Interface (Dart sketch)

```dart
enum AiRiskClass { green, amber, red }

class AiRequest {
  final String task;            // 'game_item' | 'situational' | 'expert_qa'
  final AiRiskClass risk;
  final String prompt;
  final List<String> contextChunks;   // RAG chunks (expert/situational)
  final String? childAgeBand;         // 'A'|'B'|'C' where relevant
  final List<String> excludeItems;    // anti-repeat (games)
  final int maxTokens;
}

class AiResult {
  final String text;
  final String source;          // 'on_device' | 'cloud'
  final double? confidence;     // if available
  final bool referOutTriggered;
  final List<String> citedCardIds;
}

abstract class AiProvider {
  Future<bool> isAvailable();
  Future<AiResult> generate(AiRequest req);
}
```

### 4.2 Implementations
- `CloudProvider` — calls the existing **`ai-chat` Edge Function** (Mistral + RAG +
  refer-out). **Build now.** This is the only provider at launch.
- `OnDeviceProvider` — calls the OS framework (Apple Foundation Models / ML Kit GenAI).
  **Build in Phase 2+.**

### 4.3 The router (`AiRouter`)
One place decides the brain, per request:

```
1. Pre-screen the request for safety (see §5). If sensitive  → force CloudProvider (red).
2. If task is RED (expert + sensitive)                       → CloudProvider.
3. If OnDeviceCapability != available                        → CloudProvider.
4. If task is GREEN (game top-up)                            → OnDeviceProvider.
5. If task is AMBER (situational / easy expert):
     a. Try OnDeviceProvider.
     b. If confidence low OR retrieval weak OR output fails
        the safety/quality check                              → fall back to CloudProvider.
6. Always run post-answer safety screen (§5) on the result, whichever brain answered.
```

Keep the router **pure and testable** — given a request + capability + confidence, it
returns a provider choice. Unit-test the table.

---

## 5. Safety: refer-out always runs (non-negotiable)

Hard Rule #7 holds **regardless of brain.** On-device must never become a safety
loophole.

### 5.1 Two-stage screening
- **Pre-screen (on the incoming question):** detect the three refer-out categories
  (self-harm/abuse, medical, developmental concern) + off-topic scope. This is cheap
  (keyword/rules + a light classifier) and runs **before** routing.
  - If flagged → **force the cloud path** with the full, already-built refer-out
    handling. On-device never handles a flagged question.
- **Post-screen (on the generated answer):** every answer — on-device or cloud — passes
  an output safety check before display.
  - Cloud answers: existing server-side screen.
  - On-device answers: run a lightweight on-device check; if it's uncertain or the
    answer touches anything sensitive, **discard the on-device answer and re-ask via
    cloud** rather than show an unverified response.

### 5.2 Rules
- The refer-out response itself (the warm "please talk to a professional" redirect) is
  produced by the **cloud path**, so its wording stays consistent and reviewed.
- On-device answers are **never** shown for red-class topics.
- Log refer-out events (metadata only, no child PII) the same way the cloud path already
  does, including which brain was involved.

---

## 6. Confidence & quality gating (for amber routing)

On-device may answer amber tasks **only when it's likely to be good.** Gate on:

- **Retrieval confidence** — if the top RAG chunks are strong/on-topic (above a score
  threshold), an on-device answer grounded in them is acceptable; if retrieval is weak,
  the small model is more likely to drift → cloud.
- **Question simplicity** — short, factual, well-covered "how do I…" questions are fine
  on-device; multi-part, emotional, or nuanced ones → cloud.
- **Self-reported/derived confidence** — if the provider exposes a confidence signal and
  it's low → cloud.
- **Output sanity** — length/format/safety checks; on failure → cloud.

Tune thresholds conservatively at first (more cloud), loosen as you trust on-device.

---

## 7. Data, cost & telemetry

- **No child identifiers to any model** (cloud or on-device) — preserve the existing
  rule that the child's name is never sent. (On-device is inherently more private, but
  keep the rule uniform.)
- **Telemetry (PII-free):** log per answer → `source` (on_device|cloud), task, risk
  class, fell_back (bool), refer_out (bool), latency. This powers an on-device
  **coverage + fallback-rate** dashboard so you can see how much load on-device is
  actually taking.
- **Cost:** on-device = $0 marginal. Cloud stays as-is. Expect on-device to trim cloud
  calls modestly; treat savings as a bonus, not the justification.
- **Offline:** when offline, on-device green/amber tasks still work; red/cloud-only
  tasks show a gentle "I'll need a connection for this one" state (warm, no shame).

---

## 8. Build phasing

**Phase 1 (now, with the core build):**
- Build the `AiProvider` interface + `CloudProvider` + `AiRouter` (router returns Cloud
  for everything today).
- Wire the **pre-screen** so routing is safety-aware from day one.
- Ship. 100% cloud, fully safe, works on every phone.

**Phase 2a — on-device for games (lowest risk):**
- Add capability probe + `OnDeviceProvider`.
- Route **green** game top-ups on-device; measure quality + fallback rate.

**Phase 2b — on-device for situational (amber):**
- Extend to situational scripts with confidence gating + cloud fallback.

**Phase 3 — on-device for easy expert Q&A (most cautious):**
- Only after games + situational are proven. Tight confidence/retrieval gates; sensitive
  always cloud; post-screen always on. Loosen thresholds gradually with the dashboard.

**Never:** on-device for red-class topics; on-device as a hard dependency; bundled giant
models in the shipped app.

---

## 9. Acceptance criteria (per phase, Build-Guide style)

- **Phase 1:** all generation flows through `AiRouter`; swapping in a stub provider
  requires no app changes; pre-screen forces cloud on a sensitive-question battery;
  router table is unit-tested.
- **Phase 2a:** on a capable device, game top-ups generate on-device, offline, with no
  child PII sent; on a non-capable device, the same flow silently uses cloud with no
  user-visible downgrade; fallback rate is logged.
- **Phase 2b/3:** for a sensitive/low-confidence question, the system provably routes to
  cloud and runs full refer-out; for an easy covered question on a capable device, it
  answers on-device and still passes the post-answer safety screen; dashboard shows
  source split + fallback rate.

---

*End of spec. Build the abstraction now, the on-device implementation later, games
first, expert last — and keep the refer-out screen in front of every answer no matter
which brain produced it.*
