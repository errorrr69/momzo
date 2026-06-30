import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';

/// Short, warm "how to play" for each game (Hard Rule #18 — friendly, no pressure).
/// One source of truth, fed into the shared [GameRulesScreen]; pulled from the
/// games spec (§2). A game without an entry falls back to a gentle default.
const Map<String, String> kGameRules = {
  'would-you-rather':
      'Two fun choices on each card — you both pick your favourite, then share why. There are no wrong answers!',
  'get-to-know-you':
      'Take turns reading a question, and you BOTH answer. Little windows into each other 💛',
  'finish-the-sentence':
      'Read the start of a sentence, then you each finish it your own way — out loud!',
  'emoji-decode':
      'Look at the emojis and guess what they mean together. Tap to reveal the answer!',
  'story-builder': 'Build a silly story together — one line each. See where it goes!',
  'how-well-know-me':
      'You’ll take turns on the same phone. One of you answers with the phone hidden, then passes '
          'it over for the other — then you reveal together and see if you matched!',
  'guess-my-answer':
      'You’ll take turns on the same phone. One of you guesses with the phone hidden, then passes '
          'it over so the other can answer — then reveal together and compare!',
  'hot-seat':
      'Quick-fire questions for one of you — answer as fast as you can, then swap seats!',
  'time-machine':
      'One card looks back at the grown-up’s childhood, one looks ahead to yours. Share them both!',
  'memory-lane': 'A little prompt about a happy memory — take turns sharing yours.',
  'gratitude-swap':
      'Each of you shares something you’re thankful for about the other. 💚',
  'compliment-toss': 'Finish the kind sentence for each other — be warm and specific!',
  'charades': 'Act out the card with no talking — the other guesses! Then swap.',
  'drawing-telephone': 'Grab some paper! One of you draws the card while the other guesses.',
  'simon-says': 'Only do the action if it starts with “Simon says”. Take turns being Simon!',
  'mirror-me': 'One of you leads a slow movement, the other mirrors it — then swap.',
  'two-truths':
      'One of you says (or types) two true things and one made-up one — tap the mic to '
          'speak it! The other picks the two they think are true, then you reveal the fib together.',
};

/// Shared rules screen shown BEFORE any game starts (one component for every game,
/// fed by [kGameRules]). The "Start" button replaces this screen with the game.
class GameRulesScreen extends StatelessWidget {
  final Game game;
  final WidgetBuilder gameBuilder;
  const GameRulesScreen({super.key, required this.game, required this.gameBuilder});

  Color get _accent {
    final h = (game.accent ?? '#A593D6').replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final rules = kGameRules[game.slug] ?? 'Play together and have fun — there are no wrong answers!';
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      border: Border.all(color: MomzoColors.cardBorder, width: 1.5)),
                    child: const Icon(Icons.close_rounded, size: 18, color: MomzoColors.muted),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92, height: 92,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_accent.withValues(alpha: .82), _accent],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(color: _accent.withValues(alpha: .3), blurRadius: 22, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Text(game.emoji ?? '🎲', style: const TextStyle(fontSize: 44)),
                    ),
                    const SizedBox(height: 22),
                    Text(game.title,
                        textAlign: TextAlign.center,
                        style: MomzoText.sans(26, color: MomzoColors.ink, weight: FontWeight.w900, height: 1.15)),
                    const SizedBox(height: 22),
                    Text('HOW TO PLAY', style: MomzoText.eyebrow()),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Text(rules,
                          textAlign: TextAlign.center,
                          style: MomzoText.serif(17, color: MomzoColors.body, height: 1.5)),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 26),
              child: SizedBox(
                width: double.infinity,
                child: MomzoButton('Start',
                    color: _accent,
                    onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: gameBuilder),
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
