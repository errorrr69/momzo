import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_bottom_nav.dart';

/// 22 · Calendar · together-time — upcoming bonding moments & activities.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      bottomNavigationBar: const MomzoBottomNav(MomzoTab.together),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
          children: [
            Text('Our together-times',
                style: MomzoText.sans(26,
                    color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5)),
            const SizedBox(height: 14),
            _monthCard(),
            const SizedBox(height: 18),
            Text('COMING UP', style: MomzoText.eyebrow()),
            const SizedBox(height: 11),
            _event('21', 'SAT', 'Blanket fort 🏰',
                "After tea · from Aarav's wishes", MomzoColors.coral),
            const SizedBox(height: 12),
            _event('27', 'FRI', 'Stargazing 🌟', 'Bedtime · weather permitting',
                MomzoColors.lavender),
          ],
        ),
      ),
    );
  }

  Widget _monthCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('June 2026',
                  style: MomzoText.sans(15,
                      color: MomzoColors.ink, weight: FontWeight.w800)),
              const Row(
                children: [
                  Icon(Icons.chevron_left_rounded, color: MomzoColors.faint),
                  SizedBox(width: 14),
                  Icon(Icons.chevron_right_rounded, color: MomzoColors.faint),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 5,
            childAspectRatio: 1.2,
            children: [
              for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Center(
                  child: Text(d,
                      style: MomzoText.sans(10,
                          color: MomzoColors.faint, weight: FontWeight.w800)),
                ),
              for (final d in [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29])
                _day(d),
            ],
          ),
        ],
      ),
    );
  }

  Widget _day(int d) {
    Color? bg;
    Color fg = MomzoColors.muted;
    if (d == 21) {
      bg = MomzoColors.coral;
      fg = Colors.white;
    } else if (d == 27) {
      bg = MomzoColors.lavender;
      fg = Colors.white;
    } else if (d == 19) {
      bg = MomzoColors.cream;
      fg = MomzoColors.ink;
    }
    return Center(
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: bg == null
            ? null
            : BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text('$d',
            style: MomzoText.sans(12,
                color: fg,
                weight: (d == 21 || d == 27) ? FontWeight.w800 : FontWeight.w700)),
      ),
    );
  }

  Widget _event(String day, String dow, String title, String sub, Color accent) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(day,
                          style: MomzoText.sans(20,
                              color: accent, weight: FontWeight.w900, height: 1)),
                      Text(dow,
                          style: MomzoText.sans(10,
                              color: MomzoColors.muted, weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: MomzoText.sans(15,
                                color: MomzoColors.ink, weight: FontWeight.w800)),
                        Text(sub,
                            style: MomzoText.sans(12,
                                color: MomzoColors.muted, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
