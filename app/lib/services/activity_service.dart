import '../core/supabase/supabase_init.dart';
import '../models/activity.dart';
import 'auth_service.dart';
import 'child_service.dart';

/// Activity library queries + "did it" logging (Task 18).
///
/// Filters the vetted `activities` by the time a mom has (duration ≤ chosen),
/// the child's age, and optionally place. Completions are written to
/// `activity_logs` (RLS owner-only).
class ActivityService {
  const ActivityService._();

  /// [maxMinutes] = the time budget (5/15/30); returns activities that fit.
  /// [place] in {'indoor','car','kitchen'}; 'indoor' is the catch-all (no filter).
  static Future<List<Activity>> list({required int maxMinutes, String? place}) async {
    final age = ChildService.current?.age;
    var q = supabase.from('activities').select('*').lte('duration_min', maxMinutes);
    if (age != null) q = q.lte('age_min', age).gte('age_max', age);
    if (place != null && place != 'indoor') q = q.overlaps('location', [place]);
    final rows = await q.order('title', ascending: true).limit(50) as List;
    return rows.map((r) => Activity.fromMap(r as Map<String, dynamic>)).toList();
  }

  static Future<void> logCompletion({
    required String activityId,
    String? note,
    String? photoUrl,
  }) async {
    final user = AuthService.currentUser;
    final child = ChildService.current;
    if (user == null || child == null) {
      throw StateError('Sign in and select a child first.');
    }
    await supabase.from('activity_logs').insert({
      'owner_id': user.id,
      'child_id': child.id,
      'activity_id': activityId,
      'user_id': user.id,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (photoUrl != null) 'photo_url': photoUrl,
    });
  }
}
