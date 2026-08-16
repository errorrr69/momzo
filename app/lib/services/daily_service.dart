import 'package:flutter/foundation.dart';

import '../core/supabase/supabase_init.dart';
import '../models/child.dart';
import '../models/daily_card.dart';
import 'auth_service.dart';
import 'profile_service.dart';

/// Daily card assignment + retrieval (Task 13).
///
/// One card per child per day, recorded in `daily_assignments`. Selection is
/// RULE-BASED and stays that way: age window, then tag overlap with what the
/// mother told us about this child, then least-recently-shown. No model is in
/// this path — a daily card must be explainable and instant.
class DailyService {
  const DailyService._();

  /// Bumps whenever today's card is marked read, so any visible view can refresh
  /// (Home is kept alive in the shell's IndexedStack, so it won't rebuild on its
  /// own when the reader screen pops). Same idiom as LibraryService.savedRevision.
  static final ValueNotifier<int> readRevision = ValueNotifier<int>(0);

  /// The columns the app is allowed to read.
  ///
  /// Spelled out rather than `*` because `content_cards.concept_basis` is internal
  /// (00_CARD_SPEC §6) and the database revokes it from `authenticated` — a `*`
  /// select now fails outright rather than leaking it. Listing the columns is what
  /// keeps that guarantee cheap.
  static const _cardColumns =
      'id, slug, title, summary, why_it_matters, main_read, activity, '
      'category, subtopic, tags, age_min, age_max, source, slides';

  // ---- targeting ----
  //
  // Onboarding stores human sentences ("Handling big feelings"); cards carry the
  // controlled vocabulary from 00_CARD_SPEC §4 ("big-feelings", "meltdowns"). This
  // map is the join between them, and it is the single place the two vocabularies
  // meet.
  //
  // It matters more than it looks. Tag targeting fails SILENTLY when it drifts:
  // `overlaps` still runs, matches nothing, and selection falls through to an
  // untargeted card. Nobody sees an error — the product just quietly stops being
  // personalised. The database enforces the card side with a check constraint; the
  // test suite pins this side.

  /// Q3 — "what would you love help with" (child.focus_goals).
  static const Map<String, List<String>> _focusGoalTags = {
    'Handling big feelings': ['big-feelings', 'meltdowns', 'frustration', 'anger', 'worries'],
    'Confidence & self-belief': ['confidence', 'self-belief', 'independence'],
    'Focus & attention': ['focus', 'listening', 'transitions', 'high-energy'],
    'Kindness & sharing': ['kindness', 'sharing', 'friendships'],
    'Independence & responsibility': ['independence', 'confidence', 'tidying'],
    'Love of learning & curiosity': ['learning', 'curiosity', 'reading', 'numbers'],
    'Friendships & social skills': ['friendships', 'sharing', 'kindness', 'shy-warm-up'],
    'Calmer routines (sleep / meals / mornings)': ['sleep', 'mornings', 'mealtimes', 'rituals'],
    'Screen-time balance': ['screens'],
    // No 'creativity' tag exists in §4; curiosity and learning are the honest
    // neighbours rather than inventing vocabulary the cards don't carry.
    'Creativity & imagination': ['curiosity', 'learning'],
  };

  /// Q4 — "anything tricky at the moment" (child.challenges).
  static const Map<String, List<String>> _challengeTags = {
    'Big emotions / meltdowns': ['meltdowns', 'big-feelings', 'anger'],
    'Takes a while to warm up / shy': ['shy-warm-up', 'confidence', 'friendships'],
    'Lots of energy, hard to settle': ['high-energy', 'focus', 'sleep'],
    'Gets frustrated easily': ['frustration', 'big-feelings', 'confidence'],
    'Sharing & taking turns': ['sharing', 'kindness', 'siblings'],
    'Listening & following directions': ['listening', 'focus', 'transitions'],
    'Worries or nervousness': ['worries', 'big-feelings', 'confidence'],
    'Changes & transitions are hard': ['transitions', 'rituals', 'mornings'],
    'Sibling moments': ['siblings', 'sharing', 'kindness'],
    // Deliberately empty: "nothing major" is not a topic, and mapping it to
    // anything would fake a preference she didn't express.
    'Honestly, nothing major right now': [],
  };

  /// Q8 — the mother's own goals (users.mom_goals).
  ///
  /// Included because the connection-bonding shelf — 13 of the 90 cards — has no
  /// route in from the child questions. Nothing a mother says about her child
  /// asks for special time or rituals; she says it about herself, here.
  static const Map<String, List<String>> _momGoalTags = {
    'Feel closer to': ['connection', 'bonding', 'rituals'],
    'Have nice things to do together': ['bonding', 'connection', 'rituals'],
    'Understand them better': ['big-feelings', 'connection'],
    'Build better routines': ['rituals', 'mornings', 'sleep', 'mealtimes'],
    'Learn practical tools': ['listening', 'transitions', 'frustration'],
    // "Feel less stressed or guilty" names her worry; §5 rule 1 says never reflect
    // that back at her, so it targets nothing and simply falls through.
  };

  static List<String> _tagsFor(Child child, List<String> momGoals) {
    final out = <String>{};
    for (final s in child.focusGoals) {
      out.addAll(_focusGoalTags[s] ?? const []);
    }
    for (final s in child.challenges) {
      out.addAll(_challengeTags[s] ?? const []);
    }
    for (final s in momGoals) {
      out.addAll(_momGoalTags[s] ?? const []);
    }
    return out.toList();
  }

