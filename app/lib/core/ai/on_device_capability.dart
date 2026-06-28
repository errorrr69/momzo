import 'package:flutter/services.dart';

/// Whether this device can run an OS-provided on-device model (strategy §3).
/// There is no "connect your AI" flow — these are OS APIs the app calls.
enum OnDeviceCapability { available, unavailable, unknown }

/// Silent capability probe (strategy §3.1). Asks the native bridge whether an
/// on-device GenAI runtime is present, caches the result, and degrades to
/// [unavailable] on any error or unsupported platform — a false negative just
/// means "use cloud", which is always safe. Re-probe on OS/app update via [reset].
class OnDeviceProbe {
  const OnDeviceProbe._();

  static const _channel = MethodChannel('momzo/on_device_ai');
  static OnDeviceCapability? _cached;

  static Future<OnDeviceCapability> capability() async {
    final cached = _cached;
    if (cached != null) return cached;
    return _cached = await _probe();
  }

  static Future<OnDeviceCapability> _probe() async {
    try {
      final res = await _channel.invokeMethod<String>('capability');
      switch (res) {
        case 'available':
          return OnDeviceCapability.available;
        case 'unknown':
          return OnDeviceCapability.unknown;
        default:
          return OnDeviceCapability.unavailable;
      }
    } on MissingPluginException {
      return OnDeviceCapability.unavailable; // platform has no bridge yet (e.g. iOS)
    } catch (_) {
      return OnDeviceCapability.unavailable;
    }
  }

  /// Re-probe on next call (OS/app update — strategy §3.1).
  static void reset() => _cached = null;

  /// Test seam: force a capability (pass null to clear).
  static void debugSetCapability(OnDeviceCapability? c) => _cached = c;
}
