import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../services/auth_service.dart';
import '../../services/child_service.dart';
import '../../services/notification_service.dart';
import '../onboarding/delete_child_screen.dart';
import '../onboarding/welcome_screen.dart';
import '../timeline/memory_timeline_screen.dart';

/// 25 · Reminders & quiet hours — the mom is always in control of when & how
/// often. Tone is kind, never a guilt-trip (Hard Rule #18). Persists to her
/// profile; the server dispatcher honours these (Task 20).
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

const _slotToLabel = {'morning': 'Morning', 'noon': 'Noon', 'evening': 'Evening'};
const _labelToSlot = {'Morning': 'morning', 'Noon': 'noon', 'Evening': 'evening'};

class _RemindersScreenState extends State<RemindersScreen> {
  bool _dailyNudge = true;
  String _bestTime = 'Morning';
  int? _quietStart = 21;
  int? _quietEnd = 7;

  bool get _live => AppEnv.hasSupabase;

  @override
  void initState() {
    super.initState();
    if (_live) _load();
  }

  Future<void> _load() async {
    final p = await NotificationService.load();
    if (!mounted) return;
    setState(() {
      _dailyNudge = p.dailyNudge;
      _bestTime = _slotToLabel[p.nudgeSlot] ?? 'Morning';
      _quietStart = p.quietStart;
      _quietEnd = p.quietEnd;
    });
  }

  String _fmtHour(int? h) {
    if (h == null) return '—';
    final am = h < 12;
    final hr = h % 12 == 0 ? 12 : h % 12;
    return '$hr:00 ${am ? 'AM' : 'PM'}';
  }

  Future<void> _editQuietHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _quietStart ?? 21, minute: 0),
      helpText: 'Quiet hours start',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _quietEnd ?? 7, minute: 0),
      helpText: 'Quiet hours end',
    );
    if (end == null) return;
    setState(() {
      _quietStart = start.hour;
      _quietEnd = end.hour;
    });
    if (_live) NotificationService.save(quietStart: start.hour, quietEnd: end.hour);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
          children: [
            Text('Gentle nudges',
                style: MomzoText.sans(26,
                    color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5)),
            Text("You're always in control of when & how often.",
                style: MomzoText.serif(15, color: MomzoColors.muted)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoryTimelineScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC9B6EC), MomzoColors.lavender],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your moments',
                              style: MomzoText.sans(15, color: Colors.white, weight: FontWeight.w900)),
                          Text('A private keepsake of photos & notes',
                              style: MomzoText.sans(12,
                                  color: Colors.white.withValues(alpha: .9), weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Daily nudge toggle
            _card(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily nudge',
                            style: MomzoText.sans(15,
                                color: MomzoColors.ink, weight: FontWeight.w800)),
                        Text('A kind reminder — never a guilt-trip',
                            style: MomzoText.sans(12,
                                color: MomzoColors.muted, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  _toggle(_dailyNudge, MomzoColors.sage, () {
                    setState(() => _dailyNudge = !_dailyNudge);
                    if (_live) NotificationService.save(dailyNudge: _dailyNudge);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 13),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Best time to reach you',
                      style: MomzoText.sans(13,
                          color: MomzoColors.ink, weight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final t in ['Morning', 'Noon', 'Evening']) ...[
                        Expanded(child: _timePill(t)),
                        if (t != 'Evening') const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            GestureDetector(
              onTap: _editQuietHours,
              behavior: HitTestBehavior.opaque,
              child: _card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quiet hours',
                              style: MomzoText.sans(15,
                                  color: MomzoColors.ink, weight: FontWeight.w800)),
                          Text(
                              (_quietStart == null || _quietEnd == null)
                                  ? 'Off · tap to set'
                                  : '${_fmtHour(_quietStart)} – ${_fmtHour(_quietEnd)} · no pings',
                              style: MomzoText.sans(12,
                                  color: MomzoColors.muted, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: MomzoColors.faint, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text('Account',
                style: MomzoText.sans(13,
                    color: MomzoColors.muted, weight: FontWeight.w800)),
            const SizedBox(height: 10),
            // Delete the child's profile + all data (COPPA: a parent can erase anytime).
            GestureDetector(
              onTap: _openDeleteChild,
              behavior: HitTestBehavior.opaque,
              child: _card(
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        color: MomzoColors.coral, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delete my child & data',
                              style: MomzoText.sans(15,
                                  color: MomzoColors.ink, weight: FontWeight.w800)),
                          Text('Erase the profile and everything in it',
                              style: MomzoText.sans(12,
                                  color: MomzoColors.muted, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: MomzoColors.faint, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
            GestureDetector(
              onTap: _confirmSignOut,
              behavior: HitTestBehavior.opaque,
              child: _card(
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: MomzoColors.muted, size: 22),
                    const SizedBox(width: 12),
                    Text('Sign out',
                        style: MomzoText.sans(15,
                            color: MomzoColors.ink, weight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDeleteChild() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeleteChildScreen(
          childId: ChildService.current?.id ?? '',
          childName: ChildService.current?.name ?? 'your child',
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Sign out?', style: MomzoText.sans(18, color: MomzoColors.ink, weight: FontWeight.w800)),
        content: Text("You can sign back in anytime with your email.",
            style: MomzoText.serif(15, color: MomzoColors.body)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w700))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sign out', style: MomzoText.sans(14, color: MomzoColors.coral, weight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AuthService.signOut();
    ChildService.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  Widget _timePill(String t) {
    final sel = t == _bestTime;
    return GestureDetector(
      onTap: () {
        setState(() => _bestTime = t);
        if (_live) NotificationService.save(nudgeSlot: _labelToSlot[t]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? MomzoColors.coralTint : MomzoColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? const Color(0xFFF3C7B5) : MomzoColors.cardBorder,
              width: 1.5),
        ),
        child: Text(t,
            textAlign: TextAlign.center,
            style: MomzoText.sans(13,
                color: sel ? MomzoColors.coralDeep : MomzoColors.muted,
                weight: sel ? FontWeight.w800 : FontWeight.w700)),
      ),
    );
  }

  Widget _toggle(bool on, Color onColor, VoidCallback onTap,
      {Color offColor = const Color(0xFFE3DBD0)}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: on ? onColor : offColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Align(
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
