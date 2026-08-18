import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/supabase/supabase_init.dart';
import '../../core/env/feature_flags.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_bottom_nav.dart';
import '../../models/child.dart';
import '../../models/daily_card.dart';
import '../../services/auth_service.dart';
import '../../services/child_service.dart';
import '../../services/daily_service.dart';
import '../../services/recap_service.dart';
import '../daily/daily_card_screen.dart';
import '../onboarding/child_basics_screen.dart';
import '../onboarding/edit_child_screen.dart';
import '../me/me_sheet.dart';

/// 06 · Home · Today (UX plan §3.1).
///
/// The screen that has already decided. One decision above the fold — read the
/// card or don't — and everything under it is a shortcut, never a question.
///
/// The doors row duplicates the bottom tabs deliberately. At 8:40pm she looks at
/// the middle of the screen, not the chrome at the edge, and the three things we
/// most want her to find are worth saying twice.
class HomeScreen extends StatefulWidget {
  /// Switches the shell's tab. Home's doors must land on the real TAB, not push
  /// a second copy of a screen that already has one — a stacked route has a back
  /// button and no bottom nav, which is a different place that looks the same.
  final void Function(MomzoTab)? onOpenTab;

  const HomeScreen({super.key, this.onOpenTab});

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
  // Gentle streak (Task 32). Keeps a warm default for the UI-only preview; the
  // real, never-shaming line loads from RecapService once signed in.
  String _streakMsg = "You've connected 3 days this week — lovely.";

  // Preview mode shows the sample tie-in; a real card shows it only when the
  // why_it_matters line exists (it's null until backfilled — Gemini key issue).
  bool get _showWhy => !_haveCard || (_card?.whyItMatters?.isNotEmpty ?? false);

  /// The card's `activity` — the one thing she could do tonight, surfaced so it
  /// does not require opening the card to find.
  String get _tonight => _card?.activity ?? '';

  /// Whether today's card has been read (drives the hero CTA's done state).
  bool get _isRead => _card?.isRead ?? false;
  String get _whyText => _haveCard
      ? (_card?.whyItMatters ?? '')
      : "He's still learning to ride big feelings without melting down.";

  @override
  void initState() {
    super.initState();
    _loadContext();
    // Home is kept alive in the shell's IndexedStack, so it won't rebuild when the
    // reader pops. Re-read the card (and streak) whenever today's read is recorded.
    DailyService.readRevision.addListener(_loadContext);
  }

  @override
  void dispose() {
    DailyService.readRevision.removeListener(_loadContext);
    super.dispose();
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
      int? streakDays;
      if (child != null) {
        card = await DailyService.todaysCard(child);
        streakDays = await RecapService.connectedDays();
      }
      if (!mounted) return;
      setState(() {
        if (child != null) _childName = child.name;
        if (parent != null && parent.isNotEmpty) _parentName = parent;
        if (card != null) {
          _card = card;
          _haveCard = true;
        }
        if (streakDays != null) _streakMsg = RecapService.streakMessage(streakDays);
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
                  const SizedBox(width: 8),
                  // The Me door. Settings are a weekly errand and used to hold a
                  // permanent bottom tab — the most expensive space in the app.
                  // Two taps here is what bought the fifth door for the Circle.
                  _meButton(),
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
                            _streakMsg,
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
                  // Doors before Tonight (UX plan §3.1 item 3 then 4). Built the
                  // other way round first, and on a real phone the hero card is
                  // tall enough that the doors fell off the bottom of the screen
                  // — the exact failure the doors exist to fix.
                  const SizedBox(height: 18),
                  Text('WHERE TO NEXT', style: MomzoText.eyebrow()),
                  const SizedBox(height: 11),
                  _doors(),
                  // Tonight: the ONE pre-chosen thing. The card's own activity
                  // line, lifted out so she can act on it without opening
                  // anything. Absent when there is nothing to say.
                  if (_tonight.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _tonightCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The avatar that replaced the Me tab.
  Widget _meButton() => GestureDetector(
        onTap: () => showMeSheet(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MomzoColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: MomzoColors.cardBorder, width: 1.4),
          ),
          child: const Icon(Icons.person_outline_rounded,
              size: 21, color: MomzoColors.body),
        ),
      );

  /// Tonight — one suggestion, already chosen. Not a list, not a picker.
  Widget _tonightCard() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MomzoColors.sunshine,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TRY TONIGHT',
                style: MomzoText.eyebrow(color: MomzoColors.sunshineText)),
            const SizedBox(height: 6),
            // Capped at three lines. The full activity lives in the card, and
            // an un-capped one ran to five lines on a real phone and pushed the
            // doors off the bottom of the screen — which is the opposite of the
            // point. This is a nudge, not the content.
            Text(_tonight,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: MomzoText.serif(16, color: MomzoColors.ink, height: 1.45)),
          ],
        ),
      );

  /// The three doors (UX plan §3.1 item 3).
  ///
  /// Same words and same colours as the tabs they lead to — "Play" here and
  /// "Play" down there, lilac in both places. A synonym would make her read
  /// rather than recognise, and reading is the expensive part at 8:40pm.
  Widget _doors() => Row(
        children: [
          _door(MomzoTab.ask, 'Ask\nMomzo', Icons.chat_bubble_outline_rounded),
          const SizedBox(width: 10),
          _door(MomzoTab.play, 'Play\ntogether', Icons.extension_outlined),
          const SizedBox(width: 10),
          _door(MomzoTab.circle, 'The\nCircle', Icons.favorite_border_rounded),
        ],
      );

  Widget _door(MomzoTab tab, String label, IconData icon) => Expanded(
        child: GestureDetector(
          onTap: () => widget.onOpenTab?.call(tab),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 104,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: tab.accent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tab.accentText.withValues(alpha: .18), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ink on the bright fill, never white — the contrast guard in
                // theme_contrast_test.dart is what says which way round this goes.
                Icon(icon, size: 21, color: MomzoColors.ink),
                Text(label,
                    style: MomzoText.sans(13.5,
                        color: MomzoColors.ink, weight: FontWeight.w800, height: 1.2)),
              ],
            ),
          ),
        ),
      );

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
                // Once she's read today's card the CTA becomes a calm "done" state
                // rather than still nagging her to read it.
                color: _isRead ? MomzoColors.sageTint : MomzoColors.coral,
                borderRadius: BorderRadius.circular(14),
                border: _isRead
                    ? Border.all(color: MomzoColors.sage, width: 1.5)
                    : null,
              ),
              child: Text(_isRead ? 'Read today ✓' : "Read today's card",
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(15,
                      color: _isRead ? MomzoColors.sageText : Colors.white,
                      weight: FontWeight.w800)),
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
