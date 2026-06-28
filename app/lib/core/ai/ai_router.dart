import 'ai_prescreen.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
import 'cloud_provider.dart';
import 'on_device_capability.dart';

/// Which brain a request should use.
enum AiBrain { cloud, onDevice }

/// The single place that decides the brain per request (strategy §4.3). Phase 1
/// has no on-device provider, so this always resolves to cloud — but the decision
/// is a pure function of (capability, risk) so the table can be unit-tested and the
/// on-device path drops in by wiring [OnDeviceProvider] and loosening step 4/5.
class AiRouter {
  final AiProvider _cloud;
  final AiProvider? _onDevice; // null until Phase 2

  const AiRouter({AiProvider cloud = const CloudProvider(), AiProvider? onDevice})
      : _cloud = cloud,
        _onDevice = onDevice;

  /// Pure routing decision (strategy §4.3 steps 1–5). Given a (pre-screened) risk
  /// class and the device capability, choose a brain. No I/O — unit-tested.
  ///
  ///   red                          -> cloud (always)
  ///   capability != available      -> cloud
  ///   green                        -> on-device
  ///   amber                        -> on-device (confidence/quality gated at run time,
  ///                                   strategy §6; falls back to cloud on weak signal)
  static AiBrain chooseBrain(AiRiskClass risk, OnDeviceCapability capability) {
    if (risk == AiRiskClass.red) return AiBrain.cloud;
    if (capability != OnDeviceCapability.available) return AiBrain.cloud;
    return AiBrain.onDevice; // green + amber when capable
  }

  /// Route + run a request. Pre-screen assigns risk, the table picks the brain, and
  /// the post-answer safety screen always runs (strategy §5.1) — in Phase 1 that is
  /// the server-side screen inside the cloud path.
  Future<AiResult> generate(AiRequest request) async {
    final req = AiPrescreen.classify(request); // advisory risk tagging (§5.1)
    final capability = await OnDeviceProbe.capability();
    final brain = chooseBrain(req.risk, capability);

    final provider = (brain == AiBrain.onDevice && _onDevice != null) ? _onDevice : _cloud;
    return provider.generate(req);
  }
}
