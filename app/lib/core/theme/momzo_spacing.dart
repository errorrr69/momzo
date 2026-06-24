import 'package:flutter/material.dart';

/// 4-point spacing scale. Screen padding 22–28px. Breathing room is a feature.
class MomzoSpace {
  MomzoSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard horizontal screen padding.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 24);
}

/// Corner radii.
class MomzoRadius {
  MomzoRadius._();

  static const chip = 22.0;
  static const input = 15.0;
  static const button = 16.0;
  static const card = 22.0;
  static const sheet = 32.0;
}

/// Soft, warm shadows — never harsh.
class MomzoShadow {
  MomzoShadow._();

  static List<BoxShadow> card = [
    const BoxShadow(
      color: Color(0x14342F30), // rgba(61,51,48,.08)
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static List<BoxShadow> soft = [
    const BoxShadow(
      color: Color(0x0F342F30), // rgba(61,51,48,.06)
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static List<BoxShadow> coloured(Color c) => [
        BoxShadow(
          color: c.withOpacity(.32),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
