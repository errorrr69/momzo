import '../core/supabase/supabase_init.dart';

/// One grounded answer from the ai-chat Edge Function.
class AiAnswer {
  final String conversationId;
  final String answer;
  final List<({String cardId, String title})> citations;
  final String? flagged; // refer-out category ('safety'|'medical'|'developmental') or null

  const AiAnswer({
    required this.conversationId,
    required this.answer,
    this.citations = const [],
    this.flagged,
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
    final res = await supabase.functions.invoke('ai-chat', body: {
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
    );
  }
}
