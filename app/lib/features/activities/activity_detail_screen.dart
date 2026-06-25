import 'package:flutter/material.dart';
import '../../core/theme/activity_style.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../models/activity.dart';
import '../../services/child_service.dart';
import 'activity_complete_screen.dart';

/// 15 · Activity · how to do it — simple step-by-step + one-tap "did it".
/// Renders a real Activity (Task 18); falls back to the designed sample.
class ActivityDetailScreen extends StatelessWidget {
  final Activity? activity;
  const ActivityDetailScreen({super.key, this.activity});

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final s = SkillStyle.of(a?.skill);
    final title = a?.title ?? 'Balloon belly breathing';
    final steps = a?.steps ?? const [
      'Sit together, hands on tummies.',
      'Breathe in slow — "fill the balloon" for 4 counts.',
      'Let it out slow — "the balloon flies away." Repeat 5×.',
    ];
    final mins = a?.durationMin ?? 5;
    final childName = ChildService.current?.name ?? 'your child';
    final materials = a?.materialsLabel ?? 'No materials';

    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 170 + MediaQuery.of(context).padding.top,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: s.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(18),
                child: Text(s.emoji, style: const TextStyle(fontSize: 54)),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 18,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.85), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: MomzoColors.ink),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              children: [
                Row(
                  children: [
                    _tag(s.label, s.tint, s.textColor),
                    const SizedBox(width: 7),
                    _tag('$mins min', Colors.white, MomzoColors.muted, bordered: true),
                    const SizedBox(width: 7),
                    Flexible(child: _tag(materials, Colors.white, MomzoColors.muted, bordered: true)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title,
                    style: MomzoText.sans(24,
                        color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5, height: 1.15)),
                const SizedBox(height: 10),
                Text('A little moment to enjoy together with $childName.',
                    style: MomzoText.serif(16, color: const Color(0xFF7A6B61), height: 1.5)),
                const SizedBox(height: 18),
                Text('HOW TO DO IT', style: MomzoText.eyebrow()),
                const SizedBox(height: 12),
                for (var i = 0; i < steps.length; i++) ...[
                  _step(i + 1, steps[i]),
                  if (i != steps.length - 1) const SizedBox(height: 13),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3E9DD))),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: MomzoColors.cream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                  ),
                  child: const Icon(Icons.favorite_border_rounded, color: MomzoColors.coral, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MomzoButton(
                    'We did it!',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ActivityCompleteScreen(activity: a)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg, {bool bordered = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: bordered ? Border.all(color: MomzoColors.cardBorder) : null,
      ),
      child: Text(label,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: MomzoText.sans(11, color: fg, weight: FontWeight.w700)),
    );
  }

  Widget _step(int n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: MomzoColors.sage, shape: BoxShape.circle),
          child: Text('$n', style: MomzoText.sans(14, color: Colors.white, weight: FontWeight.w800)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text,
                style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w600, height: 1.4)),
          ),
        ),
      ],
    );
  }
}
