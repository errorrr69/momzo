/// A child profile (Onboarding & Personalization Spec §4). Parent-owned; the child
/// has no account (Hard Rule #14). Drives daily cards, activities, games, and the
/// name-free AI personalization context. The NAME is used in the UI only — never
/// sent to the LLM (§5).
class Child {
  final String id;
  final String name;
  final int age;

  /// Q3 — what she'd love to help with (primary content/activity targeting).
  final List<String> focusGoals;

  /// Q4 — what's a bit tricky (everyday tags, never a clinical label).
  final List<String> challenges;

  /// Q5 — what the child loves (personalizes examples/activities/games).
  final List<String> interests;

  /// Q6 — temperament sliders 0..1: warmup, energy, expressive, social.
  final Map<String, double> temperament;

  /// "something else…" free text (safety-screened).
  final String? notes;

  /// Part B optional depth (extensible) — never churns the schema.
  final Map<String, dynamic> attributes;

  final String? avatar;

  const Child({
    required this.id,
    required this.name,
    required this.age,
    this.focusGoals = const [],
    this.challenges = const [],
    this.interests = const [],
    this.temperament = const {},
    this.notes,
    this.attributes = const {},
    this.avatar,
  });

  static List<String> _strList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const <String>[];

  static Map<String, double> _sliders(dynamic v) {
    if (v is Map) {
      return {
        for (final e in v.entries)
          if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
      };
    }
    return const {};
  }

  factory Child.fromMap(Map<String, dynamic> m) => Child(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        age: (m['age'] ?? 0) as int,
        focusGoals: _strList(m['focus_goals']),
        challenges: _strList(m['challenges']),
        interests: _strList(m['interests']),
        temperament: _sliders(m['temperament']),
        notes: m['notes'] as String?,
        attributes: m['attributes'] is Map ? Map<String, dynamic>.from(m['attributes'] as Map) : const {},
        avatar: m['avatar'] as String?,
      );

  /// Band for the bonding games (A 4–5 / B 6–7 / C 8–10).
  String get band => age <= 5 ? 'A' : (age <= 7 ? 'B' : 'C');
}
