/// The Circle — Momzo's forum (Expansion Plan §2).
///
/// One file for all four shapes because they are only ever used together, and
/// splitting them would mean four imports at every call site for no gain.
library;

class ForumCategory {
  final String id;
  final String slug;
  final String title;
  final String? blurb;
  final int sort;

  const ForumCategory({
    required this.id,
    required this.slug,
    required this.title,
    this.blurb,
    this.sort = 0,
  });

  factory ForumCategory.fromRow(Map<String, dynamic> r) => ForumCategory(
        id: r['id'] as String,
        slug: (r['slug'] ?? '') as String,
        title: (r['title'] ?? '') as String,
        blurb: r['blurb'] as String?,
        sort: (r['sort'] as num?)?.toInt() ?? 0,
      );
}

/// Who the Circle knows her as.
///
/// Deliberately not her account name (§2.4). There is no fallback to
/// `users.display_name` anywhere — a mother without a forum profile shows as
/// [anonymous], and the app asks her to choose a name before she can post.
class ForumIdentity {
  final String userId;
  final String displayName;
  final String avatarEmoji;

  const ForumIdentity({
    required this.userId,
    required this.displayName,
    this.avatarEmoji = '💛',
  });

  static const anonymous = ForumIdentity(
    userId: '', displayName: 'A mother in the Circle', avatarEmoji: '💛',
  );

  factory ForumIdentity.fromRow(Map<String, dynamic> r) => ForumIdentity(
        userId: r['user_id'] as String,
        displayName: (r['display_name'] ?? '') as String,
        avatarEmoji: (r['avatar_emoji'] ?? '💛') as String,
      );
}

class ForumThread {
  final String id;
  final String categoryId;
  final String authorId;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final int replyCount;
  final int reactionCount;
  final bool hidden;
  final String? hiddenReason;
  final bool pinned;

  /// Filled from forum_profiles; never from the account name.
  final ForumIdentity author;

  /// Whether this parent has hearted it. Hers alone — the public number is
  /// [reactionCount], maintained server-side.
  final bool hearted;

  const ForumThread({
    required this.id,
    required this.categoryId,
    required this.authorId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.lastActivityAt,
    this.replyCount = 0,
    this.reactionCount = 0,
    this.hidden = false,
    this.hiddenReason,
    this.pinned = false,
    this.author = ForumIdentity.anonymous,
    this.hearted = false,
  });

  factory ForumThread.fromRow(
    Map<String, dynamic> r, {
    ForumIdentity? author,
    bool hearted = false,
  }) {
    final profile = r['forum_profiles'];
    return ForumThread(
      id: r['id'] as String,
      categoryId: (r['category_id'] ?? '') as String,
      authorId: (r['author_id'] ?? '') as String,
      title: (r['title'] ?? '') as String,
      body: (r['body'] ?? '') as String,
      createdAt: DateTime.tryParse((r['created_at'] ?? '') as String) ?? DateTime(2000),
      lastActivityAt:
          DateTime.tryParse((r['last_activity_at'] ?? '') as String) ?? DateTime(2000),
      replyCount: (r['reply_count'] as num?)?.toInt() ?? 0,
      reactionCount: (r['reaction_count'] as num?)?.toInt() ?? 0,
      hidden: (r['hidden'] ?? false) as bool,
      hiddenReason: r['hidden_reason'] as String?,
      pinned: (r['pinned'] ?? false) as bool,
      author: author ??
          (profile is Map
              ? ForumIdentity.fromRow(Map<String, dynamic>.from(profile))
              : ForumIdentity.anonymous),
      hearted: hearted,
    );
  }

  ForumThread copyWith({bool? hearted, int? reactionCount, bool? hidden}) => ForumThread(
        id: id,
        categoryId: categoryId,
        authorId: authorId,
        title: title,
        body: body,
        createdAt: createdAt,
        lastActivityAt: lastActivityAt,
        replyCount: replyCount,
        reactionCount: reactionCount ?? this.reactionCount,
        hidden: hidden ?? this.hidden,
        hiddenReason: hiddenReason,
        pinned: pinned,
        author: author,
        hearted: hearted ?? this.hearted,
      );
}

class ForumReply {
  final String id;
  final String threadId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final int reactionCount;
  final bool hidden;
  final ForumIdentity author;
  final bool hearted;

  const ForumReply({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.reactionCount = 0,
    this.hidden = false,
    this.author = ForumIdentity.anonymous,
    this.hearted = false,
  });

  factory ForumReply.fromRow(
    Map<String, dynamic> r, {
    ForumIdentity? author,
    bool hearted = false,
  }) {
    final profile = r['forum_profiles'];
    return ForumReply(
      id: r['id'] as String,
      threadId: (r['thread_id'] ?? '') as String,
      authorId: (r['author_id'] ?? '') as String,
      body: (r['body'] ?? '') as String,
      createdAt: DateTime.tryParse((r['created_at'] ?? '') as String) ?? DateTime(2000),
      reactionCount: (r['reaction_count'] as num?)?.toInt() ?? 0,
      hidden: (r['hidden'] ?? false) as bool,
      author: author ??
          (profile is Map
              ? ForumIdentity.fromRow(Map<String, dynamic>.from(profile))
              : ForumIdentity.anonymous),
      hearted: hearted,
    );
  }

  ForumReply copyWith({bool? hearted, int? reactionCount}) => ForumReply(
        id: id,
        threadId: threadId,
        authorId: authorId,
        body: body,
        createdAt: createdAt,
        reactionCount: reactionCount ?? this.reactionCount,
        hidden: hidden,
        author: author,
        hearted: hearted ?? this.hearted,
      );
}

/// Why something was reported. `needsHelp` is the crisis-adjacent one (§2.4): it
/// is not a complaint about the author, it asks a human to look sooner.
enum ReportReason { unkind, selling, identifying, needsHelp, other }

extension ReportReasonX on ReportReason {
  String get key => switch (this) {
        ReportReason.unkind => 'unkind',
        ReportReason.selling => 'selling',
        ReportReason.identifying => 'identifying',
        ReportReason.needsHelp => 'needs_help',
        ReportReason.other => 'other',
      };

  String get label => switch (this) {
        ReportReason.unkind => 'Unkind or judgmental',
        ReportReason.selling => 'Selling something',
        ReportReason.identifying => 'Shares a child’s identifying details',
        ReportReason.needsHelp => 'Someone here may need help',
        ReportReason.other => 'Something else',
      };

  String get blurb => switch (this) {
        ReportReason.needsHelp =>
          'We’ll look at this first. Nothing is deleted — a person reads it.',
        ReportReason.identifying => 'Full names, schools, or anything that identifies a child.',
        _ => '',
      };
}

/// One open report, as the moderator queue shows it.
class ForumReport {
  final String id;
  final String targetType; // thread | reply
  final String targetId;
  final String reason;
  final String? note;
  final DateTime createdAt;
  final bool resolved;

  /// The reported words, resolved for the queue so a moderator can decide
  /// without opening four screens.
  final String? excerpt;
  final bool targetHidden;

  const ForumReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
    this.note,
    this.resolved = false,
    this.excerpt,
    this.targetHidden = false,
  });

  bool get isUrgent => reason == 'needs_help';

  String get reasonLabel => switch (reason) {
        'unkind' => 'Unkind or judgmental',
        'selling' => 'Selling something',
        'identifying' => 'Identifying details',
        'needs_help' => 'May need help',
        _ => 'Something else',
      };
}
