import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/forum.dart';
import '../../models/social_post.dart';
import '../../services/content_hub_service.dart';
import '../../services/forum_service.dart';
import '../circle/new_thread_screen.dart';

/// One of Florie's posts, read in full.
///
/// A carousel is her typographic format: one beat per slide, set large, read at a
/// glance. It renders as a swipeable deck rather than as scrolling prose, because
/// the line breaks and the one-thought-per-slide rhythm ARE the writing — flatten
/// them into paragraphs and the format stops working.
///
/// Prose posts (`tip`, `article`) render as paragraphs, same as a card's main read.
class PostReaderScreen extends StatefulWidget {
  final SocialPost post;
  const PostReaderScreen({super.key, required this.post});

  @override
  State<PostReaderScreen> createState() => _PostReaderScreenState();
}

class _PostReaderScreenState extends State<PostReaderScreen> {
  late SocialPost _post = widget.post;
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _toggleHeart() async {
    final now = await ContentHubService.toggleHeart(_post);
    if (mounted) setState(() => _post = _post.copyWith(hearted: now));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.creamWarm,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _post.isCarousel ? _deck() : _prose()),
            _talkAboutIt(),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: MomzoColors.ink),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
            Expanded(
              child: Text(
                _post.isCarousel ? '${_page + 1} of ${_post.slides.length}' : 'Momzo',
                textAlign: TextAlign.center,
                style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 48), // balances the back button
          ],
        ),
      );

  Widget _deck() {
    final slides = _post.slides;
    return PageView.builder(
      controller: _pages,
      itemCount: slides.length,
      onPageChanged: (i) => setState(() => _page = i),
      itemBuilder: (_, i) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: _EmphasisedText(
              slides[i],
              // The first slide is the title beat and carries the weight.
              size: i == 0 ? 30 : 25,
            ),
          ),
        ),
      ),
    );
  }

  Widget _prose() => ListView(
        padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),
        children: [
          Text(_post.title,
              style: MomzoText.serif(27, color: MomzoColors.ink, height: 1.25)),
          const SizedBox(height: 18),
          for (final p in _post.paragraphs) ...[
            _EmphasisedText(p, size: 17, align: TextAlign.left, serif: false),
            const SizedBox(height: 14),
          ],
        ],
      );

  /// "Talk about this in the Circle" (Expansion Plan §1.4).
  ///
  /// The reason a post has no comments of its own: discussion belongs in one
  /// place, not two. Now that Florie's posts and the mothers live behind the
  /// same tab, this is a chip-hop rather than a cross-app jump.
  ///
  /// It seeds a NEW thread rather than attaching a comment thread to the post,
  /// which keeps every conversation in the Circle where it can be moderated,
  /// reported and found by someone who never read the post.
  Widget _talkAboutIt() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openCircleThread,
            icon: const Icon(Icons.forum_outlined, size: 18, color: MomzoColors.sageText),
            label: Text('Talk about this in the Circle',
                style: MomzoText.sans(13.5,
                    color: MomzoColors.sageText, weight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: MomzoColors.sage, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      );

  Future<void> _openCircleThread() async {
    // Prefer the category the post's own tags point at, so she lands somewhere
    // that already reads as the right room. Falls back to Ask the Circle.
    final categories = await ForumService.categories();
    if (!mounted || categories.isEmpty) return;

    ForumCategory pick() {
      for (final tag in _post.tags) {
        for (final c in categories) {
          if (c.slug == tag) return c;
        }
      }
      return categories.firstWhere(
        (c) => c.slug == 'ask-the-circle',
        orElse: () => categories.first,
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewThreadScreen(
          category: pick(),
          // Her words, not ours — the post title is only a starting point she is
          // free to delete. Prefilling the BODY would be putting words in her
          // mouth, so that stays empty.
          initialTitle: _post.title,
        ),
      ),
    );
  }

  Widget _footer() => Container(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: MomzoColors.hairline)),
        ),
        child: Row(
          children: [
            if (_post.tags.isNotEmpty)
              Expanded(
                child: Text(
                  _post.tags.map((t) => t.replaceAll('-', ' ')).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700),
                ),
              )
            else
              const Spacer(),
            IconButton(
              onPressed: _toggleHeart,
              tooltip: _post.hearted ? 'Remove from your loved posts' : 'Love this',
              icon: Text(
                _post.hearted ? '💛' : '🤍',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ],
        ),
      );
}

/// Renders `*word*` as the emphasised word, and keeps the writer's line breaks.
///
/// Both matter and for the same reason: in this format the asterisk marks the word
/// the eye should land on, and the line break is where the reader breathes. Showing
/// the asterisks literally, or reflowing the lines, turns verse into a paragraph.
class _EmphasisedText extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign align;
  final bool serif;

  const _EmphasisedText(
    this.text, {
    required this.size,
    this.align = TextAlign.center,
    this.serif = true,
  });

  @override
  Widget build(BuildContext context) {
    final base = serif
        ? MomzoText.serif(size, color: MomzoColors.ink, height: 1.45)
        : MomzoText.sans(size, color: MomzoColors.body, height: 1.6);

    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*([^*]+)\*');
    var index = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > index) spans.add(TextSpan(text: text.substring(index, m.start)));
      spans.add(TextSpan(
        text: m[1],
        style: base.copyWith(
          fontWeight: FontWeight.w800,
          color: MomzoColors.coralText,
        ),
      ));
      index = m.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));

    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: align,
    );
  }
}
