import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momzo/features/circle/report_sheet.dart';
import 'package:momzo/models/forum.dart';

/// The Circle's client-side guarantees (Expansion Plan §2.4).
///
/// forum_circle.test.mjs proves the database side — who may write, who may hide,
/// what three reports do. This covers the two things that live only in the app:
/// the identity default, and the report flow's wording.
void main() {
  group('forum identity is a choice, never a fallback', () {
    test('a mother without a profile is never named', () {
      // The failure this guards against is a screen quietly rendering her
      // account name because a profile was missing. The default carries no name
      // at all, so there is nothing to leak.
      expect(ForumIdentity.anonymous.displayName, 'A mother in the Circle');
      expect(ForumIdentity.anonymous.userId, isEmpty);
    });

    test('a thread with no embedded profile falls back to anonymous, not to a name', () {
      final t = ForumThread.fromRow({
        'id': 't1',
        'category_id': 'c1',
        'author_id': 'u1',
        'title': 'A hard evening',
        'body': 'It went badly.',
        'created_at': '2026-08-18T09:00:00Z',
        'last_activity_at': '2026-08-18T09:00:00Z',
        // No forum_profiles embed — the join returned nothing.
      });
      expect(t.author.displayName, ForumIdentity.anonymous.displayName);
      expect(t.author.displayName, isNot(contains('u1')));
    });

    test('an embedded profile is used as-is', () {
      final t = ForumThread.fromRow({
        'id': 't1', 'category_id': 'c1', 'author_id': 'u1',
        'title': 'T', 'body': 'B',
        'created_at': '2026-08-18T09:00:00Z',
        'last_activity_at': '2026-08-18T09:00:00Z',
        'forum_profiles': {'user_id': 'u1', 'display_name': 'Amara', 'avatar_emoji': '🌷'},
      });
      expect(t.author.displayName, 'Amara');
      expect(t.author.avatarEmoji, '🌷');
    });
  });

  group('reporting', () {
    test('"someone may need help" is a first-class reason, not buried in other', () {
      expect(ReportReason.values, contains(ReportReason.needsHelp));
      expect(ReportReason.needsHelp.key, 'needs_help');
      // It reads as concern, not as an accusation.
      expect(ReportReason.needsHelp.label.toLowerCase(), contains('help'));
      expect(ReportReason.needsHelp.blurb, isNotEmpty);
      expect(ReportReason.needsHelp.blurb.toLowerCase(), contains('nothing is deleted'));
    });

    test('every reason maps to a value the database accepts', () {
      // The CHECK constraint lists exactly these; a drift here would fail at
      // insert time, in front of a mother who is already upset about something.
      const accepted = {'unkind', 'selling', 'identifying', 'needs_help', 'other'};
      for (final r in ReportReason.values) {
        expect(accepted, contains(r.key), reason: '${r.name} sends "${r.key}"');
      }
    });

    testWidgets('the sheet offers every reason and will not send an empty one',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showReportSheet(context, targetType: 'thread', targetId: 't1'),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final r in ReportReason.values) {
        expect(find.text(r.label), findsOneWidget, reason: 'missing reason: ${r.label}');
      }
      // Reassurance is on the sheet itself, where she is deciding whether to use it.
      expect(find.textContaining('A person reads every one'), findsOneWidget);

      // Nothing chosen yet, so the button is inert.
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('moderation queue ordering', () {
    test('"may need help" is urgent, other reasons are not', () {
      ForumReport r(String reason) => ForumReport(
            id: 'r', targetType: 'thread', targetId: 't',
            reason: reason, createdAt: DateTime(2026, 8, 18),
          );
      expect(r('needs_help').isUrgent, isTrue);
      for (final other in ['unkind', 'selling', 'identifying', 'other']) {
        expect(r(other).isUrgent, isFalse);
      }
    });

    test('every stored reason has a human label', () {
      for (final reason in ['unkind', 'selling', 'identifying', 'needs_help', 'other']) {
        final report = ForumReport(
          id: 'r', targetType: 'thread', targetId: 't',
          reason: reason, createdAt: DateTime(2026, 8, 18),
        );
        expect(report.reasonLabel, isNotEmpty);
        expect(report.reasonLabel, isNot(reason), reason: '$reason shows its raw key');
      }
    });
  });

  group('threads and replies', () {
    test('a hidden thread keeps its reason so the author can be told why', () {
      final t = ForumThread.fromRow({
        'id': 't1', 'category_id': 'c1', 'author_id': 'u1',
        'title': 'T', 'body': 'B',
        'created_at': '2026-08-18T09:00:00Z',
        'last_activity_at': '2026-08-18T09:00:00Z',
        'hidden': true, 'hidden_reason': 'Auto-hidden pending review',
      });
      expect(t.hidden, isTrue);
      expect(t.hiddenReason, contains('review'));
    });

    test('counts default to zero rather than null on a sparse row', () {
      final r = ForumReply.fromRow({
        'id': 'r1', 'thread_id': 't1', 'author_id': 'u1', 'body': 'hi',
        'created_at': '2026-08-18T09:00:00Z',
      });
      expect(r.reactionCount, 0);
      expect(r.hidden, isFalse);
      expect(r.hearted, isFalse);
    });
  });
}
