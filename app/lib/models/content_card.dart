/// A vetted content card (`content_cards`) — used by the library/browse views and
/// the generic reader (Task 24). Distinct from `DailyCard`, which pairs a card with
/// a child's daily assignment + read state.
///
/// Carries the fixed structure from 00_CARD_SPEC §7: title, summary,
/// why_it_matters, main_read, activity. Text only — the app owns the layout.
///
/// `concept_basis` is deliberately absent; it is internal (§6) and revoked from
/// `authenticated` at the database.
class ContentCard {
  final String id;
  final String title;
  final String summary;
  final String? whyItMatters;
  final String mainRead;
  final String? activity;
  final String? category;
  final String? subtopic;
  final List<String> tags;
  final String? source;

  const ContentCard({
    required this.id,
    required this.title,
    this.summary = '',
    this.whyItMatters,
    this.mainRead = '',
    this.activity,
    this.category,
    this.subtopic,
    this.tags = const [],
    this.source,
  });

  factory ContentCard.fromMap(Map<String, dynamic> m) => ContentCard(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        summary: (m['summary'] ?? '') as String,
        whyItMatters: m['why_it_matters'] as String?,
        mainRead: (m['main_read'] ?? '') as String,
        activity: m['activity'] as String?,
        category: m['category'] as String?,
        subtopic: m['subtopic'] as String?,
        tags: List<String>.from(m['tags'] ?? const <String>[]),
        source: m['source'] as String?,
      );

  /// Rough read time at ~200 wpm over everything she actually reads.
  int get readMinutes {
    final text = '$summary $mainRead ${activity ?? ''}'.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    return (words / 200).ceil().clamp(1, 9);
  }

  /// A short, human label for the card's primary topic. Prefers the shelf name
  /// (a closed set of seven) over the first tag, which is finer-grained and reads
  /// oddly on its own.
  String get topicLabel {
    const shelves = {
      'big-feelings': 'Big feelings',
      'focus-attention': 'Focus & attention',
      'confidence-independence': 'Confidence',
      'connection-bonding': 'Connection',
      'learning-curiosity': 'Learning',
      'getting-along': 'Getting along',
      'everyday-routines': 'Everyday routines',
    };
    final byShelf = shelves[category];
    if (byShelf != null) return byShelf;
    if (tags.isEmpty) return 'Read';
    return tags.first.replaceAll('-', ' ');
  }
}
