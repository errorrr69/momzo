import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/why_it_matters.dart';

/// 11 · Ask · grounded answer — chat with a cited source + tap-to-ask follow-ups.
class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, status: '● grounded in vetted guides'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                children: [
                  _userBubble(
                      'Aarav melted down again when I said no to the tablet. Why does this keep happening?'),
                  const SizedBox(height: 14),
                  _assistantBubble(),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _followUp("What if the warning doesn't work?"),
                      _followUp('Show me a calming activity'),
                    ],
                  ),
                ],
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, {required String status}) {
    return Container(
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
            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Momzo expert',
                  style: MomzoText.sans(15,
                      color: MomzoColors.ink, weight: FontWeight.w800)),
              Text(status,
                  style: MomzoText.sans(11,
                      color: MomzoColors.sage, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: const BoxDecoration(
          color: MomzoColors.coral,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(text,
            style: MomzoText.sans(14.5,
                color: Colors.white, weight: FontWeight.w600, height: 1.45)),
      ),
    );
  }

  Widget _assistantBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: const Color(0xFFF3E9DD)),
          boxShadow: const [
            BoxShadow(color: Color(0x0D342F30), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'At 8, the "stop and stay calm" part of the brain is still forming. Screens give a big dopamine hit, so ending them feels like a real loss to him — the meltdown is a flood, not defiance.',
              style: MomzoText.sans(14.5,
                  color: MomzoColors.ink, weight: FontWeight.w600, height: 1.55),
            ),
            const SizedBox(height: 12),
            Text('Try a 3-step landing:',
                style: MomzoText.sans(13,
                    color: MomzoColors.ink, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '1 · Give a 5-min warning   2 · Name it: "You\'re sad it\'s over"   3 · Offer the next thing to look forward to.',
              style: MomzoText.sans(13.5,
                  color: const Color(0xFF5A4F49),
                  weight: FontWeight.w600,
                  height: 1.6),
            ),
            const SizedBox(height: 12),
            const SourceChip('Based on Momzo\'s guide on big emotions'),
          ],
        ),
      ),
    );
  }

  Widget _followUp(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
      ),
      child: Text(text,
          style: MomzoText.sans(13, color: MomzoColors.ink, weight: FontWeight.w700)),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('Ask a follow-up…',
                  style: MomzoText.sans(14,
                      color: MomzoColors.faint, weight: FontWeight.w600)),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: MomzoColors.coral,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
