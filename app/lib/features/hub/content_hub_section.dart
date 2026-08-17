import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/social_post.dart';
import '../../services/content_hub_service.dart';
import 'post_reader_screen.dart';

/// The Content Hub feed, as a section of the Learn tab (Expansion Plan §1.1).
///
/// A section rather than a tab on purpose: the daily card stays the personalized
/// hero and this is the browsable library beside it. Adding a sixth tab for it
/// would say the opposite.
class ContentHubSection extends StatefulWidget {
  const ContentHubSection({super.key});

  @override
  State<ContentHubSection> createState() => _ContentHubSectionState();
}

class _ContentHubSectionState extends State<ContentHubSection> {
  List<SocialPost> _posts = [];
  List<String> _tags = [];
  String? _tag;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
    ContentHubService.heartRevision.addListener(_onHeartChanged);
  }

  @override
  void dispose() {
    ContentHubService.heartRevision.removeListener(_onHeartChanged);
    super.dispose();
  }

  void _onHeartChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    try {
      final posts = await ContentHubService.feed(tag: _tag);
      final tags = _tags.isEmpty ? await ContentHubService.tagsInUse() : _tags;
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _tags = tags;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  Future<void> _select(String? tag) async {
    setState(() { _tag = tag; _loading = true; });
    await _load();
  }

  Future<void> _open(SocialPost p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostReaderScreen(post: p)),
    );
    if (mounted) _load(); // a heart may have been toggled in there
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show and nothing to explain: before Florie seeds her first batch
    // this section simply is not there, rather than being an empty promise.
    if (_failed || (!_loading && _posts.isEmpty && _tag == null)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FROM MOMZO', style: MomzoText.eyebrow()),
        const SizedBox(height: 11),
        if (_tags.isNotEmpty) _chips(),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: MomzoColors.coral)),
          )
        else if (_posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text('Nothing under that one yet.',
                style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w700)),
          )
        else
          for (final p in _posts) ...[
            _PostRow(post: p, onTap: () => _open(p)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _chips() => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          children: [
            _chip('All', _tag == null, () => _select(null)),
            for (final t in _tags)
              _chip(t.replaceAll('-', ' '), _tag == t, () => _select(t)),
          ],
        ),
      );

  Widget _chip(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? MomzoColors.coral : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? MomzoColors.coral : MomzoColors.cardBorder,
                width: 1.4,
              ),
            ),
            child: Text(
              label,
              style: MomzoText.sans(12.5,
                  color: active ? Colors.white : MomzoColors.body,
                  weight: FontWeight.w800),
            ),
          ),
        ),
      );
}

class _PostRow extends StatelessWidget {
  final SocialPost post;
  final VoidCallback onTap;
  const _PostRow({required this.post, required this.onTap});

  static const _typeLabel = {
    'carousel': 'Carousel',
    'tip': 'Note',
    'reel': 'Reel',
    'article': 'Read',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_typeLabel[post.postType] ?? 'Note',
                    style: MomzoText.sans(11,
                        color: MomzoColors.honeyText, weight: FontWeight.w800)),
                const Spacer(),
                if (post.hearted) const Text('💛', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              // The title is written lower-case in her voice; leave it exactly as
              // she wrote it rather than title-casing it here.
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MomzoText.serif(18, color: MomzoColors.ink, height: 1.25),
            ),
            const SizedBox(height: 6),
            Text(
              post.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MomzoText.sans(13.5,
                  color: MomzoColors.body, weight: FontWeight.w600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
