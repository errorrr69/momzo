import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momzo/core/env/feature_flags.dart';
import 'package:momzo/core/theme/momzo_colors.dart';
import 'package:momzo/core/widgets/momzo_bottom_nav.dart';

/// The five doors (UX plan §2 and §4).
///
/// Navigation is the one part of the app she is not allowed to have to think
/// about. Everything here protects a promise that is easy to break by accident
/// in a later refactor: the order, the names, and one colour per door.
void main() {
  group('the five doors', () {
    test('there are exactly five, in the agreed order', () {
      // Order is muscle memory. A tab that moves costs her the only thing this
      // navigation is for, so reordering must be a deliberate act that breaks a
      // test rather than a quiet diff.
      expect(MomzoTab.values, [
        MomzoTab.home,
        MomzoTab.learn,
        MomzoTab.ask,
        MomzoTab.play,
        MomzoTab.circle,
      ]);
    });

    test('each door has a short, plain label', () {
      for (final tab in MomzoTab.values) {
        expect(tab.label, isNotEmpty);
        // Long labels ellipsize at this width, and an ellipsized tab is a tab
        // she has to decode.
        expect(tab.label.length, lessThanOrEqualTo(8), reason: '${tab.name} label');
        expect(tab.label.contains(' '), isFalse,
            reason: '${tab.name}: one word per door');
      }
    });

    test('no two doors share an accent', () {
      // Colour IS the wayfinding (§4.5). Two doors the same colour and the map
      // stops working.
      final accents = MomzoTab.values.map((t) => t.accent).toList();
      expect(accents.toSet().length, accents.length);
    });

    test('every door has a full colour set', () {
      for (final tab in MomzoTab.values) {
        expect(tab.accent, isA<Color>());
        expect(tab.tint, isA<Color>());
        expect(tab.accentText, isA<Color>());
        expect(tab.filledIcon, isNot(tab.outlineIcon),
            reason: '${tab.name}: active and inactive icons must differ');
      }
    });

    test('the fifth door is named for what is actually behind it', () {
      // The Circle is built but switched off (FeatureFlags.circle). While it is,
      // that tab holds Florie's posts alone, so it must not promise a community
      // that is not there. This test tracks the flag rather than pinning one
      // answer, so flipping the flag does not turn into a failing test to
      // "fix" by hardcoding a label.
      expect(MomzoTab.circle.label, FeatureFlags.circle ? 'Circle' : 'Momzo');
    });

    test('hiding the forum never hides the posts', () {
      // The whole point of the redesign was getting Florie's posts to one tap.
      // Whatever the flag says, the fifth door exists and leads to them.
      expect(MomzoTab.values, contains(MomzoTab.circle));
      expect(MomzoTab.values.length, 5);
    });

    test('Me is not a door', () {
      // It was one, and giving it up is what bought Play and Circle their slots.
      expect(MomzoTab.values.map((t) => t.name), isNot(contains('me')));
      expect(MomzoTab.values.map((t) => t.name), isNot(contains('together')));
    });
  });

  group('the bar itself', () {
    Widget host(MomzoTab active, {ValueChanged<MomzoTab>? onTap}) => MaterialApp(
          home: Scaffold(bottomNavigationBar: MomzoBottomNav(active, onTap: onTap)),
        );

    testWidgets('shows all five labels at once', (tester) async {
      await tester.pumpWidget(host(MomzoTab.home));
      await tester.pump();
      for (final tab in MomzoTab.values) {
        expect(find.text(tab.label), findsOneWidget, reason: 'missing ${tab.label}');
      }
    });

    testWidgets('the active door wears its OWN colour, not one shared highlight',
        (tester) async {
      for (final tab in [MomzoTab.play, MomzoTab.circle, MomzoTab.learn]) {
        await tester.pumpWidget(host(tab));
        await tester.pump();

        final label = tester.widget<Text>(find.text(tab.label));
        expect(label.style?.color, tab.accentText,
            reason: '${tab.label} should be its own colour when active');

        // ...and an inactive one is not.
        final other = MomzoTab.values.firstWhere((t) => t != tab);
        final otherLabel = tester.widget<Text>(find.text(other.label));
        expect(otherLabel.style?.color, MomzoColors.faint);
      }
    });

    testWidgets('tapping a door reports it', (tester) async {
      MomzoTab? tapped;
      await tester.pumpWidget(host(MomzoTab.home, onTap: (t) => tapped = t));
      await tester.pump();

      // Addressed by label rather than by a hardcoded string: the fifth door's
      // name follows FeatureFlags.circle, and a test that pins one spelling
      // breaks the moment the flag flips.
      await tester.tap(find.text(MomzoTab.circle.label));
      expect(tapped, MomzoTab.circle);

      await tester.tap(find.text(MomzoTab.play.label));
      expect(tapped, MomzoTab.play);
    });

    testWidgets('no notification dots anywhere', (tester) async {
      // §4.8: a badge is a to-do list, and she has enough of those. The only
      // count in the app is the moderator flag, which lives on the Circle
      // screen and not on the bar.
      await tester.pumpWidget(host(MomzoTab.home));
      await tester.pump();
      expect(find.byType(Badge), findsNothing);
    });
  });
}
