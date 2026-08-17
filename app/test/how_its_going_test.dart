import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momzo/features/learning_games/widgets/how_its_going.dart';
import 'package:momzo/models/game_insights.dart';
import 'package:momzo/models/learning_game.dart';

/// What the dashboard actually puts on screen (Expansion Plan §3.6).
///
/// game_insights_test.dart proves the arithmetic and the tone of the computed
/// strings. This proves the rendering: that the win really is last, that a bad
/// week is not painted as failure, and that no score reaches the screen.
void main() {
  const tenFrame = LearningGame(
    slug: 'ten-frame', title: 'Ten Frame', category: 'maths',
    ageMin: 5, ageMax: 6, entryPath: '/play/ten-frame',
  );
  const freeze = LearningGame(
    slug: 'freeze-dance', title: 'Freeze Dance', category: 'focus',
    ageMin: 5, ageMax: 6, entryPath: '/play/freeze-dance',
  );

  Widget host(GameInsights i) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HowItsGoing(insights: i, childName: 'Raya', onOpen: (_) {}),
          ),
        ),
      );

  testWidgets('with nothing played it is warm, and never a nudge', (tester) async {
    await tester.pumpWidget(host(const GameInsights()));
    await tester.pump();

    expect(find.textContaining('I’ll keep gentle notes here'), findsOneWidget);
    // No guilt, no streak, no call to action.
    for (final banned in ['haven’t', "haven't", 'streak', 'Start playing', 'yet!']) {
      expect(find.textContaining(banned), findsNothing, reason: 'pressure language: $banned');
    }
  });

  testWidgets('a rough week still ends on the win, and the win is LAST', (tester) async {
    final rough = GameInsights(
      togetherTime: const Duration(minutes: 12),
      sessionsThisWeek: 2,
      standings: [
        GameStanding(
          game: tenFrame, sessions: 2, rounds: 10, firstTime: 0,
          anotherLook: 2, stillExploring: 8, standing: Standing.exploring,
          lastPlayed: DateTime(2026, 8, 17),
        ),
      ],
      win: 'You played together 2 times this week — that’s the bit that counts 💛',
    );

    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(rough));
    await tester.pump();

    expect(find.textContaining('that’s the bit that counts'), findsOneWidget);
    expect(find.text('Still growing 🌱'), findsOneWidget);

    // The win sits below everything else on the screen.
    final winY = tester.getTopLeft(find.textContaining('that’s the bit that counts')).dy;
    final standingY = tester.getTopLeft(find.text('Ten Frame')).dy;
    expect(winY, greaterThan(standingY));
  });

  testWidgets('a struggling game reads as growing, never as red or failing', (tester) async {
    final rough = GameInsights(
      standings: [
        GameStanding(
          game: tenFrame, sessions: 1, rounds: 8, firstTime: 0, anotherLook: 0,
          stillExploring: 8, standing: Standing.exploring,
          lastPlayed: DateTime(2026, 8, 17),
        ),
      ],
      win: 'Something good 💛',
    );
    await tester.pumpWidget(host(rough));
    await tester.pump();

    for (final banned in ['failed', 'wrong', 'poor', 'weak', 'behind', 'needs work']) {
      expect(find.textContaining(banned), findsNothing, reason: 'deficit language: $banned');
    }
    // The counts are visible as observations, not as a mark.
    expect(find.textContaining('8 still exploring'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('suggestions carry their reason and open the game', (tester) async {
    LearningGame? opened;
    final withNext = GameInsights(
      standings: [
        GameStanding(
          game: tenFrame, sessions: 1, rounds: 3, firstTime: 3,
          anotherLook: 0, stillExploring: 0, standing: Standing.emerging,
          lastPlayed: DateTime(2026, 8, 17),
        ),
      ],
      next: const [
        Recommendation(
          game: freeze,
          reason: 'Because of what you told us about how things are going',
          rule: 1,
        ),
      ],
      win: 'Good things 💛',
    );

    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HowItsGoing(
            insights: withNext, childName: 'Raya', onOpen: (g) => opened = g,
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('MAYBE NEXT'), findsOneWidget);
    expect(find.textContaining('what you told us'), findsOneWidget);

    await tester.tap(find.text('Freeze Dance'));
    await tester.pump();
    expect(opened?.slug, 'freeze-dance');
  });

  testWidgets('an opened-but-unplayed game says so plainly', (tester) async {
    final unplayed = GameInsights(
      standings: [
        GameStanding(
          game: freeze, sessions: 1, rounds: 0, firstTime: 0, anotherLook: 0,
          stillExploring: 0, standing: Standing.exploring,
          lastPlayed: DateTime(2026, 8, 17),
        ),
      ],
      win: 'Good things 💛',
    );
    await tester.pumpWidget(host(unplayed));
    await tester.pump();
    expect(find.text('Opened once'), findsOneWidget);
  });
}
