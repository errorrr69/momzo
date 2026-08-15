# Bundled learning games

This is a **build artifact**, not source. It is the compiled output of
`errorrr69/games-for-5-6yr-olds`, vendored here so the 22 learning games run
offline inside Momzo's WebView with no hosting and no network (ADR 008, ADR 009).

Do not edit anything in `assets/` or `index.html` by hand — the next rebuild
overwrites it. Game changes belong in the games repo.

## What is here

```
index.html                 entry point; loads the two files below (RELATIVE paths)
assets/index-*.js          the whole SPA, ~447 kB
assets/index-*.css         ~52 kB
```

Roughly half a megabyte in total. Art in these games is drawn as code (SVG
components), not shipped as images, which is why 22 games fit in so little.

## Regenerating

```bash
cd <games-repo>
git checkout feat/together-mode      # until it lands on main
npm ci && npm run build
cp -r dist/. <momzo>/app/assets/games/
```

Then rebuild the Flutter app. A game tweak therefore costs an app release —
accepted at the current cadence (ADR 008). `learning_games.entry_path` is the
abstraction that would absorb a hosted path later without a schema change.

## Two things the games repo does specifically for this

Both are invisible until they break, and both fail as a blank screen:

- **`base: './'`** in `vite.config.ts` — relative asset paths. The Vite default
  emits `/assets/...`, which under `file://` resolves to the filesystem root.
- **Router chosen by protocol** in `main.tsx` — `HashRouter` under `file://`,
  `BrowserRouter` over http(s). `file://` has no History API, so BrowserRouter
  cannot route. Doing it by protocol keeps one build serving both, and leaves
  the live teaching URLs (`/teacher`, `/join/ABCD`) unchanged.

## Provenance

| | |
|---|---|
| Source | `errorrr69/games-for-5-6yr-olds` |
| Branch | `feat/together-mode` |
| Commit | `72c77f8` |
| Built | 2026-08-15 |

Update this table whenever the bundle is regenerated — it is the only record of
which game code actually shipped in a given app release.
