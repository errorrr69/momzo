import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';

/// COPPA parental consent (Task 9).
///
/// A parent must record consent before any child data is collected. The database
/// also enforces this (a trigger blocks `children` inserts without a consent row),
/// so this service is the *user-facing* half of a belt-and-braces gate.
///
/// NOTE: `method` is `parent_attestation` for the MVP — this is NOT full COPPA
/// verifiable parental consent. See migration 07's METHOD NOTE; the verification
/// strength must be upgraded before a US launch.
class ConsentService {
  const ConsentService._();

  /// Bump when the privacy policy / data practices change, to force re-consent.
  static const String policyVersion = '2026-06-24';
  static const String method = 'parent_attestation';

  /// True only if the signed-in parent has consented to the CURRENT policy version.
  static Future<bool> hasConsent() async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    final rows = await supabase
        .from('consents')
        .select('id')
        .eq('user_id', user.id)
        .eq('policy_version', policyVersion)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  static Future<void> recordConsent() async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('Cannot record consent without a signed-in user.');
    }
    await supabase.from('consents').insert({
      'user_id': user.id,
      'policy_version': policyVersion,
      'method': method,
    });
  }
}
