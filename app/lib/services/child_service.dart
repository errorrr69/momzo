import '../core/supabase/supabase_init.dart';
import '../models/child.dart';
import 'auth_service.dart';

/// Child profile data access + the app's "current child" context (Task 12).
///
/// Phase 1 is single-child: [current] holds the active child for the rest of the
/// app (home, daily card, activities, AI context). Multiple children + a switcher
/// is Phase 2 (Task 23). Writes go directly to `children` under RLS (owner-only),
/// and the DB blocks creation until COPPA consent exists (Task 9 trigger).
class ChildService {
  const ChildService._();

  static Child? _current;
  static Child? get current => _current;

  static Future<Child> createChild({
    required String name,
    required int age,
    required List<String> temperament,
    required List<String> struggles,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) throw StateError('Cannot create a child without a signed-in user.');

    final row = await supabase.from('children').insert({
      'owner_id': user.id,
      'name': name.trim(),
      'age': age,
      'temperament': temperament,
      'struggles': struggles,
    }).select().single();

    _current = Child.fromMap(row);
    return _current!;
  }

  /// Load the parent's child into context (Phase 1: the first/only one).
  static Future<Child?> loadMyChild() async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final rows = await supabase
        .from('children')
        .select()
        .eq('owner_id', user.id)
        .order('created_at')
        .limit(1);
    _current = (rows as List).isEmpty ? null : Child.fromMap(rows.first);
    return _current;
  }

  static void clear() => _current = null;
}
