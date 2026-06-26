import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';
import '../../../services/tts_service.dart';
import 'game_close_screen.dart';

/// Get to Know Me — flip through warm questions; both say their answer out loud
/// (and guess each other's). Conversational, no scoring.
class GetToKnowYouScreen extends StatefulWidget {
  final Game game;
  const GetToKnowYouScreen({super.key, required this.game});

  @override
  State<GetToKnowYouScreen> createState() => _GetToKnowYouScreenState();
}

class _GetToKnowYouScreenState extends State<GetToKnowYouScreen> {
  List<GameItem> _items = [];
  int _i = 0;
  bool _loading = true;

  static const _catEmoji = {
    'favourite': '🎨', 'feeling': '💗', 'dream': '✨', 'us': '💛',
  };

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
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const GameCloseScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: MomzoColors.cream,
        body: Center(child: CircularProgressIndicator(color: MomzoColors.coral)),
      );
    }
    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: MomzoColors.cream,
        appBar: AppBar(backgroundColor: MomzoColors.cream, elevation: 0),
        body: Center(child: Text('No questions yet.', style: MomzoText.serif(16, color: MomzoColors.muted))),
      );
    }
    final p = _items[_i].payload;
    final question = p['question'] as String? ?? '';
    final category = p['category'] as String? ?? 'us';
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        border: Border.all(color: MomzoColors.cardBorder, width: 1.5)),
                      child: const Icon(Icons.close_rounded, size: 18, color: MomzoColors.muted),
                    ),
                  ),
                  Column(children: [
                    Text('Get to Know Me', style: MomzoText.sans(13, color: MomzoColors.ink, weight: FontWeight.w800)),
                    Text('Card ${_i + 1} of ${_items.length}',
                        style: MomzoText.sans(11, color: MomzoColors.muted, weight: FontWeight.w700)),
                  ]),
                  const SizedBox(width: 34),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: Color(0x383D3330), blurRadius: 28, offset: Offset(0, 12)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(_catEmoji[category] ?? '💛', style: const TextStyle(fontSize: 40)),
                          const SizedBox(height: 10),
                          Text(category.toUpperCase(),
                              style: MomzoText.sans(11,
                                  color: MomzoColors.honeyText, weight: FontWeight.w800, spacing: .8)),
                          const SizedBox(height: 8),
                          Text(question,
                              textAlign: TextAlign.center,
                              style: MomzoText.serif(24, color: MomzoColors.ink, height: 1.3)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => TtsService.speak(question),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.volume_up_rounded, size: 18, color: MomzoColors.coral),
                            const SizedBox(width: 7),
                            Text('Tap to hear',
                                style: MomzoText.sans(13, color: MomzoColors.body, weight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Both say your answer out loud — then guess each other’s! 💬',
                        textAlign: TextAlign.center,
                        style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w600, height: 1.4)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
              child: SizedBox(
                width: double.infinity,
                child: MomzoButton(
                  _i < _items.length - 1 ? 'Next question →' : 'Finish 💜',
                  onTap: _next,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
