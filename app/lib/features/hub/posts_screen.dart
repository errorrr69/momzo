import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import 'content_hub_section.dart';

/// Florie's posts, mirrored in-app — the fifth door (UX plan §3.2).
///
/// This tab used to be the Circle, with Florie's feed as one of two chips and
/// the mothers' forum as the other. The forum is gone; the feed is the whole
/// tab now, which is why this screen is a header and a list rather than the
/// switchboard it replaced.
///
/// It keeps the slot because the slot was never really the forum's. The point
/// of the redesign was getting these posts from "Learn, then scroll past seven
/// shelves" down to one tap, and that is the only thing here worth protecting.
class PostsScreen extends StatelessWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          children: [
            Text('From Momzo',
                style: MomzoText.sans(26,
                    color: MomzoColors.ink, weight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('Florie’s notes, as she writes them',
                style: MomzoText.sans(13,
                    color: MomzoColors.muted, weight: FontWeight.w700)),
            const SizedBox(height: 16),
            // The heading is off because the two lines above already say what
            // this is, and repeating it is a line she has to read twice.
            const ContentHubSection(showHeading: false),
          ],
        ),
      ),
    );
  }
}
