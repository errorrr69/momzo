import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';
import '../../../services/tts_service.dart';
import 'game_close_screen.dart';
import 'game_scaffold.dart';

/// Finish the Sentence — flip through open, positive stems; both finish them aloud.
class FinishTheSentenceScreen extends StatefulWidget {
  final Game game;
  const FinishTheSentenceScreen({super.key, required this.game});

  @override
  State<FinishTheSentenceScreen> createState() => _FinishTheSentenceScreenState();
}

class _FinishTheSentenceScreenState extends State<FinishTheSentenceScreen> {
  List<GameItem> _items = [];
  int _i = 0;
  bool _loading = true;

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
      if (mounted) setState(() {
        _items = items;
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GameLoading();
    if (_items.isEmpty) return const GameEmpty();
    final stem = _items[_i].payload['stem'] as String? ?? '';
    return GameScaffold(
      title: 'Finish the Sentence',
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
                const Text('✏️', style: TextStyle(fontSize: 38)),
                const SizedBox(height: 14),
                Text('“$stem”',
                    textAlign: TextAlign.center,
                    style: MomzoText.serif(25, color: MomzoColors.ink, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _hearButton(stem),
          const SizedBox(height: 18),
          Text('Both finish it your own way — say it out loud! 💚',
              textAlign: TextAlign.center,
              style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w600, height: 1.4)),
        ],
      ),
      footer: SizedBox(
        width: double.infinity,
        child: MomzoButton(_i < _items.length - 1 ? 'Next →' : 'Finish 💜', onTap: _next),
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
