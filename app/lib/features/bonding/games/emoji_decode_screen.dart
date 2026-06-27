import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';
import 'game_close_screen.dart';
import 'game_scaffold.dart';

/// Emoji Decode — guess what the emojis mean, then reveal (generic answers, no
/// copyrighted titles — games spec §2.12).
class EmojiDecodeScreen extends StatefulWidget {
  final Game game;
  const EmojiDecodeScreen({super.key, required this.game});

  @override
  State<EmojiDecodeScreen> createState() => _EmojiDecodeScreenState();
}

class _EmojiDecodeScreenState extends State<EmojiDecodeScreen> {
  List<GameItem> _items = [];
  int _i = 0;
  bool _loading = true;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

  void _next() {
    if (_i < _items.length - 1) {
      setState(() {
        _i++;
        _revealed = false;
      });
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameCloseScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GameLoading();
    if (_items.isEmpty) return const GameEmpty();
    final p = _items[_i].payload;
    final emojis = p['emojis'] as String? ?? '❓';
    final answer = p['answer'] as String? ?? '';
    final hint = p['hint'] as String? ?? '';
    final words = answer.trim().isEmpty ? 0 : answer.trim().split(RegExp(r'\s+')).length;

    return GameScaffold(
      title: 'Emoji Decode',
      subtitle: 'Card ${_i + 1} of ${_items.length}',
      onClose: () => Navigator.maybePop(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('What could this be? 🎬',
              style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w800)),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9BCEDC), Color(0xFF8FC7D6)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x468FC7D6), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Center(child: Text(emojis, style: const TextStyle(fontSize: 52))),
          ),
          const SizedBox(height: 14),
          if (!_revealed) ...[
            Text('$words ${words == 1 ? 'word' : 'words'} · say your guess out loud!',
                style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w700)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _revealed = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                decoration: BoxDecoration(
                  color: MomzoColors.ink, borderRadius: BorderRadius.circular(14)),
                child: Text('Reveal answer',
                    style: MomzoText.sans(14, color: Colors.white, weight: FontWeight.w800)),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MomzoColors.sageTint, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Text('It’s… $answer! 🎉',
                      textAlign: TextAlign.center,
                      style: MomzoText.sans(19, color: const Color(0xFF4E7A60), weight: FontWeight.w900)),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('($hint)',
                        textAlign: TextAlign.center,
                        style: MomzoText.sans(13, color: const Color(0xFF5C6B5F), weight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      footer: SizedBox(
        width: double.infinity,
        child: MomzoButton(
          !_revealed ? 'Skip / give up' : (_i < _items.length - 1 ? 'Next →' : 'Finish 💜'),
          onTap: !_revealed ? () => setState(() => _revealed = true) : _next,
        ),
      ),
    );
  }
}
