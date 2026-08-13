## What this changes

<!-- One or two sentences. What does a mother get, or what breaks less? -->

---

## Extension protocol

The checklist from `Momzo_Architecture_Plan.md` §9. Tick what applies; strike through
what doesn't (`~~n/a~~`). **Don't delete rows** — a visible "n/a" is a decision, a
missing row is an oversight.

### 1. Boundary
- [ ] Names which tiers this touches: app / Edge Function / database / external service
- [ ] **New external service?** → an ADR was written **first** (`docs/adr/`)

### 2. Data
- [ ] New tables declare their RLS pattern at design time — **family-isolated** or
      **shared-content**. A third pattern needs its own ADR (rule 4)
- [ ] Added to the right bucket in `supabase/tests/rls_cross_family.test.mjs`
      (`FAMILY_TABLES` / `SHARED_TABLES` / `SERVER_ONLY_TABLES`) — *the coverage guard
      fails the build otherwise*
- [ ] Every policy column is indexed (rule 5)
- [ ] **Holds child data?** → joined the delete-child cascade **in this PR**
      (`child_id … references children(id) on delete cascade`) and the zero-residual
      test extended (rule 6)
- [ ] Schema changes are in `supabase/migrations` — never hand-edited in the dashboard
      (Hard Rule #19)
- [ ] **Realtime?** Only `question_responses` is published. Adding a table needs an ADR
      (rule 7)

### 3. Interfaces
- [ ] Exposed through a service — no feature imports the Supabase or http client
      directly (rule 1)
- [ ] Edge Function contract documented, if any
- [ ] Anything needing a secret is server-side. The app holds the anon key only (rule 3)

### 4. Views
- [ ] **Does this change a boundary, component, or flow?**
      → **`docs/architecture.md` updated in this PR.** Not the next one.
- [ ] New architectural decision → an ADR added to `docs/adr/`

### 5. Cost
- [ ] Any LLM call routes through `AiRouter` and appears in the approved call-site list
      (`check_llm_call_sites.mjs` enforces this)
- [ ] Per-user cost estimated against the targets in `Momzo_AI_Cost_Strategy.md`

### 6. Safety & tone
- [ ] Child data minimised — no free text, audio, or camera unless the feature needs it
- [ ] The refer-out path is unaffected, and **still runs before any cost control**
- [ ] No child identifier reaches any model
- [ ] Copy is warm and never shaming — **including error and empty states** (Hard Rule #18)

### 7. Tests
- [ ] RLS tests, **positive and negative** (non-author can't edit; non-moderator can't hide)
- [ ] Idempotency covered, if anything is scheduled
- [ ] Verified on a real device, if it's user-facing

---

## Verification

<!-- What did you actually run, and what did it say? "CI is green" is fine if CI covers
     it. If something could not be verified — no secrets locally, no device to hand —
     say so plainly rather than leaving it implied. -->

## Risk

<!-- What could this break, and how would we notice? "Nothing" is a valid answer for a
     docs-only change. -->
