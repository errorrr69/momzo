import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../services/auth_service.dart';
import 'consent_screen.dart';

/// 02 · Sign up / log in — email + social, child-safe framing.
///
/// Wired to Supabase Auth (Task 5). Reached from the welcome screen as either
/// sign-up ("Get started") or log-in ("I already have an account"); a footer
/// toggle switches between the two. Uses the anon key only — no secret in the
/// client (Hard Rule #5). On success the parent's profile is upserted and we
/// continue into the child-profile onboarding.
class SignInScreen extends StatefulWidget {
  /// Start in account-creation mode (vs. log-in). Defaults to sign-up.
  final bool isSignUp;
  const SignInScreen({super.key, this.isSignUp = true});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _isSignUp = widget.isSignUp;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Guard: in UI-only mode (no backend env) auth can't run.
  bool get _backendReady => AppEnv.hasSupabase;

  Future<void> _submitEmail() async {
    if (!_backendReady) {
      _toast('Backend not configured — running in UI-only preview mode.');
      return;
    }
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('Please enter your email and password.');
      return;
    }
    if (_isSignUp && password.length < 6) {
      _toast('Password needs at least 6 characters.');
      return;
    }

    setState(() => _busy = true);
    try {
      final res = _isSignUp
          ? await AuthService.signUpWithEmail(email, password)
          : await AuthService.signInWithEmail(email, password);

      // With email confirmation on, sign-up returns no session yet.
      if (res.session == null) {
        _toast('Check your email to confirm your account, then log in.');
        return;
      }
      await AuthService.ensureProfile();
      _goToOnboarding();
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitOAuth(OAuthProvider provider) async {
    if (!_backendReady) {
      _toast('Backend not configured — running in UI-only preview mode.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.signInWithOAuth(provider);
      // OAuth completes via a browser redirect; the auth-state listener upserts
      // the profile and the app will land on its authed start screen.
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      final name = provider == OAuthProvider.apple ? 'Apple' : 'Google';
      _toast('$name sign-in isn\'t set up yet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToOnboarding() {
    if (!mounted) return;
    // Route through the COPPA consent gate; it skips itself if already consented.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConsentScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('Welcome 👋',
                  style: MomzoText.sans(28,
                      color: MomzoColors.ink, weight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                  _isSignUp
                      ? "Create your space. It's just for you and your little one."
                      : 'Good to see you again.',
                  style: MomzoText.serif(18, color: MomzoColors.muted, height: 1.4)),
              const SizedBox(height: 28),
              _label('Email'),
              _field(
                controller: _email,
                hint: 'priya@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _label('Password'),
              _field(
                controller: _password,
                hint: '••••••••',
                obscure: _obscure,
                trailing: _obscure ? 'Show' : 'Hide',
                onTrailingTap: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 22),
              MomzoButton(
                _busy ? 'Please wait…' : (_isSignUp ? 'Continue' : 'Log in'),
                onTap: _busy ? null : _submitEmail,
              ),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Divider(color: MomzoColors.cardBorder)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or',
                      style: MomzoText.sans(12,
                          color: MomzoColors.faint, weight: FontWeight.w700)),
                ),
                const Expanded(child: Divider(color: MomzoColors.cardBorder)),
              ]),
              const SizedBox(height: 18),
              _social('Continue with Google', isApple: false,
                  onTap: () => _submitOAuth(OAuthProvider.google)),
              const SizedBox(height: 12),
              _social('Continue with Apple', isApple: true,
                  onTap: () => _submitOAuth(OAuthProvider.apple)),
              const Spacer(),
              GestureDetector(
                onTap: _busy ? null : () => setState(() => _isSignUp = !_isSignUp),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Text.rich(
                      TextSpan(
                        text: _isSignUp
                            ? 'Already have an account?  '
                            : 'New here?  ',
                        style: MomzoText.sans(13,
                            color: MomzoColors.muted, weight: FontWeight.w600),
                        children: [
                          TextSpan(
                            text: _isSignUp ? 'Log in' : 'Create account',
                            style: MomzoText.sans(13,
                                color: MomzoColors.coral, weight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Text(
                  'By continuing you agree to our child-safe Privacy Promise.',
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(12,
                      color: MomzoColors.faint, weight: FontWeight.w400, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(t,
            style: MomzoText.sans(13,
                color: MomzoColors.muted, weight: FontWeight.w700)),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    String? trailing,
    VoidCallback? onTrailingTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              autocorrect: false,
              enableSuggestions: false,
              style: MomzoText.sans(15,
                  color: MomzoColors.ink, weight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: MomzoText.sans(15,
                    color: MomzoColors.faint, weight: FontWeight.w600),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(trailing,
                    style: MomzoText.sans(13,
                        color: MomzoColors.coral, weight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _social(String label, {required bool isApple, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isApple ? MomzoColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isApple
              ? null
              : Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isApple ? Icons.apple : Icons.g_mobiledata_rounded,
                color: isApple ? Colors.white : MomzoColors.ink, size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: MomzoText.sans(15,
                    color: isApple ? Colors.white : MomzoColors.ink,
                    weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
