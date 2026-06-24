import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import 'activity_detail_screen.dart';

/// 14 · Activities · time filter — the differentiator: filter by the time a
/// mom actually has (5 / 15 / 30 min) plus location.
class ActivitiesListScreen extends StatefulWidget {
  const ActivitiesListScreen({super.key});

  @override
  State<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends State<ActivitiesListScreen> {
  int _time = 5; // 5 / 15 / 30
  String _place = 'Indoor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: MomzoColors.body),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Do something together',
                style: MomzoText.sans(26,
                    color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5)),
            const SizedBox(height: 4),
            Text('How much time do you have?',
                style: MomzoText.serif(16, color: MomzoColors.muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final t in [5, 15, 30]) ...[
                  Expanded(child: _timePill(t)),
                  if (t != 30) const SizedBox(width: 9),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _placeChip('🏠 Indoor'),
                const SizedBox(width: 8),
                _placeChip('🚗 Car'),
                const SizedBox(width: 8),
                _placeChip('🍳 Kitchen'),
              ],
            ),
            const SizedBox(height: 22),
            Text('3 IDEAS FOR $_time MINUTES', style: MomzoText.eyebrow()),
            const SizedBox(height: 11),
            _activity('🌬️', 'Balloon belly breathing', 'Calm',
                '$_time min · No materials', MomzoColors.sageTint,
                const [Color(0xFFA6D6C2), MomzoColors.sage],
                const Color(0xFF4E7A60), onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivityDetailScreen()),
              );
            }),
            const SizedBox(height: 12),
            _activity('⭐', 'Three good things', 'Confidence', '$_time min',
                MomzoColors.honeyTint,
                const [Color(0xFFFAD9A6), MomzoColors.honey],
                MomzoColors.honeyText),
            const SizedBox(height: 12),
            _activity('🤝', 'Take-turns drawing', 'Sharing', '$_time min · Paper',
                MomzoColors.lavenderTint,
                const [Color(0xFFC9B6EC), MomzoColors.lavender],
                MomzoColors.lavenderText),
          ],
        ),
      ),
    );
  }

  Widget _timePill(int t) {
    final sel = t == _time;
    return GestureDetector(
      onTap: () => setState(() => _time = t),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? MomzoColors.sage : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: sel ? null : Border.all(color: MomzoColors.cardBorder, width: 1.5),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: MomzoColors.sage.withOpacity(.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Text('$t min',
            textAlign: TextAlign.center,
            style: MomzoText.sans(15,
                color: sel ? Colors.white : MomzoColors.body,
                weight: FontWeight.w800)),
      ),
    );
  }

  Widget _placeChip(String label) {
    final name = label.split(' ').last;
    final sel = name == _place;
    return GestureDetector(
      onTap: () => setState(() => _place = name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? MomzoColors.sageTint : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: sel
              ? null
              : Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Text(label,
            style: MomzoText.sans(12,
                color: sel ? const Color(0xFF4E7A60) : MomzoColors.muted,
                weight: FontWeight.w700)),
      ),
    );
  }

  Widget _activity(String emoji, String title, String tag, String meta,
      Color tagBg, List<Color> iconColors, Color tagText,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: iconColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: MomzoText.sans(15,
                          color: MomzoColors.ink, weight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tag,
                            style: MomzoText.sans(11,
                                color: tagText, weight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Text(meta,
                          style: MomzoText.sans(11,
                              color: MomzoColors.muted, weight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
