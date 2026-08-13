# ADR 007 — `AiProvider`/`AiRouter` abstraction now, on-device later

**Status:** Accepted · backfilled 2026-08-13
**Decided:** June 2026 (`Momzo_OnDevice_AI_Strategy.md`)

## Context

On-device AI is attractive for Momzo: a mother's questions about her child would never
leave the phone, and the app would work offline.

But the honest framing in the strategy doc is that on-device buys **privacy and offline
use, not cost** — cloud RAG already costs 1–2¢ per user per month (ADR 003), so there is
nothing meaningful to save. And it cannot be a launch dependency: Gemini Nano via
Android AICore runs only on allowlisted, recent hardware. The large majority of phones
cannot run it at all.

The risk of building it late is a refactor. The risk of building it early is shipping a
safety-critical path on unproven hardware.

## Decision

**Build the abstraction now; light up the implementation later.**

All generation flows through a single risk-aware `AiRouter` that classifies each request
green, amber, or red:

- **Red** (sensitive, expert) → **always cloud**, regardless of device capability.
- **Green / amber** → may use on-device when available, then gated at runtime.

Runtime guards: an amber confidence floor of 0.6; a post-answer safety screen that
discards on-device output looking sensitive and re-asks the cloud; and cloud fallback on
any decline, error, or malformed response. The refer-out screen runs regardless of which
brain answered (ADR 004).

A capability probe over a `MethodChannel` asks Android whether AICore is present, caches
the result, and **degrades to "unavailable" on any error** — a false negative just means
cloud, which is always safe.

## Consequences

**Good.** The seam exists, so enabling on-device is configuration rather than a rewrite.

**Good.** This is the only part of the app with real test coverage — 22 unit tests over
the routing table, the guards, fallback, telemetry, and the native channel contract.

**Good.** On phones without AICore — most of them — everything silently uses cloud. No
user-visible downgrade.

**Cost.** Two code paths to reason about, as the strategy doc predicted. The abstraction
is worth it; the honesty about the trade should be preserved.

**Live gap.** The native bridge returns `confidence: null`, and amber requires ≥ 0.6.
**On-device therefore cannot currently serve anything but green game-item requests** —
every real question falls back to cloud by construction. Live Nano inference is also
still unverified; it needs an allowlisted Pixel 8+ / Galaxy S24-class device.

**Not built.** iOS Foundation Models. There is no iOS target at all.
