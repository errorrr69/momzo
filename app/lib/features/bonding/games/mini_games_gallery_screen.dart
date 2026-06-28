import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../services/child_service.dart';
import '../../../services/game_service.dart';
import 'would_you_rather_screen.dart';
import 'get_to_know_you_screen.dart';
import 'finish_the_sentence_screen.dart';
import 'emoji_decode_screen.dart';
import 'prompt_card_screen.dart';
import 'time_machine_screen.dart';
import 'mood_checkin_screen.dart';
import 'reveal_score_screen.dart';

/// 26 · Mini-games gallery — pick a deck to play together (Together page).
class MiniGamesGalleryScreen extends StatefulWidget {
  const MiniGamesGalleryScreen({super.key});

  @override
  State<MiniGamesGalleryScreen> createState() => _MiniGamesGalleryScreenState();
}

class _MiniGamesGalleryScreenState extends State<MiniGamesGalleryScreen> {
  List<Game> _games = [];
  bool _loading = true;

  String get _childName => ChildService.current?.name ?? 'your child';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await GameService.catalog();
      if (mounted) setState(() {
        _games = g;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _accent(Game g) {
    final h = (g.accent ?? '#A593D6').replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _openGame(Game g) {
    if (!g.playable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${g.title} is coming soon! 🎈')),
      );
      return;
    }
    final Widget screen = switch (g.slug) {
      'would-you-rather' => WouldYouRatherScreen(game: g),
      'get-to-know-you' => GetToKnowYouScreen(game: g),
      'finish-the-sentence' => FinishTheSentenceScreen(game: g),
      'emoji-decode' => EmojiDecodeScreen(game: g),
      'time-machine' => TimeMachineScreen(game: g),
      'mood-checkin' => MoodCheckinScreen(game: g),
      _ when kRevealGames.containsKey(g.slug) =>
        RevealScoreScreen(game: g, config: kRevealGames[g.slug]!),
      _ when kPromptGames.containsKey(g.slug) =>
        PromptCardScreen(game: g, config: kPromptGames[g.slug]!),
      _ => const SizedBox.shrink(),
    };
    if (screen is SizedBox) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 24, 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                      ),
                      child: const Icon(Icons.chevron_left_rounded, size: 22, color: MomzoColors.body),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mini-games',
                          style: MomzoText.sans(22,
                              color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.4)),
                      Text('Pick a deck to play with $_childName',
                          style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
                  : GridView.count(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: .92,
                      children: [for (final g in _games) _deck(g)],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deck(Game g) {
    final accent = _accent(g);
    return GestureDetector(
      onTap: () => _openGame(g),
      child: Opacity(
        opacity: g.playable ? 1 : .78,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: .82), accent],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: .3), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.emoji ?? '🎲', style: const TextStyle(fontSize: 30)),
              const Spacer(),
              Text(g.title,
                  style: MomzoText.sans(15,
                      color: Colors.white, weight: FontWeight.w900, height: 1.1)),
              const SizedBox(height: 3),
              Text(g.playable ? (g.subtitle ?? '') : 'Coming soon',
                  style: MomzoText.sans(11,
                      color: Colors.white.withValues(alpha: .9), weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
