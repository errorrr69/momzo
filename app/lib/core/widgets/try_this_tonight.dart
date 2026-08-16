import 'package:flutter/material.dart';
import '../theme/momzo_colors.dart';
import '../theme/momzo_text.dart';

/// The closing move of every card (00_CARD_SPEC §7): one thing to try, tonight,
/// inside a routine that already exists. Sage-tinted, so it reads as the calm
/// counterpart to the coral "why this matters" block above it.
///
/// Shared by the daily card and the library reader — the structure is fixed, so
/// the two surfaces must not drift into drawing it differently.
class TryThisTonight extends StatelessWidget {
  final String body;
  const TryThisTonight(this.body, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: MomzoColors.sageTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRY THIS TONIGHT',
              style: MomzoText.eyebrow(color: MomzoColors.sageText)
                  .copyWith(letterSpacing: .4)),
          const SizedBox(height: 9),
          Text(body,
              style: MomzoText.sans(14,
                  color: MomzoColors.sageText, weight: FontWeight.w600, height: 1.5)),
        ],
      ),
    );
  }
}
