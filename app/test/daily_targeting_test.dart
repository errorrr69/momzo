import 'package:flutter_test/flutter_test.dart';
import 'package:momzo/models/child.dart';
import 'package:momzo/services/daily_service.dart';

/// Guards the join between two vocabularies that live in different places:
/// the onboarding sentences a mother picks, and the controlled tag vocabulary the
/// cards carry (00_CARD_SPEC §4).
///
/// This is worth a test because the failure is INVISIBLE at runtime. If the two
/// drift apart, `overlaps('tags', …)` still executes, matches nothing, and
/// selection quietly falls through to an untargeted card. No exception, no log,
/// no empty screen — the product just stops being personalised and every card
/// still looks fine.
///
/// The card side is enforced by a check constraint in the database
/// (content_cards_tags_vocab). This is the app side of the same guarantee.
void main() {
  // 00_CARD_SPEC §4, verbatim.
  const vocab = {
    'big-feelings', 'meltdowns', 'frustration', 'worries', 'anger',
    'focus', 'listening', 'transitions', 'high-energy',
    'confidence', 'independence', 'self-belief',
    'connection', 'bonding', 'rituals',
    'learning', 'curiosity', 'reading', 'numbers',
    'sharing', 'friendships', 'siblings', 'kindness', 'shy-warm-up',
    'sleep', 'mornings', 'mealtimes', 'screens', 'tidying',
  };

  // The option lists exactly as onboarding_flow_screen.dart offers them. Copied
  // rather than imported so that changing the screen's options fails this test
  // instead of silently changing what it checks.
  const focusOpts = [
    'Handling big feelings', 'Confidence & self-belief', 'Focus & attention',
    'Kindness & sharing', 'Independence & responsibility',
    'Love of learning & curiosity', 'Friendships & social skills',
    'Calmer routines (sleep / meals / mornings)', 'Screen-time balance',
    'Creativity & imagination',
  ];
  const challengeOpts = [
    'Big emotions / meltdowns', 'Takes a while to warm up / shy',
    'Lots of energy, hard to settle', 'Gets frustrated easily',
    'Sharing & taking turns', 'Listening & following directions',
    'Worries or nervousness', 'Changes & transitions are hard',
    'Sibling moments', 'Honestly, nothing major right now',
  ];
  const momGoalOpts = [
    'Feel closer to', 'Understand them better', 'Learn practical tools',
    'Have nice things to do together', 'Feel less stressed or guilty',
    'Build better routines',
  ];

  test('every onboarding option is mapped', () {
    for (final o in focusOpts) {
      expect(DailyService.focusGoalTags.containsKey(o), isTrue,
          reason: 'focus goal "$o" has no tag mapping — it would target nothing');
    }
    for (final o in challengeOpts) {
      expect(DailyService.challengeTags.containsKey(o), isTrue,
          reason: 'challenge "$o" has no tag mapping — it would target nothing');
    }
  });

  test('every mapped tag exists in the §4 vocabulary', () {
    final maps = {
      'focus goal': DailyService.focusGoalTags,
      'challenge': DailyService.challengeTags,
      'mom goal': DailyService.momGoalTags,
    };
    for (final entry in maps.entries) {
      entry.value.forEach((option, tags) {
        for (final t in tags) {
          expect(vocab.contains(t), isTrue,
              reason: '${entry.key} "$option" maps to "$t", which is not in §4 — '
                  'it would match no card');
        }
      });
    }
  });

  test('every §4 tag is reachable from some onboarding answer', () {
    final reachable = <String>{
      for (final tags in DailyService.focusGoalTags.values) ...tags,
      for (final tags in DailyService.challengeTags.values) ...tags,
      for (final tags in DailyService.momGoalTags.values) ...tags,
    };
    final unreachable = vocab.difference(reachable);
    expect(unreachable, isEmpty,
        reason: 'no onboarding answer targets $unreachable — cards carrying only '
            'those tags could be served by the untargeted fallback alone');
  });

  test('a real profile resolves to real tags', () {
    const child = Child(
      id: 'c1',
      name: 'Ada',
      age: 5,
      focusGoals: ['Handling big feelings', 'Friendships & social skills'],
      challenges: ['Big emotions / meltdowns', 'Takes a while to warm up / shy'],
    );
    final tags = DailyService.tagsForChild(child, momGoals: ['Feel closer to']);

    expect(tags, contains('meltdowns'));
    expect(tags, contains('shy-warm-up'));
    expect(tags, contains('connection')); // only reachable via the mother's goal
    expect(tags.every(vocab.contains), isTrue);
  });

  test('"nothing major right now" contributes no tags', () {
    const child = Child(
      id: 'c2',
      name: 'Bo',
      age: 6,
      challenges: ['Honestly, nothing major right now'],
    );
    expect(DailyService.tagsForChild(child), isEmpty);
  });

  test('an unmapped answer degrades quietly rather than throwing', () {
    const child = Child(id: 'c3', name: 'Cy', age: 6, focusGoals: ['Something new']);
    expect(DailyService.tagsForChild(child), isEmpty);
  });

  test('mom goal options are either mapped or deliberately absent', () {
    // "Feel less stressed or guilty" is intentionally unmapped: §5 rule 1 says
    // never name her worry back at her, so nothing targets it.
    const deliberatelyUnmapped = {'Feel less stressed or guilty'};
    for (final o in momGoalOpts) {
      if (deliberatelyUnmapped.contains(o)) {
        expect(DailyService.momGoalTags.containsKey(o), isFalse,
            reason: '"$o" names her worry — §5 rule 1 says do not target it');
      } else {
        expect(DailyService.momGoalTags.containsKey(o), isTrue,
            reason: 'mom goal "$o" has no tag mapping');
      }
    }
  });
}
