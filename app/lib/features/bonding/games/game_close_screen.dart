import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';

/// Warm closing card for any mini-game — always affirms the connection, never a
/// score (games spec §1.5).
class GameCloseScreen extends StatelessWidget {
  const GameCloseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('💜', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 22),
              Text('That was lovely.',
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(28, color: MomzoColors.ink, weight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('You two are getting to know each other a little more. 💜',
                  textAlign: TextAlign.center,
                  style: MomzoText.serif(17, color: MomzoColors.muted, height: 1.5)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: MomzoButton('Back to games', onTap: () => Navigator.maybePop(context)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
