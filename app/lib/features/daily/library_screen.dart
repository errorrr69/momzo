import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';

/// 09 · Learn · library — saved + browse past content by topic.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          children: [
            Text('Learn',
                style: MomzoText.sans(26,
                    color: MomzoColors.ink, weight: FontWeight.w900)),
            const SizedBox(height: 14),
            // Search
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: MomzoColors.faint),
                  const SizedBox(width: 10),
                  Text('Search reads & topics',
                      style: MomzoText.sans(14,
                          color: MomzoColors.faint, weight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _filter('All', selected: true),
                const SizedBox(width: 8),
                _filter('Big emotions'),
                const SizedBox(width: 8),
                _filter('Focus'),
              ],
            ),
            const SizedBox(height: 22),
            Text('SAVED BY YOU', style: MomzoText.eyebrow()),
            const SizedBox(height: 11),
            _savedRow(),
            const SizedBox(height: 22),
            Text('BROWSE ALL', style: MomzoText.eyebrow()),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                    child: _topic('Big emotions', '12 reads',
                        const [Color(0xFFFAD9A6), MomzoColors.honey])),
                const SizedBox(width: 12),
                Expanded(
                    child: _topic('Focus & calm', '9 reads',
                        const [Color(0xFFA6D6C2), MomzoColors.sage])),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _topic('Confidence', '7 reads',
                        const [Color(0xFF9CCAD6), MomzoColors.sky])),
                const SizedBox(width: 12),
                Expanded(
                    child: _topic('Screen time', '6 reads',
                        const [Color(0xFFF3B0A0), MomzoColors.coral])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filter(String label, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? MomzoColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: selected
            ? null
            : Border.all(color: MomzoColors.cardBorder, width: 1.5),
      ),
      child: Text(label,
          style: MomzoText.sans(13,
              color: selected ? Colors.white : MomzoColors.body,
              weight: FontWeight.w700)),
    );
  }

  Widget _savedRow() {
    return Container(
      padding: const EdgeInsets.all(12),
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC9B6EC), MomzoColors.lavender],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Helping a shy child make a friend',
                    style: MomzoText.sans(15,
                        color: MomzoColors.ink, weight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 5),
                Text('4 min · Confidence',
                    style: MomzoText.sans(12,
                        color: MomzoColors.muted, weight: FontWeight.w700)),
              ],
            ),
          ),
          const Icon(Icons.bookmark_rounded, color: MomzoColors.coral, size: 20),
        ],
      ),
    );
  }

  Widget _topic(String title, String count, List<Color> colors) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(13),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(title,
              style: MomzoText.sans(14, color: Colors.white, weight: FontWeight.w800)),
          Text(count,
              style: MomzoText.sans(11,
                  color: Colors.white.withOpacity(.85), weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
