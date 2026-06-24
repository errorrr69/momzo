import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_bottom_nav.dart';

/// 23 · Memory Timeline — a private, treasured keepsake of activities & milestones.
class MemoryTimelineScreen extends StatelessWidget {
  const MemoryTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      bottomNavigationBar: const MomzoBottomNav(MomzoTab.me),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
          children: [
            Text('Your moments',
                style: MomzoText.sans(26,
                    color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5)),
            Text('A private keepsake of you & Aarav.',
                style: MomzoText.serif(15, color: MomzoColors.muted)),
            const SizedBox(height: 18),
            Text('THIS WEEK', style: MomzoText.eyebrow()),
            const SizedBox(height: 10),
            _photoMemory(),
            const SizedBox(height: 14),
            _milestone('🏅', 'Milestone: tied his own laces!', 'Jun 17'),
            const SizedBox(height: 18),
            Text('EARLIER', style: MomzoText.eyebrow()),
            const SizedBox(height: 10),
            _noteMemory(),
          ],
        ),
      ),
    );
  }

  Widget _photoMemory() {
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
          Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA6D6C2), MomzoColors.sage],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(child: Text('🎈', style: TextStyle(fontSize: 40))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"He giggled so hard the balloon popped."',
                    style: MomzoText.serif(16, color: MomzoColors.ink, height: 1.4)),
                const SizedBox(height: 5),
                Text('Jun 19 · Balloon breathing',
                    style: MomzoText.sans(12,
                        color: MomzoColors.muted, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestone(String emoji, String title, String date) {
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
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MomzoColors.honeyTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: MomzoText.sans(14,
                      color: MomzoColors.ink, weight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(date,
                  style: MomzoText.sans(12,
                      color: MomzoColors.muted, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noteMemory() {
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC9B6EC), MomzoColors.lavender],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('First time he said "I felt nervous" out loud. 💜',
                    style: MomzoText.serif(15, color: MomzoColors.ink, height: 1.35)),
                const SizedBox(height: 3),
                Text('Jun 12',
                    style: MomzoText.sans(12,
                        color: MomzoColors.muted, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
