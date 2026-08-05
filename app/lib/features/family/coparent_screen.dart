import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../models/child.dart';
import '../../services/family_service.dart';

/// Co-parent / caregiver sharing (Task 33). Owner mints a one-time code to share
/// out-of-band; a co-parent redeems a code to join. Owner-only actions (invite,
/// revoke) are gated here in the UI and enforced again by RLS in the database.
class CoparentScreen extends StatefulWidget {
  final Child child;
  const CoparentScreen({super.key, required this.child});

  @override
  State<CoparentScreen> createState() => _CoparentScreenState();
}

class _CoparentScreenState extends State<CoparentScreen> {
  final _codeInput = TextEditingController();
  List<FamilyMember> _members = [];
  bool _loading = true;
  bool _busy = false;
  String? _invite; // freshly minted code to display

  bool get _isOwner => FamilyService.isOwner(widget.child);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeInput.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await FamilyService.members(widget.child.id);
      if (mounted) setState(() {
        _members = m;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mintInvite() async {
    setState(() => _busy = true);
    try {
      final code = await FamilyService.createInvite(widget.child.id);
      if (mounted) setState(() => _invite = code);
    } catch (_) {
      _snack('Could not create an invite just now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _codeInput.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final child = await FamilyService.acceptInvite(code);
      if (!mounted) return;
      _codeInput.clear();
      _snack("You've joined ${child?.name ?? 'the family'} 🌸");
      Navigator.pop(context);
    } catch (e) {
      _snack(e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'That code did not work.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(FamilyMember m) async {
    setState(() => _busy = true);
    try {
      await FamilyService.removeMember(m.id);
      await _load();
    } catch (_) {
      _snack('Could not remove access just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _snack('Invite code copied');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      appBar: AppBar(
        backgroundColor: MomzoColors.cream,
        elevation: 0,
        foregroundColor: MomzoColors.ink,
        title: Text('Co-parents & sharing',
            style: MomzoText.sans(18, color: MomzoColors.ink, weight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              children: [
                Text('Share ${widget.child.name} with someone you trust',
                    style: MomzoText.serif(22, color: MomzoColors.ink, height: 1.3)),
                const SizedBox(height: 6),
                Text('A co-parent or grandparent can see and take part — daily cards, '
                    'activities, questions and memories. Only you can edit or remove '
                    '${widget.child.name}.',
                    style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w500, height: 1.45)),
                const SizedBox(height: 22),
                if (_isOwner) ..._ownerSection(),
                _joinSection(),
              ],
            ),
    );
  }

  List<Widget> _ownerSection() {
    return [
      Text('WHO SHARES ${widget.child.name.toUpperCase()}', style: MomzoText.eyebrow()),
      const SizedBox(height: 10),
      for (final m in _members) _memberRow(m),
      if (_members.isEmpty)
        Text("It's just you for now.",
            style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w600)),
      const SizedBox(height: 18),
      if (_invite == null)
        MomzoButton(_busy ? 'Creating…' : 'Invite a co-parent',
            onTap: _busy ? null : _mintInvite)
      else
        _inviteCard(_invite!),
      const SizedBox(height: 28),
      const Divider(color: MomzoColors.cardBorder),
      const SizedBox(height: 20),
    ];
  }

  Widget _memberRow(FamilyMember m) {
    final owner = m.relationship == 'parent';
    final pending = m.status == 'invited';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MomzoColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: MomzoColors.honey, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.displayName,
                    style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w800)),
                Text(owner ? 'Owner' : (pending ? '${m.relationship} · pending' : m.relationship),
                    style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w600)),
              ],
            ),
          ),
          // Only the owner may revoke, and never the owner row itself.
          if (_isOwner && !owner)
            GestureDetector(
              onTap: _busy ? null : () => _revoke(m),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: MomzoColors.muted, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inviteCard(String code) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MomzoColors.sageTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share this code (valid 7 days)',
              style: MomzoText.sans(13, color: const Color(0xFF4E7A60), weight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectableText(code,
                    style: MomzoText.sans(22, color: MomzoColors.ink, weight: FontWeight.w900, spacing: 1)),
              ),
              GestureDetector(
                onTap: () => _copy(code),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: MomzoColors.sage, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Copy', style: MomzoText.sans(13, color: Colors.white, weight: FontWeight.w800)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('They enter it under “Join a family” to start sharing.',
              style: MomzoText.sans(12.5, color: MomzoColors.muted, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _joinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JOIN A FAMILY', style: MomzoText.eyebrow()),
        const SizedBox(height: 8),
        Text('Got an invite code? Enter it to start sharing a child.',
            style: MomzoText.sans(14, color: MomzoColors.muted, weight: FontWeight.w500, height: 1.4)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
          ),
          child: TextField(
            controller: _codeInput,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _join(),
            style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w700),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Enter invite code',
              hintStyle: MomzoText.sans(15, color: MomzoColors.faint, weight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 12),
        MomzoSecondaryButton(_busy ? 'Joining…' : 'Join', onTap: _busy ? null : _join),
      ],
    );
  }
}
