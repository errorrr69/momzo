import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/momzo_chip.dart';
import '../../models/child.dart';
import '../../services/child_service.dart';

/// Edit a child's profile — keep name/age/goals/challenges/interests current over
/// time (Onboarding Spec §7). Edits re-target content + AI from the next request.
class EditChildScreen extends StatefulWidget {
  final Child child;
  const EditChildScreen({super.key, required this.child});

  @override
  State<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends State<EditChildScreen> {
  static const _focusOpts = [
    'Handling big feelings', 'Confidence & self-belief', 'Focus & attention', 'Kindness & sharing',
    'Independence & responsibility', 'Love of learning & curiosity', 'Friendships & social skills',
    'Calmer routines (sleep / meals / mornings)', 'Screen-time balance', 'Creativity & imagination',
  ];
  static const _challengeOpts = [
    'Big emotions / meltdowns', 'Takes a while to warm up / shy', 'Lots of energy, hard to settle',
    'Gets frustrated easily', 'Sharing & taking turns', 'Listening & following directions',
    'Worries or nervousness', 'Changes & transitions are hard', 'Sibling moments',
    'Honestly, nothing major right now',
  ];
  static const _interestOpts = [
    'Drawing & art', 'Building (blocks / Lego)', 'Sports & active play', 'Music & dancing',
    'Animals & nature', 'Books & stories', 'Pretend & imaginative play', 'Puzzles & games',
    'How things work / science', 'Video games & screens', 'Cooking & helping out',
  ];

  late final TextEditingController _name = TextEditingController(text: widget.child.name);
  late int _age = widget.child.age.clamp(4, 10);
  late final Set<String> _focus = {...widget.child.focusGoals};
  late final Set<String> _challenges = {...widget.child.challenges};
  late final Set<String> _interests = {...widget.child.interests};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) {
      _toast('Please add a name or nickname.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ChildService.updateChild(
        id: widget.child.id,
        name: _name.text.trim(),
        age: _age,
        focusGoals: _focus.toList(),
        challenges: _challenges.toList(),
        interests: _interests.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      _toast('Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: MomzoColors.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text('Edit profile',
                      style: MomzoText.sans(20, color: MomzoColors.ink, weight: FontWeight.w900)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                children: [
                  Text('Name or nickname',
                      style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w700)),
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
                      style: MomzoText.sans(16, color: MomzoColors.ink, weight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('How old are they?',
                      style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w700)),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final age in [4, 5, 6, 7, 8, 9, 10]) _agePill(age)],
                  ),
                  const SizedBox(height: 24),
                  _chipGroup("WHAT YOU'D LOVE TO HELP WITH", _focusOpts, _focus,
                      MomzoColors.sage, MomzoColors.sageTint),
                  const SizedBox(height: 24),
                  _chipGroup("WHAT'S A BIT TRICKY", _challengeOpts, _challenges,
                      MomzoColors.coral, MomzoColors.coralTint),
                  const SizedBox(height: 24),
                  _chipGroup('WHAT THEY LOVE', _interestOpts, _interests,
                      MomzoColors.honey, MomzoColors.honeyTint),
                  const SizedBox(height: 28),
                  MomzoButton(_busy ? 'Saving…' : 'Save changes', onTap: _busy ? null : _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipGroup(String title, List<String> opts, Set<String> sel, Color accent, Color tint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: MomzoText.eyebrow()),
        const SizedBox(height: 11),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final o in opts)
              MomzoChip(
                o,
                selected: sel.contains(o),
                accent: accent,
                tint: tint,
                tintText: MomzoColors.body,
                onTap: () => setState(() => sel.contains(o) ? sel.remove(o) : sel.add(o)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _agePill(int age) {
    final selected = age == _age;
    return GestureDetector(
      onTap: () => setState(() => _age = age),
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? MomzoColors.coral : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? MomzoColors.coral : MomzoColors.cardBorder, width: 1.5),
        ),
        child: Text('$age',
            textAlign: TextAlign.center,
            style: MomzoText.sans(16,
                color: selected ? Colors.white : MomzoColors.faint, weight: FontWeight.w800)),
      ),
    );
  }
}
