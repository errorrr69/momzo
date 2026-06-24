/// A content card as assigned to a child for a given day (Task 13).
/// Joins `daily_assignments` (the assignment + read state) with `content_cards`.
class DailyCard {
  final String assignmentId;
  final String cardId;
  final String title;
  final String body;
  final String? whyItMatters; // the behaviour-at-home tie-in (may be null until backfilled)
  final String? source;
  final List<String> tags;
  final List<dynamic>? slides; // raw `slides` jsonb, if the card is a carousel
  final DateTime? readAt;

  const DailyCard({
    required this.assignmentId,
    required this.cardId,
    required this.title,
    required this.body,
    this.whyItMatters,
    this.source,
    this.tags = const [],
    this.slides,
    this.readAt,
  });

  bool get isRead => readAt != null;
  bool get hasSlides => slides != null && slides!.isNotEmpty;

  static DailyCard _from(Map<String, dynamic> card, {required String assignmentId, dynamic readAt}) {
    return DailyCard(
      assignmentId: assignmentId,
      cardId: card['id'] as String,
      title: (card['title'] ?? '') as String,
      body: (card['body'] ?? '') as String,
      whyItMatters: card['why_it_matters'] as String?,
      source: card['source'] as String?,
      tags: List<String>.from(card['tags'] ?? const <String>[]),
      slides: card['slides'] as List<dynamic>?,
      readAt: readAt == null ? null : DateTime.tryParse(readAt as String),
    );
  }

  /// From a daily_assignments row with an embedded `content_cards`.
  factory DailyCard.fromAssignment(Map<String, dynamic> a) =>
      _from(a['content_cards'] as Map<String, dynamic>, assignmentId: a['id'] as String, readAt: a['read_at']);

  /// From a freshly-picked card + the assignment we just inserted.
  factory DailyCard.fromCard(Map<String, dynamic> card, {required String assignmentId, dynamic readAt}) =>
      _from(card, assignmentId: assignmentId, readAt: readAt);

  DailyCard copyWith({DateTime? readAt}) => DailyCard(
        assignmentId: assignmentId,
        cardId: cardId,
        title: title,
        body: body,
        whyItMatters: whyItMatters,
        source: source,
        tags: tags,
        slides: slides,
        readAt: readAt ?? this.readAt,
      );
}
