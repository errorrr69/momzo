import 'package:flutter/material.dart';
import '../theme/momzo_colors.dart';
import '../theme/momzo_spacing.dart';
import '../theme/momzo_text.dart';

/// Full-width, thumb-friendly primary action. Soft coloured shadow.
class MomzoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;

  const MomzoButton(
    this.label, {
    super.key,
    this.onTap,
    this.color = MomzoColors.coral,
    this.icon,
  });

  /// Sage "confirm" variant (e.g. "Mark as read", "We did it!").
  const MomzoButton.confirm(this.label, {super.key, this.onTap, this.icon})
      : color = MomzoColors.sage;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(MomzoRadius.button),
          boxShadow: MomzoShadow.coloured(color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: MomzoText.sans(16,
                    color: Colors.white, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined secondary action on the warm canvas.
class MomzoSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const MomzoSecondaryButton(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: MomzoColors.white,
          borderRadius: BorderRadius.circular(MomzoRadius.button),
          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w800),
        ),
      ),
    );
  }
}
