/// One of Florie's foundational-learning games, as catalogued in `learning_games`.
///
/// The game itself is a route inside the bundled web app; this is only the card
/// Momzo shows and the path to open. [slug] IS the games app's own GameId — the
/// two must never drift apart, which is why [entryPath] is derived from it
/// server-side rather than assembled here.
class LearningGame {
  final String slug;
  final String title;

  /// Momzo's display shelf: maths | reading | feelings | focus.
  /// Deliberately not the games repo's own three — see the seeder.
  final String category;

  final int ageMin;
  final int ageMax;
  final List<String> skillTags;

  /// Florie's teaching progression, where the game belongs to one.
  /// Null for Feelings and Focus games — those are not a sequence.
  final String? ladderKey;
  final int? ladderStep;

  /// Route within the bundled SPA, e.g. `/play/ten-frame`.
  final String entryPath;

  const LearningGame({
    required this.slug,
    required this.title,
    required this.category,
    required this.ageMin,
    required this.ageMax,
    required this.entryPath,
    this.skillTags = const [],
    this.ladderKey,
    this.ladderStep,
  });

  factory LearningGame.fromMap(Map<String, dynamic> m) => LearningGame(
        slug: m['slug'] as String,
        title: m['title'] as String,
        category: m['category'] as String,
        ageMin: (m['age_min'] as num?)?.toInt() ?? 5,
        ageMax: (m['age_max'] as num?)?.toInt() ?? 6,
        entryPath: m['entry_path'] as String? ?? '/play/${m['slug']}',
        skillTags: ((m['skill_tags'] as List?) ?? const []).map((e) => '$e').toList(),
        ladderKey: m['ladder_key'] as String?,
        ladderStep: (m['ladder_step'] as num?)?.toInt(),
      );

  /// Whether this game suits a child of [age]. Every game is 5–6 today; the
  /// range is a column so adding a band later is a data change.
  bool suitsAge(int age) => age >= ageMin && age <= ageMax;
}

/// The four shelves, in the order they appear.
enum GameShelf { maths, reading, feelings, focus }

extension GameShelfX on GameShelf {
  String get key => name;

  String get label => switch (this) {
        GameShelf.maths => 'Maths',
        GameShelf.reading => 'Reading',
        GameShelf.feelings => 'Feelings',
        GameShelf.focus => 'Focus & mind',
      };

  /// What this shelf is for, in a mother's terms rather than a curriculum's.
  String get blurb => switch (this) {
        GameShelf.maths => 'Numbers that make sense',
        GameShelf.reading => 'Sounds, then words',
        GameShelf.feelings => 'Naming what they feel',
        GameShelf.focus => 'Settling and paying attention',
      };

  String get emoji => switch (this) {
        GameShelf.maths => '🔢',
        GameShelf.reading => '📖',
        GameShelf.feelings => '💛',
        GameShelf.focus => '🌱',
      };
}
