import '../supabase/supabase_init.dart';
import '../../services/ai_service.dart';
import 'ai_provider.dart';
import 'ai_request.dart';

/// The cloud brain — the existing Mistral + RAG + refer-out path (strategy §4.2).
/// This is the ONLY provider at launch and serves every request. It just adapts an
/// [AiRequest] onto the already-built Edge Functions; all keys, RAG and the
/// authoritative refer-out screen stay server-side.
class CloudProvider implements AiProvider {
  const CloudProvider();

  @override
  Future<bool> isAvailable() async => true; // cloud is the always-on baseline

  @override
  Future<AiResult> generate(AiRequest req) async {
    switch (req.task) {
      case AiTask.gameItem:
        return _gameTopUp(req);
      case AiTask.situational:
        return _ask(req, mode: 'situational');
      case AiTask.expertQa:
      default:
        return _ask(req, mode: 'qa');
    }
  }

  // Expert Q&A + situational both go through ai-chat (refer-out runs there).
  Future<AiResult> _ask(AiRequest req, {required String mode}) async {
    final a = await AiService.ask(
      question: req.prompt,
      childId: req.childId ?? '',
      conversationId: req.conversationId,
      mode: mode,
    );
    return AiResult(
      text: a.answer,
      source: 'cloud',
      referOutTriggered: a.isReferOut,
      flagged: a.flagged,
      conversationId: a.conversationId,
      messageId: a.messageId,
      citations: a.citations,
    );
  }

  // Game-bank top-up writes into the GLOBAL bank server-side (cost amortised across
  // families). Returns how many were added.
  Future<AiResult> _gameTopUp(AiRequest req) async {
    final res = await supabase.functions.invoke('generate-game-items', body: {
      'game_slug': req.gameSlug,
      'child_id': req.childId,
    });
    final d = res.data;
    final added = (d is Map && d['added'] is int) ? d['added'] as int : null;
    return AiResult(source: 'cloud', itemsAdded: added);
  }
}
