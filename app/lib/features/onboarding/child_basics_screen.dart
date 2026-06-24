import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import 'child_temperament_screen.dart';

/// 03 · About your child — name, photo, age. Step 1 of 3.
class ChildBasicsScreen extends StatefulWidget {
  const ChildBasicsScreen({super.key});

  @override
  State<ChildBasicsScreen> createState() => _ChildBasicsScreenState();
}

class _ChildBasicsScreenState extends State<ChildBasicsScreen> {
  int _age = 8;
  final _name = TextEditingController(text: 'Aarav');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const _StepDots(step: 1),
              const SizedBox(height: 24),
              Text('Who are we\ngetting to know?',
                  style: MomzoText.sans(27,
                      color: MomzoColors.ink, weight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 8),
              Text("This shapes everything you'll see.",
                  style: MomzoText.serif(17, color: MomzoColors.muted, height: 1.4)),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            color: MomzoColors.honeyTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.face_rounded,
                              color: MomzoColors.honey, size: 44),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: MomzoColors.coral,
                              shape: BoxShape.circle,
                              border: Border.all(color: MomzoColors.cream, width: 3),
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Add a photo (optional)',
                        style: MomzoText.sans(13,
                            color: MomzoColors.muted, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Name or nickname',
                  style: MomzoText.sans(13,
                      color: MomzoColors.muted, weight: FontWeight.w700)),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                ),
                child: TextField(
                  controller: _name,
                  style: MomzoText.sans(16,
                      color: MomzoColors.ink, weight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('How old are they?',
                  style: MomzoText.sans(13,
                      color: MomzoColors.muted, weight: FontWeight.w700)),
              const SizedBox(height: 9),
              Row(
                children: [
                  for (final age in [6, 7, 8, 9, 10]) ...[
                    Expanded(child: _agePill(age)),
                    if (age != 10) const SizedBox(width: 8),
                  ],
                ],
              ),
              const Spacer(),
              MomzoButton(
                'Next',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ChildTemperamentScreen(childName: _name.text)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agePill(int age) {
    final selected = age == _age;
    return GestureDetector(
      onTap: () => setState(() => _age = age),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? MomzoColors.coral : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? MomzoColors.coral : MomzoColors.cardBorder,
              width: 1.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: MomzoColors.coral.withOpacity(.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Text('$age',
            textAlign: TextAlign.center,
            style: MomzoText.sans(16,
                color: selected ? Colors.white : MomzoColors.faint,
                weight: FontWeight.w800)),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int step; // 1-based
  const _StepDots({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 1; i <= 3; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= step ? MomzoColors.coral : const Color(0xFFF6D9C8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (i != 3) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
