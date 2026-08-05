import '../core/supabase/supabase_init.dart';
import 'child_service.dart';

/// A gentle weekly summary for a child: what the week held (reads, activities,
/// shared questions), how many days you connected, a warm reflection, and one
/// small thing to try next week (Task 31).
class WeeklyRecap {
  final String childName;
  final int reads; // daily cards opened this week
  final int activities; // activities logged this week
  final int moments; // shared questions answered (bonding) this week
  final int connectedDays; // distinct days with any engagement (0–7)
  final String learned; // a warm, non-judgemental reflection
  final String nextStep; // one small, concrete thing to try next week

  const WeeklyRecap({
    required this.childName,
    required this.reads,
    required this.activities,
    required this.moments,
    required this.connectedDays,
    required this.learned,
    required this.nextStep,
  });

  int get total => reads + activities + moments;

  /// True once there is anything to celebrate; drives an encouraging empty state.
  bool get hasActivity => total > 0 || connectedDays > 0;
}

/// Builds the gentle weekly recap (Task 31) and the soft consistency streak
/// (Task 32) from real engagement — reads, activities, and shared questions —
/// over the trailing 7 days.
///
/// Tone is non-negotiable (Hard Rule #18): celebrate small wins, never shame a
/// miss. A quiet week reads as an invitation, never a guilt-trip. All queries are
/// child-scoped and run under RLS (owner-only), so there is nothing cross-family
/// to leak.
class RecapService {
  const RecapService._();

  static const _window = Duration(days: 7);

  // ── Streak (Task 32) ──────────────────────────────────────────────────────

  /// Distinct days (0–7) in the last week with any engagement for the current
  /// child. Lightweight — used by the home streak chip.
  static Future<int> connectedDays() async {
    final child = ChildService.current;
    if (child == null) return 0;
    final days = <int>{};
    for (final ts in await _engagementTimestamps(child.id)) {
      days.add(_dayKey(ts));
    }
    return days.length;
  }

  /// A soft, encouraging line for [days] connected this week. Never negative:
  /// zero days is a fresh-start invitation, not a broken streak. The caller
  /// supplies the 🌱 leading icon, so the copy itself carries no emoji.
  static String streakMessage(int days) {
    if (days <= 0) return 'A fresh week — connect whenever it suits you.';
    if (days == 1) return 'You connected 1 day this week — every moment counts.';
    if (days >= 5) return "You've connected $days days this week — you're on a roll!";
    return "You've connected $days days this week — lovely.";
  }

  // ── Weekly recap (Task 31) ────────────────────────────────────────────────

