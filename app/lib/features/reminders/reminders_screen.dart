import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../services/notification_service.dart';

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
  bool _whatsApp = false;
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
            const SizedBox(height: 13),
            // WhatsApp opt-in (sky-tinted, differentiator)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MomzoColors.skyTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reminders on WhatsApp',
                            style: MomzoText.sans(15,
                                color: const Color(0xFF2E6675),
                                weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          'Get playdate nudges where you already are. Opt-in, utility only.',
                          style: MomzoText.sans(12,
                              color: const Color(0xFF3E8497),
                              weight: FontWeight.w600,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _toggle(_whatsApp, MomzoColors.sky,
                      () => setState(() => _whatsApp = !_whatsApp),
                      offColor: const Color(0xFFCDE3E9)),
                ],
              ),
            ),
          ],
        ),
      ),
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
