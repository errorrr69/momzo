# ADR 001 — Flutter + Supabase + Edge Functions

**Status:** Accepted · backfilled 2026-08-13
**Decided:** June 2026 (Build Guide §1–§2)

## Context

Momzo is built by one founder working with an AI coding assistant, targeting a phone
app for mothers. The product needs auth, a relational database, file storage, scheduled
jobs, vector search for RAG, and push — on a budget of roughly zero before launch.

Running a conventional API server would mean writing and operating an auth layer, an
ORM, a job runner, and a deployment story, all of which are undifferentiated work for a
product whose value is warm content and a safe AI expert.

## Decision

**Flutter** for a single mobile codebase, and **Supabase** as the entire managed
backend: Postgres 17, Auth, Storage, Realtime, Edge Functions, `pg_cron`, `pgvector`.

The app talks to Postgres **directly** for ordinary reads and writes, holding only the
anon key, with Row-Level Security as the access control. Anything requiring a secret, a
paid third party, or a schedule goes through a **stateless Edge Function**.

The app never holds the `service_role` key, an LLM key, or FCM credentials.

## Consequences

**Good.** No API tier to write or operate. Auth, storage and realtime arrive working.
The security boundary is one thing — RLS — rather than scattered endpoint checks, which
is far easier for a small team to reason about and test exhaustively.

**Cost.** Correctness now depends entirely on RLS being right, which is why ADR 002 and
the cross-family test suite exist. A policy mistake is a data breach, not a bug.

**Cost.** Edge Functions must connect through the transaction pooler (`:6543`, prepared
statements off). Serverless invocations against a direct connection would exhaust
Postgres connections under load.

**Cost.** Business logic is split between Dart services and Deno functions. The rule
that keeps this coherent: if it needs a secret or must not be client-trusted, it is a
function; otherwise it is a service.

**Constraint.** iOS is not built (no `ios/` target). Flutter makes it possible later; it
needs a paid Apple account and APNs.
