import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';

/// 13 · Safety · refer-out — on a safety/medical/developmental signal, the AI
/// leads with warmth and directs to a professional. It never diagnoses.
class ReferOutScreen extends StatelessWidget {
  const ReferOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF3E9DD))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: MomzoColors.body),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: MomzoColors.sky,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Momzo expert',
                          style: MomzoText.sans(15,
                              color: MomzoColors.ink, weight: FontWeight.w800)),
                      Text('● here with care',
                          style: MomzoText.sans(11,
                              color: MomzoColors.sage, weight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 250),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: const BoxDecoration(
                        color: MomzoColors.coral,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        "He's been talking about not wanting to be here anymore and it's scaring me.",
                        style: MomzoText.sans(14.5,
                            color: Colors.white, weight: FontWeight.w600, height: 1.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _careCard(),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      "Momzo won't try to handle this one alone — and neither should you. 💛",
                      style: MomzoText.serif(13,
                          color: MomzoColors.muted, italic: true),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: MomzoButton.confirm('Find help near me', onTap: () {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _careCard() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: const Color(0xFFF0D9CD), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x0D342F30), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: MomzoColors.coralTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: MomzoColors.coral, size: 18),
                ),
                const SizedBox(width: 9),
                Text('This deserves real support',
                    style: MomzoText.sans(15,
                        color: MomzoColors.coralDeep, weight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Thank you for telling me — you're doing the right thing by taking it seriously. This is beyond what I can help with, and a person should hear it today.",
              style: MomzoText.sans(14.5,
                  color: MomzoColors.ink, weight: FontWeight.w600, height: 1.6),
            ),
            const SizedBox(height: 14),
            _resource(
              bg: MomzoColors.cream,
              title: 'Talk to your pediatrician or a child psychologist',
              titleColor: MomzoColors.ink,
              body: 'They can assess what\'s going on with care.',
              bodyColor: MomzoColors.muted,
            ),
            const SizedBox(height: 10),
            _resource(
              bg: MomzoColors.coralTint,
              title: 'If it feels urgent',
              titleColor: MomzoColors.coralDeep,
              body: "Call your local child helpline now — you don't have to wait.",
              bodyColor: MomzoColors.coralText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resource({
    required Color bg,
    required String title,
    required Color titleColor,
    required String body,
    required Color bodyColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: MomzoText.sans(13, color: titleColor, weight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(body,
              style: MomzoText.sans(12.5, color: bodyColor, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
