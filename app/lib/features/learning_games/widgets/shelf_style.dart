import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../models/learning_game.dart';

/// Momzo's accent per learning-games shelf.
///
/// Reuses the palette the rest of the app already assigns by pillar, so a shelf
/// feels like part of Momzo rather than a visiting product: Honey for maths,
/// Sage for reading, Coral for feelings, Lavender for focus (Expansion Plan §3.1).
class ShelfStyle {
  final GameShelf shelf;
  final Color accent;
  final Color tint;
  final Color text;

  const ShelfStyle._(this.shelf, this.accent, this.tint, this.text);

  static const _maths = ShelfStyle._(
      GameShelf.maths, MomzoColors.honey, MomzoColors.honeyTint, MomzoColors.honeyText);
  static const _reading = ShelfStyle._(
      GameShelf.reading, MomzoColors.sage, MomzoColors.sageTint, MomzoColors.sageText);
  static const _feelings = ShelfStyle._(
      GameShelf.feelings, MomzoColors.coral, MomzoColors.coralTint, MomzoColors.coralText);
  static const _focus = ShelfStyle._(
      GameShelf.focus, MomzoColors.lavender, MomzoColors.lavenderTint, MomzoColors.lavenderText);

  /// Unknown categories fall back to maths rather than throwing — a new shelf
  /// added as data must never crash a screen that predates it.
  static ShelfStyle of(String category) => switch (category) {
        'reading' => _reading,
        'feelings' => _feelings,
        'focus' => _focus,
        _ => _maths,
      };

  static ShelfStyle forShelf(GameShelf shelf) => of(shelf.key);
}
