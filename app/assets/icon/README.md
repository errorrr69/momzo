# App icon

Drop the source artwork here, then regenerate. The five `mipmap-*` PNGs under
`android/app/src/main/res/` are **generated** — never edit them by hand, they get
overwritten.

## What to put here

| File | Size | What it is |
|---|---|---|
| `icon.png` | 1024×1024 | The full icon, artwork edge to edge. Used for older Android and as the fallback. |
| `icon_foreground.png` | 1024×1024 | The same artwork, **smaller and centred**, on a transparent background. |

### Why there are two

Android 8+ masks every icon into whatever shape the launcher likes — circle,
squircle, rounded square — and crops roughly **the outer third**. An icon drawn
edge to edge loses its edges.

So the foreground keeps everything important inside the middle **~66%**: on a
1024px canvas, that is a safe circle about 660px across, centred. The rest is
transparent padding that the mask is free to eat. The background is a flat Momzo
cream (`#FFF7F0`), set in `pubspec.yaml` rather than drawn into the image.

If you only have one image, hand it over anyway — the padded foreground can be
generated from it.

## Regenerating

```bash
cd app
dart run flutter_launcher_icons
```

Then rebuild the app. The icon only changes on reinstall; Android caches it, so
if the old one lingers, uninstall first.

## Worth knowing

- **PNG, square, no transparency in `icon.png`.** Play Store rejects alpha in the
  store listing icon.
- Keep the source files here in git. The generated mipmaps are what ships, but
  these are what they came from.
