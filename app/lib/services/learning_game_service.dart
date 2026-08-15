import 'dart:convert';

import '../core/supabase/supabase_init.dart';
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
}
