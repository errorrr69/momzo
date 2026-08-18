import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/forum.dart';
import '../../services/forum_service.dart';

/// Reporting something (Expansion Plan §2.4).
///
/// The reasons are deliberately worded so that "someone here may need help" is a
/// first-class option rather than buried in "other". The forum is where hard
/// things will surface, and a mother who is worried about another mother needs a
/// route that is obviously not an accusation.
///
/// Returns true if a report was filed.
Future<bool?> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final String targetId;
  const _ReportSheet({required this.targetType, required this.targetId});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) return;
    setState(() => _sending = true);
    try {
      await ForumService.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _reason!,
        note: _note.text.trim().isEmpty ? null : _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Tell us what’s wrong',
                  style: MomzoText.serif(23, color: MomzoColors.ink)),
              const SizedBox(height: 6),
              Text('A person reads every one of these. Nothing is deleted automatically.',
                  style: MomzoText.sans(13.5,
                      color: MomzoColors.body, weight: FontWeight.w600, height: 1.45)),
              const SizedBox(height: 16),
              for (final r in ReportReason.values) ...[
                _option(r),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Anything else we should know? (optional)',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_reason == null || _sending) ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: MomzoColors.coral,
                    disabledBackgroundColor: MomzoColors.hairline,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text('Send this',
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

  Widget _option(ReportReason r) {
    final selected = _reason == r;
    // The crisis-adjacent reason gets its own colour, because it is not a
    // complaint and should not look like one.
    final urgent = r == ReportReason.needsHelp;
    return GestureDetector(
      onTap: () => setState(() => _reason = r),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? (urgent ? MomzoColors.sageTint : MomzoColors.coralTint)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? (urgent ? MomzoColors.sage : MomzoColors.coral)
                : MomzoColors.cardBorder,
            width: selected ? 1.8 : 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.label,
                style: MomzoText.sans(14,
                    color: MomzoColors.ink, weight: FontWeight.w800)),
            if (r.blurb.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.blurb,
                  style: MomzoText.sans(12.5,
                      color: MomzoColors.muted, weight: FontWeight.w600, height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }
}
