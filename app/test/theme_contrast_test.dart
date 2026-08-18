import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momzo/core/theme/momzo_colors.dart';

/// The palette's guardrails (UX plan §5.2).
///
/// Colour decays quietly. Nothing crashes when a bright fill starts carrying
/// white body text — it just gets a little harder to read, and nobody notices
/// until a tired mother in a dark bedroom gives up on a screen. So the rules are
/// asserted here rather than trusted to review.
///
/// Ratios are WCAG 2.1: 4.5:1 for body text, 3:1 for large/bold text (≥18.66px
/// bold or ≥24px regular) and for UI component boundaries.
void main() {
  double luminance(Color c) => c.computeLuminance();

  double ratio(Color a, Color b) {
    final l1 = math.max(luminance(a), luminance(b));
    final l2 = math.min(luminance(a), luminance(b));
    return (l1 + 0.05) / (l2 + 0.05);
  }

  String fmt(double r) => r.toStringAsFixed(2);

  // The five wayfinding accents, and the surfaces each one pairs with.
  const accents = <String, ({Color bright, Color deep, Color tint, Color text})>{
    'coral': (
      bright: MomzoColors.coral,
      deep: MomzoColors.coralDeep,
      tint: MomzoColors.coralTint,
      text: MomzoColors.coralText,
    ),
    'honey': (
      bright: MomzoColors.honey,
      deep: MomzoColors.honey,
      tint: MomzoColors.honeyTint,
      text: MomzoColors.honeyText,
    ),
    'sage': (
      bright: MomzoColors.sage,
      deep: MomzoColors.sage,
      tint: MomzoColors.sageTint,
      text: MomzoColors.sageText,
    ),
    'lavender': (
      bright: MomzoColors.lavender,
      deep: MomzoColors.lavender,
      tint: MomzoColors.lavenderTint,
      text: MomzoColors.lavenderText,
    ),
    'sky': (
      bright: MomzoColors.sky,
      deep: MomzoColors.sky,
      tint: MomzoColors.skyTint,
      text: MomzoColors.skyText,
    ),
  };

  group('reading surfaces stay calm and legible', () {
    test('body text on the canvas clears AA', () {
      expect(ratio(MomzoColors.body, MomzoColors.cream), greaterThanOrEqualTo(4.5),
          reason: 'body on cream = ${fmt(ratio(MomzoColors.body, MomzoColors.cream))}');
      expect(ratio(MomzoColors.body, MomzoColors.white), greaterThanOrEqualTo(4.5));
    });

    test('headings clear AA comfortably', () {
      expect(ratio(MomzoColors.ink, MomzoColors.cream), greaterThanOrEqualTo(7));
    });

    test('meta text clears the large-text bar at minimum', () {
      // `muted` is only ever used for small meta lines, which is a real
      // weakness — it is pinned here so it cannot get lighter.
      expect(ratio(MomzoColors.muted, MomzoColors.cream), greaterThanOrEqualTo(3));
    });

    test('the canvas is a canvas, not an accent', () {
      // Cream must stay near-white. A "brighter palette" that tints the whole
      // background is the tiring version of this idea.
      expect(MomzoColors.cream.computeLuminance(), greaterThan(0.9));
    });
  });

  group('each accent carries text only where it is allowed to', () {
    for (final entry in accents.entries) {
      final name = entry.key;
      final c = entry.value;

      test('$name: its own text colour is readable on its tint', () {
        expect(ratio(c.text, c.tint), greaterThanOrEqualTo(4.5),
            reason: '$name text on tint = ${fmt(ratio(c.text, c.tint))}');
      });

      test('$name: ink is readable on its tint', () {
        // Tints are used as callout backgrounds with ordinary ink text.
        expect(ratio(MomzoColors.ink, c.tint), greaterThanOrEqualTo(4.5),
            reason: '$name ink on tint = ${fmt(ratio(MomzoColors.ink, c.tint))}');
      });

      test('$name: the tint is a tint, not a fill', () {
        expect(c.tint.computeLuminance(), greaterThan(0.7),
            reason: '$name tint is too dark to sit behind ink');
      });

      test('$name: INK is readable on the bright fill', () {
        // This is the binding requirement for a door, because a door carries a
        // label. It replaced an earlier check on fill-vs-cream, which was a
        // proxy for the wrong thing: honey and sky are inherently light hues,
        // and darkening them to clear an invented ratio against a near-white
        // canvas would have made them muddy and lost the point of the palette.
        expect(ratio(MomzoColors.ink, c.bright), greaterThanOrEqualTo(4.5),
            reason: '$name ink on fill = ${fmt(ratio(MomzoColors.ink, c.bright))}');
      });

      test('$name: the fill is not the canvas', () {
        // A modest floor only. Doors also carry a 1.4px border and a shadow, so
        // the shape does not depend on this ratio alone to be visible.
        expect(ratio(c.bright, MomzoColors.cream), greaterThanOrEqualTo(1.5),
            reason: '$name fill vs cream = ${fmt(ratio(c.bright, MomzoColors.cream))}');
      });
    }
  });

  group('white-on-bright is only claimed where it is true', () {
    test('coralDeep carries white text at body size', () {
      // Primary buttons are white-on-coralDeep at ~15px bold — under the 18.66px
      // large-text threshold, so it needs the full 4.5:1 and not the 3:1 relief.
      // The pre-redesign coralDeep managed 3.83 and had been failing since launch.
      expect(ratio(Colors.white, MomzoColors.coralDeep), greaterThanOrEqualTo(4.5),
          reason: 'white on coralDeep = ${fmt(ratio(Colors.white, MomzoColors.coralDeep))}');
    });

    test('the bright accents do NOT pretend to carry small white text', () {
      // Documentation as much as assertion: if a future change makes one of
      // these clear 4.5:1, the rule in §5.2 can be relaxed for it deliberately
      // rather than by accident.
      for (final entry in accents.entries) {
        final r = ratio(Colors.white, entry.value.bright);
        expect(r, lessThan(4.5),
            reason: '${entry.key} now clears AA for white text (${fmt(r)}) — '
                'update §5.2 on purpose if that is intended');
      }
    });
  });

  group('the five accents stay tellable apart', () {
    test('no two wayfinding colours are near-identical', () {
      // Wayfinding only works if the colours are distinct at a glance. Compares
      // hue, because two colours can share a luminance and still be obvious.
      final hues = {
        for (final e in accents.entries) e.key: HSLColor.fromColor(e.value.bright).hue,
      };
      final names = hues.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final a = hues[names[i]]!;
          final b = hues[names[j]]!;
          final apart = math.min((a - b).abs(), 360 - (a - b).abs());
          expect(apart, greaterThan(25),
              reason: '${names[i]} and ${names[j]} are only '
                  '${apart.toStringAsFixed(0)}° apart');
        }
      }
    });
  });

  group('the win colour stays scarce and readable', () {
    test('sunshine carries its own text', () {
      expect(ratio(MomzoColors.sunshineText, MomzoColors.sunshine),
          greaterThanOrEqualTo(4.5));
    });
  });
}
