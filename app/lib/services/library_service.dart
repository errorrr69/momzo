import 'package:flutter/foundation.dart';

import '../core/supabase/supabase_init.dart';
import '../models/content_card.dart';
import 'auth_service.dart';

/// Personal library (Task 24): bookmark vetted cards + browse content by topic.
/// Bookmarks live in `saved_cards` (owner-scoped, RLS). Browsing reads the global
/// `content_cards` (published only — Hard Rule #6).
class LibraryService {
  const LibraryService._();

  /// Bumps whenever a bookmark is toggled, so any visible library view can refresh
  /// (the Learn tab is kept alive in the shell, so it won't rebuild on its own).
  static final ValueNotifier<int> savedRevision = ValueNotifier<int>(0);

  /// The columns the app may read. Spelled out because `concept_basis` is internal
  /// (00_CARD_SPEC §6) and revoked from `authenticated` — `*` now fails rather than
  /// leaking it.
  static const _cardColumns =
      'id, title, summary, why_it_matters, main_read, activity, '
      'category, subtopic, tags, source';

  /// The seven shelves (00_CARD_SPEC §3) — one browse group per category.
  ///
  /// These used to be hand-curated tag bundles over the old corpus, which meant the
  /// browse structure and the content structure could drift apart silently. Now a
  /// group IS a category, so the library cannot show a shelf the cards don't have.
  static const List<({String label, String category, String emoji, String intro})>
      topicGroups = [
    (label: 'Big feelings', category: 'big-feelings', emoji: '😣', intro: 'riding the big ones'),
    (label: 'Focus & attention', category: 'focus-attention', emoji: '🎯', intro: 'listening and settling'),
    (label: 'Confidence', category: 'confidence-independence', emoji: '🌱', intro: 'trying hard things'),
    (label: 'Connection', category: 'connection-bonding', emoji: '💛', intro: 'closeness and repair'),
    (label: 'Learning', category: 'learning-curiosity', emoji: '📚', intro: 'curiosity and early skills'),
    (label: 'Getting along', category: 'getting-along', emoji: '🤝', intro: 'sharing and friendships'),
    (label: 'Everyday routines', category: 'everyday-routines', emoji: '🌙', intro: 'sleep, mornings, meals'),
  ];

  /// The set of card ids the parent has saved (for bookmark state).
  static Future<Set<String>> savedCardIds() async {
    if (AuthService.currentUser == null) return {};
    final rows = await supabase.from('saved_cards').select('card_id');
    return {for (final r in rows as List) r['card_id'] as String};
  }

  /// Toggle a bookmark; returns the new saved state (true = now saved).
  static Future<bool> toggleSaved(String cardId) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return false;
    final existing = await supabase
        .from('saved_cards')
        .select('id')
        .eq('card_id', cardId)
        .maybeSingle();
    if (existing != null) {
      await supabase.from('saved_cards').delete().eq('card_id', cardId);
      savedRevision.value++;
      return false;
    }
    await supabase.from('saved_cards').insert({'owner_id': uid, 'card_id': cardId});
    savedRevision.value++;
    return true;
  }

  /// The parent's saved cards, newest first.
  static Future<List<ContentCard>> loadSaved() async {
    if (AuthService.currentUser == null) return [];
    final rows = await supabase
        .from('saved_cards')
        .select('content_cards($_cardColumns)')
        .order('created_at', ascending: false);
    return [
      for (final r in rows as List)
        if (r['content_cards'] != null)
          ContentCard.fromMap(r['content_cards'] as Map<String, dynamic>)
    ];
  }

  /// Card counts per shelf (one query, counted client-side).
  static Future<Map<String, int>> topicCounts() async {
    final rows =
        await supabase.from('content_cards').select('category').eq('published', true);
    final counts = <String, int>{for (final g in topicGroups) g.label: 0};
    for (final r in rows as List) {
      final cat = r['category'] as String?;
      for (final g in topicGroups) {
        if (g.category == cat) counts[g.label] = (counts[g.label] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Published cards on one shelf, alphabetical.
  static Future<List<ContentCard>> cardsByCategory(String category) async {
    final rows = await supabase
        .from('content_cards')
        .select(_cardColumns)
        .eq('published', true)
        .eq('category', category)
        .order('title', ascending: true);
    return [for (final r in rows as List) ContentCard.fromMap(r as Map<String, dynamic>)];
  }
}
