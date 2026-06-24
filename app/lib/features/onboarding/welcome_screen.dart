import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import 'sign_in_screen.dart';

/// 01 · Welcome — warm first impression, one clear action.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEFE2), Color(0xFFFCE6D6), Color(0xFFF6E7CF)],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 32),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: MomzoColors.coral.withOpacity(.28),
                              blurRadius: 26,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: MomzoColors.coral, size: 48),
                      ),
                      const SizedBox(height: 30),
                      Text.rich(
                        TextSpan(
                          text: 'momzo',
                          style: MomzoText.sans(38,
                              color: MomzoColors.coral,
                              weight: FontWeight.w900,
                              spacing: -1),
                          children: [
                            TextSpan(
                              text: '.',
                              style: MomzoText.sans(38,
                                  color: MomzoColors.sage,
                                  weight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 240,
                        child: Text(
                          'Understand your child a little better — and feel closer, every day.',
                          textAlign: TextAlign.center,
                          style: MomzoText.serif(22,
                              color: const Color(0xFF5A4F49), height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                MomzoButton(
                  'Get started',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignInScreen(isSignUp: true)),
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignInScreen(isSignUp: false)),
                  ),
                  child: Text('I already have an account',
                      style: MomzoText.sans(14,
                          color: MomzoColors.body, weight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
