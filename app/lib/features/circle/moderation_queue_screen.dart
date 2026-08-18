import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/forum.dart';
import '../../services/forum_service.dart';

/// The report queue (Expansion Plan §2.4).
///
/// Deliberately a plain list with three actions. A moderation tool that needs
/// learning is a moderation tool that does not get used, and this one is for one
/// person doing it between other work.
///
/// "Someone may need help" sorts to the top regardless of when it arrived.
class ModerationQueueScreen extends StatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen> {
  List<ForumReport> _reports = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reports = await ForumService.openReports();
      if (mounted) setState(() { _reports = reports; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(ForumReport r, {required bool hide, required String resolution}) async {
    await ForumService.setHidden(
      targetType: r.targetType,
      targetId: r.targetId,
      hidden: hide,
      reason: hide ? 'Hidden after review' : null,
    );
    await ForumService.resolveReport(r.id, resolution);
    await _load();
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
        title: Text('Reports',
            style: MomzoText.sans(17, color: MomzoColors.ink, weight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
          : _reports.isEmpty
              ? Center(
                  child: Text('Nothing waiting. 💛',
                      style: MomzoText.serif(20, color: MomzoColors.muted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: _reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(_reports[i]),
                ),
    );
  }

  Widget _card(ForumReport r) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: r.isUrgent ? MomzoColors.sage : MomzoColors.cardBorder,
            width: r.isUrgent ? 2 : 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.isUrgent ? MomzoColors.sageTint : MomzoColors.coralTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.reasonLabel,
                      style: MomzoText.sans(11,
                          color: r.isUrgent ? MomzoColors.sageText : MomzoColors.coralText,
                          weight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Text(r.targetType == 'thread' ? 'Thread' : 'Reply',
                    style: MomzoText.sans(11,
                        color: MomzoColors.faint, weight: FontWeight.w700)),
                const Spacer(),
                if (r.targetHidden)
                  Text('Hidden',
                      style: MomzoText.sans(11,
                          color: MomzoColors.muted, weight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Text(r.excerpt ?? '(this has since been deleted)',
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: MomzoText.sans(14,
                    color: MomzoColors.body, weight: FontWeight.w600, height: 1.5)),
            if (r.note != null && r.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('“${r.note}”',
                  style: MomzoText.sans(12.5,
                      color: MomzoColors.muted,
                      weight: FontWeight.w600,
                      height: 1.4)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (r.targetHidden)
                  _action('Put it back',
                      () => _act(r, hide: false, resolution: 'restored'))
                else
                  _action('Hide it', () => _act(r, hide: true, resolution: 'hidden')),
                const SizedBox(width: 8),
                _action('It’s fine', () => _act(r, hide: false, resolution: 'no action'),
                    quiet: true),
              ],
            ),
          ],
        ),
      );

  Widget _action(String label, VoidCallback onTap, {bool quiet = false}) => Expanded(
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: quiet ? MomzoColors.cardBorder : MomzoColors.coral, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          child: Text(label,
              style: MomzoText.sans(13,
                  color: quiet ? MomzoColors.muted : MomzoColors.coral,
                  weight: FontWeight.w800)),
        ),
      );
}
