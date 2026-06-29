import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';

/// Mom-level profile (Onboarding & Personalization Spec §4 `profiles`/users).
/// Holds the answers that personalize at the parent level: time-with-child (Q2),
/// her goals (Q8), daily-moment time (Q7), quiet hours. Push is the only channel.
class ProfileService {
  const ProfileService._();

  static Future<void> save({
    String? displayName,
    String? timeWithChild,
    List<String>? momGoals,
    String? dailyNudgeTime, // 'HH:mm'
    Map<String, dynamic>? quietHours,
  }) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final patch = <String, dynamic>{
      if (displayName != null) 'display_name': displayName.trim(),
      if (timeWithChild != null) 'time_with_child': timeWithChild,
      if (momGoals != null) 'mom_goals': momGoals,
      if (dailyNudgeTime != null) 'daily_nudge_time': dailyNudgeTime,
      if (quietHours != null) 'quiet_hours': quietHours,
    };
    if (patch.isEmpty) return;
    await supabase.from('users').update(patch).eq('id', uid);
  }

  static Future<Map<String, dynamic>?> load() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return null;
    return await supabase
        .from('users')
        .select('display_name,time_with_child,mom_goals,daily_nudge_time,nudge_channel,quiet_hours')
        .eq('id', uid)
        .maybeSingle();
  }
}
