import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/try_this_tonight.dart';
import '../../core/widgets/why_it_matters.dart';
import '../../models/content_card.dart';
import '../../services/child_service.dart';
import '../../services/library_service.dart';

/// Topic reader — renders a saved or browsed card in the same fixed structure as
/// the daily card (00_CARD_SPEC §7): title → summary → why this matters →
/// main_read → try this tonight. Bookmark via saved_cards.
///
/// It used to reconstruct a readable shape from scraped article text (a generated
/// hook, three generated bullets, a "full read" fallback). The cards now arrive in
/// that shape, so there is nothing to reconstruct.
class CardReaderScreen extends StatefulWidget {
  final ContentCard card;
  final bool initiallySaved;
  const CardReaderScreen({super.key, required this.card, this.initiallySaved = false});

  @override
  State<CardReaderScreen> createState() => _CardReaderScreenState();
}

class _CardReaderScreenState extends State<CardReaderScreen> {
  /// The callout is addressed to the child by name, exactly as on the daily card.
  String get _childName => ChildService.current?.name ?? 'your child';

  late bool _saved = widget.initiallySaved;
  bool _busy = false;
  final _scroll = ScrollController();
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final p = max <= 0 ? 0.0 : (_scroll.offset / max).clamp(0.0, 1.0);
      if ((p - _progress).abs() > 0.01) setState(() => _progress = p);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _saved = !_saved;
    });
    try {
      final now = await LibraryService.toggleSaved(widget.card.id);
      if (mounted) setState(() => _saved = now);
    } catch (_) {
      if (mounted) setState(() => _saved = !_saved);
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
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circle(Icons.chevron_left_rounded, MomzoColors.body,
                      onTap: () => Navigator.maybePop(context)),
                  _circle(
                      _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      MomzoColors.coral,
                      onTap: _toggle),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 13, 24, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFF0E4D6),
                  valueColor: const AlwaysStoppedAnimation(MomzoColors.coral),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 15, 24, 24),
                children: [
                  _pill('${c.topicLabel.toUpperCase()} · ${c.readMinutes} MIN READ'),
                  const SizedBox(height: 13),
                  Text(c.title,
                      style: MomzoText.sans(25,
                          color: MomzoColors.ink,
                          weight: FontWeight.w900, height: 1.18, spacing: -.5)),
                  const SizedBox(height: 14),
                  // The fixed structure (00_CARD_SPEC §7) — identical to the daily
                  // card, because a card should read the same wherever she opens it.

                  // summary
                  if (c.summary.isNotEmpty) ...[
                    Text(c.summary,
                        style: MomzoText.serif(16.5,
                            color: const Color(0xFF5A4F49), height: 1.6)),
                    const SizedBox(height: 16),
                  ],

                  // why this matters
                  if (c.whyItMatters?.isNotEmpty ?? false) ...[
                    WhyItMatters(childName: _childName, body: c.whyItMatters!),
                    const SizedBox(height: 18),
                  ],

                  // main_read
                  for (final p in _paragraphs(c.mainRead)) ...[
                    Text(p,
                        style: MomzoText.serif(15.5, color: MomzoColors.body, height: 1.6)),
                    const SizedBox(height: 12),
                  ],

                  // activity
                  if (c.activity?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 6),
                    TryThisTonight(c.activity!),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  // ---- pieces ----

  Widget _circle(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _pill(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: MomzoColors.honeyTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: MomzoText.sans(11,
                color: MomzoColors.honeyText, weight: FontWeight.w800, spacing: .4)),
      ),
    );
  }

  Widget _footer() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: MomzoColors.hairline, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _saved ? MomzoColors.coralTint : MomzoColors.cream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
              ),
              child: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 20, color: MomzoColors.coral),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: MomzoButton.confirm(_saved ? 'Saved ✓' : 'Save to library', onTap: _toggle)),
        ],
      ),
    );
  }

  // Paragraph split, nothing more.
  //
  // This used to strip markdown, bylines and SharePoint placeholders, because the
  // text came from scraped articles. The cards are written for this screen, so the
  // only structure in main_read is the blank line between paragraphs.
  List<String> _paragraphs(String text) => text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}
