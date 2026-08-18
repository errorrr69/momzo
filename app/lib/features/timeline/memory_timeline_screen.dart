import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../services/child_service.dart';
import '../../services/memory_service.dart';
import 'weekly_recap_screen.dart';

/// 23 · Memory Timeline — a private, treasured keepsake of activities & milestones
/// (Task 30). Photos load via short-lived signed URLs from private storage.
class MemoryTimelineScreen extends StatefulWidget {
  const MemoryTimelineScreen({super.key});

  @override
  State<MemoryTimelineScreen> createState() => _MemoryTimelineScreenState();
}

class _MemoryTimelineScreenState extends State<MemoryTimelineScreen> {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  List<Memory> _memories = [];
  bool _loading = true;

  String get _childName => ChildService.current?.name ?? 'your child';
  bool get _live => AppEnv.hasSupabase && ChildService.current != null;

  @override
  void initState() {
    super.initState();
    if (_live) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final m = await MemoryService.load();
      if (mounted) setState(() {
        _memories = m;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                children: [
                  Text('Your moments',
                      style: MomzoText.sans(26,
                          color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5)),
                  Text('A private keepsake of you & $_childName.',
                      style: MomzoText.serif(15, color: MomzoColors.muted)),
                  const SizedBox(height: 18),
                  _weeklyRecapBanner(),
                  const SizedBox(height: 14),
                  if (_memories.isEmpty)
                    _empty()
                  else
                    for (final m in _memories) ...[
                      _memoryCard(m),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
      ),
    );
  }

  /// Entry point to the gentle Weekly Recap (Task 31).
  Widget _weeklyRecapBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WeeklyRecapScreen()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: MomzoColors.coralTint,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Text('🌸', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your week with $_childName',
                      style: MomzoText.sans(15,
                          color: MomzoColors.ink, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('A gentle look back at what you shared',
                      style: MomzoText.sans(12.5,
                          color: MomzoColors.muted, weight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: MomzoColors.coralDeep),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text('Your keepsake starts here.',
                textAlign: TextAlign.center,
                style: MomzoText.sans(17, color: MomzoColors.ink, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Finish an activity and save a photo or note to begin your timeline.',
                textAlign: TextAlign.center,
                style: MomzoText.serif(15, color: MomzoColors.muted, height: 1.4)),
          ],
        ),
      );

  Widget _memoryCard(Memory m) {
    if (m.kind == 'milestone' && m.photoUrl == null) return _milestone(m);
    if (m.photoUrl != null) return _photoMemory(m);
    return _noteMemory(m);
  }

  Widget _photoMemory(Memory m) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            m.photoUrl!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              color: MomzoColors.sageTint,
              child: const Center(child: Icon(Icons.image_not_supported_outlined, color: MomzoColors.sage)),
            ),
            loadingBuilder: (c, child, progress) => progress == null
                ? child
                : Container(
                    height: 180,
                    color: MomzoColors.sageTint,
                    child: const Center(child: CircularProgressIndicator(color: MomzoColors.sage)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.note != null && m.note!.isNotEmpty)
                  Text('“${m.note}”', style: MomzoText.serif(16, color: MomzoColors.ink, height: 1.4)),
                if (m.note != null && m.note!.isNotEmpty) const SizedBox(height: 5),
                Text('${_date(m.date)} · ${m.title}',
                    style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestone(Memory m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: MomzoColors.honeyTint, borderRadius: BorderRadius.circular(13)),
            child: const Text('🏅', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: MomzoText.sans(14, color: MomzoColors.ink, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(_date(m.date), style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteMemory(Memory m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC9B6EC), MomzoColors.lavender],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Center(child: Text('💜', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.note != null && m.note!.isNotEmpty ? '“${m.note}”' : m.title,
                    style: MomzoText.serif(15, color: MomzoColors.ink, height: 1.35)),
                const SizedBox(height: 3),
                Text('${_date(m.date)} · ${m.title}',
                    style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
