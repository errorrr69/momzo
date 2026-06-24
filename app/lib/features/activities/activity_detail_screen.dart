import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import 'activity_complete_screen.dart';

/// 15 · Activity · how to do it — simple step-by-step + one-tap "did it".
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: Column(
        children: [
          // Hero image
          Stack(
            children: [
              Container(
                height: 170 + MediaQuery.of(context).padding.top,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFA6D6C2), MomzoColors.sage],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(18),
                child: const Text('🌬️', style: TextStyle(fontSize: 54)),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 18,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: MomzoColors.ink),
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
                    _tag('Calm', MomzoColors.sageTint, const Color(0xFF4E7A60)),
                    const SizedBox(width: 7),
                    _tag('5 min', Colors.white, MomzoColors.muted, bordered: true),
                    const SizedBox(width: 7),
                    _tag('No materials', Colors.white, MomzoColors.muted,
                        bordered: true),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Balloon belly breathing',
                    style: MomzoText.sans(24,
                        color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5, height: 1.15)),
                const SizedBox(height: 10),
                Text(
                  'A 5-minute reset that teaches Aarav to settle his own big feelings.',
                  style: MomzoText.serif(16, color: const Color(0xFF7A6B61), height: 1.5),
                ),
                const SizedBox(height: 18),
                Text('HOW TO DO IT', style: MomzoText.eyebrow()),
                const SizedBox(height: 12),
                _step(1, 'Sit together, hands on tummies.'),
                const SizedBox(height: 13),
                _step(2, 'Breathe in slow — "fill the balloon" for 4 counts.'),
                const SizedBox(height: 13),
                _step(3, 'Let it out slow — "the balloon flies away." Repeat 5×.'),
              ],
            ),
          ),
          // Action bar
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
                  child: const Icon(Icons.favorite_border_rounded,
                      color: MomzoColors.coral, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MomzoButton(
                    'We did it!',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ActivityCompleteScreen()),
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
          decoration: const BoxDecoration(
            color: MomzoColors.sage,
            shape: BoxShape.circle,
          ),
          child: Text('$n',
              style: MomzoText.sans(14, color: Colors.white, weight: FontWeight.w800)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text,
                style: MomzoText.sans(15,
                    color: MomzoColors.ink, weight: FontWeight.w600, height: 1.4)),
          ),
        ),
      ],
    );
  }
}
