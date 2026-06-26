import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_init.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../services/child_service.dart';
import '../../services/quiz_service.dart';
import 'quiz_flow_screen.dart';

/// 19 · Know-each-other · match — the reveal. Real per-question results from
/// question_responses, updated **live** via Realtime (Task 25): if the child
/// answers on another surface, the matches fill in without a refresh.
class QuizMatchScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  const QuizMatchScreen({super.key, required this.questions});

  @override
  State<QuizMatchScreen> createState() => _QuizMatchScreenState();
}

class _QuizMatchScreenState extends State<QuizMatchScreen> {
  List<QuizResult> _results = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  String get _childName => ChildService.current?.name ?? 'your child';

  @override
  void initState() {
    super.initState();
    _load();
    _channel = QuizService.subscribeForChild(_load); // live reveal
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) supabase.removeChannel(ch);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await QuizService.reveal(widget.questions);
      if (mounted) {
        setState(() {
          _results = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _matches => _results.where((r) => r.matched).length;
  int get _answered => _results.where((r) => r.answered).length;

  String get _headline {
    if (_results.isNotEmpty && _answered < _results.length) {
      return 'Waiting for $_childName to finish…';
    }
    final pct = _results.isEmpty ? 0 : _matches / _results.length;
    if (pct >= 0.8) return 'You two really get each other 💛';
    if (pct >= 0.4) return 'You know each other well 💛';
    return 'So much to discover together!';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: MomzoColors.cream,
        body: Center(child: CircularProgressIndicator(color: MomzoColors.coral)),
      );
    }
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text('HOW WELL DO YOU KNOW EACH OTHER?',
                            textAlign: TextAlign.center,
                            style: MomzoText.eyebrow().copyWith(letterSpacing: 1)),
                        const SizedBox(height: 16),
                        _scoreRing(),
                        const SizedBox(height: 14),
                        Text(_headline,
                            textAlign: TextAlign.center,
                            style: MomzoText.serif(24, color: MomzoColors.ink)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (final r in _results) ...[
                    _result(r),
                    const SizedBox(height: 11),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
              child: Row(
                children: [
                  Expanded(
                    child: MomzoSecondaryButton('Done',
                        onTap: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 13,
                    child: MomzoButton('Play again',
                        onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const QuizFlowScreen()),
                            )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreRing() {
    final total = _results.isEmpty ? 1 : _results.length;
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: _matches / total,
              strokeWidth: 13,
              backgroundColor: const Color(0xFFF1E4D6),
              valueColor: const AlwaysStoppedAnimation(MomzoColors.coral),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_matches/${_results.length}',
                  style: MomzoText.sans(30,
                      color: MomzoColors.ink, weight: FontWeight.w900)),
              Text('matched',
                  style: MomzoText.sans(11,
                      color: MomzoColors.muted, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _result(QuizResult r) {
    if (!r.answered) {
      return _resultCard(
        bg: const Color(0xFFF1ECE4),
        iconText: '…',
        iconBg: MomzoColors.faint,
        question: r.question.prompt,
        answer: 'Waiting for $_childName to answer',
        answerColor: MomzoColors.muted,
      );
    }
    if (r.matched) {
      return _resultCard(
        bg: MomzoColors.sageTint,
        icon: Icons.check_rounded,
        iconBg: MomzoColors.sage,
        question: r.question.prompt,
        answer: 'You both said "${r.child}" ✓',
        answerColor: const Color(0xFF4E7A60),
      );
    }
    return _resultCard(
      bg: MomzoColors.coralTint,
      iconText: '!',
      iconBg: MomzoColors.coral,
      question: r.question.prompt,
      answer: 'You guessed "${r.parent}", they said "${r.child}" — chat about it! 💬',
      answerColor: MomzoColors.coralDeep,
    );
  }

  Widget _resultCard({
    required Color bg,
    IconData? icon,
    String? iconText,
    required Color iconBg,
    required String question,
    required String answer,
    required Color answerColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 18)
                : Text(iconText ?? '',
                    style: MomzoText.sans(15, color: Colors.white, weight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question,
                    style: MomzoText.sans(14,
                        color: MomzoColors.ink, weight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 4),
                Text(answer,
                    style: MomzoText.sans(13,
                        color: answerColor, weight: FontWeight.w700, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
