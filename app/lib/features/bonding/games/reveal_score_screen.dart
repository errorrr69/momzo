import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/child_service.dart';
import '../../../services/game_service.dart';
import 'game_scaffold.dart';

/// One round's framing for a same-phone "predict + reveal" game: the shared
/// question and who answers first (hidden) vs second (strategy §2.7/§2.8). Child
/// name kept on-device only — never sent to an LLM (COPPA).
class RevealRound {
  final String question;
  final String firstLabel; // person who answers first, with the phone hidden
  final String firstHint;
  final String secondLabel; // person who answers after the hand-off
  final String secondHint;
  const RevealRound({
    required this.question,
    required this.firstLabel,
    required this.firstHint,
    required this.secondLabel,
    required this.secondHint,
  });
}

class RevealGameConfig {
  final String emoji;
  final Color accent;
  final RevealRound Function(Map<String, dynamic> payload, String childName) round;
  const RevealGameConfig({required this.emoji, required this.accent, required this.round});
}

String _guessQuestion(Map<String, dynamic> p) {
  final q = (p['question'] as String?)?.trim() ?? '';
  final opts = p['options'];
  if (p['mode'] == 'either_or' && opts is List && opts.length >= 2) {
    return '$q  (${opts[0]} or ${opts[1]}?)';
  }
  return q;
}

final Map<String, RevealGameConfig> kRevealGames = {
  'how-well-know-me': RevealGameConfig(
    emoji: '💞',
    accent: MomzoColors.lavender,
    round: (p, child) {
      final attr = (p['attribute'] as String?)?.trim() ?? 'favourite thing';
      final aboutParent = p['about'] == 'parent';
      if (aboutParent) {
        return RevealRound(
          question: "What is your grown-up's $attr?",
          firstLabel: child,
          firstHint: "Guess your grown-up's answer — keep it hidden!",
          secondLabel: 'Grown-up',
          secondHint: 'Now type your real answer.',
        );
      }
      return RevealRound(
        question: "What is $child's $attr?",
        firstLabel: 'Grown-up',
        firstHint: "Guess $child's answer — keep it hidden!",
        secondLabel: child,
        secondHint: 'Now type your real answer.',
      );
    },
  ),
  'guess-my-answer': RevealGameConfig(
    emoji: '🔮',
    accent: MomzoColors.sky,
    round: (p, child) => RevealRound(
      question: _guessQuestion(p),
      firstLabel: 'Grown-up',
      firstHint: "Guess what $child will say — keep it hidden!",
      secondLabel: child,
      secondHint: 'Now type your real answer.',
    ),
  ),
};

enum _Phase { answerFirst, handoff, answerSecond, reveal }

/// Same-phone, pass-the-phone play (edits #3). Person 1 answers hidden → hand-off
/// → Person 2 answers → only now reveal both side by side. No answer is shown
/// until both are in. Soft, no-"loser" scoring of shared 💜 moments.
class RevealScoreScreen extends StatefulWidget {
  final Game game;
  final RevealGameConfig config;
  final List<GameItem>? initialItems;
  const RevealScoreScreen({super.key, required this.game, required this.config, this.initialItems});

  @override
  State<RevealScoreScreen> createState() => _RevealScoreScreenState();
}

class _RevealScoreScreenState extends State<RevealScoreScreen> {
  List<GameItem> _items = [];
  int _i = 0;
  int _matches = 0;
  bool _loading = true;
  bool _done = false;

  _Phase _phase = _Phase.answerFirst;
  final _first = TextEditingController();
  final _second = TextEditingController();

