# Momzo

A few cozy minutes a day to understand your child better — and feel closer to them.
Flutter + Supabase mobile app for busy mothers of 6–10 year-olds.

> Planning, scope, and the build sequence live in **Taskmaster** (`.taskmaster/`).
> Run `task-master list` / `task-master next`. The authoritative specs are in
> [`docs/`](docs/): `Momzo_PRD.md` (what) and `Momzo_BuildGuide.md` (how + the
> non-negotiable §6 Hard Rules).

## Monorepo layout (Build Guide §4)

```
momzo/
├─ app/                    # Flutter app (iOS + Android) — the UI source of truth
│  └─ lib/
│     ├─ features/         # one folder per feature (25 screens, already designed)
│     ├─ core/             # supabase client, theme, routing, env, push
│     ├─ models/           # Dart models matching the DB
│     └─ services/         # API wrappers (Supabase / Edge Functions)
├─ supabase/
│  ├─ migrations/          # SQL: schema + RLS + indexes (source of truth, Task 3)
│  ├─ functions/           # Edge Functions (Deno) — hold ALL secrets
│  └─ seed/                # seed content_cards, activities, questions, embeddings
├─ docs/                   # PRD, Build Guide, UI design guide
└─ .github/workflows/      # CI: app analyze/test, migrations, RLS test, deploy
```

## Architecture in one line

The app reads/writes its **own family's data directly** against Supabase
(fast, RLS-protected, anon key only). Anything needing a secret key, a paid
third party, or a schedule goes through a **stateless Edge Function** on the
transaction pooler (port 6543). The app never holds the `service_role` key, an
LLM key, a WhatsApp token, or the FCM server key.

## Running the app

The app boots to a **screen gallery** (all 25 screens) and runs UI-only with no
backend. To connect Supabase, supply the anon key at build time:

```bash
cd app
cp env.example.json env.json   # then paste the anon key (git-ignored)
flutter pub get
flutter run --dart-define-from-file=env.json
```

## Secrets

- `app/env.json` — Supabase **anon** key only (client).
- `supabase/.env` — server-side secrets (service_role, Gemini, FCM, WhatsApp).
- Neither is committed. See `app/env.example.json` and `supabase/.env.example`.
