import 'ai_prescreen.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
import 'ai_telemetry.dart';
import 'cloud_provider.dart';
import 'on_device_capability.dart';
import 'on_device_provider.dart';

/// Which brain a request should use.
enum AiBrain { cloud, onDevice }

/// The single place that decides the brain per request (strategy §4.3). The brain
/// choice is a pure function of (capability, risk) so the table is unit-testable;
/// [generate] then adds the runtime guards — amber confidence gating (§6), the
/// post-answer safety screen (§5.1), and cloud fallback whenever on-device is
/// unavailable or its answer is weak/unsafe. Red is always cloud.
class AiRouter {
  final AiProvider _cloud;
  final AiProvider? _onDevice;

  /// Amber tasks only use an on-device answer when its confidence clears this floor
  /// (strategy §6). No confidence signal → treat as not confident → cloud. Tuned
  /// conservatively (more cloud) at first.
  final double amberConfidenceFloor;

  const AiRouter({
    AiProvider cloud = const CloudProvider(),
    AiProvider? onDevice,
    this.amberConfidenceFloor = 0.6,
  })  : _cloud = cloud,
        _onDevice = onDevice;

  /// The app's configured router: cloud baseline + the platform on-device provider.
  /// On non-capable devices the probe reports unavailable and this is pure cloud;
  /// on capable devices it tries on-device and falls back per the guards below.
  factory AiRouter.app() => AiRouter(
        onDevice: OnDeviceProvider(
          engine: const PlatformOnDeviceEngine(),
          isAvailable: () async =>
              (await OnDeviceProbe.capability()) == OnDeviceCapability.available,
        ),
      );

  /// Pure routing decision (strategy §4.3 steps 1–4):
  ///   red                     -> cloud (always)
  ///   capability != available -> cloud
  ///   green / amber           -> on-device (then run-time gated in [generate])
  static AiBrain chooseBrain(AiRiskClass risk, OnDeviceCapability capability) {
    if (risk == AiRiskClass.red) return AiBrain.cloud;
    if (capability != OnDeviceCapability.available) return AiBrain.cloud;
    return AiBrain.onDevice;
  }

  Future<AiResult> generate(AiRequest request) async {
    final sw = Stopwatch()..start();
    final req = AiPrescreen.classify(request); // advisory risk tagging (§5.1)
    final capability = await OnDeviceProbe.capability();
    final brain = chooseBrain(req.risk, capability);
    final onDevice = _onDevice;

    AiResult result;
    var fellBack = false;
    if (brain == AiBrain.cloud || onDevice == null) {
      result = await _cloud.generate(req);
    } else {
      final attempt = await _tryOnDevice(onDevice, req);
      if (attempt != null) {
        result = attempt;
      } else {
        fellBack = true; // chose on-device but its answer was unavailable/weak/unsafe
        result = await _cloud.generate(req);
      }
    }

    sw.stop();
    AiTelemetry.record(AiTelemetryEvent(
      task: req.task,
      risk: req.risk,
      source: result.source,
      fellBack: fellBack,
      referOut: result.referOutTriggered,
      latencyMs: sw.elapsedMilliseconds,
    ));
    return result;
  }

  /// Runs the on-device provider through the run-time guards. Returns the result
  /// if it's good to show, or null to signal the caller should fall back to cloud.
  Future<AiResult?> _tryOnDevice(AiProvider onDevice, AiRequest req) async {
    try {
      final res = await onDevice.generate(req);
      // Amber confidence/quality gate (§6): weak signal → cloud.
      if (req.risk == AiRiskClass.amber && !_confident(res)) return null;
      // Post-answer safety screen (§5.1): on-device output that touches anything
      // sensitive is discarded and re-asked via cloud (never shown unverified).
      if (req.task != AiTask.gameItem && AiPrescreen.outputLooksSensitive(res.text)) return null;
      return res;
    } on OnDeviceUnavailable {
      return null; // §4.3 step 5b
    } catch (_) {
      return null; // any on-device failure → cloud
    }
  }

  bool _confident(AiResult r) {
    final c = r.confidence;
    return c != null && c >= amberConfidenceFloor;
  }
}
