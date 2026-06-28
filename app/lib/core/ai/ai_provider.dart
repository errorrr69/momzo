import 'ai_request.dart';

/// One brain that can answer an [AiRequest]. The app talks to this interface; the
/// [AiRouter] picks the implementation per request (strategy §4). Today the only
/// implementation is the cloud path; [OnDeviceProvider] arrives in Phase 2.
abstract class AiProvider {
  /// Whether this provider can serve requests right now.
  Future<bool> isAvailable();

  /// Generate an answer. Implementations must never bypass the refer-out safety
  /// screen (Hard Rule #7) — the cloud path screens server-side; an on-device path
  /// must run its own check and fall back to cloud when unsure (strategy §5).
  Future<AiResult> generate(AiRequest req);
}
