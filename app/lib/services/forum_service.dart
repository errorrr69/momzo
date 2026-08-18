import 'package:flutter/foundation.dart';

import '../core/supabase/supabase_init.dart';
import '../models/forum.dart';
import 'auth_service.dart';

/// The Circle (Expansion Plan §2).
///
/// This is the app's first shared-AUTHORED surface: mothers write rows other
/// mothers read. Everything protective lives in the database — the author-only
/// write policies, the moderator `security definer` check, the column guard that
/// stops an author clearing her own `hidden` flag, and the three-report auto-hide.
/// Nothing here is the security boundary; this is only the client that uses it.
class ForumService {
  const ForumService._();

  /// Bumps on any write, so open lists refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const _threadColumns =
      'id, category_id, author_id, title, body, created_at, last_activity_at, '
      'reply_count, reaction_count, hidden, hidden_reason, pinned, '
      'forum_profiles!forum_threads_author_profile_fkey(user_id, display_name, avatar_emoji)';

  static const _replyColumns =
      'id, thread_id, author_id, body, created_at, reaction_count, hidden, '
      'forum_profiles!forum_replies_author_profile_fkey(user_id, display_name, avatar_emoji)';

  // ---- identity ----

  /// Her Circle identity, or null if she has not chosen one yet.
  ///
  /// Null is a real state the UI must handle: §2.4 says the forum name is a
  /// choice, so posting is gated on making it rather than defaulting to the name
  /// on her account.
  static Future<ForumIdentity?> myIdentity() async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final row = await supabase
        .from('forum_profiles')
        .select('user_id, display_name, avatar_emoji')
        .eq('user_id', user.id)
        .maybeSingle();
    return row == null ? null : ForumIdentity.fromRow(row);
  }

  static Future<ForumIdentity> setIdentity({
    required String displayName,
    required String avatarEmoji,
  }) async {
    final user = AuthService.currentUser!;
    final row = await supabase
        .from('forum_profiles')
        .upsert({
          'user_id': user.id,
          'display_name': displayName.trim(),
          'avatar_emoji': avatarEmoji,
        }, onConflict: 'user_id')
        .select('user_id, display_name, avatar_emoji')
        .single();
    revision.value++;
    return ForumIdentity.fromRow(row);
  }

  /// Whether this account can see the report queue. Reads `moderators`, which
  /// only ever returns her own row.
  static Future<bool> amModerator() async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    try {
      final row = await supabase
          .from('moderators')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  // ---- reading ----

  /// The ids of one kind she has hearted. One query per list rather than one per
  /// row, and it degrades to "none hearted" rather than failing the whole screen.
  static Future<Set<String>> _heartedIds(String targetType) async {
    if (AuthService.currentUser == null) return {};
    try {
      final rows = await supabase
          .from('forum_reactions')
          .select('target_id')
          .eq('target_type', targetType) as List;
      return {for (final r in rows) r['target_id'] as String};
    } catch (_) {
      return {};
    }
  }

  static Future<List<ForumCategory>> categories() async {
    final rows = await supabase
        .from('forum_categories')
        .select('id, slug, title, blurb, sort')
        .eq('active', true)
        .order('sort') as List;
    return rows.map((r) => ForumCategory.fromRow(r as Map<String, dynamic>)).toList();
  }

  /// Threads, newest activity first. Pinned rise to the top — that is how the
  /// resources post stays reachable (§2.4).
  static Future<List<ForumThread>> threads({String? categoryId, int limit = 40}) async {
    var q = supabase.from('forum_threads').select(_threadColumns);
    if (categoryId != null) q = q.eq('category_id', categoryId);

    final rows = List<Map<String, dynamic>>.from(
      await q.order('pinned', ascending: false)
          .order('last_activity_at', ascending: false)
          .limit(limit) as List,
    );

    final hearts = await _heartedIds('thread');
    return rows
        .map((r) => ForumThread.fromRow(r, hearted: hearts.contains(r['id'])))
        .toList();
  }

  static Future<ForumThread?> thread(String id) async {
    final row = await supabase
        .from('forum_threads').select(_threadColumns).eq('id', id).maybeSingle();
    if (row == null) return null;
    final hearts = await _heartedIds('thread');
    return ForumThread.fromRow(row, hearted: hearts.contains(id));
  }

  static Future<List<ForumReply>> replies(String threadId) async {
    final rows = List<Map<String, dynamic>>.from(
      await supabase
          .from('forum_replies')
          .select(_replyColumns)
          .eq('thread_id', threadId)
          .order('created_at') as List,
    );
    final hearts = await _heartedIds('reply');
    return rows
        .map((r) => ForumReply.fromRow(r, hearted: hearts.contains(r['id'])))
        .toList();
  }

  // ---- writing ----

  static Future<ForumThread> post({
    required String categoryId,
    required String title,
    required String body,
  }) async {
    final user = AuthService.currentUser!;
    final row = await supabase
        .from('forum_threads')
        .insert({
          'category_id': categoryId,
          'author_id': user.id,
          'title': title.trim(),
          'body': body.trim(),
        })
        .select(_threadColumns)
        .single();
    revision.value++;
    return ForumThread.fromRow(row);
  }

  static Future<ForumReply> reply({required String threadId, required String body}) async {
    final user = AuthService.currentUser!;
    final row = await supabase
        .from('forum_replies')
        .insert({'thread_id': threadId, 'author_id': user.id, 'body': body.trim()})
        .select(_replyColumns)
        .single();
    revision.value++;
    return ForumReply.fromRow(row);
  }

  /// Toggle her 💛. The unique constraint makes a double tap harmless; the public
  /// count is maintained by trigger, so it is never computed here.
  static Future<bool> toggleHeart({
    required String targetType,
    required String targetId,
    required bool currentlyHearted,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return currentlyHearted;

    if (currentlyHearted) {
      await supabase
          .from('forum_reactions')
          .delete()
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .eq('user_id', user.id);
      revision.value++;
      return false;
    }
    try {
      await supabase.from('forum_reactions').insert({
        'target_type': targetType, 'target_id': targetId, 'user_id': user.id,
      });
    } catch (e) {
      if (!e.toString().contains('23505')) rethrow;
    }
    revision.value++;
    return true;
  }

  /// File a report. Three open ones auto-hide the target, server-side.
  ///
  /// A second report from the same person on the same thing is refused by the
  /// unique constraint — reported once is reported, and stacking them would let
  /// one person reach the auto-hide threshold alone.
  static Future<void> report({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String? note,
  }) async {
    final user = AuthService.currentUser!;
    try {
      await supabase.from('forum_reports').insert({
        'target_type': targetType,
        'target_id': targetId,
        'reporter_id': user.id,
        'reason': reason.key,
        'note': note?.trim(),
      });
    } catch (e) {
      if (!e.toString().contains('23505')) rethrow;
    }
    revision.value++;
  }

  static Future<void> deleteThread(String id) async {
    await supabase.from('forum_threads').delete().eq('id', id);
    revision.value++;
  }

  static Future<void> deleteReply(String id) async {
    await supabase.from('forum_replies').delete().eq('id', id);
    revision.value++;
  }

  // ---- moderation ----

  /// The open queue, urgent first. Only a moderator gets rows back; for anyone
  /// else the policy returns their own reports and nothing else.
  static Future<List<ForumReport>> openReports() async {
    final rows = List<Map<String, dynamic>>.from(
      await supabase
          .from('forum_reports')
          .select('id, target_type, target_id, reason, note, created_at, resolved')
          .eq('resolved', false)
          .order('created_at', ascending: false) as List,
    );

    final reports = <ForumReport>[];
    for (final r in rows) {
      // Resolve the reported words so the queue is decidable at a glance.
      String? excerpt;
      bool hidden = false;
      try {
        final target = r['target_type'] == 'thread'
            ? await supabase
                .from('forum_threads')
                .select('title, body, hidden')
                .eq('id', r['target_id'])
                .maybeSingle()
            : await supabase
                .from('forum_replies')
                .select('body, hidden')
                .eq('id', r['target_id'])
                .maybeSingle();
        if (target != null) {
          excerpt = [target['title'], target['body']].whereType<String>().join(' — ');
          hidden = (target['hidden'] ?? false) as bool;
        }
      } catch (_) {
        // A report whose target was deleted still belongs in the queue, so it can
        // be resolved rather than sitting there forever.
      }
      reports.add(ForumReport(
        id: r['id'] as String,
        targetType: r['target_type'] as String,
        targetId: r['target_id'] as String,
        reason: r['reason'] as String,
        note: r['note'] as String?,
        createdAt: DateTime.tryParse((r['created_at'] ?? '') as String) ?? DateTime(2000),
        excerpt: excerpt,
        targetHidden: hidden,
      ));
    }

    // "Someone may need help" goes first, whatever the clock says (§2.4).
    reports.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return reports;
  }

  static Future<void> setHidden({
    required String targetType,
    required String targetId,
    required bool hidden,
    String? reason,
  }) async {
    final table = targetType == 'thread' ? 'forum_threads' : 'forum_replies';
    final patch = <String, dynamic>{'hidden': hidden};
    if (targetType == 'thread') patch['hidden_reason'] = hidden ? reason : null;
    await supabase.from(table).update(patch).eq('id', targetId);
    revision.value++;
  }

  static Future<void> resolveReport(String id, String resolution) async {
    await supabase
        .from('forum_reports')
        .update({'resolved': true, 'resolution': resolution})
        .eq('id', id);
    revision.value++;
  }
}
