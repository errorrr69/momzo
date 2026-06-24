import 'package:flutter/material.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';

/// Privacy Promise — reachable from the consent flow (Task 9).
///
/// PLACEHOLDER COPY: this is plain-language summary text, NOT a lawyer-reviewed
/// privacy policy. Replace with the real policy before launch (alongside the
/// COPPA verifiable-consent upgrade).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      appBar: AppBar(
        backgroundColor: MomzoColors.cream,
        elevation: 0,
        foregroundColor: MomzoColors.ink,
        title: Text('Our Privacy Promise',
            style: MomzoText.sans(17,
                color: MomzoColors.ink, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            _p('Momzo is built for you and your child — not advertisers. Here is '
                'our promise, in plain words.'),
            _h('What we collect'),
            _p('Only what the app needs to help: your email, the first name and age '
                'you give for your child, and the choices you make in the app. No '
                'precise location. No third-party ad tracking, ever.'),
            _h('Your child has no account'),
            _p('You create and own your child’s profile. Your child never signs '
                'in independently. Kid Mode runs on your device, under your session.'),
            _h('We never sell your data'),
            _p('Your family’s information is never sold or shared for advertising.'),
            _h('Photos and notes are private'),
            _p('Anything you save is private to your family by default, stored '
                'securely and shown only to you.'),
            _h('You can delete everything'),
            _p('You can delete your child’s profile and all related data at any '
                'time, from the app. When you do, it’s gone.'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MomzoColors.honeyTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Note: this is a plain-language summary for the build, not the final '
                'legal policy. The complete, lawyer-reviewed Privacy Policy will be '
                'in place before launch.',
                style: MomzoText.sans(12.5,
                    color: MomzoColors.honeyText, weight: FontWeight.w600, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(t,
            style: MomzoText.sans(16,
                color: MomzoColors.ink, weight: FontWeight.w800)),
      );

  Widget _p(String t) => Text(t,
      style: MomzoText.serif(15.5, color: MomzoColors.body, height: 1.5));
}
