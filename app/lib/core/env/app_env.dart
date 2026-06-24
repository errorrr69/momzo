/// Compile-time environment configuration for the Momzo app.
///
/// Hard Rule (Build Guide §5): the app only ever holds the Supabase **anon**
/// key — never the `service_role` key, an LLM key, a WhatsApp token, or the FCM
/// server key. Those live in Edge Function env only.
///
/// Values are injected at build time via `--dart-define` (or a
/// `--dart-define-from-file=env.json`) so no key is committed to the repo:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://nngjqhrxbhugnafyviqj.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
class AppEnv {
  const AppEnv._();

  /// Supabase project URL. Project id: nngjqhrxbhugnafyviqj.
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// Supabase anon (public) key — safe in the client because RLS protects data.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// True only when both Supabase values were provided at build time. Until
  /// then the app runs in UI-only (mock) mode — useful for the screen gallery.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
