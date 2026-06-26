import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/env/app_env.dart';
import 'core/push/push_service.dart';
import 'core/supabase/supabase_init.dart';
import 'core/theme/momzo_colors.dart';
import 'services/auth_service.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/onboarding/consent_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connects to Supabase when build-time env is provided (anon key only).
  final connected = await initSupabase();
  // Keep the parent's profile row in sync on every sign-in (Task 5).
  if (connected) AuthService.startProfileSync();
  // FCM registration (Task 7) — best-effort; no-ops where push can't run.
  await PushService.init();

  // Crash/error reporting (Task 4). Disabled if no DSN. PII-scrubbed: we never
  // attach user/device identity, and beforeSend strips user/request payloads.
  if (!AppEnv.hasSentry) {
    runApp(const MomzoApp());
    return;
  }
  await SentryFlutter.init(
    (o) {
      o.dsn = AppEnv.sentryDsn;
      o.environment = AppEnv.sentryEnv;
      o.sendDefaultPii = false; // no device/user identifiers (COPPA, Hard Rule #10)
      o.tracesSampleRate = 0.0;
      o.beforeSend = (event, hint) {
        // PII scrub (COPPA, Hard Rule #10): never ship user/request payloads.
        event.user = null;
        event.request = null;
        return event;
      };
    },
    appRunner: () {
      // One-shot delivery self-test when built with --dart-define=SENTRY_TEST=true.
      if (AppEnv.sentryTest) {
        Sentry.captureException(
          Exception('Sentry test error — Momzo app boot'),
          stackTrace: StackTrace.current,
        );
      }
      runApp(const MomzoApp());
    },
  );
}

class MomzoApp extends StatelessWidget {
  const MomzoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momzo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: MomzoColors.cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: MomzoColors.coral,
          primary: MomzoColors.coral,
          surface: MomzoColors.cream,
        ),
        useMaterial3: true,
      ),
      home: const MomzoRoot(),
    );
  }
}

/// Decides the start screen at launch:
///   - signed in  -> ConsentScreen, which itself routes onward (returning
///     parents skip straight to Home; new ones go through consent + onboarding).
///   - otherwise  -> Welcome.
/// The persisted Supabase session is restored during initSupabase(), so this is
/// accurate on a cold start. Sign-in/out navigation is driven by the screens.
class MomzoRoot extends StatelessWidget {
  const MomzoRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = AppEnv.hasSupabase && AuthService.isSignedIn;
    return signedIn ? const ConsentScreen() : const WelcomeScreen();
  }
}
