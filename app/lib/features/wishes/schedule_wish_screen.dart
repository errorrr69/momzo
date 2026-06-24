import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';

/// 21 · Plan a together-time — turn a wish into a scheduled moment + a tip on
/// how to make it special.
class ScheduleWishScreen extends StatefulWidget {
  const ScheduleWishScreen({super.key});

  @override
  State<ScheduleWishScreen> createState() => _ScheduleWishScreenState();
}

class _ScheduleWishScreenState extends State<ScheduleWishScreen> {
  String _day = 'Sat';
  String _time = 'After tea';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: MomzoColors.body),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Plan it in',
                      style: MomzoText.sans(16,
                          color: MomzoColors.ink, weight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: MomzoColors.honeyTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('🏰', style: TextStyle(fontSize: 34)),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("AARAV'S WISH",
                                style: MomzoText.eyebrow(color: MomzoColors.honeyText)
                                    .copyWith(letterSpacing: .5)),
                            Text('Build a giant blanket fort',
                                style: MomzoText.sans(18,
                                    color: MomzoColors.ink, weight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('WHEN WORKS?', style: MomzoText.eyebrow()),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      for (final d in ['Today', 'Sat', 'Sun']) ...[
                        Expanded(child: _choice(d, _day == d,
                            () => setState(() => _day = d))),
                        if (d != 'Sun') const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      for (final t in ['Morning', 'After tea', 'Bedtime']) ...[
                        Expanded(child: _choice(t, _time == t,
                            () => setState(() => _time = t), small: true)),
                        if (t != 'Bedtime') const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: MomzoColors.skyTint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Make it special',
                                  style: MomzoText.sans(13,
                                      color: const Color(0xFF2E6675),
                                      weight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(
                                'Let him be the "architect" — you just follow his blueprint. Kids glow when they lead.',
                                style: MomzoText.sans(13,
                                    color: const Color(0xFF3E8497),
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
              child: MomzoButton('Add to our calendar & remind me',
                  onTap: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(String label, bool sel, VoidCallback onTap, {bool small = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: small ? 11 : 13),
        decoration: BoxDecoration(
          color: sel
              ? (small ? MomzoColors.coralTint : MomzoColors.coral)
              : Colors.white,
          borderRadius: BorderRadius.circular(small ? 12 : 14),
          border: sel
              ? (small
                  ? Border.all(color: const Color(0xFFF3C7B5), width: 1.5)
                  : null)
              : Border.all(color: MomzoColors.cardBorder, width: 1.5),
          boxShadow: sel && !small
              ? [
                  BoxShadow(
                    color: MomzoColors.coral.withOpacity(.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: MomzoText.sans(13,
                color: sel
                    ? (small ? MomzoColors.coralDeep : Colors.white)
                    : (small ? MomzoColors.muted : MomzoColors.body),
                weight: small && !sel ? FontWeight.w700 : FontWeight.w800)),
      ),
    );
  }
}
