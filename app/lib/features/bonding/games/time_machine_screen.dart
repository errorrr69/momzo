import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';
import '../../../services/tts_service.dart';
import 'game_close_screen.dart';
import 'game_scaffold.dart';

/// Time Machine — a gentle pair of prompts per card: the grown-up looks back at
/// their childhood, the child looks forward to growing up (games spec §2.6).
class TimeMachineScreen extends StatefulWidget {
  final Game game;

  /// Test-only seam: inject the cards instead of dealing from the backend.
  final List<GameItem>? initialItems;
  const TimeMachineScreen({super.key, required this.game, this.initialItems});

  @override
  State<TimeMachineScreen> createState() => _TimeMachineScreenState();
}

class _TimeMachineScreenState extends State<TimeMachineScreen> {
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
    if (widget.initialItems != null) {
      setState(() { _items = widget.initialItems!; _loading = false; });
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GameLoading();
    if (_items.isEmpty) return const GameEmpty();
    final p = _items[_i].payload;
    final parentPrompt = (p['parentPrompt'] as String?)?.trim() ?? '';
    final childPrompt = (p['childPrompt'] as String?)?.trim() ?? '';

    return GameScaffold(
      title: 'Time Machine',
      subtitle: 'Card ${_i + 1} of ${_items.length}',
      onClose: () => Navigator.maybePop(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _promptCard('⏪', 'Grown-up, look back…', parentPrompt,
              const Color(0xFFECE6F8), MomzoColors.lavenderText),
          const SizedBox(height: 14),
          _promptCard('⏩', 'Now you, look forward…', childPrompt,
              const Color(0xFFE2F0E4), MomzoColors.sageText),
        ],
      ),
      footer: SizedBox(
        width: double.infinity,
        child: MomzoButton(_i < _items.length - 1 ? 'Next →' : 'Finish 💜',
            color: MomzoColors.lavender, onTap: _next),
      ),
    );
  }

  Widget _promptCard(String icon, String label, String text, Color bg, Color labelColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: MomzoText.sans(12, color: labelColor, weight: FontWeight.w900)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => TtsService.speak(text),
              child: Icon(Icons.volume_up_rounded, size: 20, color: labelColor.withValues(alpha: .7)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(text, style: MomzoText.serif(18, color: MomzoColors.ink, height: 1.3)),
        ],
      ),
    );
  }
}
