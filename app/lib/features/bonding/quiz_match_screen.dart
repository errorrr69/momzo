import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';

/// 19 · Know-each-other · match — playful score reveal + per-question results.
class QuizMatchScreen extends StatelessWidget {
  const QuizMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text('HOW WELL DO YOU KNOW EACH OTHER?',
                            textAlign: TextAlign.center,
                            style: MomzoText.eyebrow().copyWith(letterSpacing: 1)),
                        const SizedBox(height: 16),
                        _scoreRing(),
                        const SizedBox(height: 14),
                        Text('You two really get each other 💛',
                            style: MomzoText.serif(24, color: MomzoColors.ink)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _result(
                    bg: MomzoColors.sageTint,
                    icon: Icons.check_rounded,
                    iconBg: MomzoColors.sage,
                    question: 'His favourite dinner?',
                    answer: 'You both said "pasta" ✓',
                    answerColor: const Color(0xFF4E7A60),
                  ),
                  const SizedBox(height: 11),
                  _result(
                    bg: MomzoColors.coralTint,
                    iconText: '!',
                    iconBg: MomzoColors.coral,
                    question: "What's he most proud of?",
                    answer: 'A sweet surprise — ask him! 💬',
                    answerColor: MomzoColors.coralDeep,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
              child: Row(
                children: [
                  Expanded(
                    child: MomzoSecondaryButton('See all',
                        onTap: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 13,
                    child: MomzoButton('Play again', onTap: () {}),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreRing() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: 0.8,
              strokeWidth: 13,
              backgroundColor: const Color(0xFFF4DFD3),
              valueColor: const AlwaysStoppedAnimation(MomzoColors.coral),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('8/10',
                  style: MomzoText.sans(36,
                      color: MomzoColors.coral, weight: FontWeight.w900)),
              Text('matched',
                  style: MomzoText.sans(11,
                      color: MomzoColors.muted, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _result({
    required Color bg,
    IconData? icon,
    String? iconText,
    required Color iconBg,
    required String question,
    required String answer,
    required Color answerColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 16)
                : Text(iconText ?? '',
                    style: MomzoText.sans(15,
                        color: Colors.white, weight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question,
                    style: MomzoText.sans(13,
                        color: MomzoColors.ink, weight: FontWeight.w700)),
                Text(answer,
                    style: MomzoText.sans(12,
                        color: answerColor, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
