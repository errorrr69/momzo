import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_bottom_nav.dart';
import '../daily/daily_card_screen.dart';

/// 06 · Home · Today — greeting, today's read, two quick actions.
/// One hero, never cluttered.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      bottomNavigationBar: const MomzoBottomNav(MomzoTab.home),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good morning,',
                            style: MomzoText.serif(19,
                                color: MomzoColors.muted, italic: true)),
                        Text('Priya',
                            style: MomzoText.sans(24,
                                color: MomzoColors.ink, weight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  _childSwitcher(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                children: [
                  // Gentle streak
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MomzoColors.sageTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Text('🌱', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "You've connected 3 days this week — lovely.",
                            style: MomzoText.sans(13,
                                color: const Color(0xFF5C6B5F),
                                weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("TODAY'S 3-MINUTE READ", style: MomzoText.eyebrow()),
                  const SizedBox(height: 10),
                  _todaysRead(context),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _quickAction(
                          bg: MomzoColors.skyTint,
                          fg: const Color(0xFF2E6675),
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Need help\nright now?',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickAction(
                          bg: MomzoColors.sageTint,
                          fg: const Color(0xFF3F6B52),
                          icon: Icons.timer_outlined,
                          label: "I've got\n10 minutes",
                        ),
                      ),
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

  Widget _childSwitcher() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: MomzoColors.honeyTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.face_rounded, color: MomzoColors.honey, size: 18),
          ),
          const SizedBox(width: 7),
          Text('Aarav',
              style: MomzoText.sans(14,
                  color: MomzoColors.ink, weight: FontWeight.w800)),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: MomzoColors.faint, size: 18),
        ],
      ),
    );
  }

  Widget _todaysRead(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E9DD)),
        boxShadow: const [
          BoxShadow(color: Color(0x14342F30), blurRadius: 26, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 104,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFAD9A6), MomzoColors.honey],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.favorite_rounded, color: Colors.white70, size: 44),
            ),
          ),
          const SizedBox(height: 16),
          Text('When "no" turns into a meltdown',
              style: MomzoText.sans(21,
                  color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.3, height: 1.25)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: MomzoColors.coralTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text.rich(
              TextSpan(
                text: 'Why this matters for Aarav · ',
                style: MomzoText.sans(12,
                    color: MomzoColors.coralDeep, weight: FontWeight.w700),
                children: [
                  TextSpan(
                    text:
                        "He's still learning to ride big feelings without melting down.",
                    style: MomzoText.sans(13,
                        color: MomzoColors.coralText,
                        weight: FontWeight.w600,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyCardScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: MomzoColors.coral,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text("Read today's card",
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(15,
                      color: Colors.white, weight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required Color bg,
    required Color fg,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(height: 8),
          Text(label,
              style: MomzoText.sans(14, color: fg, weight: FontWeight.w800, height: 1.2)),
        ],
      ),
    );
  }
}
