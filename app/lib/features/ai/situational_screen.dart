import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';

/// 12 · Right now · calm script — short, actionable steps for in-the-moment help.
class SituationalScreen extends StatelessWidget {
  const SituationalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.coralTint, MomzoColors.cream],
            stops: [0, .45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 10, 26, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF0D9CD), width: 1.5),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: MomzoColors.body),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('⚡ Right now',
                        style: MomzoText.sans(16,
                            color: MomzoColors.coralDeep, weight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(26, 18, 26, 8),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x0D342F30),
                              blurRadius: 12,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: Text(
                        '"He\'s screaming because I said no to ice cream before dinner."',
                        style: MomzoText.sans(14,
                            color: const Color(0xFF5A4F49), weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Here\'s a calm way through 👇',
                        style: MomzoText.serif(22, color: MomzoColors.ink)),
                    const SizedBox(height: 18),
                    _step(1, 'Get to his level. Soft voice: ', '"You really want it. I get it."'),
                    const SizedBox(height: 12),
                    _step(2, 'Hold the boundary kindly: "Ice cream is after dinner."', null),
                    const SizedBox(height: 12),
                    _step(3, 'Give a yes he can have now: "Want to pick which bowl?"', null),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(
                        color: MomzoColors.sageTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        "It's okay if he stays upset — staying calm yourself is the lesson.",
                        style: MomzoText.sans(13.5,
                            color: const Color(0xFF4E7A60),
                            weight: FontWeight.w600,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
                child: Row(
                  children: [
                    const Expanded(child: MomzoSecondaryButton('That helped')),
                    const SizedBox(width: 10),
                    Expanded(child: MomzoButton('Still stuck', onTap: () {})),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(int n, String text, String? quote) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: MomzoColors.coral,
            shape: BoxShape.circle,
          ),
          child: Text('$n',
              style: MomzoText.sans(15, color: Colors.white, weight: FontWeight.w800)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(
                text: text,
                style: MomzoText.sans(15,
                    color: MomzoColors.ink, weight: FontWeight.w600, height: 1.45),
                children: quote == null
                    ? null
                    : [
                        TextSpan(
                          text: quote,
                          style: MomzoText.serif(15,
                              color: MomzoColors.coralDeep, italic: true),
                        ),
                      ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
