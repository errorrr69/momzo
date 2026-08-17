/// Compile-time environment configuration for the Momzo app.
///
/// Hard Rule (Build Guide §5): the app only ever holds the Supabase **anon**
/// key — never the `service_role` key, an LLM key, a WhatsApp token, or the FCM
/// server key. Those live in Edge Function env only.
///
/// Values are injected at build time so no key is committed to the repo. Use
/// the git-ignored `app/env.json` (see `env.example.json`) rather than spelling
/// the values out — a build that forgets them does not fail, it silently runs in
/// UI-only mock mode with no backend:
///
///   flutter run   --dart-define-from-file=env.json
///   flutter build apk --release --dart-define-from-file=env.json
class AppEnv {
  const AppEnv._();

  /// Supabase project URL. Comes from `env.json`; not hardcoded here, so there
  /// is one place to change when the project changes.
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// Supabase anon (public) key — safe in the client because RLS protects data.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// True only when both Supabase values were provided at build time. Until
  /// then the app runs in UI-only (mock) mode — useful for the screen gallery.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Sentry DSN (Task 4, observability). Not a data-access secret — it only allows
  /// sending crash events. Empty -> Sentry stays disabled.
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  /// Sentry environment tag (e.g. production / staging).
  static const String sentryEnv =
      String.fromEnvironment('SENTRY_ENV', defaultValue: 'production');

  /// When true, capture a deliberate test error at boot to verify Sentry delivery.
  static const bool sentryTest =
      bool.fromEnvironment('SENTRY_TEST', defaultValue: false);

  static bool get hasSentry => sentryDsn.isNotEmpty;
}
