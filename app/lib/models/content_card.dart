/// A vetted content card (PRD §8 `content_cards`) — used by the library/browse
/// views and the generic reader (Task 24). Distinct from `DailyCard`, which pairs
/// a card with a child's daily assignment + read state.
class ContentCard {
  final String id;
  final String title;
  final String body; // markdown
  final List<String> tags;
  final String? whyItMatters;
  final String? source;
  // "Quick read" structured fields (Learn redesign) — may be empty for old cards.
  final String? hook;
  final List<String> quickPoints;
  final String? tryThis;

  const ContentCard({
    required this.id,
    required this.title,
    required this.body,
    this.tags = const [],
    this.whyItMatters,
    this.source,
    this.hook,
    this.quickPoints = const [],
    this.tryThis,
  });

  factory ContentCard.fromMap(Map<String, dynamic> m) => ContentCard(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        tags: List<String>.from(m['tags'] ?? const <String>[]),
        whyItMatters: m['why_it_matters'] as String?,
        source: m['source'] as String?,
        hook: m['hook'] as String?,
        quickPoints: List<String>.from(m['quick_points'] ?? const <String>[]),
        tryThis: m['try_this'] as String?,
      );

  bool get hasQuickRead =>
      (hook?.isNotEmpty ?? false) && quickPoints.length >= 3;

  /// Rough read time at ~200 wpm, clamped to a sensible range.
  int get readMinutes {
    final t = body.trim();
    final words = t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
    return (words / 200).ceil().clamp(1, 30);
  }

  /// A short, human label for the card's primary topic.
  String get topicLabel => tags.isEmpty ? 'Read' : tags.first;
}
