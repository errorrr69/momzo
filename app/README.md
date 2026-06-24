# Momzo — Flutter frontend (UI screens)

The complete UI layer for Momzo, built to match the **Momzo UI Design Guide**.
25 screens across 7 feature areas, all wired to a shared theme so the design
system is enforced in code (not hand-tuned per screen).

> Scope: this is the **frontend / presentation layer** — widgets, layout, theme,
> and local interactive state (selections, toggles, navigation). Data, Supabase,
> Edge Functions, AI (RAG), auth, and notifications are intentionally **not**
> here — wire them per `Momzo_PRD.md` + `Momzo_BuildGuide.md`. Sample copy
> (Priya, Aarav) is placeholder content for layout.

## Run it

```bash
cd app
flutter pub get
flutter run
```

The app opens on a **Screen Gallery** (`ScreenGallery` in `lib/main.dart`) that
lists every screen — tap any to preview it. For the real entry flow, change
`home:` in `MomzoApp` to `const WelcomeScreen()`.

Requires Flutter 3.3+ and the `google_fonts` package (declared in `pubspec.yaml`).
Fonts (Nunito Sans + Newsreader) are fetched at runtime by `google_fonts`; for
offline/production, bundle them as assets instead.

## Structure

```
app/
├─ pubspec.yaml
└─ lib/
   ├─ main.dart                      # MaterialApp + screen gallery index
   ├─ core/
   │  ├─ theme/
   │  │  ├─ momzo_colors.dart        # the soft palette (single source of truth)
   │  │  ├─ momzo_text.dart          # Newsreader + Nunito Sans type helpers
   │  │  └─ momzo_spacing.dart       # 4-pt spacing, radii, soft shadows
   │  └─ widgets/
   │     ├─ momzo_buttons.dart       # MomzoButton / .confirm / MomzoSecondaryButton
   │     ├─ momzo_chip.dart          # MomzoChip (filters, tags, intake)
   │     ├─ momzo_bottom_nav.dart    # 5-pillar nav (Home/Learn/Ask/Together/Me)
   │     └─ why_it_matters.dart      # WhyItMatters callout + SourceChip
   └─ features/
      ├─ onboarding/   (01–05)  welcome, sign-in, child basics, temperament, all-set
      ├─ home/         (06)     home · today
      ├─ daily/        (07–09)  card read, slide format, library
      ├─ ai/           (10–13)  ask home, grounded chat, right-now, refer-out
      ├─ activities/   (14–16)  time filter, detail, did-it
      ├─ bonding/      (17–19)  together hub, question reveal, quiz match
      ├─ wishes/       (20–22)  kid wish wall, schedule, calendar
      ├─ timeline/     (23–24)  memory timeline, weekly recap
      └─ reminders/    (25)     reminders & quiet hours
```

This mirrors the `app/lib/features/` layout in `Momzo_BuildGuide.md` §4.

## Design system in code

- **Colours** live only in `MomzoColors`. Never hard-code a hex in a screen —
  add/reference a token so the palette stays consistent.
- **Type** comes from `MomzoText.serif(...)` (emotional) and `MomzoText.sans(...)`
  (everything else). Body never below 15px.
- **Spacing/radius/shadow** from `MomzoSpace` / `MomzoRadius` / `MomzoShadow`.
- **Tone:** copy celebrates small wins and never shames. Keep it that way.

## Notes for wiring up

- Replace placeholder content with real models (`children`, `content_cards`,
  `activities`, `questions`, `wishes`, …) from the PRD §8 data models.
- The AI screens (`ai/`) are presentation only — connect the composer + bubbles
  to the grounded `/ai-chat` Edge Function; keep the `SourceChip` populated from
  `cited_card_ids`, and route safety signals to `ReferOutScreen`.
- `RemindersScreen` toggles are local state — persist to the `users` row
  (`whatsapp_opt_in`, `quiet_hours`) and honour them server-side.
- Kid Mode (`WishWallScreen`) hides the bottom nav by design — gate entry behind
  a parent unlock.
