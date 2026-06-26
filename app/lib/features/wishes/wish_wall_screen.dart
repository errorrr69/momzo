import 'package:flutter/material.dart';

import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../services/child_service.dart';
import '../../services/wish_service.dart';

/// 20 · Kid mode · Wish Wall (Task 26) — a playful, safe surface for the child's
/// own voice, reached from the parent's session. Runs under the parent's account
/// (the child has no login — Hard Rule #14) and only ever writes wishes here.
class WishWallScreen extends StatefulWidget {
  const WishWallScreen({super.key});

  @override
  State<WishWallScreen> createState() => _WishWallScreenState();
}

class _WishWallScreenState extends State<WishWallScreen> {
  static const _emojis = ['🏰', '🍪', '🌟', '🎨', '⚽', '🦄', '🍦', '🚀', '🎁', '🐢'];
  List<Wish> _wishes = [];
  bool _loading = true;

  String get _childName => ChildService.current?.name ?? 'friend';

  @override
  void initState() {
    super.initState();
    if (AppEnv.hasSupabase) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final w = await WishService.load();
      if (mounted) setState(() {
        _wishes = w;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addWish() async {
    final ctrl = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 22,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What do you wish for? ✨',
                style: MomzoText.sans(20,
                    color: MomzoColors.ink, weight: FontWeight.w900)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: MomzoColors.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
              ),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: MomzoText.sans(16, color: MomzoColors.ink, weight: FontWeight.w700),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. build a blanket fort',
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
                onSubmitted: (v) => Navigator.pop(sheetCtx, v),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(sheetCtx, ctrl.text),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: MomzoColors.coral,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('Add it! ⭐',
                      textAlign: TextAlign.center,
                      style: MomzoText.sans(17, color: Colors.white, weight: FontWeight.w900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      final w = await WishService.add(text.trim(), createdBy: 'child');
      if (mounted) setState(() => _wishes = [w, ..._wishes]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add the wish. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE08A), Color(0xFFFFD0E0), Color(0xFFC9F0E2)],
            stops: [0, .5, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _badge('🔒 Kid Mode', onTap: () => Navigator.pop(context)),
                    _badge('Hi $_childName! 👋'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('My Wish Wall ✨',
                  style: MomzoText.sans(30,
                      color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5, height: 1.1)),
              const SizedBox(height: 6),
              Text('What do you want to do with Mom?',
                  style: MomzoText.sans(15,
                      color: const Color(0xFF7A6B61), weight: FontWeight.w700)),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
                    : _wishes.isEmpty
                        ? _empty()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                            itemCount: _wishes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 13),
                            itemBuilder: (_, i) => _wishCard(_wishes[i], i),
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
                child: GestureDetector(
                  onTap: _addWish,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: MomzoColors.coral,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: MomzoColors.coral.withValues(alpha: .4),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Text('＋ Add a wish',
                        textAlign: TextAlign.center,
                        style: MomzoText.sans(18,
                            color: Colors.white, weight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text('Tap "Add a wish" to put your first idea on the wall! 🌟',
            textAlign: TextAlign.center,
            style: MomzoText.sans(16,
                color: const Color(0xFF7A6B61), weight: FontWeight.w700, height: 1.4)),
      ),
    );
  }

  Widget _badge(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style: MomzoText.sans(12,
                color: const Color(0xFF7A6B61), weight: FontWeight.w800)),
      ),
    );
  }

  Widget _wishCard(Wish w, int i) {
    final emoji = _emojis[i % _emojis.length];
    final rotate = (i.isEven ? -1.0 : 1.0) * (i % 3 == 0 ? 1.5 : .6);
    final (tag, tagBg, tagColor) = switch (w.status) {
      'done' => ('Done ✓', MomzoColors.sageTint, const Color(0xFF4E7A60)),
      'scheduled' => ('Soon!', MomzoColors.honeyTint, MomzoColors.honeyText),
      _ => (null, null, null),
    };
    return Transform.rotate(
      angle: rotate * 3.14159 / 180,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Color(0x1A342F30), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 13),
            Expanded(
              child: Text(w.text,
                  style: MomzoText.sans(17,
                      color: MomzoColors.ink, weight: FontWeight.w800)),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(10)),
                child: Text(tag,
                    style: MomzoText.sans(11,
                        color: tagColor ?? MomzoColors.ink, weight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
