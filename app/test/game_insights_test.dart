import 'package:flutter_test/flutter_test.dart';
import 'package:momzo/models/child.dart';
import 'package:momzo/models/game_insights.dart';
import 'package:momzo/models/learning_game.dart';
import 'package:momzo/services/learning_game_service.dart';

/// The games dashboard (Expansion Plan §3.6).
///
/// Two things are being protected here, and only one of them is arithmetic.
///
/// The arithmetic is the two-day rule and the four recommendation rules. The
/// other is TONE — never a score, never a comparison to another child, always
/// ending on something that went well. Tone is the part that decays silently:
/// nothing crashes when a dashboard starts quietly telling a mother her child is
/// behind, so it is asserted here rather than left to review.
void main() {
  const maths1 = LearningGame(
    slug: 'flash-hide', title: 'Flash & Hide', category: 'maths',
    ageMin: 5, ageMax: 6, entryPath: '/play/flash-hide',
    skillTags: ['subitising', 'working-memory'], ladderKey: 'number', ladderStep: 1,
  );
  const maths2 = LearningGame(
    slug: 'ten-frame', title: 'Ten Frame', category: 'maths',
    ageMin: 5, ageMax: 6, entryPath: '/play/ten-frame',
    skillTags: ['ten-frame', 'number-sense'], ladderKey: 'number', ladderStep: 2,
  );
  const reading1 = LearningGame(
    slug: 'sound-safari', title: 'Sound Safari', category: 'reading',
    ageMin: 5, ageMax: 6, entryPath: '/play/sound-safari',
    skillTags: ['initial-sounds'], ladderKey: 'reading', ladderStep: 1,
  );
  const feelings1 = LearningGame(
    slug: 'feeling-thermometer', title: 'Feeling Thermometer', category: 'feelings',
    ageMin: 5, ageMax: 6, entryPath: '/play/feeling-thermometer',
    skillTags: ['emotion-vocabulary', 'intensity', 'self-regulation'],
  );
  const focus1 = LearningGame(
    slug: 'freeze-dance', title: 'Freeze Dance', category: 'focus',
    ageMin: 5, ageMax: 6, entryPath: '/play/freeze-dance',
    skillTags: ['inhibitory-control', 'gross-motor'],
  );

  const catalogue = [maths1, maths2, reading1, feelings1, focus1];
  final now = DateTime(2026, 8, 17, 12);

  PlayedSession played(
    String slug,
    DateTime at, {
    int rounds = 0,
    int firstTime = 0,
    int anotherLook = 0,
    int stillExploring = 0,
    int seconds = 300,
    List<String> notes = const [],
  }) =>
      PlayedSession(
        gameSlug: slug, startedAt: at, durationSec: seconds, rounds: rounds,
        firstTime: firstTime, anotherLook: anotherLook,
        stillExploring: stillExploring, notes: notes,
      );

  GameInsights build(List<PlayedSession> sessions, {List<String> skills = const []}) =>
      GameInsights.build(
        sessions: sessions, catalogue: catalogue,
        profileSkillTags: skills, now: now,
      );

  group("Florie's two-day rule", () {
    test('one brilliant session is "coming along", never "got it"', () {
      final i = build([played('ten-frame', now.subtract(const Duration(hours: 2)),
          rounds: 8, firstTime: 8)]);
      expect(i.standings.single.standing, Standing.emerging);
    });

    test('two brilliant sessions on the SAME day are still one day', () {
      final i = build([
        played('ten-frame', DateTime(2026, 8, 17, 9), rounds: 6, firstTime: 6),
        played('ten-frame', DateTime(2026, 8, 17, 18), rounds: 6, firstTime: 6),
      ]);
      expect(i.standings.single.standing, Standing.emerging,
          reason: 'the rule counts days, not sittings');
    });

    test('two different days makes it secure', () {
      final i = build([
        played('ten-frame', DateTime(2026, 8, 15, 9), rounds: 4, firstTime: 3),
        played('ten-frame', DateTime(2026, 8, 17, 9), rounds: 4, firstTime: 2),
      ]);
      expect(i.standings.single.standing, Standing.secure);
    });

    test('played but never got there first time is "still growing", not a failure', () {
      final i = build([
        played('ten-frame', DateTime(2026, 8, 15), rounds: 5, anotherLook: 3, stillExploring: 2),
        played('ten-frame', DateTime(2026, 8, 16), rounds: 5, stillExploring: 5),
      ]);
      expect(i.standings.single.standing, Standing.exploring);
      expect(Standing.exploring.label, contains('growing'));
    });
  });

  group('the four recommendation rules, in priority order', () {
    test('rule 1 — what she told us about this child comes first', () {
      final i = build(
        [played('ten-frame', now.subtract(const Duration(days: 1)), rounds: 3, firstTime: 3)],
        skills: ['inhibitory-control', 'gross-motor'],
      );
      expect(i.next.first.rule, 1);
      expect(i.next.first.game.slug, 'freeze-dance');
    });

    test('rule 1 picks the STRONGEST match, not merely a match', () {
      final i = build([], skills: ['emotion-vocabulary', 'intensity', 'self-regulation']);
      // feeling-thermometer carries all three; freeze-dance carries none.
      expect(i.next.first.game.slug, 'feeling-thermometer');
    });

    test('rule 2 suggests the next ladder step only once they are getting it', () {
      final i = build([
        played('flash-hide', DateTime(2026, 8, 15), rounds: 4, firstTime: 4),
        played('flash-hide', DateTime(2026, 8, 16), rounds: 4, firstTime: 4),
      ]);
      final ladder = i.next.where((r) => r.rule == 2);
      expect(ladder, isNotEmpty);
      expect(ladder.first.game.slug, 'ten-frame');
    });

    test('rule 2 never advances a child who is still finding the current step', () {
      // mastery.ts: the software never advances a child on its own. A child still
      // exploring step 1 must not be handed step 2 by an algorithm.
      final i = build([
        played('flash-hide', DateTime(2026, 8, 15), rounds: 6, stillExploring: 6),
        played('flash-hide', DateTime(2026, 8, 16), rounds: 6, stillExploring: 6),
      ]);
      expect(i.next.where((r) => r.rule == 2), isEmpty);
    });

    test('rule 3 offers a shelf untouched for a fortnight', () {
      final i = build([played('ten-frame', now.subtract(const Duration(days: 1)), rounds: 2)]);
      final balance = i.next.where((r) => r.rule == 3);
      expect(balance, isNotEmpty);
      expect(balance.first.game.category, isNot('maths'));
    });

    test('rule 4 nudges a game that was opened but never played', () {
      final i = build([played('reading-none', now), played('sound-safari', now, rounds: 0)]);
      final unfinished = i.next.where((r) => r.rule == 4);
      expect(unfinished, isNotEmpty);
      expect(unfinished.first.game.slug, 'sound-safari');
    });

    test('never suggests the same game under two rules', () {
      final i = build(
        [played('flash-hide', DateTime(2026, 8, 15), rounds: 3, firstTime: 3),
         played('flash-hide', DateTime(2026, 8, 16), rounds: 3, firstTime: 3)],
        skills: ['ten-frame', 'number-sense'],
      );
      final slugs = i.next.map((r) => r.game.slug).toList();
      expect(slugs.toSet().length, slugs.length);
    });

    test('rules come back in priority order', () {
      final i = build(
        [played('flash-hide', DateTime(2026, 8, 15), rounds: 3, firstTime: 3),
         played('flash-hide', DateTime(2026, 8, 16), rounds: 3, firstTime: 3)],
        skills: ['emotion-vocabulary'],
      );
      final rules = i.next.map((r) => r.rule).toList();
      expect(rules, orderedEquals([...rules]..sort()));
    });
  });

  group('tone — the hard requirements', () {
    late GameInsights mixed;
    setUp(() {
      mixed = build([
        played('ten-frame', DateTime(2026, 8, 15), rounds: 6, firstTime: 1, stillExploring: 5,
            notes: ['Chose belly breathing']),
        played('ten-frame', DateTime(2026, 8, 16), rounds: 6, stillExploring: 6),
        played('sound-safari', DateTime(2026, 8, 17), rounds: 4, anotherLook: 4),
      ]);
    });

    test('there is always a win, and it is the last thing said', () {
      expect(mixed.win, isNotNull);
      expect(mixed.win, contains('💛'));
    });

    test('a single first-time round gets a sentence, not a tally of one', () {
      final one = build([
        played('ten-frame', DateTime(2026, 8, 17), rounds: 1, firstTime: 1),
      ]);
      expect(one.win, 'They got a Ten Frame round first time 💛');
      expect(one.win, isNot(contains('1 of them')));
    });

    test('several first-time rounds are worth counting', () {
      final several = build([
        played('ten-frame', DateTime(2026, 8, 17), rounds: 4, firstTime: 3),
      ]);
      expect(several.win, contains('3 Ten Frame rounds'));
    });

    test('a session where nothing went right STILL ends on a win', () {
      final rough = build([
        played('ten-frame', DateTime(2026, 8, 17), rounds: 8, stillExploring: 8),
      ]);
      expect(rough.win, isNotNull, reason: 'the dashboard must never end on a failure');
    });

    test('no percentage, score or grade appears anywhere', () {
      final text = [
        mixed.win ?? '',
        ...mixed.standings.map((s) => s.standing.label),
        ...mixed.next.map((r) => r.reason),
        ...mixed.moments,
      ].join(' ');
      expect(text, isNot(contains('%')));
      expect(text.toLowerCase(), isNot(matches(RegExp(r'\bscore|\bgrade|\brank|\blevel \d'))));
    });

    test('no comparison to other children, ever', () {
      final text = [
        mixed.win ?? '',
        ...mixed.standings.map((s) => s.standing.label),
        ...mixed.next.map((r) => r.reason),
      ].join(' ').toLowerCase();
      for (final banned in [
        'behind', 'ahead', 'average', 'percentile', 'other children',
        'peers', 'typical for', 'should be', 'most kids',
      ]) {
        expect(text, isNot(contains(banned)), reason: 'comparison language: "$banned"');
      }
    });

    test('growing areas are the least explored, never the worst performing', () {
      // ten-frame went badly and sound-safari middling; neither may be named a
      // weakness. Only untouched shelves appear.
      expect(mixed.growing, isNot(contains(GameShelf.maths)));
      expect(mixed.growing, contains(GameShelf.feelings));
    });

    test('the child\'s own words are carried through, unscored', () {
      expect(mixed.moments, contains('Chose belly breathing'));
    });

    test('nothing played at all: no win, and nothing pretends otherwise', () {
      final empty = build([]);
      expect(empty.hasPlayed, isFalse);
      expect(empty.win, isNull, reason: 'the empty state carries the warmth instead');
      expect(empty.standings, isEmpty);
      expect(empty.togetherTime, Duration.zero);
    });
  });

  group('reading the raw session rows', () {
    test('pulls the numbers out of a real bridge payload', () {
      final s = PlayedSession.fromRow({
        'game_slug': 'feed-monster',
        'started_at': '2026-08-17T17:09:15Z',
        'duration_sec': 40,
        'completed': true,
        'progress': {
          'events': [
            {'event': 'game_ready', 'game': 'feed-monster'},
            {
              'event': 'session_summary', 'game': 'feed-monster', 'durationSec': 34,
              'rounds': 1, 'firstTime': 1, 'anotherLook': 0, 'stillExploring': 0,
              'notes': <String>[],
            },
          ],
        },
      });
      expect(s, isNotNull);
      expect(s!.rounds, 1);
      expect(s.firstTime, 1);
      expect(s.durationSec, 40);
    });

    test('takes the LAST summary when several arrived', () {
      // The game re-sends its rollup after every answer, so a session normally
      // carries one — but if an older client sent several, the newest wins.
      final s = PlayedSession.fromRow({
        'game_slug': 'ten-frame',
        'started_at': '2026-08-17T10:00:00Z',
        'progress': {
          'events': [
            {'event': 'session_summary', 'rounds': 1, 'firstTime': 1},
            {'event': 'session_summary', 'rounds': 3, 'firstTime': 3},
          ],
        },
      });
      expect(s!.rounds, 3);
    });

    test('a session with no summary still counts as time together', () {
      final s = PlayedSession.fromRow({
        'game_slug': 'ten-frame',
        'started_at': '2026-08-17T10:00:00Z',
        'duration_sec': 120,
        'progress': {'events': <dynamic>[]},
      });
      expect(s!.durationSec, 120);
      expect(s.rounds, 0);
    });

    test('a malformed row is dropped rather than crashing the screen', () {
      expect(PlayedSession.fromRow({'game_slug': 'x'}), isNull);
      expect(PlayedSession.fromRow({'started_at': 'nonsense'}), isNull);
    });

    test('a session for a retired game is ignored', () {
      final i = build([played('a-game-we-removed', now, rounds: 5, firstTime: 5)]);
      expect(i.standings, isEmpty);
    });
  });

  group('the onboarding → skill_tags map', () {
    // The 41-term vocabulary the seeded catalogue actually carries. Duplicated
    // here for the same reason the seeder duplicates the card vocabulary: a
    // mismatch must fail a build rather than quietly recommend nothing.
    const vocabulary = {
      'addition', 'blending', 'breathing', 'calming', 'comprehension',
      'context-clues', 'decoding', 'digraphs', 'emotion-recognition',
      'emotion-vocabulary', 'executive-function', 'fluency', 'grapheme-phoneme',
      'gross-motor', 'inhibitory-control', 'initial-sounds', 'intensity',
      'letter-formation', 'listening', 'long-vowels', 'missing-part',
      'nonsense-words', 'number-bonds', 'number-line', 'number-sense',
      'oral-blending', 'part-whole', 'perspective-taking', 'phoneme-count',
      'phoneme-manipulation', 'phonemic-awareness', 'segmenting', 'self-awareness',
      'self-regulation', 'sight-words', 'split-digraph', 'subitising',
      'subtraction', 'ten-frame', 'tricky-words', 'working-memory',
    };

    test('every mapped skill is one a game actually carries', () {
      for (final map in [
        LearningGameService.challengeSkills,
        LearningGameService.focusGoalSkills,
      ]) {
        map.forEach((answer, skills) {
          for (final s in skills) {
            expect(vocabulary, contains(s),
                reason: '"$answer" maps to "$s", which no game carries');
          }
        });
      }
    });

    test('a real profile resolves to skills', () {
      const raya = Child(
        id: 'c1', name: 'Raya', age: 5,
        focusGoals: ['Handling big feelings', 'Friendships & social skills'],
        challenges: ['Big emotions / meltdowns', 'Takes a while to warm up / shy'],
      );
      final skills = LearningGameService.skillTagsFor(raya);
      expect(skills, contains('emotion-vocabulary'));
      expect(skills, contains('perspective-taking'));
      expect(skills, contains('self-regulation'));
    });

    test('"nothing major" stays empty rather than faking a preference', () {
      const quiet = Child(
        id: 'c2', name: 'Sam', age: 6,
        challenges: ['Honestly, nothing major right now'],
      );
      expect(LearningGameService.skillTagsFor(quiet), isEmpty);
    });

    test('an unmapped answer degrades quietly instead of throwing', () {
      const odd = Child(id: 'c3', name: 'Kit', age: 5, focusGoals: ['Something new we added']);
      expect(LearningGameService.skillTagsFor(odd), isEmpty);
    });
  });
}
