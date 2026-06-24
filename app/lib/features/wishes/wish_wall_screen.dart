import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import 'schedule_wish_screen.dart';

/// 20 · Kid mode · Wish Wall — playful, safe, parent-unlocked surface for the
/// child's own voice. No bottom nav (simpler, safer).
class WishWallScreen extends StatelessWidget {
  const WishWallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE08A), Color(0xFFFFD0E0), Color(0xFFC9F0E2)],
            stops: [0, .5, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _badge('🔒 Kid Mode',
                        onTap: () => Navigator.pop(context)),
                    _badge('Hi Aarav! 👋'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('My Wish Wall ✨',
                  style: MomzoText.sans(30,
                      color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5, height: 1.1)),
              const SizedBox(height: 6),
              Text('What do you want to do with Mom?',
                  style: MomzoText.sans(15,
                      color: const Color(0xFF7A6B61), weight: FontWeight.w700)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  children: [
                    _wish('🏰', 'Build a giant blanket fort',
                        tag: 'Soon!', tagBg: MomzoColors.honeyTint,
                        tagColor: MomzoColors.honeyText, rotate: -1.5),
                    const SizedBox(height: 13),
                    _wish('🍪', 'Bake cookies together',
                        tag: 'Sat ✓', tagBg: MomzoColors.sageTint,
                        tagColor: const Color(0xFF4E7A60), rotate: 1),
                    const SizedBox(height: 13),
                    _wish('🌟', 'Go stargazing', rotate: -.5),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScheduleWishScreen()),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: MomzoColors.coral,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: MomzoColors.coral.withOpacity(.4),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Text('＋ Add a wish',
                        textAlign: TextAlign.center,
                        style: MomzoText.sans(18,
                            color: Colors.white, weight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style: MomzoText.sans(12,
                color: const Color(0xFF7A6B61), weight: FontWeight.w800)),
      ),
    );
  }

  Widget _wish(String emoji, String text,
      {String? tag, Color? tagBg, Color? tagColor, double rotate = 0}) {
    return Transform.rotate(
      angle: rotate * 3.14159 / 180,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Color(0x1A342F30), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 13),
            Expanded(
              child: Text(text,
                  style: MomzoText.sans(17,
                      color: MomzoColors.ink, weight: FontWeight.w800)),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(tag,
                    style: MomzoText.sans(11, color: tagColor ?? MomzoColors.ink, weight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
