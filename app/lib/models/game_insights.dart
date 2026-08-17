/// "How it's going" — what the games area tells the MOTHER (Expansion Plan §3.6).
///
/// Pure computation over the sessions, deliberately: every tone rule below is a
/// property of this file, so it can be tested without a database or a screen.
///
/// The tone rules are hard requirements, not styling (§3.6, and Florie's own
/// pedagogy in mastery.ts / summary.ts):
///
///  * Compare the child only to their OWN earlier sessions. Never peers, never
///    percentiles, never age norms, never "behind".
///  * Wrong is never a penalty. A dip is "still growing", never red, never a
///    failure. There are no scores here at all — only counts of what happened.
///  * Always end on a win. [win] is the last thing the screen shows and is
///    non-null whenever there is any play to draw it from.
///  * No streaks, no daily-play pressure, no leaderboards.
///
/// The child never sees any of this. Celebration happens in the game.
library;

import 'learning_game.dart';

/// One game's standing, on Florie's two-day rule.
enum Standing {
  /// Got there on their own on two DIFFERENT days. One great session is not
  /// mastery — that is `mastery.ts`'s rule, kept here so Momzo's dashboard and
  /// Florie's session panel never disagree about what "secure" means.
  secure,

  /// Got there first time, but so far on one day only.
  emerging,

  /// Played, still finding it. Never "failing", never "behind".
  exploring,
}

extension StandingX on Standing {
  String get label => switch (this) {
        Standing.secure => 'Got this',
        Standing.emerging => 'Coming along',
        Standing.exploring => 'Still growing 🌱',
      };
}

/// What one session reported, flattened out of the raw bridge payload.
class PlayedSession {
  final String gameSlug;
  final DateTime startedAt;
  final int durationSec;
  final int rounds;
  final int firstTime;
  final int anotherLook;
  final int stillExploring;
  final List<String> notes;

  const PlayedSession({
    required this.gameSlug,
    required this.startedAt,
    this.durationSec = 0,
    this.rounds = 0,
    this.firstTime = 0,
    this.anotherLook = 0,
    this.stillExploring = 0,
    this.notes = const [],
  });

  /// The calendar day, which is what the two-day rule counts.
  String get day =>
      '${startedAt.year}-${startedAt.month.toString().padLeft(2, '0')}-'
      '${startedAt.day.toString().padLeft(2, '0')}';

  /// Reads one `game_play_sessions` row, including its raw bridge events.
  ///
  /// A session with no summary still counts as time spent together — the app may
  /// have been killed, or she may have closed before anyone answered anything.
  /// It contributes its duration and nothing else, rather than being discarded.
  static PlayedSession? fromRow(Map<String, dynamic> r) {
    final started = DateTime.tryParse((r['started_at'] ?? '') as String);
    if (started == null || r['game_slug'] == null) return null;

    final progress = r['progress'];
    final events = (progress is Map ? progress['events'] : null);
    Map<String, dynamic>? summary;
    if (events is List) {
      for (final e in events) {
        if (e is Map && e['event'] == 'session_summary') {
          summary = Map<String, dynamic>.from(e);
        }
      }
    }

    int n(String k) => (summary?[k] as num?)?.toInt() ?? 0;
    return PlayedSession(
      gameSlug: r['game_slug'] as String,
      startedAt: started.toLocal(),
      durationSec: (r['duration_sec'] as num?)?.toInt() ?? 0,
      rounds: n('rounds'),
      firstTime: n('firstTime'),
      anotherLook: n('anotherLook'),
      stillExploring: n('stillExploring'),
      notes: List<String>.from(summary?['notes'] ?? const <String>[]),
    );
  }
}

/// One game, and how it has gone across every session of it.
class GameStanding {
  final LearningGame game;
  final int sessions;
  final int rounds;
  final int firstTime;
  final int anotherLook;
  final int stillExploring;
  final Standing standing;
  final DateTime lastPlayed;

  const GameStanding({
    required this.game,
    required this.sessions,
    required this.rounds,
    required this.firstTime,
    required this.anotherLook,
    required this.stillExploring,
    required this.standing,
    required this.lastPlayed,
  });
}

/// Why a game is being suggested. The rule number is the §3.6 priority order and
/// exists so the ordering can be asserted rather than eyeballed.
class Recommendation {
  final LearningGame game;
  final String reason;
  final int rule; // 1 profile · 2 ladder · 3 balance · 4 unfinished

  const Recommendation({required this.game, required this.reason, required this.rule});
}

class CategoryTime {
  final GameShelf shelf;
  final Duration time;
  final int sessions;
  const CategoryTime({required this.shelf, required this.time, required this.sessions});
}

class GameInsights {
  final Duration togetherTime;
  final int sessionsThisWeek;
  final List<CategoryTime> byCategory;
  final List<GameStanding> standings;

  /// The child's own in-game choices, as summary.ts phrased them. Shown as warm
  /// moments and never scored.
  final List<String> moments;