  static Future<WeeklyRecap> weekly() async {
    final child = ChildService.current;
    if (child == null) {
      return const WeeklyRecap(
        childName: 'your child',
        reads: 0,
        activities: 0,
        moments: 0,
        connectedDays: 0,
        learned: 'Every small moment you share adds up.',
        nextStep: 'Open a daily card together this week.',
      );
    }

    final since = _since();
    final days = <int>{};

    final readRows = await supabase
        .from('daily_assignments')
        .select('read_at')
        .eq('child_id', child.id)
        .not('read_at', 'is', null)
        .gte('read_at', since) as List;
    for (final r in readRows) {
      days.add(_dayKey(DateTime.parse(r['read_at'] as String).toLocal()));
    }

    final actRows = await supabase
        .from('activity_logs')
        .select('completed_at')
        .eq('child_id', child.id)
        .gte('completed_at', since) as List;
    for (final r in actRows) {
      days.add(_dayKey(DateTime.parse(r['completed_at'] as String).toLocal()));
    }

    final momentRows = await supabase
        .from('question_responses')
        .select('answered_at')
        .eq('child_id', child.id)
        .eq('respondent', 'parent')
        .gte('answered_at', since) as List;
    for (final r in momentRows) {
      days.add(_dayKey(DateTime.parse(r['answered_at'] as String).toLocal()));
    }

    final reads = readRows.length;
    final activities = actRows.length;
    final moments = momentRows.length;

    // Theme the reflection + next step on what the mom said she cares about, so
    // the recap stays personal and honest without an AI call.
    final goal = child.focusGoals.isNotEmpty ? child.focusGoals.first : null;
    final theme = _themes[goal] ?? _defaultTheme;
    final name = child.name;

    final learned = reads + activities + moments > 0
        ? theme.learned.replaceAll('{name}', name)
        : 'Every small moment you shared this week added up for $name.';

    return WeeklyRecap(
      childName: name,
      reads: reads,
      activities: activities,
      moments: moments,
      connectedDays: days.length,
      learned: learned,
      nextStep: theme.nextStep.replaceAll('{name}', name),
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// All engagement timestamps (reads + activities + shared questions) in the
  /// last week for [childId], as local DateTimes.
  static Future<List<DateTime>> _engagementTimestamps(String childId) async {
    final since = _since();
    final out = <DateTime>[];

    final reads = await supabase
        .from('daily_assignments')
        .select('read_at')
        .eq('child_id', childId)
        .not('read_at', 'is', null)
        .gte('read_at', since) as List;
    for (final r in reads) {
      out.add(DateTime.parse(r['read_at'] as String).toLocal());
    }

    final acts = await supabase
        .from('activity_logs')
        .select('completed_at')
        .eq('child_id', childId)
        .gte('completed_at', since) as List;
    for (final r in acts) {
      out.add(DateTime.parse(r['completed_at'] as String).toLocal());
    }

    final moments = await supabase
        .from('question_responses')
        .select('answered_at')
        .eq('child_id', childId)
        .eq('respondent', 'parent')
        .gte('answered_at', since) as List;
    for (final r in moments) {
      out.add(DateTime.parse(r['answered_at'] as String).toLocal());
    }

    return out;
  }

  static String _since() =>
      DateTime.now().toUtc().subtract(_window).toIso8601String();

  /// Buckets a moment into a whole-day key (local date) for distinct-day counts.
  static int _dayKey(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  // Reflections + next steps keyed to the onboarding focus goals (see
  // DailyService._labelTags). {name} is substituted with the child's name.
  static const _defaultTheme = (
    learned: "You're showing up for {name} in the small, everyday moments.",
    nextStep: 'Ask {name} what made them smile today.',
  );

  static const Map<String, ({String learned, String nextStep})> _themes = {
    'Handling big feelings': (
      learned: "You're getting better at helping {name} name big feelings before fixing them.",
      nextStep: 'Next time {name} melts down, try naming the feeling out loud first.',
    ),
    'Confidence & self-belief': (
      learned: "You're noticing and naming {name}'s small wins.",
      nextStep: 'Catch {name} being brave this week and say exactly what you saw.',
    ),
    'Focus & attention': (
      learned: "You're building calmer, more focused moments with {name}.",
      nextStep: 'Try one short, screen-free activity together this week.',
    ),
    'Kindness & sharing': (
      learned: "You're modelling kindness in everyday moments with {name}.",
      nextStep: 'Point out one moment when {name} was kind — name it out loud.',
    ),
    'Independence & responsibility': (
      learned: "You're giving {name} room to try things on their own.",
      nextStep: 'Let {name} lead one small task this week.',
    ),
    'Love of learning & curiosity': (
      learned: "You're feeding {name}'s curiosity with everyday wonder.",
      nextStep: "Follow one of {name}'s 'why' questions all the way this week.",
    ),
    'Friendships & social skills': (
      learned: "You're helping {name} navigate friendships with care.",
      nextStep: 'Ask {name} about a friend this week and really listen.',
    ),
    'Calmer routines (sleep / meals / mornings)': (
      learned: "You're bringing a little more calm to {name}'s routines.",
      nextStep: 'Pick one routine and make it gentler this week.',
    ),
    'Screen-time balance': (
      learned: "You're finding a kinder balance around screens with {name}.",
      nextStep: 'Swap ten minutes of screen time for something together.',
    ),
    'Creativity & imagination': (
      learned: "You're making space for {name}'s imagination.",
      nextStep: 'Build a tiny made-up story together this week.',
    ),
  };
}
