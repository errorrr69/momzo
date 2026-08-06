import '../core/supabase/supabase_init.dart';

/// One grounded answer from the ai-chat Edge Function.
class AiAnswer {
  final String conversationId;
  final String answer;
  final List<({String cardId, String title})> citations;
  final String? flagged; // refer-out category ('safety'|'medical'|'developmental') or null

  /// The stored assistant message, for rating this answer. Null on refer-out
  /// (a safety response is not rated) and when the limit / breaker copy is shown.
  final String? messageId;

  const AiAnswer({
    required this.conversationId,
    required this.answer,
    this.citations = const [],
    this.flagged,
    this.messageId,
  });

  bool get isReferOut => flagged != null && flagged!.isNotEmpty;
}

/// Calls the server-side `ai-chat` function (Task 14). All AI keys + RAG logic
/// live in the Edge Function — the app only sends the question + child id and
/// renders the grounded, cited answer.
class AiService {
  const AiService._();

  static Future<AiAnswer> ask({
    required String question,
    required String childId,
    String? conversationId,
    String mode = 'qa', // 'qa' | 'situational'
  }) async {
    final res = await supabase.functions.invoke('ai-chat', region: kFunctionRegion, body: {
      'question': question,
      'child_id': childId,
      'mode': mode,
      if (conversationId != null) 'conversation_id': conversationId,
    });
    final d = res.data;
    if (d is! Map || d['ok'] != true) {
      throw Exception('AI request failed (status ${res.status}).');
    }
    final cites = (d['citations'] as List? ?? const [])
        .map<({String cardId, String title})>(
            (c) => (cardId: c['card_id'] as String, title: c['title'] as String))
        .toList();
    return AiAnswer(
      conversationId: d['conversation_id'] as String,
      answer: d['answer'] as String,
      citations: cites,
      flagged: d['flagged'] as String?,
      messageId: d['message_id'] as String?,
    );
  }

  /// Record whether an answer helped: +1 or -1, or null to undo.
  ///
  /// This is the only learning signal Momzo has. It also closes a loop on the
  /// shared answer cache: a thumbs-down on an answer that came from — or went
  /// into — the cache retires that cached answer server-side, so one unhelpful
  /// answer can't keep being served to other families.
  ///
  /// Goes through the `rate_ai_answer` function rather than a table update: the
  /// cache is service-role-only and the app must never touch it directly. Best
  /// effort — a failed rating must never interrupt her conversation.
  static Future<bool> rateAnswer(String messageId, int? rating) async {
    try {
      await supabase.rpc('rate_ai_answer', params: {
        'p_message_id': messageId,
        'p_rating': rating,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
