import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momzo/core/widgets/try_this_tonight.dart';
import 'package:momzo/core/widgets/why_it_matters.dart';
import 'package:momzo/features/daily/card_reader_screen.dart';
import 'package:momzo/models/content_card.dart';
import 'package:momzo/models/daily_card.dart';

/// The fixed display structure (00_CARD_SPEC §7).
///
/// The spec's central claim is that every card renders the SAME WAY, so a tired
/// reader's eye learns the shape. That only holds if the order is enforced
/// somewhere other than in a developer's memory — the daily card and the library
/// reader are separate widgets and drifted apart once already.
void main() {
  const card = ContentCard(
    id: 'card-1',
    title: 'Name the feeling before you fix it',
    summary: 'When a child hears their feeling put into words, the feeling gets smaller.',
    whyItMatters: 'When your child is on the floor about the wrong colour cup, '
        "they aren't being difficult about cups.",
    mainRead: 'A five-year-old\'s feelings arrive faster than their language.\n\n'
        'When you say the feeling out loud, something shifts.',
    activity: 'Next time the storm comes, say one sentence and then stop talking.',
    category: 'big-feelings',
    tags: ['big-feelings', 'meltdowns'],
  );

  testWidgets('the reader renders all five parts in spec order', (tester) async {
    // The card is a ListView, which only builds what fits. At the default 800x600
    // test surface the activity block is below the fold and never constructed, so
    // the viewport is made tall enough to hold a whole card — otherwise this test
    // would "prove" the structure by only ever seeing its top half.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CardReaderScreen(card: card)));
    await tester.pump();

    for (final expected in [
      card.title,
      card.summary,
      card.whyItMatters!,
      'TRY THIS TONIGHT',
      card.activity!,
    ]) {
      expect(find.text(expected), findsOneWidget, reason: 'missing: $expected');
    }
    // main_read is split on blank lines, so each paragraph is its own Text.
    expect(find.textContaining('feelings arrive faster'), findsOneWidget);
    expect(find.textContaining('something shifts'), findsOneWidget);

    // Order is the point, not just presence.
    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(top(find.text(card.title)), lessThan(top(find.text(card.summary))));
    expect(top(find.text(card.summary)), lessThan(top(find.text(card.whyItMatters!))));
    expect(top(find.text(card.whyItMatters!)),
        lessThan(top(find.textContaining('feelings arrive faster'))));
    expect(top(find.textContaining('something shifts')),
        lessThan(top(find.text('TRY THIS TONIGHT'))));
  });

  testWidgets('the callout is addressed to the child by name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WhyItMatters(childName: 'Ada', body: 'Because reasons.')),
    ));
    expect(find.text('WHY THIS MATTERS FOR ADA'), findsOneWidget);
    expect(find.text('Because reasons.'), findsOneWidget);
  });

  testWidgets('try-this-tonight carries its own heading', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TryThisTonight('Count to five before you speak.')),
    ));
    expect(find.text('TRY THIS TONIGHT'), findsOneWidget);
    expect(find.text('Count to five before you speak.'), findsOneWidget);
  });

  test('DailyCard maps every v2 column', () {
    final d = DailyCard.fromCard({
      'id': 'c1',
      'title': 'T',
      'summary': 'S',
      'why_it_matters': 'W',
      'main_read': 'M',
      'activity': 'A',
      'category': 'big-feelings',
      'source': 'Momzo',
      'tags': ['meltdowns'],
    }, assignmentId: 'a1');

    expect(d.title, 'T');
    expect(d.summary, 'S');
    expect(d.whyItMatters, 'W');
    expect(d.mainRead, 'M');
    expect(d.activity, 'A');
    expect(d.category, 'big-feelings');
    expect(d.tags, ['meltdowns']);
    expect(d.isRead, isFalse);
  });

  test('a card missing optional text still renders something coherent', () {
    // reference_only notes carry main_read but no summary or activity. They never
    // reach this screen today, but a null here must not crash a reader.
    final d = DailyCard.fromCard(
      {'id': 'c2', 'title': 'T', 'main_read': 'M'},
      assignmentId: 'a2',
    );
    expect(d.summary, '');
    expect(d.activity, isNull);
    expect(d.readMinutes, greaterThanOrEqualTo(1));
  });

  test('topicLabel prefers the shelf name over a raw tag', () {
    expect(card.topicLabel, 'Big feelings');
    const untagged = ContentCard(id: 'x', title: 'T', tags: ['meltdowns']);
    expect(untagged.topicLabel, 'meltdowns');
  });
}
