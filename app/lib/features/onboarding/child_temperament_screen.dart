import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/momzo_chip.dart';
import 'all_set_screen.dart';

/// 04 · Temperament & focus — multi-select intake. Step 2 of 3.
class ChildTemperamentScreen extends StatefulWidget {
  final String childName;
  const ChildTemperamentScreen({super.key, required this.childName});

  @override
  State<ChildTemperamentScreen> createState() => _ChildTemperamentScreenState();
}

class _ChildTemperamentScreenState extends State<ChildTemperamentScreen> {
  final _temperaments = const [
    'Shy', 'Spirited', 'A bit anxious', 'Sensitive', 'Curious', 'Easygoing'
  ];
  final _struggles = const [
    'Big emotions', "Won't share", 'Screen time', 'Focus', 'Confidence', 'Bedtime'
  ];
  final _selTemp = {'Shy', 'A bit anxious'};
  final _selStr = {'Big emotions', 'Screen time'};

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
              Row(
                children: [
                  for (int i = 1; i <= 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= 2
                              ? MomzoColors.coral
                              : const Color(0xFFF6D9C8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    if (i != 3) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Text("What's ${widget.childName}\nlike lately?",
                  style: MomzoText.sans(27,
                      color: MomzoColors.ink, weight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 8),
              Text('Pick a few. You can change these anytime.',
                  style: MomzoText.serif(17, color: MomzoColors.muted, height: 1.4)),
              const SizedBox(height: 24),
              Text('TEMPERAMENT', style: MomzoText.eyebrow()),
              const SizedBox(height: 11),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final t in _temperaments)
                    MomzoChip(
                      t,
                      selected: _selTemp.contains(t),
                      accent: MomzoColors.lavender,
                      tint: MomzoColors.lavenderTint,
                      tintText: MomzoColors.body,
                      onTap: () => setState(() => _toggle(_selTemp, t)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text("WHAT YOU'D LOVE HELP WITH", style: MomzoText.eyebrow()),
              const SizedBox(height: 11),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final s in _struggles)
                    MomzoChip(
                      s,
                      selected: _selStr.contains(s),
                      accent: MomzoColors.sage,
                      tint: MomzoColors.sageTint,
                      tintText: const Color(0xFF5C6B5F),
                      onTap: () => setState(() => _toggle(_selStr, s)),
                    ),
                ],
              ),
              const Spacer(),
              MomzoButton(
                'Next',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AllSetScreen(childName: widget.childName)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(Set<String> set, String v) {
    set.contains(v) ? set.remove(v) : set.add(v);
  }
}
