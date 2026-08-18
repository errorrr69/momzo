import 'package:flutter/material.dart';

/// Momzo palette — warm, bright, kind at 8:40pm. Never pure black, dark UIs,
/// or neon. See `docs/Momzo_UX_Redesign_Plan.md` §5.
///
/// Three rules hold this together, and breaking them is what makes an app tiring
/// to look at rather than cheerful:
///
///  1. **The canvas stays calm.** [cream] and white carry every reading surface.
///     Brightness lives AROUND the reading, never behind it.
///  2. **Brights decorate; deeps carry text.** The accent (`coral`, `honey`, …)
///     is a fill, an icon, a chip. White text on a bright fill does not reach
///     WCAG AA at body sizes, so anything text-bearing uses the `*Deep` variant,
///     and everything else is ink-on-tint. `theme_contrast_test.dart` pins this.
///  3. **Colour is wayfinding.** One accent per tab — Home coral, Learn honey,
///     Ask sky, Play lavender, Circle mint — used on that tab's door, its active
///     state and its headers, and nowhere else. She learns the map without being
///     told, which costs her nothing.
class MomzoColors {
  MomzoColors._();

  // Neutrals -----------------------------------------------------------------
  static const cream = Color(0xFFFFF9F2); // app canvas
  static const creamWarm = Color(0xFFFBF1E7);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF3D3330); // headings
  static const body = Color(0xFF6B5D55); // body text
  static const muted = Color(0xFF9C8E85); // meta / placeholder
  static const faint = Color(0xFFB6A89D);
  static const hairline = Color(0xFFF0E6DC);
  static const cardBorder = Color(0xFFEFE4D8);

  // Home · primary action ----------------------------------------------------
  static const coral = Color(0xFFFF7A5C); // "Sunset"
  // Carries WHITE text, so it is set by contrast rather than by taste: 4.64:1,
  // clearing AA at button sizes. The old sage-era coralDeep managed only 3.83
  // and had been failing quietly since launch.
  static const coralDeep = Color(0xFFCE4623);
  static const coralText = Color(0xFF9A4B2E); // ink-weight, for coralTint
  static const coralTint = Color(0xFFFFE4DC);

  // Learn --------------------------------------------------------------------
  static const honey = Color(0xFFFFB020); // "Marigold"
  static const honeyTint = Color(0xFFFFF0CE);
  static const honeyText = Color(0xFF8A5B00);

  // Circle · confirmations ---------------------------------------------------
  // Was "sage", and greener now: the Circle is people, alive, growing. It keeps
  // the old name so nothing downstream has to be renamed in the same pass.
  static const sage = Color(0xFF4FC69A); // "Fresh mint"
  static const sageTint = Color(0xFFDCF6EB);
  static const sageText = Color(0xFF1F6E52);

  // Play · bonding -----------------------------------------------------------
  // Lightened from A98BF5, which put ink-on-fill at 4.49 — a hair under AA for
  // a door that carries a label.
  static const lavender = Color(0xFFB79BF7); // "Lilac"
  static const lavenderTint = Color(0xFFEDE6FE);
  static const lavenderText = Color(0xFF5B3FA8);

  // Ask ----------------------------------------------------------------------
  static const sky = Color(0xFF4FC3E8); // "Clear sky"
  static const skyTint = Color(0xFFDCF2FA);
  static const skyText = Color(0xFF14607A);

  // The win moment -----------------------------------------------------------
  /// Reserved for something that went well — the dashboard's closing line, a
  /// quiz reveal. Deliberately scarce: a colour that means "good" only keeps
  /// meaning it if it is not used for decoration.
  static const sunshine = Color(0xFFFFE9A8);
  static const sunshineText = Color(0xFF7A5B00);
}
