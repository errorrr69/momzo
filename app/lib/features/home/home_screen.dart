import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/supabase/supabase_init.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/child.dart';
import '../../models/daily_card.dart';
import '../../services/auth_service.dart';
import '../../services/child_service.dart';
import '../../services/daily_service.dart';
import '../activities/activities_list_screen.dart';
import '../ai/ai_home_screen.dart';
import '../daily/daily_card_screen.dart';
import '../onboarding/child_basics_screen.dart';
import '../onboarding/edit_child_screen.dart';

/// 06 · Home · Today — greeting, today's read, two quick actions.
/// One hero, never cluttered.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Defaults keep the gallery / UI-only preview looking right; real values load
  // from the signed-in parent's profile + child (Task 12).
  String _parentName = 'Priya';
  String _childName = 'Aarav';
  DailyCard? _card; // today's real card, when loaded
  bool _haveCard = false;

  // Preview mode shows the sample tie-in; a real card shows it only when the
  // why_it_matters line exists (it's null until backfilled — Gemini key issue).
  bool get _showWhy => !_haveCard || (_card?.whyItMatters?.isNotEmpty ?? false);
  String get _whyText => _haveCard
      ? (_card?.whyItMatters ?? '')
      : "He's still learning to ride big feelings without melting down.";

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    if (!AppEnv.hasSupabase) return;
    try {
      // Ensure the full child list is loaded (for the switcher); keeps the active one.
      if (ChildService.children.isEmpty) await ChildService.loadChildren();
      final child = ChildService.current;
      String? parent;
      final uid = AuthService.currentUser?.id;
      if (uid != null) {
        final row = await supabase
            .from('users')
            .select('display_name')
            .eq('id', uid)
            .maybeSingle();
        parent = row?['display_name'] as String?;
      }
      DailyCard? card;
      if (child != null) card = await DailyService.todaysCard(child);
      if (!mounted) return;
      setState(() {
        if (child != null) _childName = child.name;
        if (parent != null && parent.isNotEmpty) _parentName = parent;
        if (card != null) {
          _card = card;
          _haveCard = true;
        }
      });
    } catch (_) {
      // Keep defaults on any load failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good morning,',
                            style: MomzoText.serif(19,
                                color: MomzoColors.muted, italic: true)),
                        Text(_parentName,
                            style: MomzoText.sans(24,
                                color: MomzoColors.ink, weight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  _childSwitcher(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                children: [
                  // Gentle streak
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MomzoColors.sageTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Text('🌱', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "You've connected 3 days this week — lovely.",
                            style: MomzoText.sans(13,
                                color: const Color(0xFF5C6B5F),
                                weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("TODAY'S 3-MINUTE READ", style: MomzoText.eyebrow()),
                  const SizedBox(height: 10),
                  _todaysRead(context),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _quickAction(
                          bg: MomzoColors.skyTint,
                          fg: const Color(0xFF2E6675),
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Need help\nright now?',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AiHomeScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _quickAction(
                          bg: MomzoColors.sageTint,
                          fg: const Color(0xFF3F6B52),
                          icon: Icons.timer_outlined,
                          label: "I've got\n10 minutes",
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ActivitiesListScreen())),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _childSwitcher() {
    return GestureDetector(
      onTap: _openChildPicker,
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: MomzoColors.honeyTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.face_rounded, color: MomzoColors.honey, size: 18),
          ),
          const SizedBox(width: 7),
          Text(_childName,
              style: MomzoText.sans(14,
                  color: MomzoColors.ink, weight: FontWeight.w800)),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: MomzoColors.faint, size: 18),
        ],
      ),
      ),
    );
  }

  Future<void> _openChildPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final kids = ChildService.children;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: MomzoColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text('Your children', style: MomzoText.eyebrow()),
                const SizedBox(height: 10),
                for (final c in kids) _childRow(sheetCtx, c),
                const SizedBox(height: 6),
                _pickerAction(
                  icon: Icons.edit_outlined,
                  label: ChildService.current == null
                      ? 'Edit profile'
                      : "Edit ${ChildService.current!.name}'s profile",
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    final cur = ChildService.current;
                    if (cur != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditChildScreen(child: cur)),
                      );
                    }
                  },
                ),
                _pickerAction(
                  icon: Icons.add_rounded,
                  label: 'Add a child',
                  accent: MomzoColors.coral,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChildBasicsScreen(addAnother: true),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _childRow(BuildContext sheetCtx, Child c) {
    final active = ChildService.current?.id == c.id;
    return GestureDetector(
      onTap: () {
        ChildService.select(c); // notifier rebuilds the tabs for the new child
        Navigator.pop(sheetCtx);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: MomzoColors.honeyTint, shape: BoxShape.circle),
              child: const Icon(Icons.face_rounded, color: MomzoColors.honey, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${c.name}  ·  ${c.age}',
                  style: MomzoText.sans(16,
                      color: MomzoColors.ink, weight: FontWeight.w800)),
            ),
            if (active)
              const Icon(Icons.check_circle_rounded, color: MomzoColors.coral, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _pickerAction({
    required IconData icon,
    required String label,
    Color accent = MomzoColors.muted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: MomzoText.sans(15, color: accent, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _todaysRead(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3E9DD)),
        boxShadow: const [
          BoxShadow(color: Color(0x14342F30), blurRadius: 26, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 104,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFAD9A6), MomzoColors.honey],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.favorite_rounded, color: Colors.white70, size: 44),
            ),
          ),
          const SizedBox(height: 16),
          Text(_haveCard ? _card!.title : 'When "no" turns into a meltdown',
              style: MomzoText.sans(21,
                  color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.3, height: 1.25)),
          const SizedBox(height: 10),
          if (_showWhy) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: MomzoColors.coralTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text.rich(
                TextSpan(
                  text: 'Why this matters for $_childName · ',
                  style: MomzoText.sans(12,
                      color: MomzoColors.coralDeep, weight: FontWeight.w700),
                  children: [
                    TextSpan(
                      text: _whyText,
                      style: MomzoText.sans(13,
                          color: MomzoColors.coralText,
                          weight: FontWeight.w600,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyCardScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: MomzoColors.coral,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text("Read today's card",
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(15,
                      color: Colors.white, weight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required Color bg,
    required Color fg,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(height: 8),
          Text(label,
              style: MomzoText.sans(14, color: fg, weight: FontWeight.w800, height: 1.2)),
        ],
      ),
      ),
    );
  }
}
