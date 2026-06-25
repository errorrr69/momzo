import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../../services/auth_service.dart';
import '../env/app_env.dart';
import '../supabase/supabase_init.dart';

/// Push notification wiring (FCM, Task 7).
///
/// Momzo's primary (and Phase 1 only) reminder channel; WhatsApp is Phase 2
/// (Hard Rules #11, #12). The FCM **server** key never lives in the app — only
/// the client SDK config (google-services.json). Sending happens server-side in
/// an Edge Function (Task 20). Here we just register + store the device token.
class PushService {
  const PushService._();

  static bool _ready = false;

  /// Initialise Firebase + request permission, then keep the signed-in device's
  /// token in sync. Best-effort: silently no-ops where push can't run (web,
  /// desktop, or a build with no native Firebase config) so the app still works.
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      // Token can change; keep it current.
      FirebaseMessaging.instance.onTokenRefresh.listen(_store);
      _ready = true;

      // Register on this launch (returning, already-signed-in user) and on any
      // future sign-in.
      await syncToken();
      if (AppEnv.hasSupabase) {
        supabase.auth.onAuthStateChange.listen((state) {
          if (state.event == AuthChangeEvent.signedIn) syncToken();
        });
      }
    } catch (_) {
      _ready = false; // no native config / unsupported platform — run without push
    }
  }

  /// Fetch the current FCM token and store it for the signed-in user.
  static Future<void> syncToken() async {
    if (!_ready || !AppEnv.hasSupabase || AuthService.currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _store(token);
    } catch (_) {/* offline / transient — retried on next launch or refresh */}
  }

  static Future<void> _store(String token) async {
    final user = AuthService.currentUser;
    if (user == null || !AppEnv.hasSupabase) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await supabase.from('device_tokens').upsert(
      {'user_id': user.id, 'token': token, 'platform': platform},
      onConflict: 'token',
    );
  }
}
