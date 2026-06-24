import '../core/supabase/supabase_init.dart';
import '../models/child.dart';
import '../models/daily_card.dart';
import 'auth_service.dart';

/// Daily card assignment + retrieval (Task 13).
///
/// One card per child per day, recorded in `daily_assignments`. Selection targets
/// the child's age (age_min..age_max) and, when possible, their struggles (mapped
/// to card tags), avoiding cards already shown. All content comes from vetted
/// `content_cards` (Hard Rule #6).
class DailyService {
  const DailyService._();

  // Onboarding struggle labels -> content_card tags used by the seeded corpus.
  static const Map<String, List<String>> _struggleTags = {
    'Big emotions': ['emotional', 'feelings', 'self-control', 'behavior'],
    'Screen time': ['screen-time', 'digital'],
    'Focus': ['focus', 'development', 'milestones'],
    'Confidence': ['confidence', 'self-esteem', 'emotional'],
    "Won't share": ['behavior', 'self-control', 'family'],
    'Bedtime': ['bedtime', 'behavior'],
  };

  static List<String> _tagsFor(List<String> struggles) {
    final out = <String>{};
    for (final s in struggles) {
      out.addAll(_struggleTags[s] ?? const []);
    }
    return out.toList();
  }

  static String _today() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  /// Today's card for [child] — returns the existing assignment if there is one,
  /// otherwise picks + records a new one. Null if nothing suitable exists.
  static Future<DailyCard?> todaysCard(Child child) async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final today = _today();

    final existing = await supabase
        .from('daily_assignments')
        .select('id, read_at, content_cards(*)')
        .eq('child_id', child.id)
        .eq('date', today)
        .maybeSingle();
    if (existing != null && existing['content_cards'] != null) {
      return DailyCard.fromAssignment(existing);
    }

    final assignedRows = await supabase
        .from('daily_assignments')
        .select('card_id')
        .eq('child_id', child.id);
    final assigned = (assignedRows as List).map((r) => r['card_id'] as String).toList();

    // Prefer struggle-matched & unseen; then any unseen; then allow a repeat.
    var card = await _pick(child, _tagsFor(child.struggles), assigned);
    card ??= await _pick(child, null, assigned);
    card ??= await _pick(child, null, const []);
    if (card == null) return null;

    final ins = await supabase.from('daily_assignments').insert({
      'owner_id': user.id,
      'child_id': child.id,
      'card_id': card['id'],
      'date': today,
    }).select('id, read_at').single();

    return DailyCard.fromCard(card, assignmentId: ins['id'] as String, readAt: ins['read_at']);
  }

  static Future<Map<String, dynamic>?> _pick(
      Child child, List<String>? tags, List<String> exclude) async {
    var q = supabase
        .from('content_cards')
        .select('*')
        .eq('published', true)
        .lte('age_min', child.age)
        .gte('age_max', child.age);
    if (tags != null && tags.isNotEmpty) q = q.overlaps('tags', tags);
    if (exclude.isNotEmpty) q = q.not('id', 'in', '(${exclude.join(',')})');

    final rows = await q.limit(12) as List;
    if (rows.isEmpty) return null;
    // Stable within a day, varies across days.
    return rows[DateTime.now().day % rows.length] as Map<String, dynamic>;
  }

  static Future<void> markRead(String assignmentId) async {
    await supabase
        .from('daily_assignments')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', assignmentId);
  }
}
