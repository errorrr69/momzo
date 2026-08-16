/// A content card as assigned to a child for a given day (Task 13).
/// Joins `daily_assignments` (the assignment + read state) with `content_cards`.
///
/// The five text fields are the fixed structure from 00_CARD_SPEC §7. They arrive
/// as text and nothing else — no card carries its own layout, so there is nothing
/// here to interpret, only to render in order.
///
/// `concept_basis` is deliberately absent: it is internal QA vocabulary, and the
/// database revokes it from `authenticated`, so it cannot arrive even if asked for.
class DailyCard {
  final String assignmentId;
  final String cardId;
  final String title;
  final String summary;
  final String? whyItMatters;
  final String mainRead;
  final String? activity;
  final String? category;
  final String? source;
  final List<String> tags;
  final List<dynamic>? slides; // raw `slides` jsonb, if the card is a carousel
  final DateTime? readAt;

  const DailyCard({
    required this.assignmentId,
    required this.cardId,
    required this.title,
    this.summary = '',
    this.whyItMatters,
    this.mainRead = '',
    this.activity,
    this.category,
    this.source,
    this.tags = const [],
    this.slides,
    this.readAt,
  });

  bool get isRead => readAt != null;
  bool get hasSlides => slides != null && slides!.isNotEmpty;

  /// Rough read time at ~200 wpm over everything she actually reads.
  int get readMinutes {
    final text = '$summary $mainRead ${activity ?? ''}'.trim();
    final w = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    return (w / 200).ceil().clamp(1, 9);
  }

  static DailyCard _from(Map<String, dynamic> card,
      {required String assignmentId, dynamic readAt}) {
    return DailyCard(
      assignmentId: assignmentId,
      cardId: card['id'] as String,
      title: (card['title'] ?? '') as String,
      summary: (card['summary'] ?? '') as String,
      whyItMatters: card['why_it_matters'] as String?,
      mainRead: (card['main_read'] ?? '') as String,
      activity: card['activity'] as String?,
      category: card['category'] as String?,
      source: card['source'] as String?,
      tags: List<String>.from(card['tags'] ?? const <String>[]),
      slides: card['slides'] as List<dynamic>?,
      readAt: readAt == null ? null : DateTime.tryParse(readAt as String),
    );
  }

  /// From a daily_assignments row with an embedded `content_cards`.
  factory DailyCard.fromAssignment(Map<String, dynamic> a) => _from(
        a['content_cards'] as Map<String, dynamic>,
        assignmentId: a['id'] as String,
        readAt: a['read_at'],
      );

  /// From a freshly-picked card + the assignment we just inserted.
  factory DailyCard.fromCard(Map<String, dynamic> card,
          {required String assignmentId, dynamic readAt}) =>
      _from(card, assignmentId: assignmentId, readAt: readAt);

  DailyCard copyWith({DateTime? readAt}) => DailyCard(
        assignmentId: assignmentId,
        cardId: cardId,
        title: title,
        summary: summary,
        whyItMatters: whyItMatters,
        mainRead: mainRead,
        activity: activity,
        category: category,
        source: source,
        tags: tags,
        slides: slides,
        readAt: readAt ?? this.readAt,
      );
}
