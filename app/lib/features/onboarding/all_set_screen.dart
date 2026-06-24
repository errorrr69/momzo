import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../home/home_screen.dart';

/// 05 · All set — personalization confirmed, warm hand-off into the app.
class AllSetScreen extends StatelessWidget {
  final String childName;
  const AllSetScreen({super.key, required this.childName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.sageTint, Color(0xFFFFF3E2)],
            stops: [0, .6],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(34, 8, 34, 32),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: MomzoColors.sage,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MomzoColors.sage.withOpacity(.4),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            )
                          ],
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 52),
                      ),
                      const SizedBox(height: 28),
                      Text.rich(
                        TextSpan(
                          text: 'Momzo is now tuned to ',
                          style: MomzoText.serif(28,
                              color: MomzoColors.ink, height: 1.35),
                          children: [
                            TextSpan(
                              text: childName,
                              style: MomzoText.serif(28,
                                  color: MomzoColors.coral,
                                  italic: true,
                                  height: 1.35),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 250,
                        child: Text(
                          "Every read, activity and idea you'll see is picked for an 8-year-old working through big emotions and screen time.",
                          textAlign: TextAlign.center,
                          style: MomzoText.sans(17,
                              color: MomzoColors.body,
                              weight: FontWeight.w400,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                MomzoButton(
                  'Take me in',
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
