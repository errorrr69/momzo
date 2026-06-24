import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/why_it_matters.dart';
import 'daily_slides_screen.dart';

/// 07 · Daily card · read — micro-read with the signature "why it matters".
class DailyCardScreen extends StatelessWidget {
  const DailyCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleBtn(Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context)),
                  _circleBtn(Icons.bookmark_border_rounded),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DailySlidesScreen()),
                    ),
                    child: Container(
                      height: 150,
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.bottomLeft,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFAD9A6), MomzoColors.honey],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('😣 BIG EMOTIONS · 3 MIN',
                            style: MomzoText.sans(12,
                                color: MomzoColors.honeyText,
                                weight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('When "no" turns into a meltdown',
                      style: MomzoText.sans(25,
                          color: MomzoColors.ink,
                          weight: FontWeight.w900,
                          spacing: -.5,
                          height: 1.2)),
                  const SizedBox(height: 14),
                  Text(
                    "A meltdown isn't your child being \"difficult\" — it's a brain that's flooded and can't access calm yet. At 8, that part is still very much under construction.",
                    style: MomzoText.serif(16.5,
                        color: const Color(0xFF5A4F49), height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  const WhyItMatters(
                    childName: 'Aarav',
                    body:
                        "When you said no to more screen time and he crumbled — that was a flood, not defiance. Naming it out loud helps him learn to ride it.",
                  ),
                  const SizedBox(height: 16),
                  Text('Based on Momzo\'s guide on big emotions',
                      style: MomzoText.sans(13,
                          color: MomzoColors.muted, weight: FontWeight.w700)),
                ],
              ),
            ),
            // Action bar
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF3E9DD))),
              ),
              child: Row(
                children: [
                  _squareBtn(Icons.bookmark_border_rounded),
                  const SizedBox(width: 12),
                  const Expanded(child: MomzoButton.confirm('Mark as read')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Icon(icon, size: 17, color: MomzoColors.body),
      ),
    );
  }

  Widget _squareBtn(IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: MomzoColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
      ),
      child: const Icon(Icons.bookmark_border_rounded,
          size: 20, color: MomzoColors.coral),
    );
  }
}
