import 'package:flutter/material.dart';

import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../models/child.dart';
import '../../services/child_service.dart';
import '../../services/consent_service.dart';
import '../../services/onboarding_service.dart';
import '../shell/main_shell.dart';
import 'child_basics_screen.dart';
import 'onboarding_flow_screen.dart';
import 'privacy_policy_screen.dart';

/// COPPA parental-consent gate (Task 9). Sits between sign-in and child-profile
/// onboarding: a parent must attest + consent before ANY child data is collected.
/// Already-consented parents are skipped straight through. The database also
/// enforces the gate (a trigger blocks child creation without consent).
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _checking = true;
  bool _agreed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _maybeSkip();
  }

  Future<void> _maybeSkip() async {
    // In UI-only preview mode there's no backend to check or record against.
    if (!AppEnv.hasSupabase) {
      setState(() => _checking = false);
      return;
    }
    try {
      if (await ConsentService.hasConsent()) {
        final child = await ChildService.loadMyChild();
        if (child == null) {
          _goToChildBasics(); // consented, no child yet -> start onboarding
          return;
        }
        // Resume an incomplete onboarding where she left off (spec §3.1).
        final st = await OnboardingService.load();
        if (st != null && !st.completed) {
          _goToFlow(child, (st.step + 1).clamp(2, 8));
        } else {
          _goToHome(); // returning parent, onboarding done
        }
        return;
      }
    } catch (_) {
      // Fall through to showing the consent UI on any check failure.
    }
    if (mounted) setState(() => _checking = false);
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _continue() async {
    if (!_agreed) return;
    if (!AppEnv.hasSupabase) {
      _toast('Backend not configured — running in UI-only preview mode.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ConsentService.recordConsent();
      _goToChildBasics();
    } catch (_) {
      _toast('Could not save your consent. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToChildBasics() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChildBasicsScreen()),
    );
  }

  void _goToFlow(Child child, int startStep) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OnboardingFlowScreen(child: child, startStep: startStep)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: MomzoColors.cream,
        body: Center(child: CircularProgressIndicator(color: MomzoColors.coral)),
      );
    }

    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('A quick promise 🤝',
                  style: MomzoText.sans(27,
                      color: MomzoColors.ink, weight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(
                "Momzo is just for you and your little one. Before we set up your "
                "child's profile, we need your okay as their parent.",
                style: MomzoText.serif(17, color: MomzoColors.body, height: 1.45),
              ),
              const SizedBox(height: 22),
              _promise('🔒', 'Private by default',
                  'Photos and notes stay within your family.'),
              _promise('🚫', 'No ads, ever',
                  "We never show ads to children or sell your data."),
              _promise('🗑️', 'Delete anytime',
                  "You can erase your child's profile and all data whenever you want."),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                ),
                behavior: HitTestBehavior.opaque,
                child: Text('Read our Privacy Promise',
                    style: MomzoText.sans(14,
                        color: MomzoColors.coral, weight: FontWeight.w800)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _busy ? null : () => setState(() => _agreed = !_agreed),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _checkbox(_agreed),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          "I'm this child's parent or legal guardian, and I consent "
                          "to Momzo collecting the information I provide to "
                          "personalise the app for us.",
                          style: MomzoText.sans(13.5,
                              color: MomzoColors.body,
                              weight: FontWeight.w600,
                              height: 1.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Opacity(
                opacity: _agreed && !_busy ? 1 : .5,
                child: MomzoButton(
                  _busy ? 'Saving…' : 'I agree & continue',
                  onTap: _agreed && !_busy ? _continue : null,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promise(String emoji, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: MomzoText.sans(15,
                        color: MomzoColors.ink, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body,
                    style: MomzoText.sans(13,
                        color: MomzoColors.muted, weight: FontWeight.w500, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkbox(bool on) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: on ? MomzoColors.coral : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
            color: on ? MomzoColors.coral : MomzoColors.cardBorder, width: 1.5),
      ),
      child: on
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
          : null,
    );
  }
}
