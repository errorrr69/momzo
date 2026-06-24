/// A child profile (PRD §8 `children`). Parent-owned; the child has no account
/// (Hard Rule #14). Drives daily cards, activities, and AI context.
class Child {
  final String id;
  final String name;
  final int age;
  final List<String> temperament;
  final List<String> struggles;
  final String? avatar;

  const Child({
    required this.id,
    required this.name,
    required this.age,
    this.temperament = const [],
    this.struggles = const [],
    this.avatar,
  });

  factory Child.fromMap(Map<String, dynamic> m) => Child(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        age: (m['age'] ?? 0) as int,
        temperament: List<String>.from(m['temperament'] ?? const <String>[]),
        struggles: List<String>.from(m['struggles'] ?? const <String>[]),
        avatar: m['avatar'] as String?,
      );
}
