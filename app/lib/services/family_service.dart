import '../core/supabase/supabase_init.dart';
import '../models/child.dart';
import 'auth_service.dart';
import 'child_service.dart';

/// A person who shares a child (owner or accepted co-parent) — Task 33.
class FamilyMember {
  final String id;
  final String userId;
  final String displayName;
  final String relationship; // parent | coparent | grandparent
  final String status; // invited | active
  const FamilyMember({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.relationship,
    required this.status,
  });
}

/// Co-parent / caregiver sharing (Task 33).
///
/// The owner mints a one-time invite CODE for a child and shares it out-of-band
/// (text / WhatsApp). The co-parent redeems it via the `accept_family_invite`
/// security-definer RPC, which creates their active membership. From then on RLS
/// (accessible_child_ids) lets them see + participate in that child. Owner-only
/// rights (edit / delete the child, revoke members) are enforced in the database.
class FamilyService {
  const FamilyService._();

  /// Owner mints a shareable invite code for [childId]. Returns the code.
  static Future<String> createInvite(String childId) async {
    final row = await supabase
        .from('family_invites')
        .insert({'child_id': childId})
        .select('code')
        .single();
    return row['code'] as String;
  }

  /// Redeem an invite [code]; on success the shared child is loaded and returned.
  /// Throws with a friendly message on an invalid / expired code.
  static Future<Child?> acceptInvite(String code) async {
    try {
      final childId = await supabase
          .rpc('accept_family_invite', params: {'invite_code': code.trim()});
      await ChildService.loadChildren();
      final id = childId as String?;
      if (id == null) return ChildService.current;
      for (final c in ChildService.children) {
        if (c.id == id) {
          ChildService.select(c);
          return c;
        }
      }
      return ChildService.current;
    } catch (_) {
      throw Exception("That invite code didn't work — it may be expired or already used.");
    }
  }

  /// Everyone who shares [childId] — the owner plus accepted co-parents.
  static Future<List<FamilyMember>> members(String childId) async {
    final rows = await supabase
        .from('family_members')
        .select('id,user_id,relationship,status,users(display_name)')
        .eq('child_id', childId)
        .order('created_at') as List;
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final u = m['users'];
      return FamilyMember(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        displayName: (u is Map ? u['display_name'] as String? : null) ?? 'Co-parent',
        relationship: (m['relationship'] ?? 'coparent') as String,
        status: (m['status'] ?? 'active') as String,
      );
    }).toList();
  }

  /// Owner revokes a co-parent's access (or a member removes themselves).
  static Future<void> removeMember(String membershipId) async {
    await supabase.from('family_members').delete().eq('id', membershipId);
  }

  /// Does the signed-in user own [child] (may invite / revoke / edit / delete)?
  static bool isOwner(Child child) => child.isOwnedBy(AuthService.currentUser?.id);
}
