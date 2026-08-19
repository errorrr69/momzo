# Momzo — UX Redesign Plan: five doors, one tired mother

**Version:** v1.1 · August 2026 · **Status: BUILT** (18 Aug 2026) and verified on device.
Deviations from the plan as written are recorded in §8.
**Resolves:** Expansion Plan §2.5/§6.1 (the Option A/B nav decision) — this plan **is Option A**, adapted.
**Companions:** `Momzo_PRD.md`, `Momzo_Expansion_Plan.md`, Hard Rule #18 (warm, zero shame)

---

## 0. The person this is for

Every decision below is tested against one picture: it is 8:40pm, she has been
"on" since 6am, the child is finally down, and she has eleven minutes and half a
brain left. She did not open the app to explore it. She opened it because it has
been good to her before.

Three rules fall out of that picture, and they outrank aesthetics:

1. **The app decides, she confirms.** Never present a menu where a suggestion
   would do. Home's job is to have already chosen tonight's one thing.
2. **Nothing she loves is more than one tap from open.** Depth is where features
   go to die for a tired user. If we're proud of it, it gets a door.
3. **Recognition beats recall.** Same place, same colour, same words, every day.
   She should navigate on muscle memory, because that costs no brain.

---

## 1. What's wrong today (measured, not guessed)

The four headline features live at four different depths. This is the core
problem — the things we want her to love are the things she has to dig for:

| Feature | Today's path | Taps from open |
|---|---|---|
| Daily read card | Home hero | **0** ✓ |
| AI chat ("Ask") | Ask tab | 1 ✓ |
| **Learning games** | Together → scroll → Learning games | **2 + scroll** ✗ |
| **The Circle** | Together → scroll → The Circle | **2 + scroll** ✗ |
| **Florie's posts** | Learn → scroll past saved + 7 shelves | **1 + long scroll** ✗ |
| Mini-games / quiz / wish wall | Together → row | 2 |
| Reminders & profile | Me tab | 1 (overpriced — see below) |

Other findings from using it on the device this week:

- **Together is a junk drawer.** Seven destinations in one list (question of the
  day, quiz, wish wall, mini-games, learning games, Circle, calendar). A tired
  reader parses that list every single visit. The two most valuable things in
  the app are items 5 and 6 of 7.
- **Me is a wasted prime slot.** A permanent bottom-nav tab — the most expensive
  real estate in the app — currently holds reminders and settings, which she
  touches maybe once a week.
- **Florie's posts sit below the fold** of a screen whose top half is about
  something else. The freshest content in the app (she posts to social several
  times a week) is the least visible.
- The palette is warm but **dusty** — everything is a tint of beige. Nothing
  says "this is the fun part" because nothing is allowed to be louder than
  anything else.

---

## 2. The new shape: five doors

**Home · Learn · Ask · Play · Momzo** — Me moves to the avatar in the Home
header. (The fifth door was the Circle when this plan was written; see §9.)

Each tab is one *promise*, nameable in her words:

| Tab | Her words for it | Accent |
|---|---|---|
| **Home** | "What's for me today" | coral |
| **Learn** | "The library" | honey |
| **Ask** | "Help, right now" | sky |
| **Play** | "Things to do with her" | lavender |
| **Momzo** | "What Florie has been saying" | mint |

This is the Expansion Plan's own Option A recommendation, finally taken. The
change is almost entirely *promotion*: games and Florie's posts stop being rows
inside Together and Learn, and become doors.

### 2.1 Tap-depth after

| Feature | New path | Taps |
|---|---|---|
| Daily read | Home hero | 0 |
| AI chat | Ask tab, **plus a Home shortcut** | 1 / 1 |
| Learning games | Play tab, first thing | **1** |
| Florie's posts | Momzo tab | **1** |
| Quiz / wish wall / mini-games | Play tab, below games | 2 |
| Calendar | Play tab row + Home "coming up" card when non-empty | 2 |
| Reminders, profile, children, sign out | Avatar → Me sheet | 2 |

Reminders getting *deeper* is deliberate: frequency should buy depth, and
settings are weekly at best. Everything she touches daily is now ≤1.

---

## 3. Screen by screen

