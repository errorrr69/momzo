import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';

/// Creates reminder rows that the live `send-due-reminders` Edge Function picks up
/// every 15 min (Task 28). Idempotency + quiet-hours + delivery all live in that
/// function; here we just schedule the row. `user_id` is the owner (its RLS policy
/// compares user_id directly).
class ReminderService {
  const ReminderService._();

  /// Schedule a push reminder for a calendar event. [sendAt] is clamped to the
  /// near future so a just-scheduled, soon event still nudges rather than being
  /// skipped as "in the past".
  static Future<void> forEvent({
    required String eventId,
    required DateTime sendAt,
    String type = 'playdate', // 'playdate' | 'activity'
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final when = sendAt.isAfter(now.add(const Duration(minutes: 1)))
        ? sendAt
        : now.add(const Duration(minutes: 1));
    await supabase.from('reminders').insert({
      'user_id': user.id,
      'event_id': eventId,
      'type': type,
      'channel': 'push',
      'send_at': when.toUtc().toIso8601String(),
    });
  }
}
