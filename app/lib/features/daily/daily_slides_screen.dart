import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';

/// 08 · Card · slide format — swipeable, focused carousel for bite-sized lessons.
class DailySlidesScreen extends StatefulWidget {
  const DailySlidesScreen({super.key});

  @override
  State<DailySlidesScreen> createState() => _DailySlidesScreenState();
}

class _DailySlidesScreenState extends State<DailySlidesScreen> {
  static const _total = 4;
  int _index = 1; // 0-based; showing slide 2

  void _next() => setState(() => _index = (_index + 1) % _total);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E2A33),
      body: SafeArea(
        child: GestureDetector(
          onTap: _next,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Progress segments
                Row(
                  children: [
                    for (int i = 0; i < _total; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _index
                                ? Colors.white
                                : Colors.white.withOpacity(.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i != _total - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: MomzoColors.lavender,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text('${_index + 1}',
                              style: MomzoText.sans(30,
                                  color: Colors.white, weight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 30),
                        Text.rich(
                          TextSpan(
                            text: 'Name the feeling ',
                            style: MomzoText.serif(32,
                                color: Colors.white, height: 1.3),
                            children: [
                              TextSpan(
                                text: 'before',
                                style: MomzoText.serif(32,
                                    color: const Color(0xFFF5C76B),
                                    italic: true,
                                    height: 1.3),
                              ),
                              const TextSpan(text: ' you fix the problem.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '"You really wanted more time, and stopping felt unfair." Naming lowers the storm faster than logic ever will.',
                          style: MomzoText.sans(17,
                              color: const Color(0xFFC7C0D0),
                              weight: FontWeight.w400,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tap to continue',
                          style: MomzoText.sans(13,
                              color: const Color(0xFF8C8497),
                              weight: FontWeight.w700)),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: MomzoColors.coral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