  /// Exposed for the targeting test, which asserts every onboarding option maps
  /// into the §4 vocabulary and that the whole vocabulary stays reachable.
  @visibleForTesting
  static List<String> tagsForChild(Child child, {List<String> momGoals = const []}) =>
      _tagsFor(child, momGoals);

  @visibleForTesting
  static Map<String, List<String>> get focusGoalTags => _focusGoalTags;
  @visibleForTesting
  static Map<String, List<String>> get challengeTags => _challengeTags;
  @visibleForTesting
  static Map<String, List<String>> get momGoalTags => _momGoalTags;

  static String _today() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  /// Today's card for [child] — returns the existing assignment if there is one,
  /// otherwise picks + records a new one. Null if nothing suitable exists.
  static Future<DailyCard?> todaysCard(Child child) async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final today = _today();

    final existing = await supabase
        .from('daily_assignments')
        .select('id, read_at, content_cards($_cardColumns)')
        .eq('child_id', child.id)
        .eq('date', today)
        .maybeSingle();
    if (existing != null && existing['content_cards'] != null) {
      return DailyCard.fromAssignment(existing);
    }

    // Full history, not just the ids: "least recently shown" needs the dates.
    final history = await supabase
        .from('daily_assignments')
        .select('card_id, date')
        .eq('child_id', child.id) as List;

    final lastShown = <String, String>{};
    for (final r in history) {
      final id = r['card_id'] as String;
      final date = (r['date'] ?? '') as String;
      if (date.compareTo(lastShown[id] ?? '') > 0) lastShown[id] = date;
    }

    // The mother's own goals only matter when picking a NEW card, so this query
    // stays off the once-a-day cached path above.
    List<String> momGoals = const [];
    try {
      final profile = await ProfileService.load();
      momGoals = List<String>.from(profile?['mom_goals'] ?? const <String>[]);
    } catch (_) {
      // Targeting degrades to the child's own answers. Not worth failing over.
    }

    final tags = _tagsFor(child, momGoals);

    // Targeted first, then anything age-appropriate. Both go through the same
    // least-recently-shown ordering, so the fallback is a widening of the pool
    // rather than a different rule.
    var card = await _pick(child, tags, lastShown);
    card ??= await _pick(child, null, lastShown);
    if (card == null) return null;

    final ins = await supabase.from('daily_assignments').insert({
      'owner_id': user.id,
      'child_id': child.id,
      'card_id': card['id'],
      'date': today,
    }).select('id, read_at').single();

    return DailyCard.fromCard(card, assignmentId: ins['id'] as String, readAt: ins['read_at']);
  }

  /// One card from the pool: never-shown first, then strongest tag match, then a
  /// stable per-day rotation.
  ///
  /// Ordering happens here rather than in SQL because "when did this child last
  /// see this card" lives in a different table per child; pulling the candidate
  /// set and ranking it in memory is one round trip instead of a join that
  /// PostgREST would need a view for. The pool is ~90 rows.
  ///
  /// Match STRENGTH, not just a match, because `overlaps` is nearly free to
  /// satisfy. A mother who picks four answers ends up with ~17 of the 29 tags, and
  /// a plain overlap then matches 89 of 90 cards — technically targeted, in
  /// practice random. Counting how many of her tags a card carries is what makes
  /// the answers she gave actually change what she reads first.
  static Future<Map<String, dynamic>?> _pick(
    Child child,
    List<String>? tags,
    Map<String, String> lastShown,
  ) async {
    var q = supabase
        .from('content_cards')
        .select(_cardColumns)
        .eq('published', true)
        .lte('age_min', child.age)
        .gte('age_max', child.age);
    if (tags != null && tags.isNotEmpty) q = q.overlaps('tags', tags);

    final rows = List<Map<String, dynamic>>.from(await q as List);
    if (rows.isEmpty) return null;

    final wanted = (tags ?? const <String>[]).toSet();
    int strength(Map<String, dynamic> r) =>
        List<String>.from(r['tags'] ?? const <String>[]).where(wanted.contains).length;

    rows.sort((a, b) {
      // 1. Never-shown ahead of everything shown; among shown, longest-ago first.
      final byDate = (lastShown[a['id']] ?? '').compareTo(lastShown[b['id']] ?? '');
      if (byDate != 0) return byDate;

      // 2. Among equally-unseen cards, the ones that speak to more of what she
      //    told us come first.
      final byStrength = strength(b).compareTo(strength(a));
      if (byStrength != 0) return byStrength;

      // 3. Stable tie-break so a fresh library doesn't always open on the same
      //    card, and so the choice is identical every time it's computed today.
      return _rank(a['id'] as String).compareTo(_rank(b['id'] as String));
    });
    return rows.first;
  }

  /// Deterministic per-day shuffle key: same card ordering all day, different
  /// tomorrow. Keeps selection reproducible — a card you can't explain is a bug.
  static int _rank(String id) {
    final seed = DateTime.now().day;
    var h = seed;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  static Future<void> markRead(String assignmentId) async {
    await supabase
        .from('daily_assignments')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', assignmentId);
    readRevision.value++;
  }
}
