import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';
import 'child_service.dart';
import 'reminder_service.dart';
import 'wish_service.dart';

class ScheduledEvent {
  final String id;
  final String title;
  final DateTime startsAt;
  final String? tip;
  final String? wishId;
  const ScheduledEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.tip,
    this.wishId,
  });

  factory ScheduledEvent.fromMap(Map<String, dynamic> m) => ScheduledEvent(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        startsAt: DateTime.parse(m['starts_at'] as String).toLocal(),
        tip: m['tip'] as String?,
        wishId: m['wish_id'] as String?,
      );
}

/// Together-time calendar (Task 27). Turns a wish into a `scheduled_events` row,
/// flips the wish to 'scheduled', and schedules a gentle push reminder ahead of it
/// (Task 28). Family-scoped under the parent's session (owner_id + child_id).
class ScheduledEventService {
  const ScheduledEventService._();

  /// How long before the event the reminder fires.
  static const _reminderLead = Duration(hours: 3);

  static Future<ScheduledEvent> schedule({
    required String title,
    required DateTime startsAt,
    String? tip,
    String? wishId,
    String? activityId,
  }) async {
    final user = AuthService.currentUser;
    final child = ChildService.current;
    if (user == null || child == null) {
      throw StateError('Sign in and select a child first.');
    }
    final row = await supabase.from('scheduled_events').insert({
      'owner_id': user.id,
      'child_id': child.id,
      if (wishId != null) 'wish_id': wishId,
      if (activityId != null) 'activity_id': activityId,
      'title': title.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (tip != null && tip.trim().isNotEmpty) 'tip': tip.trim(),
    }).select().single();
    final event = ScheduledEvent.fromMap(row);

    // Mark the wish as scheduled so the wall reflects it.
    if (wishId != null) {
      try {
        await WishService.setStatus(wishId, 'scheduled');
      } catch (_) {/* non-fatal: the event is already saved */}
    }
    // Schedule a gentle reminder ahead of the event (best-effort).
    try {
      await ReminderService.forEvent(
        eventId: event.id,
        sendAt: startsAt.subtract(_reminderLead),
        type: 'playdate',
      );
    } catch (_) {/* non-fatal */}

    return event;
  }

  /// Upcoming events for the active child, soonest first.
  static Future<List<ScheduledEvent>> listUpcoming() async {
    final child = ChildService.current;
    if (child == null) return [];
    final cutoff = DateTime.now().subtract(const Duration(hours: 12)).toUtc().toIso8601String();
    final rows = await supabase
        .from('scheduled_events')
        .select('id,title,starts_at,tip,wish_id')
        .eq('child_id', child.id)
        .gte('starts_at', cutoff)
        .order('starts_at', ascending: true) as List;
    return [for (final r in rows) ScheduledEvent.fromMap(r as Map<String, dynamic>)];
  }

  static Future<void> delete(String id) async {
    await supabase.from('scheduled_events').delete().eq('id', id);
  }
}
