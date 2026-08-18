import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/forum.dart';
import '../../services/forum_service.dart';

/// Choosing what the Circle calls her, and the community rules (§2.4).
///
/// Shown before her first post, never before merely reading. Two things happen
/// here and both are deliberate:
///
///  * She picks a NAME. It is not her account name and there is no default —
///    the field starts empty, so nothing can quietly publish her real one. The
///    database backs this up: a post carries a foreign key to this row.
///  * She reads the rules at the moment they become relevant, rather than in an
///    onboarding step she scrolled past weeks ago.
///
/// Returns the identity she chose, or null if she backed out.
Future<ForumIdentity?> showCircleIdentitySheet(
  BuildContext context, {
  ForumIdentity? existing,
}) {
  return showModalBottomSheet<ForumIdentity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _IdentitySheet(existing: existing),
  );
}

class _IdentitySheet extends StatefulWidget {
  final ForumIdentity? existing;
  const _IdentitySheet({this.existing});

  @override
  State<_IdentitySheet> createState() => _IdentitySheetState();
}

class _IdentitySheetState extends State<_IdentitySheet> {
  static const _emojis = ['💛', '🌷', '🌿', '☕', '🌙', '🐝', '🍋', '🫖', '🐚', '🌻'];

  late final _name = TextEditingController(text: widget.existing?.displayName ?? '');
  late String _emoji = widget.existing?.avatarEmoji ?? '💛';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'A couple of letters at least.');
      return;
    }
    if (name.length > 24) {
      setState(() => _error = 'A little shorter, if you can.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final identity =
          await ForumService.setIdentity(displayName: name, avatarEmoji: _emoji);
      if (mounted) Navigator.pop(context, identity);
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'That didn’t save. Try again?'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.existing == null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MomzoColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: MomzoColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(first ? 'Before you post' : 'Your Circle name',
                  style: MomzoText.serif(24, color: MomzoColors.ink)),
              const SizedBox(height: 8),
              Text(
                'The Circle only ever sees this name — never the one on your '
                'account, and never your child’s.',
                style: MomzoText.sans(14,
                    color: MomzoColors.body, weight: FontWeight.w600, height: 1.45),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                maxLength: 24,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'What should we call you?',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: MomzoColors.cardBorder, width: 1.4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: MomzoColors.cardBorder, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('AND A LITTLE PICTURE', style: MomzoText.eyebrow()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _emojis)
                    GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: Container(
                        width: 44, height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _emoji == e ? MomzoColors.coralTint : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _emoji == e ? MomzoColors.coral : MomzoColors.cardBorder,
                            width: _emoji == e ? 2 : 1.4,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                ],
              ),
              if (first) ...[
                const SizedBox(height: 18),
                _rules(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: MomzoText.sans(13,
                        color: MomzoColors.coralDeep, weight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: MomzoColors.coral,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(first ? 'Join the Circle' : 'Save',
                      style: MomzoText.sans(15,
                          color: Colors.white, weight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The community rules, in the community-plan voice rather than as terms.
  Widget _rules() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MomzoColors.sageTint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How we do this here',
                style: MomzoText.sans(13.5,
                    color: const Color(0xFF3F5E4A), weight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final line in const [
              'Kindness only. Everyone here is doing their best on not much sleep.',
              'No advice that shames. Share what worked for you, not what she did wrong.',
              'Nothing that identifies a child — no full names, no schools.',
              'Nothing for sale.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('· $line',
                    style: MomzoText.sans(12.5,
                        color: const Color(0xFF4E7A60),
                        weight: FontWeight.w600,
                        height: 1.4)),
              ),
          ],
        ),
      );
}
