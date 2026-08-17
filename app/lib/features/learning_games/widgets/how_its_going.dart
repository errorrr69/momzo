import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../models/game_insights.dart';
import '../../../models/learning_game.dart';
import 'shelf_style.dart';

/// "How it's going" — the parent dashboard above the games (Expansion Plan §3.6).
///
/// For the mother, never the child: the child sees celebration inside the game
/// and no analytics anywhere. Everything shown is a count of what happened, and
/// the section always ends on something that went well.
class HowItsGoing extends StatelessWidget {
  final GameInsights insights;
  final String childName;
  final void Function(LearningGame) onOpen;

  const HowItsGoing({
    super.key,
    required this.insights,
    required this.childName,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (!insights.hasPlayed) return _empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HOW IT’S GOING', style: MomzoText.eyebrow()),
        const SizedBox(height: 11),
        _thisWeek(),
        if (insights.standings.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final s in insights.standings.take(4)) ...[
            _standingRow(s),
            const SizedBox(height: 8),
          ],
        ],
        if (insights.moments.isNotEmpty) ...[
          const SizedBox(height: 6),
          _moments(),
        ],
        if (insights.next.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('MAYBE NEXT', style: MomzoText.eyebrow()),
          const SizedBox(height: 10),
          for (final r in insights.next.take(3)) ...[
            _suggestion(r),
            const SizedBox(height: 8),
          ],
        ],
        // Always last, always good. §3.6 requires the section to close on a win.
        if (insights.win != null) ...[
          const SizedBox(height: 14),
          _win(insights.win!),
        ],
      ],
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MomzoColors.sageTint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              // Warm, not a nudge: no "you haven't played yet", no streak to break.
              child: Text(
                'When you two play, I’ll keep gentle notes here.',
                style: MomzoText.sans(13,
                    color: const Color(0xFF5C6B5F), weight: FontWeight.w700, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _thisWeek() {
    final mins = insights.togetherTime.inMinutes;
    final n = insights.sessionsThisWeek;
    final line = n == 0
        ? 'Nothing this week — the notes below are from before.'
        : '$n ${n == 1 ? 'game' : 'games'} together this week'
            '${mins > 0 ? ' · about $mins ${mins == 1 ? 'minute' : 'minutes'}' : ''}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line,
              style: MomzoText.sans(14, color: MomzoColors.ink, weight: FontWeight.w800)),
          if (insights.byCategory.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in insights.byCategory)
                  _pill('${c.shelf.emoji} ${c.shelf.label}', ShelfStyle.of(c.shelf.key)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, ShelfStyle style) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: style.tint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: MomzoText.sans(11.5, color: style.text, weight: FontWeight.w800)),
      );

  Widget _standingRow(GameStanding s) {
    final style = ShelfStyle.of(s.game.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.game.title,
                    style: MomzoText.sans(14, color: MomzoColors.ink, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  // Counts of what happened, in her words. Never a score, and the
                  // comparison is always to this child's own earlier sessions.
                  _progressLine(s),
                  style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              // A dip is never red. `exploring` gets the same warm treatment as
              // the rest, because "still growing" is not a failure state.
              color: style.tint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(s.standing.label,
                style: MomzoText.sans(11.5, color: style.text, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  String _progressLine(GameStanding s) {
    if (s.rounds == 0) {
      return 'Opened ${s.sessions == 1 ? 'once' : '${s.sessions} times'}';
    }
    final bits = <String>[];
    if (s.firstTime > 0) bits.add('${s.firstTime} first time');
    if (s.anotherLook > 0) bits.add('${s.anotherLook} wanted another look');
    if (s.stillExploring > 0) bits.add('${s.stillExploring} still exploring');
    return bits.join(' · ');
  }

  Widget _moments() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MomzoColors.honeyTint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Little moments',
                style: MomzoText.sans(12.5,
                    color: MomzoColors.honeyText, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final m in insights.moments)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('· $m',
                    style: MomzoText.sans(13,
                        color: MomzoColors.body, weight: FontWeight.w600, height: 1.4)),
              ),
          ],
        ),
      );

  Widget _suggestion(Recommendation r) {
    final style = ShelfStyle.of(r.game.category);
    return GestureDetector(
      onTap: () => onOpen(r.game),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: style.tint, width: 1.6),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: style.tint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(style.shelf.emoji, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.game.title,
                      style: MomzoText.sans(14,
                          color: MomzoColors.ink, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(r.reason,
                      style: MomzoText.sans(12,
                          color: MomzoColors.muted, weight: FontWeight.w600, height: 1.35)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: style.text, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _win(String text) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MomzoColors.sageTint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: MomzoText.serif(16, color: const Color(0xFF3F5E4A), height: 1.45)),
      );
}
