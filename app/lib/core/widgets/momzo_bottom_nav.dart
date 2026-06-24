import 'package:flutter/material.dart';
import '../theme/momzo_colors.dart';
import '../theme/momzo_text.dart';

enum MomzoTab { home, learn, ask, together, me }

/// The five-pillar bottom navigation. Active = coral filled icon + label.
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
      padding: const EdgeInsets.only(top: 10, bottom: 12, left: 6, right: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(MomzoTab.home, 'Home', Icons.home_rounded, Icons.home_outlined),
          _item(MomzoTab.learn, 'Learn', Icons.menu_book_rounded,
              Icons.menu_book_outlined),
          _item(MomzoTab.ask, 'Ask', Icons.chat_bubble_rounded,
              Icons.chat_bubble_outline_rounded),
          _item(MomzoTab.together, 'Together', Icons.favorite_rounded,
              Icons.favorite_border_rounded),
          _item(MomzoTab.me, 'Me', Icons.person_rounded,
              Icons.person_outline_rounded),
        ],
      ),
    );
  }

  Widget _item(MomzoTab tab, String label, IconData filled, IconData outline) {
    final isActive = tab == active;
    final color = isActive ? MomzoColors.coral : MomzoColors.faint;
    return GestureDetector(
      onTap: () => onTap?.call(tab),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? filled : outline, size: 23, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: MomzoText.sans(10,
                color: color,
                weight: isActive ? FontWeight.w800 : FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
