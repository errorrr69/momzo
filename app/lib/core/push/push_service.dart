/// Push notification wiring (FCM).
///
/// Placeholder scaffold — implemented in Phase 0 Task 7 ("FCM push wiring").
/// Push is Momzo's primary (and Phase 1 only) reminder channel; WhatsApp is
/// Phase 2 and opt-in (Build Guide Hard Rules #11, #12).
///
/// Hard Rule (Build Guide §5): the FCM **server** key never lives in the app —
/// only the client SDK config does. The server-side `send-due-reminders` Edge
/// Function (Task 20) holds the credentials needed to send.
class PushService {
  const PushService._();

  /// Requests notification permission and registers the device's FCM token
  /// against the signed-in user. No-op until Task 7 implements it.
  static Future<void> init() async {
    // TODO(Task 7): firebase_core init + firebase_messaging permission +
    // token registration + foreground/background handlers.
  }
}
