import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';

/// Notification preferences for the gentle daily nudge + quiet hours (Task 20).
/// Reads/writes the signed-in parent's row; the server-side dispatcher honours
/// these (slot time, quiet hours) when sending.
class NotificationPrefs {
  final bool dailyNudge;
  final String nudgeSlot; // 'morning' | 'noon' | 'evening'
  final int? quietStart; // local hour 0-23, null = off
  final int? quietEnd;

  const NotificationPrefs({
    this.dailyNudge = true,
    this.nudgeSlot = 'morning',
    this.quietStart = 21,
    this.quietEnd = 7,
  });
}

class NotificationService {
  const NotificationService._();

  static Future<NotificationPrefs> load() async {
    final user = AuthService.currentUser;
    if (user == null) return const NotificationPrefs();
    final row = await supabase
        .from('users')
        .select('daily_nudge, nudge_slot, quiet_hours')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return const NotificationPrefs();
    final qh = row['quiet_hours'] as Map<String, dynamic>?;
    return NotificationPrefs(
      dailyNudge: (row['daily_nudge'] ?? true) as bool,
      nudgeSlot: (row['nudge_slot'] ?? 'morning') as String,
      quietStart: qh?['start'] as int?,
      quietEnd: qh?['end'] as int?,
    );
  }

  static Future<void> save({bool? dailyNudge, String? nudgeSlot, int? quietStart, int? quietEnd, bool clearQuiet = false}) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final patch = <String, dynamic>{};
    if (dailyNudge != null) patch['daily_nudge'] = dailyNudge;
    if (nudgeSlot != null) patch['nudge_slot'] = nudgeSlot;
    if (clearQuiet) {
      patch['quiet_hours'] = null;
    } else if (quietStart != null && quietEnd != null) {
      patch['quiet_hours'] = {'start': quietStart, 'end': quietEnd};
    }
    if (patch.isEmpty) return;
    await supabase.from('users').update(patch).eq('id', user.id);
  }
}