  final List<GameShelf> strengths;
  final List<GameShelf> growing;
  final List<Recommendation> next;

  /// The closing line. Non-null whenever anything at all has been played — §3.6
  /// requires the dashboard to end on something that went well.
  final String? win;

  const GameInsights({
    this.togetherTime = Duration.zero,
    this.sessionsThisWeek = 0,
    this.byCategory = const [],
    this.standings = const [],
    this.moments = const [],
    this.strengths = const [],
    this.growing = const [],
    this.next = const [],
    this.win,
  });

  bool get hasPlayed => standings.isNotEmpty;

  /// Builds the whole dashboard.
  ///
  /// [now] is injected so "this week" and "the last 14 days" are testable rather
  /// than dependent on when the suite happens to run.
  static GameInsights build({
    required List<PlayedSession> sessions,
    required List<LearningGame> catalogue,
    List<String> profileSkillTags = const [],
    required DateTime now,
  }) {
    final bySlug = {for (final g in catalogue) g.slug: g};

    // Only sessions of games still in the catalogue: a retired game should not
    // haunt the dashboard.
    final played = sessions.where((s) => bySlug.containsKey(s.gameSlug)).toList();

    final weekAgo = now.subtract(const Duration(days: 7));
    final recent = played.where((s) => s.startedAt.isAfter(weekAgo)).toList();

    // ---- time together, by shelf ----
    final catSeconds = <GameShelf, int>{};
    final catSessions = <GameShelf, int>{};
    for (final s in recent) {
      final shelf = _shelfOf(bySlug[s.gameSlug]!);
      catSeconds[shelf] = (catSeconds[shelf] ?? 0) + s.durationSec;
      catSessions[shelf] = (catSessions[shelf] ?? 0) + 1;
    }
    final byCategory = [
      for (final shelf in GameShelf.values)
        if ((catSessions[shelf] ?? 0) > 0)
          CategoryTime(
            shelf: shelf,
            time: Duration(seconds: catSeconds[shelf] ?? 0),
            sessions: catSessions[shelf]!,
          ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    // ---- per-game standing, over all time ----
    final grouped = <String, List<PlayedSession>>{};
    for (final s in played) {
      (grouped[s.gameSlug] ??= []).add(s);
    }

    final standings = <GameStanding>[];
    for (final entry in grouped.entries) {
      final all = entry.value;
      // The two-day rule: distinct CALENDAR DAYS on which they got there first
      // time. Two good runs in one sitting is one day, and stays "coming along".
      final winningDays = all.where((s) => s.firstTime > 0).map((s) => s.day).toSet();
      standings.add(GameStanding(
        game: bySlug[entry.key]!,
        sessions: all.length,
        rounds: all.fold(0, (a, s) => a + s.rounds),
        firstTime: all.fold(0, (a, s) => a + s.firstTime),
        anotherLook: all.fold(0, (a, s) => a + s.anotherLook),
        stillExploring: all.fold(0, (a, s) => a + s.stillExploring),
        standing: winningDays.length >= 2
            ? Standing.secure
            : winningDays.length == 1
                ? Standing.emerging
                : Standing.exploring,
        lastPlayed: all.map((s) => s.startedAt).reduce((a, b) => a.isAfter(b) ? a : b),
      ));
    }
    standings.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));

    // ---- moments ----
    final moments = <String>[];
    for (final s in played.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt))) {
      for (final n in s.notes) {
        if (n.trim().isNotEmpty && !moments.contains(n)) moments.add(n);
      }
      if (moments.length >= 4) break;
    }

    // ---- strengths and growing areas ----
    //
    // "Growing" is the LEAST EXPLORED shelf, not the worst-performing one. There
    // is no worst-performing shelf here by design: framing a category as weak
    // would be a score about a child, which §3.6 forbids outright.
    final shelfProgress = <GameShelf, int>{};
    for (final st in standings) {
      final shelf = _shelfOf(st.game);
      shelfProgress[shelf] = (shelfProgress[shelf] ?? 0) +
          (st.standing == Standing.secure ? 2 : st.standing == Standing.emerging ? 1 : 0);
    }
    final strengths = shelfProgress.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final fortnightAgo = now.subtract(const Duration(days: 14));
    final recentShelves = played
        .where((s) => s.startedAt.isAfter(fortnightAgo))
        .map((s) => _shelfOf(bySlug[s.gameSlug]!))
        .toSet();
    final growing = GameShelf.values
        .where((s) => !recentShelves.contains(s))
        .where((s) => catalogue.any((g) => _shelfOf(g) == s))
        .toList();

    return GameInsights(
      togetherTime: Duration(seconds: recent.fold(0, (a, s) => a + s.durationSec)),
      sessionsThisWeek: recent.length,
      byCategory: byCategory,
      standings: standings,
      moments: moments,
      strengths: strengths.take(2).map((e) => e.key).toList(),
      growing: growing.take(2).toList(),
      next: _recommend(
        catalogue: catalogue,
        standings: standings,
        played: played,
        profileSkillTags: profileSkillTags,
        now: now,
      ),
      win: _win(standings, moments, recent),
    );
  }

  /// §3.6's four rules, in priority order. At most one suggestion per rule, and
  /// never the same game twice.
  static List<Recommendation> _recommend({
    required List<LearningGame> catalogue,
    required List<GameStanding> standings,
    required List<PlayedSession> played,
    required List<String> profileSkillTags,
    required DateTime now,
  }) {
    final out = <Recommendation>[];
    final taken = <String>{};
    final playedSlugs = standings.map((s) => s.game.slug).toSet();

    void add(LearningGame? g, String reason, int rule) {
      if (g == null || taken.contains(g.slug)) return;
      taken.add(g.slug);
      out.add(Recommendation(game: g, reason: reason, rule: rule));
    }

    // 1. Profile match — what she told us about this child, mapped to skills.
    //    Strongest match wins, and an already-played game does not count as new.
    if (profileSkillTags.isNotEmpty) {
      final wanted = profileSkillTags.toSet();
      final ranked = catalogue
          .where((g) => !playedSlugs.contains(g.slug))
          .map((g) => (g, g.skillTags.where(wanted.contains).length))
          .where((e) => e.$2 > 0)
          .toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
      if (ranked.isNotEmpty) {
        add(ranked.first.$1, 'Because of what you told us about how things are going', 1);
      }
    }

    // 2. Ladder order — the next step after one they have been playing.
    //
    // Only from a game they have actually got somewhere with: suggesting step 4
    // to a child still finding step 3 is the software deciding to advance them,
    // which is exactly what mastery.ts forbids.
    for (final st in standings) {
      if (st.standing == Standing.exploring) continue;
      final key = st.game.ladderKey;
      final step = st.game.ladderStep;
      if (key == null || step == null) continue;
      final nextStep = catalogue
          .where((g) => g.ladderKey == key && (g.ladderStep ?? 0) == step + 1)
          .where((g) => !playedSlugs.contains(g.slug));
      if (nextStep.isNotEmpty) {
        add(nextStep.first, 'The next step after ${st.game.title}', 2);
        break;
      }
    }

    // 3. Balance — a shelf they have not touched in a fortnight.
    final fortnightAgo = now.subtract(const Duration(days: 14));
    final recentShelves = played
        .where((s) => s.startedAt.isAfter(fortnightAgo))
        .map((s) => s.gameSlug)
        .toSet();
    final bySlug = {for (final g in catalogue) g.slug: g};
    final touched = recentShelves.map((s) => _shelfOf(bySlug[s]!)).toSet();
    final quiet = GameShelf.values.where((s) => !touched.contains(s));
    for (final shelf in quiet) {
      final candidate = catalogue.where((g) => _shelfOf(g) == shelf && !taken.contains(g.slug));
      if (candidate.isNotEmpty) {
        add(candidate.first, 'You two haven\'t tried ${shelf.label.toLowerCase()} lately', 3);
        break;
      }
    }

    // 4. Finish the fun — opened, but nothing ever came back from it.
    final unfinished = standings.where((s) => s.rounds == 0);
    if (unfinished.isNotEmpty) {
      add(unfinished.first.game, 'You started this one — worth another go', 4);
    }

    return out;
  }

  /// The closing line. Always something that went well.
  ///
  /// Ordered by how good the news is, so the best available thing is what she
  /// reads last. Null only when nothing has been played at all, where the empty
  /// state carries the warmth instead.
  static String? _win(
    List<GameStanding> standings,
    List<String> moments,
    List<PlayedSession> recent,
  ) {
    if (standings.isEmpty) return null;

    final secure = standings.where((s) => s.standing == Standing.secure);
    if (secure.isNotEmpty) {
      return '${secure.first.game.title} has clicked — twice on different days now 💛';
    }
    final firstTimes = standings.where((s) => s.firstTime > 0);
    if (firstTimes.isNotEmpty) {
      final s = firstTimes.first;
      // "— 1 of them" reads as a shrug about a single success. One round that
      // landed is worth a whole sentence; several are worth counting.
      return s.firstTime == 1
          ? 'They got a ${s.game.title} round first time 💛'
          : 'They got ${s.firstTime} ${s.game.title} rounds first time 💛';
    }
    if (moments.isNotEmpty) return '${moments.first} 💛';
    if (recent.isNotEmpty) {
      return 'You played together ${recent.length} ${recent.length == 1 ? "time" : "times"} '
          'this week — that\'s the bit that counts 💛';
    }
    return 'You two have played together before, and that stays with them 💛';
  }

  static GameShelf _shelfOf(LearningGame g) => GameShelf.values.firstWhere(
        (s) => s.key == g.category,
        orElse: () => GameShelf.maths,
      );
}
