import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/child_service.dart';
import '../../../services/game_service.dart';
import '../../../services/tts_service.dart';
import 'game_scaffold.dart';

/// How one "predict + reveal" 2-player game turns a bank item into the question
/// shown on the card. These games are lightly scored as shared 💜 matches —
/// connection-first, never a loser (games spec §1.6, §2.7, §2.8).
class RevealGameConfig {
  /// Build the on-card question from the payload + the child's name (kept on-device;
  /// never sent to an LLM — COPPA).
  final String Function(Map<String, dynamic> payload, String childName) prompt;

  /// Who guesses first, shown as a gentle role hint.
  final String guesserHint;
  final String emoji;
  final Color accent;

  const RevealGameConfig({
    required this.prompt,
    required this.guesserHint,
    required this.emoji,
    required this.accent,
  });
}

String _attrQuestion(Map<String, dynamic> p, String child) {
  final attr = (p['attribute'] as String?)?.trim() ?? 'favourite thing';
  final about = p['about'] as String? ?? 'child';
  final who = about == 'parent' ? 'your grown-up' : child;
  return "What is $who's $attr?";
}

const Map<String, RevealGameConfig> kRevealGames = {
  'how-well-know-me': RevealGameConfig(
    prompt: _attrQuestion,
    guesserHint: 'One guesses, the other answers about themselves — then reveal!',
    emoji: '💞',
    accent: MomzoColors.lavender,
  ),
  'guess-my-answer': RevealGameConfig(
    prompt: _guessQuestion,
    guesserHint: 'Guess what they’ll say — then compare!',
    emoji: '🔮',
    accent: MomzoColors.sky,
  ),
};

String _guessQuestion(Map<String, dynamic> p, String child) {
  final q = (p['question'] as String?)?.trim() ?? '';
  final opts = p['options'];
  if (p['mode'] == 'either_or' && opts is List && opts.length >= 2) {
    return '$q  (${opts[0]} or ${opts[1]}?)';
  }
  return q;
}

/// Shared screen for the predict + reveal + soft-score games (see [kRevealGames]).
class RevealScoreScreen extends StatefulWidget {
  final Game game;
  final RevealGameConfig config;
  const RevealScoreScreen({super.key, required this.game, required this.config});

  @override
  State<RevealScoreScreen> createState() => _RevealScoreScreenState();
}

class _RevealScoreScreenState extends State<RevealScoreScreen> {
  List<GameItem> _items = [];
  int _i = 0;
  int _matches = 0;
  bool _loading = true;
  bool _revealed = false;
  bool _done = false;

  RevealGameConfig get _cfg => widget.config;
  String get _childName => ChildService.current?.name ?? 'your child';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final n = widget.game.roundsFor(GameService.currentBand);
    try {
      final items = await GameService.deal(widget.game.slug, n);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _score(bool matched) {
    TtsService.stop();
    if (matched) _matches++;
    if (_i < _items.length - 1) {
      setState(() {
        _i++;
        _revealed = false;
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

    final q = _cfg.prompt(_items[_i].payload, _childName);

    return GameScaffold(
      title: widget.game.title,
      subtitle: 'Card ${_i + 1} of ${_items.length}  ·  💜 $_matches',
      onClose: () => Navigator.maybePop(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x303D3330), blurRadius: 26, offset: Offset(0, 12))],
            ),
            child: Column(
              children: [
                Text(widget.game.emoji ?? _cfg.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 14),
                Text(q,
                    textAlign: TextAlign.center,
                    style: MomzoText.sans(22, color: MomzoColors.ink, weight: FontWeight.w800, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => TtsService.speak(q),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.volume_up_rounded, size: 18, color: MomzoColors.coral),
                const SizedBox(width: 7),
                Text('Tap to hear', style: MomzoText.sans(13, color: MomzoColors.body, weight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Text(_revealed ? 'Did you match?' : _cfg.guesserHint,
              textAlign: TextAlign.center,
              style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w600, height: 1.4)),
        ],
      ),
      footer: !_revealed
          ? SizedBox(
              width: double.infinity,
              child: MomzoButton('Reveal & compare ✨',
                  color: _cfg.accent, onTap: () => setState(() => _revealed = true)),
            )
          : Row(children: [
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
              Expanded(
                child: MomzoButton('Matched 💜', color: _cfg.accent, onTap: () => _score(true)),
              ),
            ]),
    );
  }

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
