/// An activity from the vetted library (PRD §8 `activities`). Global content,
/// filtered by the time a mom has + the child's age (Task 18).
class Activity {
  final String id;
  final String title;
  final List<String> steps;
  final String? skill;
  final int? ageMin;
  final int? ageMax;
  final int? durationMin;
  final List<String> location;
  final List<String> materials;

  const Activity({
    required this.id,
    required this.title,
    this.steps = const [],
    this.skill,
    this.ageMin,
    this.ageMax,
    this.durationMin,
    this.location = const [],
    this.materials = const [],
  });

  factory Activity.fromMap(Map<String, dynamic> m) => Activity(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        steps: List<String>.from((m['steps'] ?? const []) as List),
        skill: m['skill'] as String?,
        ageMin: m['age_min'] as int?,
        ageMax: m['age_max'] as int?,
        durationMin: m['duration_min'] as int?,
        location: List<String>.from((m['location'] ?? const []) as List),
        materials: List<String>.from((m['materials'] ?? const []) as List),
      );

  String get materialsLabel => materials.isEmpty ? 'No materials' : materials.take(2).join(', ');
}
