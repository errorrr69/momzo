import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../models/game_insights.dart';
import '../../../models/learning_game.dart';
import '../../../services/child_service.dart';
import '../../../services/learning_game_service.dart';
import '../widgets/how_its_going.dart';
import '../widgets/shelf_style.dart';
import 'game_player_screen.dart';

/// Momzo Learning Games — the shelves.
///
/// Grounded in child development, delivered as play. Not framed as tutoring and
/// carrying no booking links: the practice and the app stay separate in anything
/// a mother sees (Expansion Plan §3.1).
///
/// Age-gated by data, not by a hardcoded 5–6: the screen asks the catalog which
/// games suit the selected child. Adding a band later is a row, not a release.
class LearningGamesScreen extends StatefulWidget {
  const LearningGamesScreen({super.key});

  @override
  State<LearningGamesScreen> createState() => _LearningGamesScreenState();
}

class _LearningGamesScreenState extends State<LearningGamesScreen> {
  List<LearningGame> _games = const [];
  GameInsights _insights = const GameInsights();
  bool _loading = true;

  String get _childName => ChildService.current?.name ?? 'your child';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final age = ChildService.current?.age;
      final games = await LearningGameService.catalogue(age: age);
      // The dashboard is a second read and must never hold up the shelves: if it
      // fails, she still gets her games and simply no notes.
      GameInsights insights = const GameInsights();
      try {
        insights = await LearningGameService.insights();
      } catch (_) {/* shelves are the point; notes are the bonus */}
      if (mounted) {
        setState(() { _games = games; _insights = insights; _loading = false; });
      }
    } catch (_) {
      // An empty shelf reads as "nothing here yet", which is the honest result
      // of a failed fetch too. No error card for a mother who just wants to play.
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LearningGame> _shelf(GameShelf s) =>
      _games.where((g) => g.category == s.key).toList();

  void _play(LearningGame game) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GamePlayerScreen(game: game)),
    ).then((_) => _load()); // a finished session changes what the dashboard says
  }

  @override
  Widget build(BuildContext context) {
    final shelves = GameShelf.values.where((s) => _shelf(s).isNotEmpty).toList();

    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Learning games',
                      style: MomzoText.sans(24,
                          color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.4)),
                  const SizedBox(height: 2),
                  Text('Play these together — you drive, $_childName plays',
                      style: MomzoText.sans(13,
                          color: MomzoColors.muted, weight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
                  : shelves.isEmpty
                      ? _empty()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 28),
                          children: [
                            // For the mother, above the shelves (Expansion Plan
                            // §3.6). The child never sees it.
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
                              child: HowItsGoing(
                                insights: _insights,
                                childName: _childName,
                                onOpen: _play,
                              ),
                            ),
                            for (final s in shelves) _shelfBlock(s),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Games for $_childName’s age are on their way 💛',
                  textAlign: TextAlign.center,
                  style: MomzoText.serif(21, color: MomzoColors.ink)),
              const SizedBox(height: 8),
              Text('There’s plenty else to do together in the meantime.',
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(14, color: MomzoColors.body)),
            ],
          ),
        ),
      );

  Widget _shelfBlock(GameShelf shelf) {
    final style = ShelfStyle.forShelf(shelf);
    final games = _shelf(shelf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
          child: Row(
            children: [
              Text(shelf.emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              Text(shelf.label,
                  style: MomzoText.sans(16, color: MomzoColors.ink, weight: FontWeight.w800)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(shelf.blurb,
                    overflow: TextOverflow.ellipsis,
                    style: MomzoText.sans(12,
                        color: MomzoColors.muted, weight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (_, i) => _card(games[i], style),
          ),
        ),
      ],
    );
  }

  Widget _card(LearningGame game, ShelfStyle style) => GestureDetector(
        onTap: () => _play(game),
        child: Container(
          width: 156,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: style.tint, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(style.shelf.emoji, style: const TextStyle(fontSize: 16)),
              ),
              const Spacer(),
              Text(game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MomzoText.sans(14.5,
                      color: MomzoColors.ink, weight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text('Play',
                      style: MomzoText.sans(12.5, color: style.text, weight: FontWeight.w800)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 16, color: style.text),
                ],
              ),
            ],
          ),
        ),
      );
}
