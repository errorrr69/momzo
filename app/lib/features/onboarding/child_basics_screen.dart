import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../models/child.dart';
import '../../services/child_service.dart';
import '../../services/onboarding_service.dart';
import 'onboarding_flow_screen.dart';

/// 03 · About your child — name, photo, age. Step 1 of 3.
class ChildBasicsScreen extends StatefulWidget {
  /// When true this is "add another child" (from the home switcher), not first-run
  /// onboarding — so it saves and returns to the app instead of the all-set screen.
  final bool addAnother;
  const ChildBasicsScreen({super.key, this.addAnother = false});

  @override
  State<ChildBasicsScreen> createState() => _ChildBasicsScreenState();
}

class _ChildBasicsScreenState extends State<ChildBasicsScreen> {
  int _age = 8;
  bool _busy = false;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a name or nickname.')),
      );
      return;
    }
    final name = _name.text.trim();
    setState(() => _busy = true);
    try {
      Child child;
      if (AppEnv.hasSupabase) {
        child = await ChildService.createChild(name: name, age: _age);
        await OnboardingService.saveStep(1, childId: child.id);
      } else {
        child = Child(id: 'preview', name: name, age: _age); // UI-only preview
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingFlowScreen(child: child, addAnother: widget.addAnother),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save just now. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        value: 1 / 8,
                        minHeight: 6,
                        backgroundColor: Color(0xFFF6D9C8),
                        color: MomzoColors.coral,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('1 of 8',
                      style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w800)),
                ],
              ),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final age in [4, 5, 6, 7, 8, 9, 10]) _agePill(age)],
              ),
              const Spacer(),
              MomzoButton(_busy ? 'Saving…' : 'Next', onTap: _busy ? null : _next),
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
        width: 44,
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
