import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/forum.dart';
import '../../services/auth_service.dart';
import '../../services/forum_service.dart';
import 'circle_identity_sheet.dart';
import 'report_sheet.dart';

/// One thread and its replies.
class ThreadScreen extends StatefulWidget {
  final ForumThread thread;
  const ThreadScreen({super.key, required this.thread});

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  late ForumThread _thread = widget.thread;
  List<ForumReply> _replies = const [];
  final _reply = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  String? get _me => AuthService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final fresh = await ForumService.thread(_thread.id);
      final replies = await ForumService.replies(_thread.id);
      if (!mounted) return;
      setState(() {
        if (fresh != null) _thread = fresh;
        _replies = replies;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;

    // Same gate as starting a thread: a reply is posting too.
    var identity = await ForumService.myIdentity();
    if (!mounted) return;
    if (identity == null) {
      identity = await showCircleIdentitySheet(context);
      if (identity == null || !mounted) return;
    }

    setState(() => _sending = true);
    try {
      await ForumService.reply(threadId: _thread.id, body: body);
      _reply.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That didn’t send. Try again in a moment?')),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _toggleThreadHeart() async {
    final now = await ForumService.toggleHeart(
      targetType: 'thread', targetId: _thread.id, currentlyHearted: _thread.hearted,
    );
    if (!mounted) return;
    setState(() => _thread = _thread.copyWith(
          hearted: now,
          reactionCount: _thread.reactionCount + (now ? 1 : -1),
        ));
  }

  Future<void> _toggleReplyHeart(ForumReply r) async {
    final now = await ForumService.toggleHeart(
      targetType: 'reply', targetId: r.id, currentlyHearted: r.hearted,
    );
    if (!mounted) return;
    setState(() {
      _replies = [
        for (final x in _replies)
          if (x.id == r.id)
            x.copyWith(hearted: now, reactionCount: x.reactionCount + (now ? 1 : -1))
          else
            x,
      ];
    });
  }

  Future<void> _report(String targetType, String targetId) async {
    final filed = await showReportSheet(context, targetType: targetType, targetId: targetId);
    if (filed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you. A person will read this.')),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      appBar: AppBar(
        backgroundColor: MomzoColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MomzoColors.ink),
        actions: [
          IconButton(
            tooltip: 'Report this',
            icon: const Icon(Icons.flag_outlined, color: MomzoColors.faint, size: 20),
            onPressed: () => _report('thread', _thread.id),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                      children: [
                        if (_thread.hidden) _hiddenNotice(),
                        _head(),
                        const SizedBox(height: 20),
                        if (_replies.isNotEmpty)
                          Text('${_replies.length} '
                              '${_replies.length == 1 ? 'REPLY' : 'REPLIES'}',
                              style: MomzoText.eyebrow()),
                        const SizedBox(height: 10),
                        for (final r in _replies) ...[
                          _replyRow(r),
                          const SizedBox(height: 10),
                        ],
                        if (_replies.isEmpty)
                          Text('No replies yet. Yours would be the first.',
                              style: MomzoText.sans(13.5,
                                  color: MomzoColors.muted, weight: FontWeight.w600)),
                      ],
                    ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  /// Shown to the author of a hidden thread. It never just disappears (§2.4).
  Widget _hiddenNotice() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MomzoColors.coralTint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _thread.authorId == _me
              ? 'This is being looked at by a person, so it’s hidden from others '
                  'for now. Nothing has been deleted.'
              : 'Hidden pending review.',
          style: MomzoText.sans(13,
              color: MomzoColors.coralText, weight: FontWeight.w700, height: 1.4),
        ),
      );

  Widget _head() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_thread.author.avatarEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(_thread.author.displayName,
                  style: MomzoText.sans(13,
                      color: MomzoColors.muted, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_thread.title,
              style: MomzoText.serif(25, color: MomzoColors.ink, height: 1.25)),
          const SizedBox(height: 12),
          Text(_thread.body,
              style: MomzoText.sans(15.5,
                  color: MomzoColors.body, weight: FontWeight.w600, height: 1.6)),
          const SizedBox(height: 14),
          Row(
            children: [
              _heartButton(
                hearted: _thread.hearted,
                count: _thread.reactionCount,
                onTap: _toggleThreadHeart,
              ),
              const Spacer(),
              if (_thread.authorId == _me)
                TextButton(
                  onPressed: _confirmDeleteThread,
                  child: Text('Delete',
                      style: MomzoText.sans(13,
                          color: MomzoColors.faint, weight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      );

  Widget _replyRow(ForumReply r) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MomzoColors.cardBorder, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(r.author.avatarEmoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(r.author.displayName,
                      style: MomzoText.sans(12,
                          color: MomzoColors.muted, weight: FontWeight.w800)),
                ),
                if (r.hidden)
                  Text('Being reviewed',
                      style: MomzoText.sans(11,
                          color: MomzoColors.coralText, weight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            Text(r.body,
                style: MomzoText.sans(14.5,
                    color: MomzoColors.body, weight: FontWeight.w600, height: 1.55)),
            const SizedBox(height: 10),
            Row(
              children: [
                _heartButton(
                  hearted: r.hearted,
                  count: r.reactionCount,
                  onTap: () => _toggleReplyHeart(r),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Report this',
                  icon: const Icon(Icons.flag_outlined, color: MomzoColors.faint, size: 17),
                  onPressed: () => _report('reply', r.id),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _heartButton({
    required bool hearted,
    required int count,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hearted ? '💛' : '🤍', style: const TextStyle(fontSize: 16)),
            if (count > 0) ...[
              const SizedBox(width: 5),
              // The public count is the you-are-not-alone signal, which is what a
              // forum reaction is FOR. It is never a score about anybody.
              Text('$count',
                  style: MomzoText.sans(12.5,
                      color: MomzoColors.muted, weight: FontWeight.w800)),
            ],
          ],
        ),
      );

  Widget _composer() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: MomzoColors.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _reply,
                maxLines: 4,
                minLines: 1,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                style: MomzoText.sans(14.5, color: MomzoColors.body, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Say something kind…',
                  hintStyle: MomzoText.sans(14.5, color: MomzoColors.faint),
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: Icon(Icons.send_rounded,
                  color: _sending ? MomzoColors.faint : MomzoColors.coral),
            ),
          ],
        ),
      );

  Future<void> _confirmDeleteThread() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MomzoColors.cream,
        title: Text('Delete this?',
            style: MomzoText.serif(20, color: MomzoColors.ink)),
        content: Text('It will go, along with its replies. This can’t be undone.',
            style: MomzoText.sans(14, color: MomzoColors.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: MomzoText.sans(14,
                    color: MomzoColors.coralDeep, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ForumService.deleteThread(_thread.id);
    if (mounted) Navigator.pop(context);
  }
}
