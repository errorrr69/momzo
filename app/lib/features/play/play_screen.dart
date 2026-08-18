import 'package:flutter/material.dart';

import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/game_insights.dart';
import '../../models/learning_game.dart';
import '../../services/child_service.dart';
import '../../services/learning_game_service.dart';
import '../../services/question_service.dart';
import '../bonding/daily_question_screen.dart';
import '../bonding/games/mini_games_gallery_screen.dart';
import '../bonding/quiz_flow_screen.dart';
import '../learning_games/screens/game_player_screen.dart';
import '../learning_games/widgets/how_its_going.dart';
import '../learning_games/widgets/shelf_style.dart';
import '../wishes/calendar_screen.dart';
import '../wishes/wish_wall_screen.dart';

/// **Play** — everything she does *with* the child (UX plan §3.3).
///
/// This replaces the old Together hub, which had become a junk drawer: seven
/// destinations in one flat list, with the two best things in the app sitting at
/// positions five and six. A tired reader parsed that list on every visit.
///
/// The order here is the argument. Learning games are the differentiator, so
/// they are visible without scrolling past anything. The dashboard sits above
/// them but collapsed to a single line, because "how it went" should be
/// available, not compulsory — she came here to play, not to read analytics.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  List<LearningGame> _games = const [];
  GameInsights _insights = const GameInsights();
  bool _loading = true;
  bool _insightsOpen = false;

  String _prompt = '';
  bool _answeredToday = false;

  String get _childName => ChildService.current?.name ?? 'your child';

  @override
  void initState() {
    super.initState();
    if (AppEnv.hasSupabase) _load();
  }

  Future<void> _load() async {
    try {
      final age = ChildService.current?.age;
      final games = await LearningGameService.catalogue(age: age);

      // Each of the three is allowed to fail on its own. A dead dashboard must
      // not take the games down with it, and neither should the daily question.
      GameInsights insights = const GameInsights();
      try {
        insights = await LearningGameService.insights();
      } catch (_) {/* games are the point; notes are the bonus */}

      String prompt = '';
      bool answered = false;
      try {
        final q = await QuestionService.todaysQuestion();
        if (q != null) {
          prompt = q.prompt;
          final answers = await QuestionService.todaysResponses(q.id);
          answered = answers.containsKey('parent') && answers.containsKey('child');
        }
      } catch (_) {/* the card falls back to its own copy */}

      if (!mounted) return;
      setState(() {
        _games = games;
        _insights = insights;
        _prompt = prompt;
        _answeredToday = answered;
        _loading = false;
      });
    } catch (_) {
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
            : ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Play',
                            style: MomzoText.sans(26,
                                color: MomzoColors.ink, weight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('Things to do with $_childName',
                            style: MomzoText.sans(13,
                                color: MomzoColors.muted, weight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        if (_prompt.isNotEmpty) ...[
                          _questionCard(),
                          const SizedBox(height: 14),
                        ],
                        if (_insights.hasPlayed) ...[
                          _howItsGoing(),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                  if (shelves.isEmpty)
                    _noGames()
                  else ...[
                    for (final s in shelves) _shelfBlock(s),
                    const SizedBox(height: 8),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MORE TO DO TOGETHER', style: MomzoText.eyebrow()),
                        const SizedBox(height: 11),
                        _row(
                          emoji: '🧩',
                          title: 'How well do you know each other?',
                          sub: 'The flagship match-up quiz',
                          tint: MomzoColors.coralTint,
                          onTap: () => _push(const QuizFlowScreen()),
                        ),
                        const SizedBox(height: 10),
                        _row(
                          emoji: '⭐',
                          title: '$_childName’s Wish Wall',
                          sub: 'Kid mode — their wishes for time with you',
                          tint: MomzoColors.honeyTint,
                          onTap: () => _push(const WishWallScreen()),
                        ),
                        const SizedBox(height: 10),
                        _row(
                          emoji: '🎲',
                          title: 'Mini-games',
                          sub: 'Would-you-rather & more',
                          tint: MomzoColors.skyTint,
                          onTap: () => _push(const MiniGamesGalleryScreen()),
                        ),
                        const SizedBox(height: 10),
                        _row(
                          emoji: '🗓️',
                          title: 'Our together-times',
                          sub: 'Plan wishes in & see what’s coming up',
                          tint: MomzoColors.lavenderTint,
                          onTap: () => _push(const CalendarScreen()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _load());
  }

  /// The only time-sensitive thing on this screen, so it keeps the top slot —
  /// and says plainly when it is already done, so she can skip it.
  Widget _questionCard() => GestureDetector(
        onTap: () => _push(const DailyQuestionScreen()),
        behavior: HitTestBehavior.opaque,
        child: Container(
          // Without this the Container shrink-wraps its text and the card comes
          // out narrower than everything below it — a ragged right edge that
          // reads as a rendering fault rather than a design.
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: MomzoColors.lavender,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QUESTION OF THE DAY',
                  style: MomzoText.eyebrow(color: MomzoColors.lavenderText)),
              const SizedBox(height: 7),
              Text(_prompt,
                  style: MomzoText.serif(19, color: MomzoColors.ink, height: 1.3)),
              const SizedBox(height: 12),
              Text(_answeredToday ? 'Answered today 💛' : 'Tap to answer together',
                  style: MomzoText.sans(12.5,
                      color: MomzoColors.lavenderText, weight: FontWeight.w800)),
            ],
          ),
        ),
      );

  /// Collapsed to the win line by default (UX plan §3.3).
  ///
  /// The full dashboard is good and she may want it — but not before she has
  /// found the games. One tap opens it; the closing win is what shows meanwhile,
  /// which is the part that was worth reading anyway.
  Widget _howItsGoing() {
    if (_insightsOpen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HowItsGoing(
            insights: _insights,
            childName: _childName,
            onOpen: _play,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _insightsOpen = false),
              child: Text('Show less',
                  style: MomzoText.sans(13,
                      color: MomzoColors.muted, weight: FontWeight.w800)),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _insightsOpen = true),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MomzoColors.sunshine,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _insights.win ?? 'You two have been playing 💛',
                style: MomzoText.serif(15.5,
                    color: MomzoColors.sunshineText, height: 1.4),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more_rounded,
                color: MomzoColors.sunshineText, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _noGames() => Padding(
        padding: const EdgeInsets.fromLTRB(34, 20, 34, 8),
        child: Column(
          children: [
            Text('Learning games for $_childName’s age are on their way 💛',
                textAlign: TextAlign.center,
                style: MomzoText.serif(19, color: MomzoColors.ink)),
            const SizedBox(height: 6),
            Text('There’s plenty else to do together below.',
                textAlign: TextAlign.center,
                style: MomzoText.sans(13.5, color: MomzoColors.body)),
          ],
        ),
      );

  Widget _shelfBlock(GameShelf shelf) {
    final style = ShelfStyle.forShelf(shelf);
    final games = _shelf(shelf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
          child: Row(
            children: [
              Text(shelf.emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              Text(shelf.label,
                  style: MomzoText.sans(17,
                      color: MomzoColors.ink, weight: FontWeight.w800)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(shelf.blurb,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MomzoText.sans(12.5,
                        color: MomzoColors.muted, weight: FontWeight.w700)),
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
            itemBuilder: (_, i) => _gameCard(games[i], style),
          ),
        ),
      ],
    );
  }

  Widget _gameCard(LearningGame game, ShelfStyle style) => GestureDetector(
        onTap: () => _play(game),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 154,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MomzoColors.cardBorder, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: style.tint, shape: BoxShape.circle),
                child: Text(style.shelf.emoji, style: const TextStyle(fontSize: 16)),
              ),
              const Spacer(),
              Text(game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MomzoText.sans(14,
                      color: MomzoColors.ink, weight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text('Play',
                      style: MomzoText.sans(12.5,
                          color: style.text, weight: FontWeight.w800)),
                  Icon(Icons.chevron_right_rounded, size: 17, color: style.text),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _row({
    required String emoji,
    required String title,
    required String sub,
    required Color tint,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MomzoColors.cardBorder, width: 1.3),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 21)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MomzoText.sans(14.5,
                            color: MomzoColors.ink, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MomzoText.sans(12,
                            color: MomzoColors.muted, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: MomzoColors.faint),
            ],
          ),
        ),
      );
}
