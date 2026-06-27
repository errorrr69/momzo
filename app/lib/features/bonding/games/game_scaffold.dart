import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';

/// Shared chrome for a mini-game card screen: a close button + centered title, the
/// card body, and an optional footer button.
class GameScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;
  final Widget? footer;
  const GameScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        border: Border.all(color: MomzoColors.cardBorder, width: 1.5)),
                      child: const Icon(Icons.close_rounded, size: 18, color: MomzoColors.muted),
                    ),
                  ),
                  Column(children: [
                    Text(title, style: MomzoText.sans(13, color: MomzoColors.ink, weight: FontWeight.w800)),
                    Text(subtitle, style: MomzoText.sans(11, color: MomzoColors.muted, weight: FontWeight.w700)),
                  ]),
                  const SizedBox(width: 34),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 22), child: footer!),
          ],
        ),
      ),
    );
  }
}

class GameLoading extends StatelessWidget {
  const GameLoading({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: MomzoColors.cream,
        body: Center(child: CircularProgressIndicator(color: MomzoColors.coral)),
      );
}

class GameEmpty extends StatelessWidget {
  const GameEmpty({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MomzoColors.cream,
        appBar: AppBar(backgroundColor: MomzoColors.cream, elevation: 0),
        body: Center(child: Text('No cards yet.', style: MomzoText.serif(16, color: MomzoColors.muted))),
      );
}
