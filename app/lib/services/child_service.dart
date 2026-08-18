import 'package:flutter/foundation.dart';

import '../core/supabase/supabase_init.dart';
import '../models/child.dart';
import 'auth_service.dart';

/// Child profile data access + the app's "current child" context (Task 12 / 23).
///
/// Phase 2 (Task 23): a parent can have multiple children. [children] holds them
/// all; [current] is the active one the rest of the app scopes to (home, daily
/// card, activities, AI). [currentChild] is a notifier so screens (e.g. the tab
/// shell) can rebuild when the parent switches child. Writes go directly to
/// `children` under RLS (owner-only); the DB blocks creation until COPPA consent
/// exists (Task 9 trigger). Selection is in-memory for the session (defaults to
/// the first child on a cold start).
class ChildService {
  const ChildService._();

  static final List<Child> _children = [];
  static Child? _current;

  /// Notifies listeners whenever the active child changes (switch/create/update).
  static final ValueNotifier<Child?> currentChild = ValueNotifier<Child?>(null);

  static List<Child> get children => List.unmodifiable(_children);
  static Child? get current => _current;

  static Child? _byId(String id) {
    for (final c in _children) {
      if (c.id == id) return c;
    }
    return null;
  }

  static void _setCurrent(Child? c) {
    _current = c;
    currentChild.value = c;
  }

  /// Switch the active child (in-memory for the session).
  static void select(Child child) {
    if (_current?.id == child.id) return;
    _setCurrent(_byId(child.id) ?? child);
  }

  static Future<Child> createChild({
    required String name,
    required int age,
    List<String> focusGoals = const [],
    List<String> challenges = const [],
    List<String> interests = const [],
    Map<String, double> temperament = const {},
    String? notes,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) throw StateError('Cannot create a child without a signed-in user.');

    final row = await supabase.from('children').insert({
      'owner_id': user.id,
      'name': name.trim(),
      'age': age,
      'focus_goals': focusGoals,
      'challenges': challenges,
      'interests': interests,
      if (temperament.isNotEmpty) 'temperament': temperament,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    }).select().single();

    final child = Child.fromMap(row);
    _children.add(child);
    _setCurrent(child); // a freshly added child becomes the active one
    return child;
  }

  /// Edit an existing child (e.g. keep goals/challenges current over time). Edits
  /// re-target content + AI from the next request (context is built fresh each call).
  static Future<Child> updateChild({
    required String id,
    String? name,
    int? age,
    List<String>? focusGoals,
    List<String>? challenges,
    List<String>? interests,
    Map<String, double>? temperament,
    String? notes,
    Map<String, dynamic>? attributes,
  }) async {
    final patch = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (age != null) 'age': age,
      if (focusGoals != null) 'focus_goals': focusGoals,
      if (challenges != null) 'challenges': challenges,
      if (interests != null) 'interests': interests,
      if (temperament != null) 'temperament': temperament,
      if (notes != null) 'notes': notes.trim(),
      if (attributes != null) 'attributes': attributes,
    };
    final row = await supabase
        .from('children')
        .update(patch)
        .eq('id', id)
        .select()
        .single();

    final updated = Child.fromMap(row);
    final i = _children.indexWhere((c) => c.id == id);
    if (i >= 0) _children[i] = updated;
    if (_current?.id == id) _setCurrent(updated);
    return updated;
  }

  /// Load ALL of the parent's children; keep/choose an active one.
  static Future<List<Child>> loadChildren() async {
    final user = AuthService.currentUser;
    if (user == null) return const [];
    final rows = await supabase
        .from('children')
        .select()
        .eq('owner_id', user.id)
        // Oldest first, so the list keeps the order she added them in.
        .order('created_at', ascending: true);
    _children
      ..clear()
      ..addAll((rows as List).map((r) => Child.fromMap(r as Map<String, dynamic>)));

    // Keep the current selection if it still exists; else default to the first.
    final keep = _current == null ? null : _byId(_current!.id);
    _setCurrent(keep ?? (_children.isEmpty ? null : _children.first));
    return children;
  }

  /// Back-compat for callers that just want the active child (home, consent gate).
  static Future<Child?> loadMyChild() async {
    await loadChildren();
    return _current;
  }

  static void clear() {
    _children.clear();
    _setCurrent(null);
  }
}
