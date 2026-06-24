import '../core/supabase/supabase_init.dart';

/// Right-to-erasure (Task 10, Hard Rule #17). Invokes the server-side
/// `delete-child` Edge Function, which verifies ownership and erases the child
/// plus ALL associated rows and private media in one transaction.
class DeletionService {
  const DeletionService._();

  static Future<void> deleteChild(String childId) async {
    final res = await supabase.functions.invoke(
      'delete-child',
      body: {'child_id': childId},
    );
    final data = res.data;
    final ok = data is Map && data['ok'] == true;
    if (!ok) {
      throw Exception('Delete failed (status ${res.status}).');
    }
  }
}
