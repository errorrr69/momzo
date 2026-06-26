import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';
import 'game_close_screen.dart';

/// Would You Rather — flip through silly either/or cards, say your pick out loud.
class WouldYouRatherScreen extends StatefulWidget {
  final Game game;
  const WouldYouRatherScreen({super.key, required this.game});

  @override
  State<WouldYouRatherScreen> createState() => _WouldYouRatherScreenState();
}

class _WouldYouRatherScreenState extends State<WouldYouRatherScreen> {
  List<GameItem> _items = [];
  int _i = 0;
  String? _pick; // 'A' | 'B' for the current card
  bool _loading = true;

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
        _pick = null;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GameCloseScreen()),
      );
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
        body: Center(child: Text('No cards yet.', style: MomzoText.serif(16, color: MomzoColors.muted))),
      );
    }
    final p = _items[_i].payload;
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _topBar('Would You Rather', 'Card ${_i + 1} of ${_items.length}'),
            _dots(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: _option('A', p['optionA'] as String? ?? '',
                              p['emojiA'] as String? ?? '✨',
                              const [Color(0xFFF4A38E), MomzoColors.coral]),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _option('B', p['optionB'] as String? ?? '',
                              p['emojiB'] as String? ?? '✨',
                              const [Color(0xFF9BCEDC), Color(0xFF7FBED0)]),
                        ),
                      ],
                    ),
                    Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0x2E3D3330), blurRadius: 16, offset: Offset(0, 6))],
                      ),
                      alignment: Alignment.center,
                      child: Text('OR', style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
              child: Column(
                children: [
                  if (_pick != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: MomzoColors.coralTint, borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        'You picked "${_pick == 'A' ? p['optionA'] : p['optionB']}"! What would your grown-up choose? 💬',
                        textAlign: TextAlign.center,
                        style: MomzoText.sans(13, color: MomzoColors.coralDeep, weight: FontWeight.w700, height: 1.35)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: MomzoButton(
                      _i < _items.length - 1 ? 'Next card →' : 'Finish 💜',
                      onTap: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(String title, String sub) {
    return Padding(
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
            Text(title, style: MomzoText.sans(13, color: MomzoColors.ink, weight: FontWeight.w800)),
            Text(sub, style: MomzoText.sans(11, color: MomzoColors.muted, weight: FontWeight.w700)),
          ]),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            Container(
              width: 18, height: 5,
              decoration: BoxDecoration(
                color: i <= _i ? MomzoColors.coral : const Color(0xFFF1D8CB),
                borderRadius: BorderRadius.circular(3)),
            ),
            if (i != _items.length - 1) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }

  Widget _option(String letter, String text, String emoji, List<Color> colors) {
    final selected = _pick == letter;
    final dim = _pick != null && !selected;
    return GestureDetector(
      onTap: () => setState(() => _pick = letter),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dim ? .5 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: selected ? Border.all(color: Colors.white, width: 3) : null,
            boxShadow: [BoxShadow(color: colors.last.withValues(alpha: .32), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(letter, style: MomzoText.sans(13, color: Colors.white70, weight: FontWeight.w900)),
                  if (selected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                ],
              ),
              const SizedBox(height: 4),
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 8),
              Text(text, style: MomzoText.sans(21, color: Colors.white, weight: FontWeight.w900, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