### 3.1 Home — the screen that already decided

Order, top to bottom. **One decision above the fold** (read the card or not);
everything else is a shortcut, not a question.

1. **Greeting + child switcher + avatar** (avatar = the new Me door).
2. **Daily card hero** — unchanged; it works and it's verified.
3. **The doors row** — three large, thumb-height, colour-coded buttons:
   *Ask Momzo* · *Play together* · *The Circle*. These duplicate the tabs on
   purpose: at 8:40pm she looks at the middle of the screen, not the bottom.
4. **"Tonight" card** — the daily card's *activity* line surfaced as its own
   tiny card ("Try tonight: …"). One thing, pre-chosen, rule 1 made visible.
   Replaces the current "Need help right now? / I've got 10 minutes" pair —
   those two migrate into the doors row (Ask) and Play respectively.
5. **"Coming up" card** — only renders when a together-time is scheduled.
   Absent, not empty (same principle as the games area's age gating).

What Home never gets: a feed, a carousel of features, badges, or anything that
scrolls horizontally. Horizontal scroll is hidden content, and hidden content
is homework.

### 3.2 Momzo — Florie's voice, one tap away

**Answering the direct question: yes, the social-media posts can appear here,
and the plumbing already exists.** The Content Hub (`social_posts`, seeder,
feed widget, reader) is built and on-device-verified — it's just parked at the
bottom of Learn. This plan *moves* it, no new backend needed. The v2 auto-sync
(publish to Instagram → appears in-app via the Graph API) is already designed
for in the schema and stays a fast-follow.

As built, this tab was one screen with a two-chip switch: **From Momzo** (the
feed, default) and **The mothers** (the forum). The forum has since been removed
(§9), so the feed is the whole tab: the typographic posts, newest first, tag
chips, the 💛.

**The cold-start reasoning survived its own conclusion.** The argument for
leading with Florie's feed was that a forum tab opening onto three quiet
categories reads as a dead app, while she posts several times a week. That was
right, and it turned out to be the whole answer rather than half of it — the
half that guaranteed the tab was alive was the only half doing work.

Learn loses the feed and becomes purely the library — cleaner promise, shorter
scroll, no loss (the feed is one tab away with a better address).

### 3.3 Play — everything she does *with* the child

Order matters: dashboard first only when there's something to say, games always
visible without scrolling past analytics.

1. **"How it's going"** — collapsed to its win line + "see more" when she has
   played before; the full dashboard on tap. Absent entirely for a new user
   (warm empty state stays inside the expanded view).
2. **Learning games shelves** — the four categories, as built.
3. **Together row** — quiz, wish wall, mini-games, question of the day, calendar
   as compact cards. The question of the day keeps its slot at the top of this
   block; it's the only time-sensitive item.

The Together tab name retires. "Play" is shorter, warmer, and honest — every
single thing on this screen is play.

### 3.4 Ask — unchanged, plus one promise made visible

The chat works and is verified. Two small things:

- A permanent, quiet reassurance line under the title: *"Private to you.
  Momzo's own advice, written for mothers of 5–6-year-olds."* — trust is the
  barrier to first use, not discoverability.
- The "Need help right now?" situational entry moves here from Home (it *is*
  this tab's job).

### 3.5 Learn — just the library now

Saved-by-you, then the seven shelves. Nothing else. The screen's promise
becomes one sentence: "everything Momzo has written, by topic."

### 3.6 Me — a sheet, not a tab

Avatar (top-right, Home) opens a bottom sheet: profile, children (add /
manage / the delete-child entry point that currently has **no door at all** —
this fixes a known caveat), reminders, notification prefs, Circle name,
sign out. Low frequency, two taps, fine.

---

## 4. The brain-budget rules (apply to every screen, now and later)

1. **The 3-second test.** Glance at any screen for 3 seconds: can she say what
   it's for and what to tap? If not, it has too many ideas.
2. **One decision above the fold.** Suggestions, not menus. The app has
   already chosen; she can override by scrolling.
3. **Depth = frequency.** Daily things: ≤1 tap. Weekly: ≤2. Rare: settings
   sheet. Never promote by "importance to us" — only by her frequency.
4. **Absent, not empty.** A section with nothing to say doesn't render (games
   age-gate and "coming up" already do this; make it universal).
5. **Colour is wayfinding, not decoration.** One accent per tab, used on that
   tab's door, its active state, and its headers — nowhere else. She learns
   "honey = library" without being told.
6. **Same words everywhere.** If the tab says "Play", the Home door says
   "Play together", not "Bonding games". No synonyms — synonyms are homework.
7. **Thumb rule.** Primary actions live in the lower half. She's one-handed;
   the other hand has a child in it.
8. **No streak pressure, no badges, no red dots** except the moderation flag
   for moderators. Notification dots are a to-do list; she has enough of those.

---

## 5. Colour — brighter, still kind at 8:40pm

Direction: **keep the cream canvas calm, let the accents actually sing.** The
current accents are all dusted with grey; the fix is chroma, not neon. Bright
colours arrive as *doses* — doors, icons, chips, active states, ~10–20% of any
screen — never as flooded backgrounds, which are exhausting on OLED at night.

### 5.1 Proposed palette (current → proposed)

| Token | Now | Proposed | Name | Used for |
|---|---|---|---|---|
| cream | `#FFF7F0` | `#FFF9F2` (touch lighter) | Cream | canvas — stays calm |
| ink / body / muted | unchanged | unchanged | — | all reading text |
| **coral** | `#EC8366` | **`#FF7A5C`** | Sunset | Home, primary buttons, hero |
| coralDeep | `#C26A4D` | `#E85D3D` | — | text-bearing coral surfaces |
| **honey** | `#F2B441` | **`#FFB020`** | Marigold | Learn |
| **sky** | `#8FC7D6` | **`#4FC3E8`** | Clear sky | Ask |
| **lavender** | `#A593D6` | **`#A98BF5`** | Lilac | Play |
| **sage → mint** | `#84B89A` | **`#4FC69A`** | Fresh mint | Circle, confirmations |
| tints | all | re-derived at ~92% lightness of each accent | — | chips, callout backgrounds |
| *new:* sunshine | — | `#FFE9A8` | Sunshine | the "win" moment only — dashboard win card, quiz reveal |

Sage moves from "activities" to the Circle: green = people/alive/growing reads
naturally, and Play takes lavender (already the bonding colour). One accent
gains a job, none are added — five tabs, five colours, still learnable.

### 5.2 Non-negotiable guardrails

- **Brights decorate; deeps carry text.** White text goes on the deep variants
  (`coralDeep` etc.), never on the bright fills — the brights don't reach WCAG
  contrast for small text and we don't pretend otherwise. Ink-on-tint for
  everything else.
- Reading surfaces (daily card body, post reader, threads) stay
  cream/white + ink. Brightness lives around the reading, never behind it.
- The `*Text` tokens (coralText, honeyText…) get re-derived and contrast-checked
  against the new tints before shipping — a widget test can assert ratios.
- Check the whole set on the real phone at low brightness before committing;
  OLED saturates and what's cheerful on a monitor can be loud in a dark bedroom.

---

## 6. What this costs (implementation notes, for when we build)

Honest scope — this is mostly *moving furniture*, not building:

| Change | Effort | Notes |
|---|---|---|
| 5-tab shell + icons + colours | small | `main_shell.dart`, `momzo_bottom_nav.dart` |
| Circle tab with From-Momzo / mothers chips | small | relocate `ContentHubSection`; both halves already built + tested |
| Play tab | small-medium | promote learning games + together rows out of `together_hub_screen` |
| Home doors row + Tonight card | medium | new widgets; remove the two old quick cards |
| Me sheet + delete-child door | small | mostly moving `RemindersScreen` content |
| Palette swap | small | one file + re-derived tints; then a device pass |
| Contrast guard test | small | pins §5.2 so it can't decay |
| Copy pass (same-words rule) | small | audit strings against §4.6 |
| Post → thread hook ("Talk about this in the Circle") | medium | the one genuinely new feature in this plan |

Existing tests that will need touching: `card_structure_test` (untouched),
shell/navigation tests (new), `how_its_going_test` (collapsed state). The RLS
suite is untouched — nothing here changes data access.

**Suggested build order:** palette (instant win, zero risk) → shell + Circle
tab (the headline) → Play tab → Home doors + Tonight → Me sheet → post-thread
hook.

---

## 7. Open choices for Florie (small, and defaults are fine)

1. **Tab names:** "Play" vs "Together" for the fourth tab. Plan says Play.
2. **Circle default chip:** From Momzo first (plan's recommendation, cold-start
   logic) or mothers first from day one.
3. **Colour intensity:** the §5.1 set, or a half-step gentler. Decide on the
   phone, not on a laptop.
4. Does the question of the day stay in Play (plan) or earn a Home slot on days
   it's unanswered?

---

*The test for every future feature request stays the same: which door does it
live behind, what does it displace, and can she find it at 8:40pm with half a
brain? If there's no good answer, it doesn't ship.*

---

## 8. What changed during the build

Three things came out different, all found by using it on a real phone.

1. **Doors moved above TRY TONIGHT.** §3.1 listed doors third and Tonight
   fourth; I built it the other way round, and the hero card is tall enough that
   the doors fell off the bottom of the screen — the exact failure they exist to
   fix. The plan's order was right. Tonight is also capped at three lines now: it
   is a nudge, not the content.

2. **Two proposed colours were wrong, and one guardrail was measuring the wrong
   thing.** `theme_contrast_test.dart` rejected lavender `#A98BF5` (ink-on-fill
   4.49, a hair under AA for a labelled door) and coralDeep `#E85D3D` (white text
   3.46). Both were corrected rather than the bars lowered. The third failure was
   my own invented "fill vs cream ≥ 2.0", which honey and sky could only pass by
   becoming muddy — replaced with the requirement that actually binds, ink-on-fill
   ≥ 4.5, plus a modest floor. The final palette is in `momzo_colors.dart`.

   That guard also caught a **pre-existing** fault: white-on-coralDeep had been at
   3.83:1 since launch and never cleared AA on any primary button.

3. **Two pushed screens were rendering a bottom tab bar** (Memory Timeline,
   Calendar). A tab bar on a stacked route claims to be a tab while having a back
   button — two navigations arguing. Removed.

**Also shipped, unplanned but adjacent:** the Me sheet gave `DeleteChildScreen`
an entry point. It had existed for months with no way to reach it from inside the
app, which BUILD_STATUS listed as a known gap.

**Tests added:** `navigation_test.dart` (the five doors, their order, one colour
each, no badges) and `theme_contrast_test.dart` (§5.2, 33 assertions). 136 total,
up from 94.

**Still open — §7's four choices are unchanged and all defaults are in place:**
"Play" as the fourth tab name, From Momzo as the Circle's default chip, the
current colour intensity, and the question of the day living in Play. Worth a
look on your own phone at low brightness before any of them is settled.

---

## 9. The Circle: switched off, then removed (19 Aug 2026)

On 18 Aug the forum went behind `FeatureFlags.circle = false` — built, tested,
device-verified, simply not shown. On 19 Aug it was removed from the app
outright: `features/circle/`, the model, the service, the seeders and the flag
itself are all gone. The database tests stayed, because the tables did.

**What did not go is Florie's posts.** They share that tab, and burying them
again would undo this plan's main win — they went from "1 tap plus a long scroll
past seven shelves" to "1 tap" precisely because they moved there. So the fifth
door stayed and became what it now only ever was:

- the tab is **"Momzo"**, opening on `PostsScreen` — the header plus the feed
- Home's third door reads **"From Momzo"** and leads to the same place, because
  §4.6 says a thing must not have two names
- the two chips, the moderator flag, the three forum queries, the Me sheet's
  "Your Circle name" row and "Talk about this in the Circle" all went with the
  forum; each of them existed only to point at it
- mint stays the fifth door's accent, and the `sage` token keeps its name

`navigation_test.dart` no longer tracks a flag; it asserts the fifth door is
named "Momzo" and, separately, that removing the forum did not remove the posts.

**Not removed: the database.** Seven `forum_*` tables, their policies, the
auto-hide trigger and `is_moderator()` are still there holding demo threads, and
three applied migrations reference them. Nothing in the app reads any of it.
Dropping them is destructive and deliberately left as a separate decision.
