import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/forum.dart';
import '../../services/forum_service.dart';
import 'circle_identity_sheet.dart';
import 'new_thread_screen.dart';
import 'thread_screen.dart';

/// One category's threads.
class ThreadListScreen extends StatefulWidget {
  final ForumCategory category;
  const ThreadListScreen({super.key, required this.category});

  @override
  State<ThreadListScreen> createState() => _ThreadListScreenState();
}

class _ThreadListScreenState extends State<ThreadListScreen> {
  List<ForumThread> _threads = const [];
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
      final threads = await ForumService.threads(categoryId: widget.category.id);
      if (mounted) setState(() { _threads = threads; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Posting is gated on having chosen a Circle name (§2.4), so the ask happens
  /// here — at the moment it means something — rather than during onboarding.
  Future<void> _startThread() async {
    var identity = await ForumService.myIdentity();
    if (!mounted) return;
    if (identity == null) {
      identity = await showCircleIdentitySheet(context);
      if (identity == null || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewThreadScreen(category: widget.category)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      appBar: AppBar(
        backgroundColor: MomzoColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.category.title,
            style: MomzoText.sans(17, color: MomzoColors.ink, weight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: MomzoColors.ink),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startThread,
        backgroundColor: MomzoColors.coral,
        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 19),
        label: Text('Say something',
            style: MomzoText.sans(14, color: Colors.white, weight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
          : _threads.isEmpty
              ? _empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                  itemCount: _threads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _row(_threads[i]),
                ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nobody’s started this one yet',
                  textAlign: TextAlign.center,
                  style: MomzoText.serif(21, color: MomzoColors.ink)),
              const SizedBox(height: 8),
              Text('Being first is a kindness — someone is looking for exactly this.',
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(14, color: MomzoColors.body, height: 1.45)),
            ],
          ),
        ),
      );

  Widget _row(ForumThread t) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ThreadScreen(thread: t)),
        ),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0F342F30), blurRadius: 14, offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(t.author.avatarEmoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(t.author.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MomzoText.sans(12,
                            color: MomzoColors.muted, weight: FontWeight.w800)),
                  ),
                  if (t.pinned)
                    Text('Pinned',
                        style: MomzoText.sans(11,
                            color: MomzoColors.honeyText, weight: FontWeight.w800)),
                  // Her own hidden thread is visible to her, and says why.
                  if (t.hidden)
                    Text('Being reviewed',
                        style: MomzoText.sans(11,
                            color: MomzoColors.coralText, weight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 7),
              Text(t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MomzoText.serif(17, color: MomzoColors.ink, height: 1.25)),
              const SizedBox(height: 5),
              Text(t.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MomzoText.sans(13,
                      color: MomzoColors.body, weight: FontWeight.w600, height: 1.4)),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text(
                    t.replyCount == 0
                        ? 'No replies yet'
                        : '${t.replyCount} ${t.replyCount == 1 ? 'reply' : 'replies'}',
                    style: MomzoText.sans(12,
                        color: MomzoColors.muted, weight: FontWeight.w700),
                  ),
                  if (t.reactionCount > 0) ...[
                    const SizedBox(width: 12),
                    Text('💛 ${t.reactionCount}',
                        style: MomzoText.sans(12,
                            color: MomzoColors.muted, weight: FontWeight.w700)),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
}
