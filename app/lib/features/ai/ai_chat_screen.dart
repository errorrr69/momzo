import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/why_it_matters.dart';
import '../../core/ai/ai_request.dart';
import '../../core/ai/ai_router.dart';
import '../../services/child_service.dart';
import 'refer_out_screen.dart';

/// 11 · Ask · grounded answer — RAG-grounded chat with cited sources (Task 14).
///
/// Opened with an initial question from the Ask home; follow-ups continue the
/// same conversation. Falls back to a designed sample when run with no backend /
/// no child / no initial question (gallery preview).
class AiChatScreen extends StatefulWidget {
  final String? initialQuestion;
  const AiChatScreen({super.key, this.initialQuestion});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMsg {
  final bool isUser;
  final String text;
  final List<({String cardId, String title})> citations;
  _ChatMsg(this.isUser, this.text, {this.citations = const []});
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMsg> _messages = [];
  String? _conversationId;
  bool _sending = false;

  bool get _live => AppEnv.hasSupabase && ChildService.current != null;

  @override
  void initState() {
    super.initState();
    if (_live && (widget.initialQuestion?.trim().isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(widget.initialQuestion!.trim()));
    } else {
      _loadSample(); // preview / gallery
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _loadSample() {
    _messages.addAll([
      _ChatMsg(true, 'My child melted down again when I said no to the tablet. Why does this keep happening?'),
      _ChatMsg(false,
        'At this age, the "stop and stay calm" part of the brain is still forming. Screens give a big '
        'dopamine hit, so ending them feels like a real loss — the meltdown is a flood, not defiance.\n\n'
        'Try a 3-step landing: 1 · give a 5-min warning  2 · name it ("You\'re sad it\'s over")  '
        '3 · offer the next thing to look forward to.',
        citations: [(cardId: '', title: "Momzo's guide on big emotions")]),
    ]);
  }

  Future<void> _send(String text) async {
    if (_sending) return;
    final child = ChildService.current;
    if (!_live || child == null) return;
    setState(() {
      _messages.add(_ChatMsg(true, text));
      _sending = true;
    });
    _composer.clear();
    _scrollToEnd();
    try {
      final a = await AiRouter.app().generate(AiRequest(
        task: AiTask.expertQa,
        risk: AiRiskClass.amber, // pre-screen may elevate to red; router picks the brain
        prompt: text,
        childId: child.id,
        conversationId: _conversationId,
      ));
      if (!mounted) return;
      setState(() {
        _conversationId = a.conversationId ?? _conversationId;
        _sending = false;
      });
      if (a.referOutTriggered) {
        // Safety/medical/developmental signal -> dedicated warm refer-out screen.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReferOutScreen(userMessage: text, message: a.text),
          ),
        );
      } else {
        setState(() => _messages.add(_ChatMsg(false, a.text, citations: a.citations)));
        _scrollToEnd();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(false, "I couldn't answer just now — please try again in a moment."));
        _sending = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, status: '● grounded in vetted guides'),
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                itemCount: _messages.length + (_sending ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  if (i >= _messages.length) return _typing();
                  final m = _messages[i];
                  return m.isUser ? _userBubble(m.text) : _assistantBubble(m);
                },
              ),
            ),
            _composer_(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, {required String status}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3E9DD))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: MomzoColors.body),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: MomzoColors.sky, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Momzo expert',
                  style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w800)),
              Text(status, style: MomzoText.sans(11, color: MomzoColors.sage, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: const BoxDecoration(
          color: MomzoColors.coral,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(text,
            style: MomzoText.sans(14.5, color: Colors.white, weight: FontWeight.w600, height: 1.45)),
      ),
    );
  }

  Widget _assistantBubble(_ChatMsg m) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: const Color(0xFFF3E9DD)),
          boxShadow: const [
            BoxShadow(color: Color(0x0D342F30), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text,
                style: MomzoText.sans(14.5, color: MomzoColors.ink, weight: FontWeight.w600, height: 1.55)),
            if (m.citations.where((c) => c.title.isNotEmpty).isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final c in m.citations.where((c) => c.title.isNotEmpty).take(2))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SourceChip(_sourceLabel(c.title)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _sourceLabel(String title) => "Based on Momzo's guide: $title";

  Widget _typing() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3E9DD)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: MomzoColors.sky),
            ),
            const SizedBox(width: 10),
            Text('Thinking…',
                style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _composer_() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                enabled: _live && !_sending,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) => v.trim().isEmpty ? null : _send(v.trim()),
                style: MomzoText.sans(14, color: MomzoColors.ink, weight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: _live ? 'Ask a follow-up…' : 'Ask a follow-up…',
                  hintStyle: MomzoText.sans(14, color: MomzoColors.faint, weight: FontWeight.w600),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                final v = _composer.text.trim();
                if (v.isNotEmpty) _send(v);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: MomzoColors.coral, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
