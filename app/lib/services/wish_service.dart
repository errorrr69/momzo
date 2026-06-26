import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';
import 'child_service.dart';

class Wish {
  final String id;
  final String text;
  final String createdBy; // 'child' | 'parent'
  final String status; // 'open' | 'scheduled' | 'done'
  const Wish({required this.id, required this.text, required this.createdBy, required this.status});

  factory Wish.fromMap(Map<String, dynamic> m) => Wish(
        id: m['id'] as String,
        text: (m['text'] ?? '') as String,
        createdBy: (m['created_by'] ?? 'child') as String,
        status: (m['status'] ?? 'open') as String,
      );
}

/// Kid Wish Wall (Task 26). Wishes are family-scoped (owner_id = parent, child_id
/// = the active child) under the PARENT's session — the child has no account
/// (Hard Rule #14). Kid mode (the wall UI) only ever writes wishes here.
class WishService {
  const WishService._();

  static Future<List<Wish>> load() async {
    final child = ChildService.current;
    if (child == null) return [];
    final rows = await supabase
        .from('wishes')
        .select('id,text,created_by,status')
        .eq('child_id', child.id)
        .order('created_at', ascending: false) as List;
    return [for (final r in rows) Wish.fromMap(r as Map<String, dynamic>)];
  }

  static Future<Wish> add(String text, {String createdBy = 'child'}) async {
    final user = AuthService.currentUser;
    final child = ChildService.current;
    if (user == null || child == null) throw StateError('Sign in and select a child first.');
    final row = await supabase.from('wishes').insert({
      'owner_id': user.id,
      'child_id': child.id,
      'text': text.trim(),
      'created_by': createdBy,
    }).select().single();
    return Wish.fromMap(row);
  }

  static Future<void> setStatus(String id, String status) async {
    await supabase.from('wishes').update({'status': status}).eq('id', id);
  }
}
