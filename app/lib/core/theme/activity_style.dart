import 'package:flutter/material.dart';
import 'momzo_colors.dart';

/// Maps an activity `skill` to its visual identity (emoji, chip label, colours)
/// so the list and detail screens stay consistent.
class SkillStyle {
  final String emoji;
  final String label;
  final Color tint;
  final Color textColor;
  final List<Color> gradient;
  const SkillStyle(this.emoji, this.label, this.tint, this.textColor, this.gradient);

  static SkillStyle of(String? skill) {
    switch (skill) {
      case 'regulation':
        return const SkillStyle('🌬️', 'Calm', MomzoColors.sageTint, Color(0xFF4E7A60),
            [Color(0xFFA6D6C2), MomzoColors.sage]);
      case 'confidence':
        return const SkillStyle('⭐', 'Confidence', MomzoColors.honeyTint, MomzoColors.honeyText,
            [Color(0xFFFAD9A6), MomzoColors.honey]);
      case 'connection':
        return const SkillStyle('🤝', 'Connect', MomzoColors.lavenderTint, MomzoColors.lavenderText,
            [Color(0xFFC9B6EC), MomzoColors.lavender]);
      case 'literacy':
        return const SkillStyle('📚', 'Reading', MomzoColors.skyTint, MomzoColors.skyText,
            [Color(0xFFAEDCE8), MomzoColors.sky]);
      case 'behavior':
        return const SkillStyle('🧩', 'Behavior', MomzoColors.coralTint, MomzoColors.coralText,
            [Color(0xFFF7C9B8), MomzoColors.coral]);
      default:
        return const SkillStyle('🎨', 'Play', MomzoColors.honeyTint, MomzoColors.honeyText,
            [Color(0xFFFAD9A6), MomzoColors.honey]);
    }
  }
}
