import 'ai_request.dart';

/// One PII-free record of how a request was served (strategy §7). Powers the
/// on-device coverage + fallback-rate dashboard. Carries NO prompt text, child
/// identifiers, or answer content — only routing metadata.
class AiTelemetryEvent {
  final String task; // AiTask.*
  final AiRiskClass risk;
  final String source; // 'on_device' | 'cloud'
  final bool fellBack; // chose on-device but ended up on cloud
  final bool referOut; // safety redirect fired
  final int latencyMs;

  const AiTelemetryEvent({
    required this.task,
    required this.risk,
    required this.source,
    required this.fellBack,
    required this.referOut,
    required this.latencyMs,
  });

  Map<String, Object?> toMap() => {
        'task': task,
        'risk': risk.name,
        'source': source,
        'fell_back': fellBack,
        'refer_out': referOut,
        'latency_ms': latencyMs,
      };
}

/// Where telemetry events go. Default is a no-op; the app can install a sink that
/// forwards to logs or an Edge Function. Kept tiny + swappable so tests can assert
/// on emitted events.
class AiTelemetry {
  const AiTelemetry._();

  static void Function(AiTelemetryEvent event)? _sink;

  static void setSink(void Function(AiTelemetryEvent event)? sink) => _sink = sink;

  static void record(AiTelemetryEvent event) {
    final sink = _sink;
    if (sink != null) sink(event);
  }
}
