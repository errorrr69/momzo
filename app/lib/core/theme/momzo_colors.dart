import 'package:flutter/material.dart';

/// Momzo palette — soft, warm, happy. Never pure black, dark UIs, or neon.
/// See the UI Design Guide, section 02 · Colour.
class MomzoColors {
  MomzoColors._();

  // Neutrals
  static const cream = Color(0xFFFFF7F0); // app canvas
  static const creamWarm = Color(0xFFFBF1E7);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF3D3330); // headings
  static const body = Color(0xFF6B5D55); // body text
  static const muted = Color(0xFF9C8E85); // meta / placeholder
  static const faint = Color(0xFFB6A89D);
  static const hairline = Color(0xFFF0E6DC);
  static const cardBorder = Color(0xFFEFE4D8);

  // Primary / action
  static const coral = Color(0xFFEC8366);
  static const coralDeep = Color(0xFFC26A4D);
  static const coralText = Color(0xFF8A5742);
  static const coralTint = Color(0xFFFBE3D8);

  // Feature accents
  static const honey = Color(0xFFF2B441); // Learn
  static const honeyTint = Color(0xFFFCEFD0);
  static const honeyText = Color(0xFF9A7424);

  static const sage = Color(0xFF84B89A); // Activities / confirm
  static const sageTint = Color(0xFFE2F0E4);
  static const sageText = Color(0xFF4E7A60);

  static const lavender = Color(0xFFA593D6); // Bonding
  static const lavenderTint = Color(0xFFECE6F8);
  static const lavenderText = Color(0xFF6A5A9C);

  static const sky = Color(0xFF8FC7D6); // AI expert
  static const skyTint = Color(0xFFE4F0F4);
  static const skyText = Color(0xFF2E6675);
}
