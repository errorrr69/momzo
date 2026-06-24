import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'momzo_colors.dart';

/// Two type voices:
///  - Newsreader (serif): emotional headers, quotes, "feel" moments.
///  - Nunito Sans: UI, buttons, labels, body. Body never below 15px.
class MomzoText {
  MomzoText._();

  /// Warm serif. Use [italic] for the softest, most personal moments.
  static TextStyle serif(
    double size, {
    Color color = MomzoColors.ink,
    bool italic = false,
    FontWeight weight = FontWeight.w400,
    double height = 1.3,
  }) =>
      GoogleFonts.newsreader(
        fontSize: size,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: weight,
        height: height,
      );

  /// The workhorse sans.
  static TextStyle sans(
    double size, {
    Color color = MomzoColors.ink,
    FontWeight weight = FontWeight.w600,
    double height = 1.4,
    double spacing = 0,
  }) =>
      GoogleFonts.nunitoSans(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
      );

  /// Uppercase eyebrow / section label.
  static TextStyle eyebrow({Color color = MomzoColors.muted}) =>
      GoogleFonts.nunitoSans(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
      );
}
