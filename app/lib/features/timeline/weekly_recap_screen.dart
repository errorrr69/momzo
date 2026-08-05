import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../services/child_service.dart';
import '../../services/recap_service.dart';
import 'memory_timeline_screen.dart';

/// 24 · Weekly recap — a gentle look back: what you learned, did, and one small
/// thing to try next week. Never a guilt-trip (Task 31, Hard Rule #18).
class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  WeeklyRecap? _recap;
  bool _loading = true;

  bool get _live => AppEnv.hasSupabase && ChildService.current != null;

  @override
  void initState() {
    super.initState();
    if (_live) {
      _load();
    } else {
      _loading = false; // UI-only preview shows the sample recap below
    }
  }

  Future<void> _load() async {
    try {
      final r = await RecapService.weekly();
      if (mounted) setState(() {
        _recap = r;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Values fall back to a warm sample when running UI-only (no backend).
  String get _childName => _recap?.childName ?? ChildService.current?.name ?? 'Aarav';
  int get _reads => _recap?.reads ?? 4;
  int get _activities => _recap?.activities ?? 3;
  int get _moments => _recap?.moments ?? 5;
  String get _learned =>
      _recap?.learned ??
      "You're getting really good at naming $_childName's feelings before fixing them.";
  String get _nextStep =>
      _recap?.nextStep ?? "Ask $_childName what they're most proud of this week.";
  bool get _quietWeek => _recap != null && !_recap!.hasActivity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.coralTint, MomzoColors.cream],
            stops: [0, .45],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 14, 26, 0),
                      child: Column(
                        children: [
                          Text('YOUR WEEK WITH ${_childName.toUpperCase()}',
                              textAlign: TextAlign.center,
                              style: MomzoText.eyebrow(color: MomzoColors.coralDeep)
                                  .copyWith(letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text('A gentle look back 🌸',
                              style: MomzoText.serif(25, color: MomzoColors.ink)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                        children: [
                          Row(
                            children: [
                              Expanded(child: _stat('$_reads', 'reads', MomzoColors.coral)),
                              const SizedBox(width: 12),
                              Expanded(child: _stat('$_activities', 'activities', MomzoColors.sage)),
                              const SizedBox(width: 12),
                              Expanded(child: _stat('$_moments', 'moments', MomzoColors.lavender)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _learnedCard(),
                          const SizedBox(height: 14),
                          _nextStepCard(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
                      child: MomzoButton(
                        "See this week's moments",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MemoryTimelineScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _learnedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MomzoColors.sageTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_quietWeek ? 'A gentle note' : 'What you learned',
              style: MomzoText.sans(13,
                  color: const Color(0xFF4E7A60), weight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _quietWeek
                ? "This was a quieter week — and that's completely okay. You're still here, and that's what $_childName remembers."
                : _learned,
            style: MomzoText.serif(16, color: MomzoColors.ink, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _nextStepCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MomzoColors.coralTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🌱', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('One small thing to try next week',
                    style: MomzoText.sans(13,
                        color: MomzoColors.ink, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  _nextStep,
                  style: MomzoText.sans(14,
                      color: MomzoColors.body, weight: FontWeight.w600, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String n, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text(n,
              style: MomzoText.sans(28, color: color, weight: FontWeight.w900)),
          Text(label,
              style: MomzoText.sans(12,
                  color: MomzoColors.muted, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
