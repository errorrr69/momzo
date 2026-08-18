import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../services/auth_service.dart';
import '../../services/child_service.dart';
import '../circle/circle_identity_sheet.dart';
import '../onboarding/child_basics_screen.dart';
import '../onboarding/delete_child_screen.dart';
import '../onboarding/edit_child_screen.dart';
import '../onboarding/privacy_policy_screen.dart';
import '../onboarding/welcome_screen.dart';
import '../reminders/reminders_screen.dart';
import '../timeline/memory_timeline_screen.dart';

/// Everything that used to be the "Me" tab (UX plan §3.6).
///
/// A sheet, not a tab, because depth should be bought with frequency: she opens
/// reminders and settings weekly at best, and a permanent bottom-nav slot is the
/// most expensive space in the app. Giving it up is what let games and the
/// Circle move from two taps to one.
///
/// It also fixes a standing gap: `DeleteChildScreen` has existed for months with
/// no way to reach it from inside the app.
Future<void> showMeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MeSheet(),
  );
}

class _MeSheet extends StatelessWidget {
  const _MeSheet();

  @override
  Widget build(BuildContext context) {
    final children = ChildService.children;
    final current = ChildService.current;

    return Padding(
      // viewPadding is the system nav bar; without it the last row sits under it.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .82,
        ),
        decoration: const BoxDecoration(
          color: MomzoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MomzoColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('You', style: MomzoText.serif(24, color: MomzoColors.ink)),
              const SizedBox(height: 16),

              Text('YOUR CHILDREN', style: MomzoText.eyebrow()),
              const SizedBox(height: 9),
              for (final c in children) ...[
                _row(
                  context,
                  emoji: '🧒',
                  title: c.name,
                  sub: '${c.age} years old${c.id == current?.id ? ' · showing now' : ''}',
                  onTap: () => _push(context, EditChildScreen(child: c)),
                ),
                const SizedBox(height: 8),
              ],
              _row(
                context,
                emoji: '➕',
                title: 'Add a child',
                sub: 'A second profile, with its own daily card',
                onTap: () => _push(context, const ChildBasicsScreen()),
              ),
              const SizedBox(height: 18),

              Text('SETTINGS', style: MomzoText.eyebrow()),
              const SizedBox(height: 9),
              _row(
                context,
                emoji: '🔔',
                title: 'Reminders',
                sub: 'When Momzo nudges you, and when it stays quiet',
                onTap: () => _push(context, const RemindersScreen()),
              ),
              const SizedBox(height: 8),
              _row(
                context,
                emoji: '📸',
                title: 'Memories',
                sub: 'Photos and milestones you’ve kept',
                onTap: () => _push(context, const MemoryTimelineScreen()),
              ),
              const SizedBox(height: 8),
              _row(
                context,
                emoji: '💛',
                title: 'Your Circle name',
                sub: 'What the other mothers see',
                onTap: () async {
                  Navigator.pop(context);
                  await showCircleIdentitySheet(context);
                },
              ),
              const SizedBox(height: 8),
              _row(
                context,
                emoji: '🔒',
                title: 'Privacy',
                sub: 'What we keep, and what we never do',
                onTap: () => _push(context, const PrivacyPolicyScreen()),
              ),
              const SizedBox(height: 18),

              // Destructive things live at the bottom, plainly labelled, behind
              // their own confirmation. Never a swipe, never an icon alone.
              Text('CAREFUL', style: MomzoText.eyebrow()),
              const SizedBox(height: 9),
              if (current != null) ...[
                _row(
                  context,
                  emoji: '🗑️',
                  title: 'Delete ${current.name}’s profile',
                  sub: 'Erases their data completely',
                  danger: true,
                  onTap: () => _push(
                    context,
                    DeleteChildScreen(childId: current.id, childName: current.name),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _row(
                context,
                emoji: '👋',
                title: 'Sign out',
                sub: 'You can come straight back',
                onTap: () => _signOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MomzoColors.cream,
        title: Text('Sign out?', style: MomzoText.serif(20, color: MomzoColors.ink)),
        content: Text('Everything stays exactly where it is.',
            style: MomzoText.sans(14, color: MomzoColors.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out',
                style: MomzoText.sans(14,
                    color: MomzoColors.coralDeep, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget _row(
    BuildContext context, {
    required String emoji,
    required String title,
    required String sub,
    required VoidCallback onTap,
    bool danger = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: danger ? MomzoColors.coralTint : MomzoColors.cardBorder,
              width: 1.3,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MomzoText.sans(14.5,
                            color: danger ? MomzoColors.coralText : MomzoColors.ink,
                            weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MomzoText.sans(12,
                            color: MomzoColors.muted, weight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: MomzoColors.faint),
            ],
          ),
        ),
      );
}
