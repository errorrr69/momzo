import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/forum.dart';
import '../../services/forum_service.dart';
import 'moderation_queue_screen.dart';
import 'thread_list_screen.dart';

/// The Circle — the forum's front door (Expansion Plan §2).
///
/// Categories, plus whatever has been talked about most recently, so a mother
/// who opens it for the first time sees people rather than empty folders.
class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  List<ForumCategory> _categories = const [];
  List<ForumThread> _recent = const [];
  bool _moderator = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    ForumService.revision.addListener(_onChanged);
  }

  @override
  void dispose() {
    ForumService.revision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    try {
      final categories = await ForumService.categories();
      final recent = await ForumService.threads(limit: 5);
      final moderator = await ForumService.amModerator();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _recent = recent;
        _moderator = moderator;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCategory(ForumCategory c) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ThreadListScreen(category: c)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('The Circle',
                                style: MomzoText.sans(26,
                                    color: MomzoColors.ink, weight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text('Mothers, talking to each other',
                                style: MomzoText.sans(13,
                                    color: MomzoColors.muted, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      if (_moderator)
                        IconButton(
                          tooltip: 'Reports',
                          icon: const Icon(Icons.flag_outlined, color: MomzoColors.coralText),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ModerationQueueScreen()),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_recent.isNotEmpty) ...[
                    Text('BEING TALKED ABOUT', style: MomzoText.eyebrow()),
                    const SizedBox(height: 11),
                    for (final t in _recent) ...[
                      _recentRow(t),
                      const SizedBox(height: 9),
                    ],
                    const SizedBox(height: 18),
                  ],
                  Text('WHERE TO POST', style: MomzoText.eyebrow()),
                  const SizedBox(height: 11),
                  for (final c in _categories) ...[
                    _categoryRow(c),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 8),
                  _promise(),
                ],
              ),
      ),
    );
  }

  Widget _recentRow(ForumThread t) => GestureDetector(
        onTap: () {
          final category = _categories.where((c) => c.id == t.categoryId);
          if (category.isNotEmpty) _openCategory(category.first);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0F342F30), blurRadius: 14, offset: Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Text(t.author.avatarEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MomzoText.sans(14.5,
                            color: MomzoColors.ink, weight: FontWeight.w800, height: 1.25)),
                    const SizedBox(height: 3),
                    Text(
                      t.replyCount == 0
                          ? 'No replies yet'
                          : '${t.replyCount} ${t.replyCount == 1 ? 'reply' : 'replies'}',
                      style: MomzoText.sans(12,
                          color: MomzoColors.muted, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _categoryRow(ForumCategory c) => GestureDetector(
        onTap: () => _openCategory(c),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MomzoColors.cardBorder, width: 1.4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: MomzoText.sans(15,
                            color: MomzoColors.ink, weight: FontWeight.w800)),
                    if (c.blurb != null) ...[
                      const SizedBox(height: 3),
                      Text(c.blurb!,
                          style: MomzoText.sans(12.5,
                              color: MomzoColors.muted, weight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: MomzoColors.faint),
            ],
          ),
        ),
      );

  /// The tone of the place, stated where she can see it. Not a legal notice.
  Widget _promise() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MomzoColors.sageTint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Kindness only. No selling, no judgment, and nothing that identifies a '
          'child. If something here worries you, report it — a person reads it.',
          style: MomzoText.sans(13,
              color: const Color(0xFF4E7A60), weight: FontWeight.w600, height: 1.45),
        ),
      );
}
