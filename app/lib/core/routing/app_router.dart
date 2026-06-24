/// App routing scaffold.
///
/// Placeholder — the real navigation graph is wired in Phase 1 (onboarding,
/// Task 12, decides the start destination: WelcomeScreen for new users vs Home
/// for an authed user with a child profile).
///
/// For now the dev entry point is the `ScreenGallery` in `main.dart`, which can
/// preview every one of the 25 screens. Production should start at
/// `WelcomeScreen()` once auth + onboarding are wired.
///
/// Route name constants live here so feature code can reference stable strings
/// rather than hard-coded literals.
class Routes {
  const Routes._();

  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String consent = '/onboarding/consent';
  static const String privacyPolicy = '/privacy-policy';
  static const String onboardingChildBasics = '/onboarding/child';
  static const String onboardingTemperament = '/onboarding/temperament';
  static const String onboardingAllSet = '/onboarding/all-set';
  static const String home = '/home';
}
