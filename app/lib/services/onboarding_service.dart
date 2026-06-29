import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';

/// Resumable onboarding state (Onboarding & Personalization Spec §4). Tracks the
/// last completed step so a mom who drops mid-flow resumes where she left off.
/// One row per user, owner-scoped (RLS).
class OnboardingState {
  final int step;
  final bool completed;
  final String? childId;
  const OnboardingState({required this.step, required this.completed, this.childId});
}

class OnboardingService {
  const OnboardingService._();

  static const currentVersion = 1;

  static Future<OnboardingState?> load() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return null;
    final row = await supabase
        .from('onboarding_state')
        .select('step,completed,child_id')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return OnboardingState(
      step: (row['step'] ?? 0) as int,
      completed: (row['completed'] ?? false) as bool,
      childId: row['child_id'] as String?,
    );
  }

  /// Persist progress (one row per user — update if present, else insert).
  static Future<void> saveStep(int step, {String? childId, bool completed = false}) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final existing = await supabase
        .from('onboarding_state')
        .select('id')
        .eq('user_id', uid)
        .maybeSingle();
    final patch = <String, dynamic>{
      'step': step,
      'version': currentVersion,
      if (childId != null) 'child_id': childId,
      'completed': completed,
      if (completed) 'completed_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (existing != null) {
      await supabase.from('onboarding_state').update(patch).eq('id', existing['id'] as String);
    } else {
      await supabase.from('onboarding_state').insert({'user_id': uid, ...patch});
    }
  }

  static Future<void> complete({String? childId}) =>
      saveStep(8, childId: childId, completed: true);
}
