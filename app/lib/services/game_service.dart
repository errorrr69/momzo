import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';
import 'child_service.dart';

class Game {
  final String slug, title;
  final String? emoji, subtitle, accent;
  final bool playable;
  final int roundsA, roundsB, roundsC;
  const Game({
    required this.slug, required this.title, this.emoji, this.subtitle,
    this.accent, this.playable = false,
    this.roundsA = 3, this.roundsB = 5, this.roundsC = 6,
  });
  factory Game.fromMap(Map<String, dynamic> m) => Game(
        slug: m['slug'] as String,
        title: (m['title'] ?? '') as String,
        emoji: m['emoji'] as String?,
        subtitle: m['subtitle'] as String?,
        accent: m['accent'] as String?,
        playable: (m['playable'] ?? false) as bool,
        roundsA: (m['rounds_a'] ?? 3) as int,
        roundsB: (m['rounds_b'] ?? 5) as int,
        roundsC: (m['rounds_c'] ?? 6) as int,
      );
  int roundsFor(String band) => band == 'A' ? roundsA : band == 'B' ? roundsB : roundsC;
}

class GameItem {
  final String id;
  final Map<String, dynamic> payload;
  const GameItem({required this.id, required this.payload});
  factory GameItem.fromMap(Map<String, dynamic> m) =>
      GameItem(id: m['id'] as String, payload: Map<String, dynamic>.from(m['payload'] as Map));
}

/// Mini-games engine (Task: Together games). Catalog + the anti-repetition dealer:
/// items unseen by this family come first; once the bank is exhausted a cooldown
/// keeps recent items out before reintroducing oldest-seen. Every dealt item is
/// recorded in game_play_history (RLS family-scoped).
class GameService {
  const GameService._();

  static String bandForAge(int age) => age <= 5 ? 'A' : (age <= 7 ? 'B' : 'C');
  static String get currentBand => bandForAge(ChildService.current?.age ?? 8);

  static Future<List<Game>> catalog() async {
    final rows = await supabase.from('games').select().order('sort') as List;
    return [for (final r in rows) Game.fromMap(r as Map<String, dynamic>)];
  }

  /// Deal `count` items for a game in the current child's band, anti-repeat aware,
  /// and record them in history.
  static Future<List<GameItem>> deal(String slug, int count) async {
    final child = ChildService.current;
    final uid = AuthService.currentUser?.id;
    if (child == null || uid == null) return [];
    final band = bandForAge(child.age);

    final itemRows = await supabase
        .from('game_items')
        .select('id,payload')
        .eq('game_slug', slug)
        .eq('band', band)
        .eq('active', true) as List;
    final all = [for (final r in itemRows) GameItem.fromMap(r as Map<String, dynamic>)];
    if (all.isEmpty) return [];

    final histRows = await supabase
        .from('game_play_history')
        .select('item_id,shown_at')
        .eq('child_id', child.id)
        .eq('game_slug', slug)
        .order('shown_at', ascending: false) as List;
    final shownOrder = [for (final h in histRows) h['item_id'] as String];
    final shownSet = shownOrder.toSet();

    final picked = <GameItem>[];
    final unseen = all.where((i) => !shownSet.contains(i.id)).toList()..shuffle();
    picked.addAll(unseen.take(count));

    if (picked.length < count) {
      // Pool exhausted — cooldown: keep the most-recent items out, then oldest-first.
      final cooldown = (all.length > 20 ? 20 : (all.length ~/ 2)).clamp(0, all.length);
      final recent = shownOrder.take(cooldown).toSet();
      final ineligible = {...picked.map((i) => i.id), ...recent};
      final eligible = all.where((i) => !ineligible.contains(i.id)).toList()..shuffle();
      picked.addAll(eligible.take(count - picked.length));
      if (picked.length < count) {
        final pickedIds = picked.map((i) => i.id).toSet();
        final more = all.where((i) => !pickedIds.contains(i.id)).toList()..shuffle();
        picked.addAll(more.take(count - picked.length));
      }
    }

    if (picked.isNotEmpty) {
      await supabase.from('game_play_history').insert([
        for (final i in picked)
          {'owner_id': uid, 'child_id': child.id, 'game_slug': slug, 'item_id': i.id}
      ]);
    }
    return picked;
  }
}
