import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../models/content_card.dart';
import '../../services/library_service.dart';

/// Topic reader (Learn redesign) — leads with scannable pieces so a busy mom gets
/// the gist fast: a hook, a 3-point "quick version", and a "try this tonight". The
/// full article sits below for anyone who wants the depth. Falls back to the body
/// when the quick-read fields aren't generated yet. Bookmark via saved_cards.
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
                  if (c.hook?.isNotEmpty ?? false) ...[
                    _tintBox(
                      MomzoColors.coralTint,
                      Text(c.hook!,
                          style: MomzoText.serif(16,
                              color: MomzoColors.coralText,
                              italic: true, weight: FontWeight.w500, height: 1.45)),
                    ),
                    const SizedBox(height: 18),
                  ] else if (c.whyItMatters?.isNotEmpty ?? false) ...[
                    _tintBox(
                      MomzoColors.coralTint,
                      Text(c.whyItMatters!,
                          style: MomzoText.serif(16,
                              color: MomzoColors.coralText,
                              italic: true, weight: FontWeight.w500, height: 1.45)),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (c.quickPoints.length >= 3) ...[
                    _quickVersion(c.quickPoints),
                    const SizedBox(height: 18),
                  ],
                  if (c.tryThis?.isNotEmpty ?? false) ...[
                    _tryThis(c.tryThis!),
                    const SizedBox(height: 20),
                  ],
                  if (c.body.trim().isNotEmpty) ...[
                    Row(children: [
                      Text(c.hasQuickRead ? 'THE FULL READ' : 'THE READ',
                          style: MomzoText.eyebrow()),
                    ]),
                    const SizedBox(height: 10),
                    for (final p in _paragraphs(c.body)) ...[
                      Text(p,
                          style: MomzoText.serif(15.5, color: MomzoColors.body, height: 1.6)),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (c.source?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text('Source: ${c.source}',
                        style: MomzoText.sans(12,
                            color: MomzoColors.muted, weight: FontWeight.w600)),
                  ],
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

  Widget _tintBox(Color color, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  Widget _quickVersion(List<String> points) {
    Widget pt(Color dot, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 7, height: 7,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(text,
                    style: MomzoText.sans(13.5,
                        color: MomzoColors.ink, weight: FontWeight.w600, height: 1.4)),
              ),
            ],
          ),
        );
    const dots = [MomzoColors.honey, MomzoColors.sage, MomzoColors.sky];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MomzoColors.hairline, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bolt_rounded, size: 16, color: MomzoColors.coral),
            const SizedBox(width: 6),
            Text('THE QUICK VERSION',
                style: MomzoText.eyebrow(color: MomzoColors.coralDeep)
                    .copyWith(letterSpacing: .5, fontSize: 11)),
          ]),
          const SizedBox(height: 11),
          for (var i = 0; i < points.length && i < 3; i++) pt(dots[i % 3], points[i]),
        ],
      ),
    );
  }

  Widget _tryThis(String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(color: MomzoColors.sageTint, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRY THIS TONIGHT',
              style: MomzoText.eyebrow(color: MomzoColors.sageText).copyWith(letterSpacing: .4)),
          const SizedBox(height: 9),
          Text(body,
              style: MomzoText.sans(14,
                  color: MomzoColors.sageText, weight: FontWeight.w600, height: 1.5)),
        ],
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

  // First several readable paragraphs of the body, stripped of markdown + obvious
  // byline noise — keeps "the full read" clean without fabricating sections.
  List<String> _paragraphs(String body) {
    final out = <String>[];
    for (var p in body.split(RegExp(r'\n\s*\n'))) {
      p = p
          .replaceAll(RegExp(r'^[#>\-\*\s]+'), '')
          .replaceAll(RegExp(r'[*_`]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (p.length < 24) continue;
      if (RegExp(r'^(by |click here|http)', caseSensitive: false).hasMatch(p)) continue;
      out.add(p);
      if (out.length >= 12) break;
    }
    return out;
  }
}