  RevealGameConfig get _cfg => widget.config;
  Color get _accent => _cfg.accent;
  String get _childName => ChildService.current?.name ?? 'your child';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.initialItems != null) {
      setState(() {
        _items = widget.initialItems!;
        _loading = false;
      });
      return;
    }
    final n = widget.game.roundsFor(GameService.currentBand);
    try {
      final items = await GameService.deal(widget.game.slug, n);
      if (mounted) setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  RevealRound get _round => _cfg.round(_items[_i].payload, _childName);

  void _advance() {
    setState(() => _phase = _Phase.handoff);
  }

  void _toSecond() => setState(() => _phase = _Phase.answerSecond);
  void _toReveal() => setState(() => _phase = _Phase.reveal);

  void _score(bool matched) {
    if (matched) _matches++;
    if (_i < _items.length - 1) {
      setState(() {
        _i++;
        _phase = _Phase.answerFirst;
        _first.clear();
        _second.clear();
      });
    } else {
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GameLoading();
    if (_items.isEmpty) return const GameEmpty();
    if (_done) return _summary();

    final r = _round;
    return GameScaffold(
      title: widget.game.title,
      subtitle: 'Card ${_i + 1} of ${_items.length}  ·  💜 $_matches',
      onClose: () => Navigator.maybePop(context),
      child: switch (_phase) {
        _Phase.answerFirst => _answerStep(r, r.firstLabel, r.firstHint, _first, _advance, 'Done'),
        _Phase.handoff => _handoff(r),
        _Phase.answerSecond => _answerStep(r, r.secondLabel, r.secondHint, _second, _toReveal, 'Reveal & Compare ✨'),
        _Phase.reveal => _reveal(r),
      },
    );
  }

  Widget _questionCard(RevealRound r) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x26342F30), blurRadius: 22, offset: Offset(0, 10))],
        ),
        child: Column(children: [
          Text(widget.game.emoji ?? _cfg.emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(r.question,
              textAlign: TextAlign.center,
              style: MomzoText.sans(20, color: MomzoColors.ink, weight: FontWeight.w800, height: 1.3)),
        ]),
      );

  Widget _answerStep(RevealRound r, String who, String hint, TextEditingController ctrl,
      VoidCallback onNext, String cta) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: _accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
          child: Text("$who's turn",
              style: MomzoText.sans(13, color: _accent, weight: FontWeight.w900)),
        ),
        const SizedBox(height: 8),
        Text(hint,
            textAlign: TextAlign.center,
            style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w600, height: 1.4)),
        const SizedBox(height: 16),
        _questionCard(r),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
          ),
          child: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: MomzoText.sans(16, color: MomzoColors.ink, weight: FontWeight.w700),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Type your answer…',
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('🙈 Keep it hidden from the other player until you reveal!',
            textAlign: TextAlign.center,
            style: MomzoText.sans(11, color: MomzoColors.faint, weight: FontWeight.w600)),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: MomzoButton(cta, color: _accent, onTap: ctrl.text.trim().isEmpty ? null : onNext),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _handoff(RevealRound r) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Text('📱💛', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 20),
        Text('Pass the phone to ${r.secondLabel}',
            textAlign: TextAlign.center,
            style: MomzoText.sans(24, color: MomzoColors.ink, weight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: 10),
        Text('No peeking at the first answer — it stays hidden until you both reveal together. 💜',
            textAlign: TextAlign.center,
            style: MomzoText.serif(16, color: MomzoColors.muted, height: 1.5)),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: MomzoButton("I'm ${r.secondLabel} — my turn", color: _accent, onTap: _toSecond),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _reveal(RevealRound r) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _questionCard(r),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _answerCard(r.firstLabel, _first.text.trim(), MomzoColors.lavenderTint, MomzoColors.lavenderText)),
            const SizedBox(width: 12),
            Expanded(child: _answerCard(r.secondLabel, _second.text.trim(), MomzoColors.sageTint, MomzoColors.sageText)),
          ],
        ),
        const SizedBox(height: 18),
        Text('Did you match?',
            style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w700)),
        const Spacer(),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _score(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: MomzoColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                ),
                child: Text('Now you know! 🌟',
                    textAlign: TextAlign.center,
                    style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: MomzoButton('Matched 💜', color: _accent, onTap: () => _score(true))),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _answerCard(String who, String answer, Color bg, Color label) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(who.toUpperCase(),
                style: MomzoText.sans(11, color: label, weight: FontWeight.w900, spacing: .4)),
            const SizedBox(height: 6),
            Text(answer.isEmpty ? '—' : answer,
                style: MomzoText.serif(17, color: MomzoColors.ink, height: 1.3)),
          ],
        ),
      );

  Widget _summary() {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('💜', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              Text('$_matches ${_matches == 1 ? 'match' : 'matches'}!',
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(30, color: MomzoColors.ink, weight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('Matched or not, you learned something new about each other. 💜',
                  textAlign: TextAlign.center,
                  style: MomzoText.serif(17, color: MomzoColors.muted, height: 1.5)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: MomzoButton('Back to games', onTap: () => Navigator.maybePop(context)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
