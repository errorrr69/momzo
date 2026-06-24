import 'package:flutter/material.dart';
import '../theme/momzo_colors.dart';
import '../theme/momzo_spacing.dart';
import '../theme/momzo_text.dart';

/// Pill-shaped chip used for filters, tags, and multi-select intake.
/// When [selected], it fills with [accent] + a soft shadow.
class MomzoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color tint;
  final Color tintText;
  final VoidCallback? onTap;

  const MomzoChip(
    this.label, {
    super.key,
    this.selected = false,
    this.accent = MomzoColors.sage,
    this.tint = MomzoColors.white,
    this.tintText = MomzoColors.body,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : tint,
          borderRadius: BorderRadius.circular(MomzoRadius.chip),
          border: selected
              ? null
              : Border.all(color: MomzoColors.cardBorder, width: 1.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(.30),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: MomzoText.sans(14,
              color: selected ? Colors.white : tintText,
              weight: FontWeight.w700),
        ),
      ),
    );
  }
}
