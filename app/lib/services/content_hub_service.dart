import 'package:flutter/foundation.dart';

import '../core/supabase/supabase_init.dart';
import '../models/social_post.dart';
import 'auth_service.dart';

/// Content Hub (Expansion Plan §1) — Florie's posts, in the app.
///
/// Reads `social_posts` (shared content: every signed-in parent reads it, none of
/// them can write it) and `post_reactions` (hers alone). No writes to posts exist
/// anywhere in the app, deliberately: publishing is a seeder run by Florie.
class ContentHubService {
  const ContentHubService._();

  /// Bumps when a 💛 is toggled, so a visible feed can refresh. The Learn tab is
  /// kept alive in the shell's IndexedStack, so it will not rebuild on its own —
  /// same idiom as LibraryService.savedRevision.
  static final ValueNotifier<int> heartRevision = ValueNotifier<int>(0);

  /// Spelled out rather than `*`, matching the rest of the app. Here it is a habit
  /// rather than a hard requirement, but `select=*` on content_cards now fails
  /// outright (concept_basis is revoked), and one convention is easier to keep
  /// than two.
  static const _columns =
      'id, slug, title, body, post_type, tags, media, source_url, published_at';

  /// The feed, newest first. [tag] filters to one chip.
  ///
  /// The RLS policy is `using (published)`, so an unpublished draft is absent
  /// whether or not this query remembers to ask — the filter here would be the
  /// second lock, not the first.
  static Future<List<SocialPost>> feed({String? tag, int limit = 50}) async {
    var q = supabase.from('social_posts').select(_columns);
    if (tag != null && tag.isNotEmpty) q = q.contains('tags', [tag]);

    final rows = List<Map<String, dynamic>>.from(
      await q.order('published_at', ascending: false).limit(limit) as List,
    );

    final hearts = await heartedIds();
    return rows
        .map((r) => SocialPost.fromRow(r, hearted: hearts.contains(r['id'])))
        .toList();
  }

  /// The post ids this parent has hearted. One query for the whole feed rather
  /// than one per card.
  static Future<Set<String>> heartedIds() async {
    if (AuthService.currentUser == null) return {};
    try {
      final rows = await supabase.from('post_reactions').select('post_id');
      return {for (final r in rows as List) r['post_id'] as String};
    } catch (_) {
      // A heart is decoration on a readable feed. Losing it must not lose the feed.
      return {};
    }
  }

  /// Every tag in use, in the order the chips should appear (most-used first).
  ///
  /// Computed from the posts rather than from the 29-tag vocabulary, so the filter
  /// row never offers a chip that would return nothing.
  static Future<List<String>> tagsInUse() async {
    final rows = await supabase.from('social_posts').select('tags');
    final counts = <String, int>{};
    for (final r in rows as List) {
      for (final t in List<String>.from(r['tags'] ?? const <String>[])) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return sorted;
  }

  /// Toggle her 💛. Returns the new state.
  ///
  /// Double-tapping cannot double-count: `post_reactions_once` is a unique
  /// constraint, so a duplicate insert is refused by the database rather than
  /// prevented by whatever the UI happened to do.
  static Future<bool> toggleHeart(SocialPost post) async {
    final user = AuthService.currentUser;
    if (user == null) return post.hearted;

    if (post.hearted) {
      await supabase
          .from('post_reactions')
          .delete()
          .eq('post_id', post.id)
          .eq('user_id', user.id);
      heartRevision.value++;
      return false;
    }

    try {
      await supabase
          .from('post_reactions')
          .insert({'post_id': post.id, 'user_id': user.id});
    } catch (e) {
      // 23505 means it was already hearted — the desired end state either way, so
      // this is success, not an error to show her.
      if (!e.toString().contains('23505')) rethrow;
    }
    heartRevision.value++;
    return true;
  }
}
