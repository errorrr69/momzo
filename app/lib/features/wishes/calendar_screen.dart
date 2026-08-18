import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../services/child_service.dart';
import '../../services/scheduled_event_service.dart';
import '../../services/wish_service.dart';
import 'schedule_wish_screen.dart';

/// 22 · Calendar · together-time — upcoming bonding moments, and a quick way to
/// turn an open wish into a planned together-time (Tasks 27 + 28).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _dow = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _accents = [MomzoColors.coral, MomzoColors.lavender, MomzoColors.sky, MomzoColors.honey];

  List<ScheduledEvent> _events = [];
  List<Wish> _openWishes = [];
  bool _loading = true;

  bool get _live => AppEnv.hasSupabase && ChildService.current != null;

  @override
  void initState() {
    super.initState();
    if (_live) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final events = await ScheduledEventService.listUpcoming();
      final wishes = await WishService.load();
      if (!mounted) return;
      setState(() {
        _events = events;
        _openWishes = wishes.where((w) => w.status == 'open').toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _plan(Wish wish) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ScheduleWishScreen(wish: wish)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                children: [
                  Text('Our together-times',
                      style: MomzoText.sans(26,
                          color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5)),
                  const SizedBox(height: 18),
                  if (_events.isEmpty && _openWishes.isEmpty) _empty(),
                  if (_events.isNotEmpty) ...[
                    Text('COMING UP', style: MomzoText.eyebrow()),
                    const SizedBox(height: 11),
                    for (var i = 0; i < _events.length; i++) ...[
                      _eventCard(_events[i], _accents[i % _accents.length]),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                  ],
                  if (_openWishes.isNotEmpty) ...[
                    Text('PLAN A WISH', style: MomzoText.eyebrow()),
                    const SizedBox(height: 4),
                    Text('Tap one to find a time together.',
                        style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w600)),
                    const SizedBox(height: 11),
                    for (final w in _openWishes) ...[
                      _wishCard(w),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text('Nothing planned yet.',
                textAlign: TextAlign.center,
                style: MomzoText.sans(17, color: MomzoColors.ink, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Add a wish on the Wish Wall, then plan it in here.',
                textAlign: TextAlign.center,
                style: MomzoText.serif(15, color: MomzoColors.muted, height: 1.4)),
          ],
        ),
      );

  Widget _eventCard(ScheduledEvent e, Color accent) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text('${e.startsAt.day}',
                          style: MomzoText.sans(20,
                              color: accent, weight: FontWeight.w900, height: 1)),
                      Text(_dow[e.startsAt.weekday - 1],
                          style: MomzoText.sans(10,
                              color: MomzoColors.muted, weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                            style: MomzoText.sans(15,
                                color: MomzoColors.ink, weight: FontWeight.w800)),
                        Text(_timeLabel(e.startsAt),
                            style: MomzoText.sans(12,
                                color: MomzoColors.muted, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wishCard(Wish w) {
    return GestureDetector(
      onTap: () => _plan(w),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MomzoColors.honeyTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3E2C0), width: 1.2),
        ),
        child: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(w.text,
                  style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w800)),
            ),
            const Icon(Icons.calendar_month_rounded, size: 20, color: MomzoColors.honeyText),
          ],
        ),
      ),
    );
  }

  // e.g. "Sat · 5:00 pm"
  String _timeLabel(DateTime d) {
    final dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'am' : 'pm';
    return '$dow · $h:$m $ap';
  }
}
