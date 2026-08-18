import 'package:flutter/material.dart';
import '../env/feature_flags.dart';
import '../theme/momzo_colors.dart';
import '../theme/momzo_text.dart';

/// The five doors (UX plan §2). Order is fixed and must not be reshuffled:
/// muscle memory is the whole point, and a tab that moves costs her the one
/// thing this navigation is for.
enum MomzoTab { home, learn, ask, play, circle }

extension MomzoTabX on MomzoTab {
  /// Her word for it, used on the tab AND on the Home door. The same thing must
  /// never have two names (UX plan §4.6) — synonyms are homework.
  String get label => switch (this) {
        MomzoTab.home => 'Home',
        MomzoTab.learn => 'Learn',
        MomzoTab.ask => 'Ask',
        MomzoTab.play => 'Play',
        // With the forum off this tab is Florie's posts alone, so it is named
        // for her rather than for a community that is not there yet.
        MomzoTab.circle => FeatureFlags.circle ? 'Circle' : 'Momzo',
      };

  /// One accent per tab — the wayfinding contract (UX plan §4.5). This is the
  /// single source of it; nothing else should hardcode a tab's colour.
  Color get accent => switch (this) {
        MomzoTab.home => MomzoColors.coral,
        MomzoTab.learn => MomzoColors.honey,
        MomzoTab.ask => MomzoColors.sky,
        MomzoTab.play => MomzoColors.lavender,
        MomzoTab.circle => MomzoColors.sage,
      };

  /// The readable variant of [accent], for the label under an active icon.
  Color get accentText => switch (this) {
        MomzoTab.home => MomzoColors.coralText,
        MomzoTab.learn => MomzoColors.honeyText,
        MomzoTab.ask => MomzoColors.skyText,
        MomzoTab.play => MomzoColors.lavenderText,
        MomzoTab.circle => MomzoColors.sageText,
      };

  Color get tint => switch (this) {
        MomzoTab.home => MomzoColors.coralTint,
        MomzoTab.learn => MomzoColors.honeyTint,
        MomzoTab.ask => MomzoColors.skyTint,
        MomzoTab.play => MomzoColors.lavenderTint,
        MomzoTab.circle => MomzoColors.sageTint,
      };

  IconData get filledIcon => switch (this) {
        MomzoTab.home => Icons.home_rounded,
        MomzoTab.learn => Icons.menu_book_rounded,
        MomzoTab.ask => Icons.chat_bubble_rounded,
        MomzoTab.play => Icons.extension_rounded,
        MomzoTab.circle =>
          FeatureFlags.circle ? Icons.favorite_rounded : Icons.auto_stories_rounded,
      };

  IconData get outlineIcon => switch (this) {
        MomzoTab.home => Icons.home_outlined,
        MomzoTab.learn => Icons.menu_book_outlined,
        MomzoTab.ask => Icons.chat_bubble_outline_rounded,
        MomzoTab.play => Icons.extension_outlined,
        MomzoTab.circle =>
          FeatureFlags.circle ? Icons.favorite_border_rounded : Icons.auto_stories_outlined,
      };
}

/// The five-door bottom navigation.
///
/// The active tab wears ITS OWN colour rather than a single app-wide highlight.
/// That is what turns the nav into a map: after a few days "the purple one" and
/// "the green one" are addresses she doesn't have to read.
///
/// Hidden entirely in Kid Mode for a simpler, safer surface.
class MomzoBottomNav extends StatelessWidget {
  final MomzoTab active;
  final ValueChanged<MomzoTab>? onTap;

  const MomzoBottomNav(this.active, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MomzoColors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3E9DD))),
      ),
      // Pad above the system navigation bar so the tabs aren't hidden behind it.
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [for (final tab in MomzoTab.values) _item(tab)],
          ),
        ),
      ),
    );
  }

  Widget _item(MomzoTab tab) {
    final isActive = tab == active;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap?.call(tab),
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          selected: isActive,
          button: true,
          label: tab.label,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A soft pill behind the active icon. It gives the accent somewhere
              // to live at a size she can actually see, without tinting the icon
              // so lightly that it disappears.
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? tab.tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isActive ? tab.filledIcon : tab.outlineIcon,
                  size: 22,
                  color: isActive ? tab.accentText : MomzoColors.faint,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MomzoText.sans(10,
                    color: isActive ? tab.accentText : MomzoColors.faint,
                    weight: isActive ? FontWeight.w800 : FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
