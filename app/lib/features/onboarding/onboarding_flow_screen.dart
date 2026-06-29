import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/momzo_chip.dart';
import '../../models/child.dart';
import '../../services/child_service.dart';
import '../../services/onboarding_service.dart';
import '../../services/profile_service.dart';
import 'all_set_screen.dart';

/// Core onboarding questions Q2–Q8 (Onboarding & Personalization Spec §3). One
/// question per screen, progress "N of 8". The child was created at Q1 (basics);
/// each step updates the child/profile + saves resumable state, so a mom who drops
/// can pick up where she left off. Mostly taps; sliders for temperament; a time
/// picker for the daily moment.
class OnboardingFlowScreen extends StatefulWidget {
  final Child child;
  final bool addAnother;
  final int startStep; // resume target (2..8); defaults to 2
  const OnboardingFlowScreen({
    super.key,
    required this.child,
    this.addAnother = false,
    this.startStep = 2,
  });

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  late int _step = widget.startStep.clamp(2, 8);
  bool _busy = false;

  // Answers (prefilled from the child/profile so resume shows saved choices).
  late String? _time;
  late final Set<String> _focus = {...widget.child.focusGoals};
  late final Set<String> _challenges = {...widget.child.challenges};
  late final Set<String> _interests = {...widget.child.interests};
  late final Map<String, double> _temp = {
    'warmup': widget.child.temperament['warmup'] ?? 0.5,
    'energy': widget.child.temperament['energy'] ?? 0.5,
    'expressive': widget.child.temperament['expressive'] ?? 0.5,
    'social': widget.child.temperament['social'] ?? 0.5,
  };
  TimeOfDay _nudge = const TimeOfDay(hour: 8, minute: 0);
  int _quietStart = 21, _quietEnd = 7;
  final Set<String> _momGoals = {};

  String get _name => widget.child.name;

  @override
  void initState() {
    super.initState();
    _time = null;
    ProfileService.load().then((p) {
      if (!mounted || p == null) return;
      setState(() => _time = p['time_with_child'] as String?);
    });
  }

  // ---- options ----
  static const _timeOpts = ['Under 15 minutes', 'About half an hour', 'An hour or more', 'It really varies'];
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
  static const _winOpts = [
    'Feel closer to', 'Understand them better', 'Learn practical tools',
    'Have nice things to do together', 'Feel less stressed or guilty', 'Build better routines',
  ];

