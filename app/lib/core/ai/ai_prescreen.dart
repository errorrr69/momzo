import 'ai_request.dart';

/// Advisory, client-side risk tagging that runs BEFORE routing (strategy §5.1).
///
/// Phase-1 scope (decided): this only assigns a [AiRiskClass] to steer the router
/// — it is NOT the authoritative refer-out. The server's `referOutReason` in the
/// `ai-chat` Edge Function remains the single source of truth for the warm refer-out
/// response (Hard Rule #7). This heuristic exists so that, once on-device lands, a
/// sensitive question is forced to the cloud path before any local model sees it.
class AiPrescreen {
  const AiPrescreen._();

  /// Light markers for the three refer-out families (self-harm/abuse, medical,
  /// developmental concern). Intentionally small and conservative — false positives
  /// just mean "use cloud", which is always safe. Kept deliberately separate from
  /// the server's fuller list so neither is mistaken for the canonical screen.
  static final RegExp _sensitive = RegExp(
    r'\b(suicid\w*|self[\s-]?harm|hurt(?:ing)?\s+(?:myself|himself|herself|themsel)|'
    r'abus\w*|hit(?:s|ting)?\s+(?:him|her|them|the\s+child)|'
    r'depress\w*|anxie\w*|harm\w*|'
    r'autis\w*|adhd|diagnos\w*|disorder|delay\w*|'
    r'medication|prescri\w*|seizure|fever|rash|swallow\w*|choking|bleeding|injur\w*)\b',
    caseSensitive: false,
  );

  /// Returns the request with its risk class set/elevated for routing.
  static AiRequest classify(AiRequest req) => req.copyWith(risk: riskFor(req));

  /// Pure classification (unit-tested): base risk by task, elevated to [red] when
  /// a conversational prompt trips a sensitive marker.
  static AiRiskClass riskFor(AiRequest req) {
    switch (req.task) {
      case AiTask.gameItem:
        return AiRiskClass.green;
      case AiTask.situational:
        return _isSensitive(req.prompt) ? AiRiskClass.red : AiRiskClass.amber;
      case AiTask.expertQa:
        return _isSensitive(req.prompt) ? AiRiskClass.red : AiRiskClass.amber;
      default:
        return AiRiskClass.amber;
    }
  }

  static bool _isSensitive(String prompt) => _sensitive.hasMatch(prompt);

  /// Post-answer safety screen for ON-DEVICE output (strategy §5.1). If an
  /// on-device answer touches anything sensitive, the router discards it and
  /// re-asks via cloud rather than show an unverified response. Same conservative
  /// markers as the pre-screen — a false positive just means "use cloud".
  static bool outputLooksSensitive(String text) => _sensitive.hasMatch(text);
}
