import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';

/// 24 · Weekly recap — a gentle look back: what you learned, did, and one small
/// thing to try next week. Never a guilt-trip.
class WeeklyRecapScreen extends StatelessWidget {
  const WeeklyRecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.coralTint, MomzoColors.cream],
            stops: [0, .45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 14, 26, 0),
                child: Column(
                  children: [
                    Text('YOUR WEEK WITH AARAV',
                        style: MomzoText.eyebrow(color: MomzoColors.coralDeep)
                            .copyWith(letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text('A gentle look back 🌸',
                        style: MomzoText.serif(25, color: MomzoColors.ink)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  children: [
                    Row(
                      children: [
                        Expanded(child: _stat('4', 'reads', MomzoColors.coral)),
                        const SizedBox(width: 12),
                        Expanded(child: _stat('3', 'activities', MomzoColors.sage)),
                        const SizedBox(width: 12),
                        Expanded(child: _stat('5', 'moments', MomzoColors.lavender)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MomzoColors.sageTint,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What you learned',
                              style: MomzoText.sans(13,
                                  color: const Color(0xFF4E7A60),
                                  weight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            "You're getting really good at naming Aarav's feelings before fixing them.",
                            style: MomzoText.serif(16,
                                color: MomzoColors.ink, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x0F342F30),
                              blurRadius: 16,
                              offset: Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: MomzoColors.coralTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('🌱', style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('One small thing to try next week',
                                    style: MomzoText.sans(13,
                                        color: MomzoColors.ink,
                                        weight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(
                                  "Ask him what he's most proud of — he surprised the quiz!",
                                  style: MomzoText.sans(14,
                                      color: MomzoColors.body,
                                      weight: FontWeight.w600,
                                      height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
                child: MomzoButton("See this week's moments", onTap: () {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String n, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text(n,
              style: MomzoText.sans(28, color: color, weight: FontWeight.w900)),
          Text(label,
              style: MomzoText.sans(12,
                  color: MomzoColors.muted, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
