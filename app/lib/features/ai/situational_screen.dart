import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/dictation_button.dart';
import '../../core/ai/ai_request.dart';
import '../../core/ai/ai_router.dart';
import '../../services/ai_service.dart';
import '../../services/child_service.dart';
import 'ai_chat_screen.dart';
import 'refer_out_screen.dart';

/// 12 · Right now · calm script — a short, actionable in-the-moment script
/// (Task 15). The parent describes what's happening; ai-chat (mode=situational)
/// returns a brief calm script. Falls back to the designed sample in preview mode.
class SituationalScreen extends StatefulWidget {
  final String? situation;
  const SituationalScreen({super.key, this.situation});

  @override
  State<SituationalScreen> createState() => _SituationalScreenState();
}

class _SituationalScreenState extends State<SituationalScreen> {
  final _input = TextEditingController();
  bool _busy = false;
  String? _situationText;
  String? _script;

  /// The stored assistant message, so the "That helped" / "Still stuck" choice
  /// she already makes becomes a real signal instead of being discarded.
  String? _messageId;

  bool get _live => AppEnv.hasSupabase && ChildService.current != null;

  @override
  void initState() {
    super.initState();
    final s = widget.situation?.trim();
    if (_live && (s?.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit(s!));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit(String text) async {
    if (_busy || text.trim().isEmpty) return;
    final child = ChildService.current;
    if (!_live || child == null) return;
    setState(() {
      _busy = true;
      _situationText = text.trim();
    });
    try {
      final a = await AiRouter.app().generate(AiRequest(
        task: AiTask.situational,
        risk: AiRiskClass.amber, // pre-screen may elevate to red; router picks the brain
        prompt: text.trim(),
        childId: child.id,
      ));
      if (!mounted) return;
      if (a.referOutTriggered) {
        setState(() => _busy = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReferOutScreen(userMessage: text.trim(), message: a.text)),
        );
        return;
      }
      setState(() {
        _script = a.text;
        _messageId = a.messageId;
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get a script just now. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.coralTint, MomzoColors.cream],
            stops: [0, .45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 10, 26, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF0D9CD), width: 1.5),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: MomzoColors.body),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('⚡ Right now',
                        style: MomzoText.sans(16,
                            color: MomzoColors.coralDeep, weight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    // Live + no result yet -> input prompt.
    if (_live && _script == null && !_busy) return _inputView();
    // Live + has a situation -> show it + script/loading.
    if (_live && _situationText != null) return _resultView();
    // Preview / UI-only -> designed sample.
    return _sampleView();
  }

  Widget _inputView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 16),
      children: [
        Text("What's happening right now?",
            style: MomzoText.serif(24, color: MomzoColors.ink)),
        const SizedBox(height: 8),
        Text("Tell me in a sentence — I'll give you a calm way through.",
            style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w500, height: 1.4)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0D9CD), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w600),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '"He\'s screaming because I said no to ice cream…"',
                    hintStyle: MomzoText.sans(15, color: MomzoColors.faint, weight: FontWeight.w500),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: DictationButton(controller: _input, enabled: _live && !_busy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MomzoButton('Get a calm script', onTap: () => _submit(_input.text)),
      ],
    );
  }

  Widget _resultView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0D342F30), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Text('"${_situationText!}"',
              style: MomzoText.sans(14, color: const Color(0xFF5A4F49), weight: FontWeight.w600)),
        ),
        const SizedBox(height: 20),
        if (_busy) ...[
          Row(children: [
            const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: MomzoColors.coral)),
            const SizedBox(width: 12),
            Text('Finding a calm way through…',
                style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w600)),
          ]),
        ] else if (_script != null) ...[
          Text("Here's a calm way through 👇", style: MomzoText.serif(22, color: MomzoColors.ink)),
          const SizedBox(height: 16),
          ..._renderScript(_script!),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: MomzoSecondaryButton('That helped', onTap: () {
                  _rate(1);
                  Navigator.pop(context);
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MomzoButton('Still stuck', onTap: () {
                  _rate(-1);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => AiChatScreen(initialQuestion: _situationText)),
                  );
                }),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Fire-and-forget: she is already navigating away, and a rating must never
  /// delay her or surface an error at a moment she is mid-situation.
  void _rate(int rating) {
    final id = _messageId;
    if (id == null) return;
    unawaited(AiService.rateAnswer(id, rating));
  }

  // Render the model's script: numbered lines become steps, the rest paragraphs.
  List<Widget> _renderScript(String script) {
    final lines = script.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final widgets = <Widget>[];
    for (final line in lines) {
      final m = RegExp(r'^(\d+)[.)]\s*(.*)$').firstMatch(line);
      if (m != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _step(int.parse(m.group(1)!), m.group(2)!),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(color: MomzoColors.sageTint, borderRadius: BorderRadius.circular(14)),
            child: Text(line,
                style: MomzoText.sans(14, color: const Color(0xFF4E7A60), weight: FontWeight.w600, height: 1.5)),
          ),
        ));
      }
    }
    return widgets;
  }

  Widget _sampleView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 8),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0D342F30), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Text('"He\'s screaming because I said no to ice cream before dinner."',
              style: MomzoText.sans(14, color: const Color(0xFF5A4F49), weight: FontWeight.w600)),
        ),
        const SizedBox(height: 20),
        Text("Here's a calm way through 👇", style: MomzoText.serif(22, color: MomzoColors.ink)),
        const SizedBox(height: 18),
        _step(1, 'Get to his level. Soft voice: "You really want it. I get it."'),
        const SizedBox(height: 12),
        _step(2, 'Hold the boundary kindly: "Ice cream is after dinner."'),
        const SizedBox(height: 12),
        _step(3, 'Give a yes he can have now: "Want to pick which bowl?"'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(color: MomzoColors.sageTint, borderRadius: BorderRadius.circular(14)),
          child: Text(
            "It's okay if he stays upset — staying calm yourself is the lesson.",
            style: MomzoText.sans(13.5, color: const Color(0xFF4E7A60), weight: FontWeight.w600, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _step(int n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: MomzoColors.coral, shape: BoxShape.circle),
          child: Text('$n', style: MomzoText.sans(15, color: Colors.white, weight: FontWeight.w800)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text,
                style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w600, height: 1.45)),
          ),
        ),
      ],
    );
  }
}
