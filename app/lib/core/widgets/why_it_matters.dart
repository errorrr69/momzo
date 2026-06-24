import 'package:flutter/material.dart';
import '../theme/momzo_colors.dart';
import '../theme/momzo_text.dart';

/// The signature element: ties a lesson to a behaviour the mom sees at home.
/// Coral-tinted, left coral accent bar.
class WhyItMatters extends StatelessWidget {
  final String childName;
  final String body;

  const WhyItMatters({super.key, required this.childName, required this.body});

  @override
  Widget build(BuildContext context) {
    // A left accent bar via a clipped Row (a left-only Border with a
    // borderRadius is illegal in Flutter and throws at paint time).
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: MomzoColors.coralTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: MomzoColors.coral),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHY THIS MATTERS FOR ${childName.toUpperCase()}',
                    style: MomzoText.eyebrow(color: MomzoColors.coralDeep)
                        .copyWith(letterSpacing: .5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: MomzoText.sans(15,
                        color: MomzoColors.coralText,
                        weight: FontWeight.w600,
                        height: 1.5),
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

/// Trust chip shown under every AI answer ("Based on Momzo's guide on …").
class SourceChip extends StatelessWidget {
  final String label;
  const SourceChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MomzoColors.skyTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 15, color: MomzoColors.skyText),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: MomzoText.sans(12,
                  color: MomzoColors.skyText, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
