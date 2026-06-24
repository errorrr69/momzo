import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';

/// 16 · Did it · photo & note — optional keepsake that feeds the Memory Timeline.
class ActivityCompleteScreen extends StatelessWidget {
  const ActivityCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.sageTint, MomzoColors.cream],
            stops: [0, .5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: MomzoColors.sage,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: MomzoColors.sage.withOpacity(.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 38),
                          ),
                          const SizedBox(height: 16),
                          Text('You did it together 🌿',
                              style: MomzoText.serif(26, color: MomzoColors.ink)),
                          const SizedBox(height: 6),
                          Text(
                            "Want to keep this little moment? It'll live in your Memory Timeline.",
                            textAlign: TextAlign.center,
                            style: MomzoText.sans(15,
                                color: MomzoColors.body,
                                weight: FontWeight.w400,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Photo drop
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFC7DCCB),
                            width: 2,
                            style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: MomzoColors.sageTint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.photo_camera_outlined,
                                color: MomzoColors.sage, size: 24),
                          ),
                          const SizedBox(height: 8),
                          Text('Add a photo',
                              style: MomzoText.sans(14,
                                  color: const Color(0xFF5C6B5F),
                                  weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                      ),
                      child: Text('He giggled so hard the balloon "popped"…',
                          style: MomzoText.serif(15,
                              color: MomzoColors.muted, height: 1.4)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 8, 26, 26),
                child: Row(
                  children: [
                    Expanded(
                      child: MomzoSecondaryButton('Skip',
                          onTap: () => Navigator.pop(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 14,
                      child: MomzoButton('Save memory',
                          onTap: () => Navigator.pop(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