  Future<void> _next() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _persistCurrent();
    } catch (_) {/* best-effort; let her keep going */}
    if (!mounted) return;
    setState(() => _busy = false);
    if (_step < 8) {
      setState(() => _step++);
    } else {
      await _finish();
    }
  }

  // Save just this step's answer, then bump resumable state.
  Future<void> _persistCurrent() async {
    switch (_step) {
      case 2:
        if (_time != null) await ProfileService.save(timeWithChild: _time);
        break;
      case 3:
        await ChildService.updateChild(id: widget.child.id, focusGoals: _focus.toList());
        break;
      case 4:
        await ChildService.updateChild(id: widget.child.id, challenges: _challenges.toList());
        break;
      case 5:
        await ChildService.updateChild(id: widget.child.id, interests: _interests.toList());
        break;
      case 6:
        await ChildService.updateChild(id: widget.child.id, temperament: _temp);
        break;
      case 7:
        await ProfileService.save(
          dailyNudgeTime: '${_two(_nudge.hour)}:${_two(_nudge.minute)}',
          quietHours: {'start': _quietStart, 'end': _quietEnd},
        );
        break;
    }
    if (!widget.addAnother) await OnboardingService.saveStep(_step, childId: widget.child.id);
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await ProfileService.save(momGoals: _momGoals.toList());
      if (!widget.addAnother) await OnboardingService.complete(childId: widget.child.id);
    } catch (_) {/* non-fatal */}
    if (!mounted) return;
    if (widget.addAnother) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AllSetScreen(childName: _name)),
      );
    }
  }

  void _back() {
    if (_step > 2) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  bool get _canAdvance {
    switch (_step) {
      case 2:
        return _time != null;
      case 3:
        return _focus.isNotEmpty;
      case 8:
        return _momGoals.isNotEmpty;
      default:
        return true; // Q4/Q5/Q6/Q7 always advanceable (optional/has defaults)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  GestureDetector(
                    onTap: _back,
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: MomzoColors.body),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: _progress()),
                  const SizedBox(width: 14),
                  Text('$_step of 8',
                      style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(child: SingleChildScrollView(child: _question())),
              MomzoButton(
                _busy ? 'Saving…' : (_step == 8 ? 'Finish' : 'Next'),
                onTap: (_busy || !_canAdvance) ? null : _next,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (_step - 1) / 7,
          minHeight: 6,
          backgroundColor: const Color(0xFFF6D9C8),
          color: MomzoColors.coral,
        ),
      );

  Widget _question() {
    switch (_step) {
      case 2:
        return _single(
          'How much time do you usually get with $_name in a day?',
          'So suggestions feel doable — never one more thing to fail at.',
          _timeOpts, _time, (v) => setState(() => _time = v));
      case 3:
        return _multi(
          'What would you love to help $_name with right now?',
          'This shapes the tips and activities you see first. Pick up to 3.',
          _focusOpts, _focus, max: 3, accent: MomzoColors.sage, tint: MomzoColors.sageTint);
      case 4:
        return _multi(
          'What feels a bit tricky at the moment?',
          'Everyday tags to tailor content — never a label on $_name.',
          _challengeOpts, _challenges, accent: MomzoColors.coral, tint: MomzoColors.coralTint);
      case 5:
        return _multi(
          'What does $_name love?',
          'So activities, games, and examples feel personal to $_name.',
          _interestOpts, _interests, accent: MomzoColors.honey, tint: MomzoColors.honeyTint);
      case 6:
        return _sliders();
      case 7:
        return _timeStep();
      case 8:
        return _multi(
          'What would feel like a win for you?',
          'We’ll lean the app toward your goal. Pick up to 2.',
          _winOpts, _momGoals, max: 2, accent: MomzoColors.lavender, tint: MomzoColors.lavenderTint,
          suffix: (o) => o == 'Feel closer to' ? ' $_name' : '');
    }
    return const SizedBox.shrink();
  }

  Widget _header(String title, String why) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MomzoText.sans(25, color: MomzoColors.ink, weight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 8),
          Text(why, style: MomzoText.serif(15, color: MomzoColors.muted, height: 1.4)),
          const SizedBox(height: 20),
        ],
      );

  Widget _single(String title, String why, List<String> opts, String? sel, ValueChanged<String> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(title, why),
        for (final o in opts) ...[
          GestureDetector(
            onTap: () => onPick(o),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: sel == o ? MomzoColors.coral : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: sel == o ? MomzoColors.coral : MomzoColors.cardBorder, width: 1.5),
              ),
              child: Text(o,
                  style: MomzoText.sans(15,
                      color: sel == o ? Colors.white : MomzoColors.body, weight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _multi(
    String title,
    String why,
    List<String> opts,
    Set<String> sel, {
    int? max,
    required Color accent,
    required Color tint,
    String Function(String)? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(title, why),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final o in opts)
              MomzoChip(
                '$o${suffix?.call(o) ?? ''}',
                selected: sel.contains(o),
                accent: accent,
                tint: tint,
                tintText: MomzoColors.body,
                onTap: () => setState(() {
                  if (sel.contains(o)) {
                    sel.remove(o);
                  } else if (max == null || sel.length < max) {
                    sel.add(o);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sliders() {
    final dims = [
      ('warmup', 'Warms up to new things', 'slowly', 'dives right in'),
      ('energy', 'Energy', 'calm & cozy', 'always on the go'),
      ('expressive', 'Feelings', 'keeps them in', 'shows them big'),
      ('social', 'Play', 'happy on their own', 'loves company'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('A little about $_name', 'No right answer — every kid’s different. This tunes the tone.'),
        for (final d in dims) ...[
          Text(d.$2, style: MomzoText.sans(14, color: MomzoColors.ink, weight: FontWeight.w800)),
          Slider(
            value: _temp[d.$1]!,
            activeColor: MomzoColors.lavender,
            onChanged: (v) => setState(() => _temp[d.$1] = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(d.$3, style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
              Text(d.$4, style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _timeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('When should we send your daily moment?',
            'One 5-minute thing for $_name at this time. Change it anytime.'),
        GestureDetector(
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _nudge, helpText: 'Daily moment');
            if (t != null) setState(() => _nudge = t);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: MomzoColors.coral),
                const SizedBox(width: 12),
                Text(_nudge.format(context),
                    style: MomzoText.sans(18, color: MomzoColors.ink, weight: FontWeight.w900)),
                const Spacer(),
                Text('Tap to change', style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('QUIET HOURS', style: MomzoText.eyebrow()),
        const SizedBox(height: 8),
        Text('No pings between these hours.',
            style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _quietPill('From', _quietStart, (h) => setState(() => _quietStart = h))),
            const SizedBox(width: 10),
            Expanded(child: _quietPill('To', _quietEnd, (h) => setState(() => _quietEnd = h))),
          ],
        ),
      ],
    );
  }

  Widget _quietPill(String label, int hour, ValueChanged<int> onPick) {
    final disp = TimeOfDay(hour: hour, minute: 0).format(context);
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(
            context: context, initialTime: TimeOfDay(hour: hour, minute: 0), helpText: 'Quiet hours $label');
        if (t != null) onPick(t.hour);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Text(label, style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
            const Spacer(),
            Text(disp, style: MomzoText.sans(14, color: MomzoColors.ink, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
