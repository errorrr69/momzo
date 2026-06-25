# Momzo — Operations (running on Supabase Free)

_Last updated: 2026-06-25_

Momzo runs on the Supabase **Free** tier by deliberate decision. Free has two real
limitations we engineer around here: **no automated backups**, and **projects pause
after ~7 days of inactivity**. This doc is the runbook for both, plus the ceilings
that tell us when to upgrade on purpose (not after an outage).

---

## 1. Backups

**What runs:** `.github/workflows/backup.yml` — a GitHub Actions job, **daily at
03:17 UTC** (and on-demand via *Run workflow*). It takes a full logical dump with
`pg_dump` (custom/compressed format) through the **session pooler** (port 5432,
which supports `pg_dump` on Free tier) and stores it as a **GitHub Actions
artifact** — off-platform, separate from Supabase — with a rolling **14-day
retention** (≈14 daily dumps kept, oldest auto-expire).

**Secrets used** (already in the repo for CI): `SUPABASE_DB_PASSWORD`,
`SUPABASE_POOLER_HOST`. No new credential is needed.

**Trade-off vs Pro:** these are daily logical dumps, so the worst-case data-loss
window is **up to 24h**. That's acceptable pre-launch; once real family data is
live and that window is too large, that's an upgrade trigger (see §3) — Pro adds
managed daily backups + point-in-time recovery.

### Run a manual backup (do this once to confirm it works)
1. GitHub → **Actions** → **DB Backup** → **Run workflow** → branch `main` → **Run**.
2. Wait for the green check, open the run, and confirm an artifact named
   `momzo-<timestamp>.dump` is attached (size > 0).

### Restore a backup
Restoring **overwrites** the target database — only do this intentionally.

1. Download the desired `momzo-<timestamp>.dump` artifact from the Actions run and unzip it.
2. Install a PostgreSQL **17** client locally (`pg_restore`).
3. Restore through the session pooler (replace `<…>` with the values from `supabase/.env`):
   ```bash
   PGPASSWORD='<SUPABASE_DB_PASSWORD>' pg_restore \
     -h '<SUPABASE_POOLER_HOST>' -p 5432 -U 'postgres.nngjqhrxbhugnafyviqj' -d postgres \
     --clean --if-exists --no-owner --no-privileges \
     momzo-<timestamp>.dump
   ```
4. Sanity-check: sign in on the app, confirm the daily card + AI still work, and run
   `cd supabase/tests && npm run integrity` to confirm no dangling references.

> Restoring into a **fresh** project instead? Create the project, set the same
> secrets, run `supabase db push --include-all` first if the schema isn't present,
> then `pg_restore --data-only` from the dump.

---

## 2. Keep-warm (anti-pause)

**What runs:** `.github/workflows/keep-warm.yml` pings the REST API **every 8 hours**
with the anon key (a `limit=1` select that touches Postgres). Regular app traffic
already keeps us warm; this covers quiet stretches.

**This is a mitigation, not a guarantee.** GitHub itself delays or disables
*scheduled* workflows when the **repository** goes inactive (~60 days), and Supabase
can still pause under conditions outside a simple ping. If the project does pause:
it's not data loss — open the Supabase dashboard (or make any request) and it
**unpauses**; the daily backup still protects the data regardless.

---

## 3. Free-tier ceilings & when to upgrade

Upgrade **deliberately** when any of these approaches its trigger — don't wait for an
outage. (Plan stays Free until then.)

| Resource | Free ceiling | Upgrade trigger (~80%) | Notes for Momzo |
|---|---|---|---|
| Database size | 500 MB | **~400 MB** | First to watch — content + embeddings + family rows. |
| Edge Function invocations | 500K / mo | **~400K / mo** | Every AI turn + each reminder dispatch counts. |
| Egress / bandwidth | 5 GB / mo | **~4 GB / mo** | Card/image payloads dominate. |
| File storage | 1 GB | **~800 MB** | Only once photo Storage is added (#16). |
| Monthly active users (Auth) | 50,000 | **~40,000** | Far off early on. |
| Realtime connections | 200 concurrent | sustained near 200 | Not heavily used yet. |
| Active projects | 2 | — | We use 1. |

**Hard upgrade triggers (independent of usage %):**
- Real family PII is live **and** a ≤24h backup window is no longer acceptable → upgrade for **managed backups + PITR**.
- The connection-pool graph runs near its limit under load (run the §9 load sanity check before launch).
- A paid-tier requirement lands (e.g. the pre-launch checklist's data-retention/SLA needs).

**Likely order Momzo hits them:** database size → Edge Function invocations → egress.
Watch those three on the Supabase dashboard monthly.
