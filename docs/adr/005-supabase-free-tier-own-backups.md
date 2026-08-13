# ADR 005 — Run on Supabase Free, and engineer around its two gaps

**Status:** Accepted · backfilled 2026-08-13
**Decided:** June 2026 · documented in `docs/OPERATIONS.md`

## Context

Momzo is pre-launch and pre-revenue. Supabase Pro is ~$25/month for capabilities that a
product with no users does not yet need.

Free has exactly two limitations that matter, and both are operational rather than
functional: **no automated backups**, and **projects pause after roughly seven days of
inactivity**.

Choosing Free without addressing those would not be frugality; it would be an
undiagnosed single point of failure.

## Decision

**Run on Free deliberately**, and mitigate both gaps in CI:

- **Backups** — `.github/workflows/backup.yml` runs daily at 03:17 UTC, taking a full
  compressed `pg_dump` through the **session** pooler (`:5432`, which supports `pg_dump`
  on Free) and storing it as a GitHub Actions artifact with 14-day retention.
  Off-platform, on infrastructure separate from Supabase. Restore is documented.
- **Pausing** — `.github/workflows/keep-warm.yml` pings a trivial REST read every eight
  hours.

**Upgrade triggers are written down in advance** rather than discovered during an
outage.

## Consequences

**Good.** Zero backend cost pre-launch, with a real, tested backup that does not live in
the same account as the thing it protects.

**Cost — accepted.** Logical dumps mean a worst-case data-loss window of up to 24 hours.
That is fine before launch and **is an upgrade trigger once real family data is live**;
Pro adds managed backups and point-in-time recovery.

**Cost.** Keep-warm is mitigation, not a guarantee — GitHub disables scheduled workflows
on repositories inactive for ~60 days.

**Cost.** The nightly job is the one place that connects on `:5432` rather than the
transaction pooler. This is a deliberate exception: `pg_dump` cannot run through the
transaction pooler.

**Named single point of failure.** The Supabase project itself. Mitigated, not
eliminated.
