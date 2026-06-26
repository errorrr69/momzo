import 'package:flutter/material.dart';

import '../../core/widgets/momzo_bottom_nav.dart';
import '../../models/child.dart';
import '../../services/child_service.dart';
import '../ai/ai_home_screen.dart';
import '../bonding/together_hub_screen.dart';
import '../daily/library_screen.dart';
import '../home/home_screen.dart';
import '../reminders/reminders_screen.dart';

/// The app's main tabbed surface — the five-pillar bottom nav (Home / Learn /
/// Ask / Together / Me) over an IndexedStack so each tab keeps its state.
/// Detail screens are pushed on top of the shell (covering the nav).
class MainShell extends StatefulWidget {
  final int initialTab;
  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _tabs = [MomzoTab.home, MomzoTab.learn, MomzoTab.ask, MomzoTab.together, MomzoTab.me];
  late int _index = widget.initialTab.clamp(0, _tabs.length - 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Rebuild the child-scoped tabs when the active child changes: keying each by
      // the child id gives them a fresh State so they reload for the new child
      // (Task 23). The "Me" tab is account-level, so it stays stable.
      body: ValueListenableBuilder<Child?>(
        valueListenable: ChildService.currentChild,
        builder: (context, child, _) {
          final k = child?.id ?? 'none';
          return IndexedStack(
            index: _index,
            children: [
              HomeScreen(key: ValueKey('home_$k')),
              LibraryScreen(key: ValueKey('library_$k')),
              AiHomeScreen(key: ValueKey('ask_$k')),
              TogetherHubScreen(key: ValueKey('together_$k')),
              const RemindersScreen(),
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
