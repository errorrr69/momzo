import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/content_card.dart';
import '../../services/library_service.dart';

/// Generic reader for any vetted content card (Task 24) — used from the library /
/// browse views. Has a working bookmark toggle (saved_cards).
class CardReaderScreen extends StatefulWidget {
  final ContentCard card;
  final bool initiallySaved;
  const CardReaderScreen({super.key, required this.card, this.initiallySaved = false});

  @override
  State<CardReaderScreen> createState() => _CardReaderScreenState();
}

class _CardReaderScreenState extends State<CardReaderScreen> {
  late bool _saved = widget.initiallySaved;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _saved = !_saved; // optimistic
    });
    try {
      final now = await LibraryService.toggleSaved(widget.card.id);
      if (mounted) setState(() => _saved = now);
    } catch (_) {
      if (mounted) setState(() => _saved = !_saved); // revert
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: MomzoColors.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: Icon(
                      _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: MomzoColors.coral,
                    ),
                    onPressed: _toggle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: MomzoColors.honeyTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${c.topicLabel.toUpperCase()}  ·  ${c.readMinutes} MIN',
                      style: MomzoText.sans(11,
                          color: MomzoColors.honey, weight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(c.title,
                      style: MomzoText.sans(24,
                          color: MomzoColors.ink, weight: FontWeight.w900, height: 1.2)),
                  const SizedBox(height: 14),
                  if (c.whyItMatters?.isNotEmpty ?? false) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: MomzoColors.coralTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(c.whyItMatters!,
                          style: MomzoText.sans(14,
                              color: MomzoColors.coralText,
                              weight: FontWeight.w600,
                              height: 1.45)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(c.body,
                      style: MomzoText.serif(16, color: MomzoColors.body, height: 1.55)),
                  if (c.source != null && c.source!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Source: ${c.source}',
                        style: MomzoText.sans(12,
                            color: MomzoColors.muted, weight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
