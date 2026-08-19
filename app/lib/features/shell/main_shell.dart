import 'package:flutter/material.dart';

import '../../core/widgets/momzo_bottom_nav.dart';
import '../../models/child.dart';
import '../../services/child_service.dart';
import '../ai/ai_home_screen.dart';
import '../daily/library_screen.dart';
import '../home/home_screen.dart';
import '../hub/posts_screen.dart';
import '../play/play_screen.dart';

/// The app's main tabbed surface — five doors (UX plan §2) over an IndexedStack
/// so each tab keeps its state. Detail screens are pushed on top of the shell.
///
/// Home · Learn · Ask · Play · Momzo. "Me" is deliberately not here: settings
/// are a weekly errand, and a permanent tab is the most expensive space in the
/// app. It lives behind the avatar in the Home header instead, which is how
/// games and Florie's posts got promoted into daily reach without adding a
/// sixth tab nobody could parse.
class MainShell extends StatefulWidget {
  final int initialTab;
  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _tabs = MomzoTab.values;
  late int _index = widget.initialTab.clamp(0, _tabs.length - 1);

  /// Lets a Home door switch tabs rather than pushing a second copy of a screen
  /// that already has one. Tapping "Play together" on Home must land on the Play
  /// TAB — otherwise she ends up on a stacked route with a back button and no
  /// bottom nav, which is a different place that looks like the same place.
  void _goTo(MomzoTab tab) => setState(() => _index = _tabs.indexOf(tab));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Rebuild the child-scoped tabs when the active child changes: keying each
      // by the child id gives them a fresh State so they reload for the new
      // child (Task 23). Florie's posts are account-level, so that one stays
      // stable.
      body: ValueListenableBuilder<Child?>(
        valueListenable: ChildService.currentChild,
        builder: (context, child, _) {
          final k = child?.id ?? 'none';
          return IndexedStack(
            index: _index,
            children: [
              HomeScreen(key: ValueKey('home_$k'), onOpenTab: _goTo),
              LibraryScreen(key: ValueKey('library_$k')),
              AiHomeScreen(key: ValueKey('ask_$k')),
              PlayScreen(key: ValueKey('play_$k')),
              const PostsScreen(),
            ],
          );
        },
      ),
      bottomNavigationBar: MomzoBottomNav(
        _tabs[_index],
        onTap: (t) => setState(() => _index = _tabs.indexOf(t)),
      ),
    );
  }
}
