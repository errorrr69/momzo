import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_bottom_nav.dart';
import 'ai_chat_screen.dart';
import 'situational_screen.dart';

/// 10 · Ask · home — entry to grounded Q&A, "right now" mode, suggested asks.
class AiHomeScreen extends StatelessWidget {
  const AiHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      bottomNavigationBar: const MomzoBottomNav(MomzoTab.ask),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.skyTint, MomzoColors.cream],
            stops: [0, .42],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(26, 14, 26, 8),
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: MomzoColors.sky,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: MomzoColors.sky.withOpacity(.4),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: const Icon(Icons.chat_bubble_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 18),
                    Text.rich(
                      TextSpan(
                        text: 'Ask me anything about ',
                        style: MomzoText.serif(27, color: MomzoColors.ink, height: 1.3),
                        children: [
                          TextSpan(
                            text: 'Aarav',
                            style: MomzoText.serif(27,
                                color: MomzoColors.skyText, italic: true, height: 1.3),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Warm, expert answers grounded in vetted child-psychology — never random internet advice.',
                      style: MomzoText.sans(16,
                          color: const Color(0xFF7A6B61),
                          weight: FontWeight.w400,
                          height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    // Right now CTA
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SituationalScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MomzoColors.coralTint,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF6D2C2), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: MomzoColors.coral,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.bolt_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Something happening right now?',
                                      style: MomzoText.sans(15,
                                          color: MomzoColors.ink,
                                          weight: FontWeight.w800)),
                                  Text('Get a calm script in seconds →',
                                      style: MomzoText.sans(13,
                                          color: MomzoColors.coralText,
                                          weight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('MOMS OFTEN ASK', style: MomzoText.eyebrow()),
                    const SizedBox(height: 11),
                    _suggested(context, "Why won't he share with his cousin?"),
                    const SizedBox(height: 10),
                    _suggested(context, 'How do I make bedtime less of a battle?'),
                    const SizedBox(height: 10),
                    _suggested(context, "Is it normal that he's so shy at school?"),
                  ],
                ),
              ),
              // Composer
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: _composer(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggested(BuildContext context, String q) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiChatScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Text(q,
            style: MomzoText.sans(14, color: MomzoColors.ink, weight: FontWeight.w600)),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x14342F30), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Type your question…',
                style: MomzoText.sans(14,
                    color: MomzoColors.faint, weight: FontWeight.w600)),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MomzoColors.cream,
              shape: BoxShape.circle,
              border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
            ),
            child: const Icon(Icons.mic_none_rounded, color: MomzoColors.sky, size: 20),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiChatScreen()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: MomzoColors.coral,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
