import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_init.dart';

/// Thin wrapper around Supabase Auth (Task 5).
///
/// The app authenticates directly against Supabase using the anon key only — no
/// secret ever lives in the client (Build Guide §5, Hard Rule #5). Sessions are
/// persisted and refreshed automatically by `supabase_flutter`, so a signed-in
/// parent stays signed in across app restarts.
///
/// On every sign-in we upsert the parent's `public.users` profile row (which is
/// RLS self-only, Hard Rule #1) so the rest of the app always has a profile to
/// hang `children` and family data off of.
class AuthService {
  const AuthService._();

  static GoTrueClient get _auth => supabase.auth;

  static Session? get currentSession => _auth.currentSession;
  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => currentSession != null;

  /// Subscribe once (at startup) so any sign-in — email OR social redirect —
  /// guarantees a profile row exists.
  static void startProfileSync() {
    _auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        // Fire-and-forget; a failed upsert is retried on the next sign-in.
        ensureProfile();
      }
    });
  }

  /// Create an account with email + password. With auto-confirm enabled (dev) the
  /// returned session is non-null and the user is immediately signed in; with
  /// email confirmation on (prod), session is null until the link is clicked.
  static Future<AuthResponse> signUpWithEmail(String email, String password) {
    return _auth.signUp(email: email.trim(), password: password);
  }

  static Future<AuthResponse> signInWithEmail(String email, String password) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Google / Apple. Requires the provider to be configured in the Supabase
  /// dashboard (subtask 5.1); throws until then, which the UI surfaces gently.
  static Future<bool> signInWithOAuth(OAuthProvider provider) {
    return _auth.signInWithOAuth(provider);
  }

  static Future<void> signOut() => _auth.signOut();

  /// Upsert the parent's profile. Omitted columns are preserved on conflict, so
  /// re-running this on every sign-in never clobbers an existing display_name.
  static Future<void> ensureProfile({String? displayName}) async {
    final user = currentUser;
    if (user == null) return;

    final row = <String, dynamic>{
      'id': user.id,
      // Best-effort starting timezone; the scheduling/quiet-hours work refines it.
      'timezone': DateTime.now().timeZoneName,
    };

    // Seed a friendly default name from the email local part on first creation.
    final name = displayName ?? _nameFromEmail(user.email);
    if (name != null && name.isNotEmpty) row['display_name'] = name;

    await supabase.from('users').upsert(row);
  }

  static String? _nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return null;
    final local = email.split('@').first.trim();
    return local.isEmpty ? null : local;
  }
}
