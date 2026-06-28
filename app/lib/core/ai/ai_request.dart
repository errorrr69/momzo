/// The AI abstraction layer (On-Device AI Strategy §4). All generation flows
/// through [AiProvider] so the on-device implementation can drop in later with no
/// refactor. Phase 1 ships one cloud provider; the router returns cloud for
/// everything, but the risk-aware seam is in place from day one.
library;

/// How much harm a bad answer could do — routes the request (strategy §1).
enum AiRiskClass {
  /// Low stakes; a weak answer is harmless (e.g. a game top-up).
  green,

  /// Medium stakes; tone/quality matters (e.g. an in-the-moment script).
  amber,

  /// High stakes; safety-critical. Always cloud + full guardrails.
  red,
}

/// The generation tasks the app performs. The `task` string is kept stable for
/// telemetry and the routing table.
class AiTask {
  static const expertQa = 'expert_qa';
  static const situational = 'situational';
  static const gameItem = 'game_item';
  const AiTask._();
}

/// One request to the AI layer, independent of which brain answers it.
class AiRequest {
  final String task; // AiTask.*
  final AiRiskClass risk;

  /// The user's question / situation. Empty for generation tasks like game top-up.
  final String prompt;

  /// RAG chunks (expert / situational). Retrieval stays cloud-side for now, so this
  /// is reserved for the on-device path (strategy §2).
  final List<String> contextChunks;

  /// 'A' | 'B' | 'C' where relevant (games).
  final String? childAgeBand;

  /// Anti-repeat exclusions (games).
  final List<String> excludeItems;

  final int maxTokens;

  // --- cloud routing context (used by CloudProvider) ---
  final String? childId;
  final String? conversationId; // expert Q&A threading
  final String? gameSlug; // game top-up

  const AiRequest({
    required this.task,
    required this.risk,
    this.prompt = '',
    this.contextChunks = const [],
    this.childAgeBand,
    this.excludeItems = const [],
    this.maxTokens = 450,
    this.childId,
    this.conversationId,
    this.gameSlug,
  });

  AiRequest copyWith({AiRiskClass? risk}) => AiRequest(
        task: task,
        risk: risk ?? this.risk,
        prompt: prompt,
        contextChunks: contextChunks,
        childAgeBand: childAgeBand,
        excludeItems: excludeItems,
        maxTokens: maxTokens,
        childId: childId,
        conversationId: conversationId,
        gameSlug: gameSlug,
      );
}

/// One answer from the AI layer. Carries conversational fields (text, citations,
/// refer-out) AND generation fields (items) so a single seam covers every task
/// (decided: one AiResult with optional fields).
class AiResult {
  final String text;

  /// Which brain answered: 'cloud' | 'on_device'.
  final String source;

  /// Provider confidence if exposed (on-device, amber gating). Null otherwise.
  final double? confidence;

  /// True when the safety net redirected to the warm refer-out response.
  final bool referOutTriggered;

  /// Refer-out category ('safety' | 'medical' | 'developmental') or null.
  final String? flagged;

  // --- conversational extras (expert / situational) ---
  final String? conversationId;
  final List<({String cardId, String title})> citations;

  // --- generation extras (game top-up) ---
  final List<Map<String, dynamic>>? items;
  final int? itemsAdded;

  const AiResult({
    this.text = '',
    this.source = 'cloud',
    this.confidence,
    this.referOutTriggered = false,
    this.flagged,
    this.conversationId,
    this.citations = const [],
    this.items,
    this.itemsAdded,
  });
}
