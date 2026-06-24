import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';

/// 18 · Question · reveal — both answers shown side by side, a shared moment.
class DailyQuestionScreen extends StatelessWidget {
  const DailyQuestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.lavender, MomzoColors.lavenderTint, MomzoColors.cream],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 0, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 8, 26, 0),
                child: Column(
                  children: [
                    Text('QUESTION OF THE DAY · REVEALED',
                        style: MomzoText.eyebrow(color: Colors.white)
                            .copyWith(letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Text('If our family was an animal, which one would we be?',
                        textAlign: TextAlign.center,
                        style: MomzoText.serif(23, color: Colors.white, height: 1.3)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  children: [
                    _answerCard(
                      who: 'Aarav said',
                      avatarBg: MomzoColors.honeyTint,
                      avatarColor: MomzoColors.honey,
                      answer:
                          '"A pack of wolves, because we stick together and we\'re loud!" 🐺',
                    ),
                    const SizedBox(height: 14),
                    _answerCard(
                      who: 'You said',
                      avatarBg: MomzoColors.coralTint,
                      avatarColor: MomzoColors.coral,
                      answer:
                          '"Honestly? Otters. Playful, a little chaotic, always together." 🦦',
                    ),
                    const SizedBox(height: 14),
                    Text('You both picked "always together." 💜',
                        textAlign: TextAlign.center,
                        style: MomzoText.serif(15,
                            color: MomzoColors.lavenderText, italic: true)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
                child: MomzoButton('Ask tomorrow\'s together',
                    color: MomzoColors.lavender, onTap: () {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerCard({
    required String who,
    required Color avatarBg,
    required Color avatarColor,
    required String answer,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MomzoColors.lavenderText.withOpacity(.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
                child: Icon(Icons.face_rounded, color: avatarColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(who,
                  style: MomzoText.sans(15,
                      color: MomzoColors.ink, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text(answer,
              style: MomzoText.serif(19, color: const Color(0xFF5A4F49), height: 1.4)),
        ],
      ),
    );
  }
}
