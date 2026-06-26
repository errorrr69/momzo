import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/momzo_chip.dart';
import '../../models/child.dart';
import '../../services/child_service.dart';

/// Edit a child's profile (Task 23) — keep name/age/temperament/struggles current
/// over time. Saves via ChildService.updateChild (RLS owner-only).
class EditChildScreen extends StatefulWidget {
  final Child child;
  const EditChildScreen({super.key, required this.child});

  @override
  State<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends State<EditChildScreen> {
  static const _temperaments = [
    'Shy', 'Spirited', 'A bit anxious', 'Sensitive', 'Curious', 'Easygoing'
  ];
  static const _struggles = [
    'Big emotions', "Won't share", 'Screen time', 'Focus', 'Confidence', 'Bedtime'
  ];

  late final TextEditingController _name =
      TextEditingController(text: widget.child.name);
  late int _age = widget.child.age.clamp(6, 10);
  late final Set<String> _selTemp = {...widget.child.temperament};
  late final Set<String> _selStr = {...widget.child.struggles};
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
        temperament: _selTemp.toList(),
        struggles: _selStr.toList(),
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
                      style: MomzoText.sans(20,
                          color: MomzoColors.ink, weight: FontWeight.w900)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                children: [
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
                  const SizedBox(height: 28),
                  MomzoButton(_busy ? 'Saving…' : 'Save changes',
                      onTap: _busy ? null : _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(Set<String> set, String v) {
    set.contains(v) ? set.remove(v) : set.add(v);
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
