import 'package:flutter/material.dart';

import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../services/deletion_service.dart';

/// Guarded "delete my child & all data" confirmation (Task 10, Hard Rule #17).
///
/// Deliberately high-friction: the parent must type the child's name to enable
/// the irreversible action. The actual erasure runs server-side (delete-child
/// Edge Function); this screen only confirms intent and reports the result.
class DeleteChildScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const DeleteChildScreen({
    super.key,
    this.childId = '',
    this.childName = 'Aarav',
  });

  @override
  State<DeleteChildScreen> createState() => _DeleteChildScreenState();
}

class _DeleteChildScreenState extends State<DeleteChildScreen> {
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _matches =>
      _confirm.text.trim().toLowerCase() == widget.childName.trim().toLowerCase();

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _delete() async {
    if (!_matches || _busy) return;
    if (!AppEnv.hasSupabase || widget.childId.isEmpty) {
      _toast('Backend not configured (or no child linked) — preview only.');
      return;
    }
    setState(() => _busy = true);
    try {
      await DeletionService.deleteChild(widget.childId);
      if (!mounted) return;
      _toast('${widget.childName}’s profile and all data were deleted.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (_) {
      _toast('Could not delete right now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      appBar: AppBar(
        backgroundColor: MomzoColors.cream,
        elevation: 0,
        foregroundColor: MomzoColors.ink,
        title: Text('Delete profile',
            style: MomzoText.sans(17,
                color: MomzoColors.ink, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: MomzoColors.coralTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: MomzoColors.coralDeep, size: 32),
              ),
              const SizedBox(height: 18),
              Text('Delete ${widget.childName}’s profile?',
                  style: MomzoText.sans(24,
                      color: MomzoColors.ink, weight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                'This permanently erases ${widget.childName}’s profile and '
                'everything linked to it — daily cards, activities, questions, '
                'wishes, plans, milestones, photos and notes. This cannot be undone.',
                style: MomzoText.serif(16, color: MomzoColors.body, height: 1.5),
              ),
              const SizedBox(height: 26),
              Text('Type “${widget.childName}” to confirm',
                  style: MomzoText.sans(13,
                      color: MomzoColors.muted, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                ),
                child: TextField(
                  controller: _confirm,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: MomzoText.sans(15,
                      color: MomzoColors.ink, weight: FontWeight.w600),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _matches && !_busy ? _delete : null,
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: _matches && !_busy ? 1 : .45,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: MomzoColors.coralDeep,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _busy ? 'Deleting…' : 'Delete everything',
                      textAlign: TextAlign.center,
                      style: MomzoText.sans(16,
                          color: Colors.white, weight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _busy ? null : () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text('Keep ${widget.childName}’s profile',
                        style: MomzoText.sans(14,
                            color: MomzoColors.body, weight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
