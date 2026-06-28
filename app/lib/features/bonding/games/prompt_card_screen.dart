import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';
import '../../../services/tts_service.dart';
import 'game_close_screen.dart';
import 'game_scaffold.dart';

/// How one conversational "say it out loud" game renders a card. The mini-games
/// engine is identical for all of them (deal → flip cards → warm closer); only the
/// payload key, copy, and accent differ. This config drives the shared
/// [PromptCardScreen] so we don't duplicate a screen per game (games spec §2).
class PromptGameConfig {
  /// payload key holding the main line to show + read aloud.
  final String textKey;

  /// optional payload key holding a big emoji hint (charades / drawing / dance).
  final String? emojiKey;

  /// header emoji fallback when the catalog row has none.
  final String emoji;

  /// reflective prompts read nicer in serif; quick/active ones in bold sans.
  final bool serif;

  /// the gentle instruction line under the card.
  final String hint;

  /// optional accent override; defaults to the deck's catalog accent (Lavender).
  final Color? accent;

  const PromptGameConfig({
    required this.textKey,
    required this.hint,
    this.emojiKey,
    this.emoji = '💜',
    this.serif = false,
    this.accent,
  });
}

/// The conversational games (one prompt per card, both say it out loud). Keyed by
/// game slug — the gallery routes any slug present here through this one screen.
const Map<String, PromptGameConfig> kPromptGames = {
  'hot-seat': PromptGameConfig(
    textKey: 'question', emoji: '🔥',
    hint: 'Quick — say the first thing that pops into your head! 🎉'),
  'memory-lane': PromptGameConfig(
    textKey: 'prompt', emoji: '💭', serif: true,
    hint: 'Take turns sharing the memory 💭'),
  'gratitude-swap': PromptGameConfig(
    textKey: 'prompt', emoji: '🌸', serif: true,
    hint: 'Both share — something about each other 💚'),
  'compliment-toss': PromptGameConfig(
    textKey: 'scaffold', emoji: '🎁', serif: true,
    hint: 'Finish it for each other — be specific and kind 💛'),
  'drawing-telephone': PromptGameConfig(
    textKey: 'drawPrompt', emoji: '✏️',
    hint: 'Grab paper ✏️ — one draws it, the other guesses!'),
  'charades': PromptGameConfig(
    textKey: 'actPrompt', emojiKey: 'emojiHint', emoji: '🎭',
    hint: 'Act it out — no talking! The other guesses 🎭'),
  'dance-freeze': PromptGameConfig(
    textKey: 'moveTheme', emoji: '🕺',
    hint: 'Dance like this… then FREEZE! 🧊'),
  'simon-says': PromptGameConfig(
    textKey: 'command', emoji: '🙌',
    hint: "Only do it if it starts with “Simon says”! 🙌"),
  'mirror-me': PromptGameConfig(
    textKey: 'moveIdea', emoji: '🪞',
    hint: 'One leads, the other mirrors — then swap! 🪞'),
  'two-truths': PromptGameConfig(
    textKey: 'scaffold', emoji: '🕵️',
    hint: 'Build your statements from these — then guess each other’s! 🕵️'),
  'story-builder': PromptGameConfig(
    textKey: 'starter', emoji: '📖', serif: true,
    hint: 'Take turns adding one line each 📖'),
};

/// Shared screen for the conversational mini-games (see [kPromptGames]).
class PromptCardScreen extends StatefulWidget {
  final Game game;
  final PromptGameConfig config;
  const PromptCardScreen({super.key, required this.game, required this.config});

  @override
  State<PromptCardScreen> createState() => _PromptCardScreenState();
}

class _PromptCardScreenState extends State<PromptCardScreen> {
  List<GameItem> _items = [];
  int _i = 0;
  bool _loading = true;

  PromptGameConfig get _cfg => widget.config;

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

  void _next() {
    TtsService.stop();
    if (_i < _items.length - 1) {
      setState(() => _i++);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameCloseScreen()));
    }
  }

  Color get _accent {
    if (_cfg.accent != null) return _cfg.accent!;
    final h = (widget.game.accent ?? '#A593D6').replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GameLoading();
    if (_items.isEmpty) return const GameEmpty();
    final p = _items[_i].payload;
    final text = (p[_cfg.textKey] as String?)?.trim() ?? '';
    final emojiHint = _cfg.emojiKey == null ? null : p[_cfg.emojiKey] as String?;

    return GameScaffold(
      title: widget.game.title,
      subtitle: 'Card ${_i + 1} of ${_items.length}',
      onClose: () => Navigator.maybePop(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x303D3330), blurRadius: 26, offset: Offset(0, 12))],
            ),
            child: Column(
              children: [
                Text(emojiHint != null && emojiHint.isNotEmpty ? emojiHint : (widget.game.emoji ?? _cfg.emoji),
                    style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 14),
                Text(_cfg.serif ? '“$text”' : text,
                    textAlign: TextAlign.center,
                    style: _cfg.serif
                        ? MomzoText.serif(24, color: MomzoColors.ink, height: 1.35)
                        : MomzoText.sans(22, color: MomzoColors.ink, weight: FontWeight.w800, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _hearButton(text),
          const SizedBox(height: 18),
          Text(_cfg.hint,
              textAlign: TextAlign.center,
              style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w600, height: 1.4)),
        ],
      ),
      footer: SizedBox(
        width: double.infinity,
        child: MomzoButton(_i < _items.length - 1 ? 'Next →' : 'Finish 💜',
            color: _accent, onTap: _next),
      ),
    );
  }

  Widget _hearButton(String text) => GestureDetector(
        onTap: () => TtsService.speak(text.replaceAll('___', 'blank')),
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
      );
}
