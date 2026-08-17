/// One of Florie's posts, mirrored in the app (Expansion Plan §1).
///
/// The body is markdown. For a `carousel` — her typographic format — slides are
/// separated by a line containing only `---`, and `*asterisks*` mark the one word
/// per line the eye should land on (her post guide §3). That convention is why
/// there is no separate slides column: the words have exactly one home, and a post
/// stays readable as plain text everywhere that does not know about slides.
class SocialPost {
  final String id;
  final String slug;
  final String title;
  final String body;
  final String postType; // carousel | tip | reel | article
  final List<String> tags;
  final List<SocialMedia> media;
  final String? sourceUrl;
  final DateTime? publishedAt;

  /// Whether this parent has hearted it. Hers alone — reactions are RLS-scoped to
  /// the user, so this is never a count of anybody else.
  final bool hearted;

  const SocialPost({
    required this.id,
    required this.slug,
    required this.title,
    required this.body,
    this.postType = 'tip',
    this.tags = const [],
    this.media = const [],
    this.sourceUrl,
    this.publishedAt,
    this.hearted = false,
  });

  bool get isCarousel => postType == 'carousel';

  /// The slides, for a carousel. A post that never learned the `---` convention
  /// simply reads as one slide, which is the right fallback: it renders whole
  /// rather than empty.
  List<String> get slides => body
      .split(RegExp(r'^---$', multiLine: true))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Paragraphs, for prose posts.
  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// What the feed card shows under the title.
  ///
  /// For a carousel that is the SECOND slide, not the first. In Florie's format
  /// slide 1 is the title beat — near enough the same words as `title` — so
  /// previewing it printed the headline twice on every card in the feed. Slide 2
  /// is the scene, which is the line that actually makes someone tap.
  String get preview {
    final String source;
    if (!isCarousel) {
      source = body;
    } else {
      final s = slides;
      if (s.isEmpty) return '';
      source = s.length > 1 ? s[1] : s.first;
    }
    return stripEmphasis(source).replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
  }

  /// `*word*` is a typographic instruction, not literal text. Anywhere the app
  /// shows a plain string rather than rendering the emphasis, the asterisks must
  /// come off — otherwise they read as punctuation the writer did not intend.
  static String stripEmphasis(String s) =>
      s.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1]!);

  factory SocialPost.fromRow(Map<String, dynamic> r, {bool hearted = false}) {
    final rawMedia = r['media'];
    return SocialPost(
      id: r['id'] as String,
      slug: (r['slug'] ?? '') as String,
      title: (r['title'] ?? '') as String,
      body: (r['body'] ?? '') as String,
      postType: (r['post_type'] ?? 'tip') as String,
      tags: List<String>.from(r['tags'] ?? const <String>[]),
      media: rawMedia is List
          ? rawMedia
              .whereType<Map>()
              .map((m) => SocialMedia.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      sourceUrl: r['source_url'] as String?,
      publishedAt: DateTime.tryParse((r['published_at'] ?? '') as String),
      hearted: hearted,
    );
  }

  SocialPost copyWith({bool? hearted}) => SocialPost(
        id: id,
        slug: slug,
        title: title,
        body: body,
        postType: postType,
        tags: tags,
        media: media,
        sourceUrl: sourceUrl,
        publishedAt: publishedAt,
        hearted: hearted ?? this.hearted,
      );
}

class SocialMedia {
  final String type; // image | video
  final String url;
  final String? alt;

  const SocialMedia({required this.type, required this.url, this.alt});

  factory SocialMedia.fromJson(Map<String, dynamic> j) => SocialMedia(
        type: (j['type'] ?? 'image') as String,
        url: (j['url'] ?? '') as String,
        alt: j['alt'] as String?,
      );
}
