import '../core/supabase/supabase_init.dart';
import '../models/content_card.dart';
import 'auth_service.dart';

/// Personal library (Task 24): bookmark vetted cards + browse content by topic.
/// Bookmarks live in `saved_cards` (owner-scoped, RLS). Browsing reads the global
/// `content_cards` (published only — Hard Rule #6).
class LibraryService {
  const LibraryService._();

  /// Curated topic groups (display label -> the card tags they cover).
  static const List<({String label, List<String> tags})> topicGroups = [
    (label: 'Big emotions', tags: ['emotional', 'feelings']),
    (label: 'Behaviour', tags: ['behavior', 'self-control', 'discipline']),
    (label: 'Milestones', tags: ['milestones', 'development']),
    (label: 'Screen time', tags: ['screen-time', 'digital']),
    (label: 'Reading', tags: ['reading', 'literacy']),
    (label: 'Temperament', tags: ['temperament']),
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
      return false;
    }
    await supabase.from('saved_cards').insert({'owner_id': uid, 'card_id': cardId});
    return true;
  }

  /// The parent's saved cards, newest first.
  static Future<List<ContentCard>> loadSaved() async {
    if (AuthService.currentUser == null) return [];
    final rows = await supabase
        .from('saved_cards')
        .select('content_cards(id,title,body,tags,why_it_matters,source)')
        .order('created_at', ascending: false);
    return [
      for (final r in rows as List)
        if (r['content_cards'] != null)
          ContentCard.fromMap(r['content_cards'] as Map<String, dynamic>)
    ];
  }

  /// Card counts per topic group (one query, counted client-side).
  static Future<Map<String, int>> topicCounts() async {
    final rows =
        await supabase.from('content_cards').select('tags').eq('published', true);
    final all = [
      for (final r in rows as List) List<String>.from(r['tags'] ?? const <String>[])
    ];
    final counts = <String, int>{};
    for (final g in topicGroups) {
      counts[g.label] = all.where((ct) => ct.any(g.tags.contains)).length;
    }
    return counts;
  }

  /// Published cards in a topic (by overlapping tags), alphabetical.
  static Future<List<ContentCard>> cardsByTags(List<String> tags) async {
    final rows = await supabase
        .from('content_cards')
        .select('id,title,body,tags,why_it_matters,source')
        .eq('published', true)
        .overlaps('tags', tags)
        .order('title');
    return [for (final r in rows as List) ContentCard.fromMap(r as Map<String, dynamic>)];
  }
}
