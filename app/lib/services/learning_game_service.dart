import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/supabase/supabase_init.dart';
import '../models/child.dart';
import '../models/game_insights.dart';
import '../models/learning_game.dart';
import 'auth_service.dart';
import 'child_service.dart';

/// Learning-games catalog + play-session logging (Expansion Plan §3.5).
///
/// The catalog is shared reference data (any signed-in parent may read it, none
/// may write it). Sessions are family-isolated child data, owner-only under RLS
/// and cascaded away with the child.
///
/// What gets stored is deliberately thin: which game, how long, and the outcome
/// buckets the games themselves produce. No free text, no audio, no camera —
/// these games have no text entry, so the only strings are the child's own
/// in-game choices ("Chose belly breathing").
class LearningGameService {
  const LearningGameService._();

  // ---- targeting ----
  //
  // Onboarding stores human sentences; games carry `skill_tags` — a 41-term
  // vocabulary that is NOT the card tag vocabulary and must not be confused with
  // it. This map is the join, and it is the single place the two meet.
  //
  // It fails silently when it drifts: an unmapped answer simply contributes no
  // tags, recommendation rule 1 finds nothing, and the dashboard quietly falls
  // through to rules 2–4. Nobody sees an error; the suggestions just stop being
  // about this child. `game_recommendation_test.dart` pins every value here to a
  // tag some game actually carries.

  /// Q4 — "anything tricky at the moment" (child.challenges).
  static const Map<String, List<String>> _challengeSkills = {
    'Big emotions / meltdowns': ['self-regulation', 'emotion-vocabulary', 'calming', 'intensity'],
    'Takes a while to warm up / shy': ['emotion-recognition', 'perspective-taking', 'self-awareness'],
    'Lots of energy, hard to settle': ['self-regulation', 'inhibitory-control', 'gross-motor'],
    'Gets frustrated easily': ['self-regulation', 'calming', 'breathing'],
    'Sharing & taking turns': ['perspective-taking', 'emotion-recognition'],
    'Listening & following directions': ['listening', 'working-memory', 'inhibitory-control'],
    'Worries or nervousness': ['calming', 'breathing', 'emotion-vocabulary'],
    'Changes & transitions are hard': ['self-regulation', 'executive-function', 'inhibitory-control'],
    'Sibling moments': ['perspective-taking', 'emotion-recognition'],
    // "Nothing major" is not a topic. Mapping it would fake a preference.
    'Honestly, nothing major right now': [],
  };

  /// Q3 — "what would you love help with" (child.focus_goals).
  static const Map<String, List<String>> _focusGoalSkills = {
    'Handling big feelings': ['emotion-vocabulary', 'emotion-recognition', 'self-regulation'],
    'Confidence & self-belief': ['self-awareness'],
    'Focus & attention': ['working-memory', 'inhibitory-control', 'executive-function', 'listening'],
    'Kindness & sharing': ['perspective-taking', 'emotion-recognition'],
    'Independence & responsibility': ['executive-function', 'self-regulation'],
    'Love of learning & curiosity': ['number-sense', 'decoding', 'comprehension'],
    'Friendships & social skills': ['perspective-taking', 'emotion-recognition', 'emotion-vocabulary'],
    'Calmer routines (sleep / meals / mornings)': ['self-regulation', 'calming', 'breathing'],
    // Nothing in these games speaks to screen time, and inventing a link would
    // make the recommendation a lie rather than a stretch.
    'Screen-time balance': [],
    'Creativity & imagination': ['comprehension'],
  };

  /// The skills to weight a recommendation towards, from what she told us.
  static List<String> skillTagsFor(Child child) {
    final out = <String>{};
    for (final s in child.focusGoals) {
      out.addAll(_focusGoalSkills[s] ?? const []);
    }
    for (final s in child.challenges) {
      out.addAll(_challengeSkills[s] ?? const []);
    }
    return out.toList();
  }

  @visibleForTesting
  static Map<String, List<String>> get challengeSkills => _challengeSkills;
  @visibleForTesting
  static Map<String, List<String>> get focusGoalSkills => _focusGoalSkills;

  /// The catalog, filtered to games that suit [age] and ordered for display.
  static Future<List<LearningGame>> catalogue({int? age}) async {
    var q = supabase.from('learning_games').select('*').eq('active', true);
    if (age != null) q = q.lte('age_min', age).gte('age_max', age);
    final rows = await q.order('category').order('sort') as List;
    return rows.map((r) => LearningGame.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// True when the signed-in family has at least one child the games suit.
  /// Drives whether the games area renders at all (§3.2) — no teaser, no
  /// "coming soon" for a five-year-old's older sibling.
  static Future<bool> availableForAnyChild() async {
    final children = ChildService.children;
    if (children.isEmpty) return false;
    final rows = await supabase
        .from('learning_games')
        .select('age_min, age_max')
        .eq('active', true) as List;
    if (rows.isEmpty) return false;
    return children.any((c) => rows.any((r) {
          final lo = (r['age_min'] as num?)?.toInt() ?? 5;
          final hi = (r['age_max'] as num?)?.toInt() ?? 6;
          return c.age >= lo && c.age <= hi;
        }));
  }

  /// Opens a session row when a game starts. Returns its id, or null if the
  /// write fails — a telemetry problem must never stop a child playing, so the
  /// caller carries on with a null id and simply records nothing.
  static Future<String?> startSession(String gameSlug) async {
    final user = AuthService.currentUser;
    final child = ChildService.current;
    if (user == null || child == null) return null;
    try {
      final row = await supabase
          .from('game_play_sessions')
          .insert({
            'owner_id': user.id,
            'child_id': child.id,
            'game_slug': gameSlug,
          })
          .select('id')
          .single();
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Closes the session with whatever the bridge reported.
  ///
  /// [events] are the raw MomzoBridge payloads, stored as-is: the dashboard reads
  /// only what it understands today and can read more later without a migration.
  /// [completed] means a summary actually arrived — if the app was killed
  /// mid-game the session still closes on elapsed time, just unsummarised.
  static Future<void> endSession({
    required String sessionId,
    required int durationSec,
    required bool completed,
    required List<Map<String, dynamic>> events,
  }) async {
    try {
      await supabase.from('game_play_sessions').update({
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'duration_sec': durationSec,
        'completed': completed,
        'progress': jsonDecode(jsonEncode({'events': events})),
      }).eq('id', sessionId);
    } catch (_) {
      // Same rule as above: never surface a telemetry failure to a mother who
      // has just finished playing with her child.
    }
  }

  /// "How it's going" for the selected child (Expansion Plan §3.6).
  ///
  /// Everything here is rule-based SQL and arithmetic — no model is in this path,
  /// per the cost strategy, and the CI guard on LLM call sites stays intact.
  ///
  /// Sessions are read for the selected child only. RLS already scopes them to
  /// the family; the child filter is what makes the numbers about this child
  /// rather than about the household.
  static Future<GameInsights> insights({DateTime? now}) async {
    final child = ChildService.current;
    if (child == null) return const GameInsights();

    final rows = List<Map<String, dynamic>>.from(
      await supabase
          .from('game_play_sessions')
          .select('game_slug, started_at, duration_sec, completed, progress')
          .eq('child_id', child.id)
          .order('started_at', ascending: false)
          .limit(200) as List,
    );

    final sessions = rows.map(PlayedSession.fromRow).nonNulls.toList();
    final catalogue = await LearningGameService.catalogue(age: child.age);

    return GameInsights.build(
      sessions: sessions,
      catalogue: catalogue,
      profileSkillTags: skillTagsFor(child),
      now: now ?? DateTime.now(),
    );
  }
}
