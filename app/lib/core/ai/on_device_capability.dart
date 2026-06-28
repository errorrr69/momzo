/// Whether this device can run an OS-provided on-device model (strategy §3).
/// There is no "connect your AI" flow — these are OS APIs the app calls. Phase 1
/// has no on-device implementation, so the probe always reports [unavailable];
/// Phase 2 fills in the real iOS (Foundation Models) / Android (ML Kit GenAI) probe.
enum OnDeviceCapability { available, unavailable, unknown }

/// Silent capability probe. Cache the result and re-probe on OS/app update
/// (strategy §3.1). Stubbed to [unavailable] until the on-device provider exists.
class OnDeviceProbe {
  const OnDeviceProbe._();

  static OnDeviceCapability? _cached;

  static Future<OnDeviceCapability> capability() async {
    // Phase 2: query Apple Intelligence / Foundation Models readiness on iOS 26+,
    // and ML Kit GenAI (Gemini Nano) availability + model-downloaded on Android.
    return _cached ??= OnDeviceCapability.unavailable;
  }

  /// Test seam: override the cached capability.
  static void debugSetCapability(OnDeviceCapability? c) => _cached = c;
}
