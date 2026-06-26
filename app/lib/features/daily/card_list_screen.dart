import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/content_card.dart';
import '../../services/child_service.dart';
import '../../services/library_service.dart';
import 'card_reader_screen.dart';

/// Category page (Learn redesign) — split into two calm parts so a mom never
/// faces a wall of boxes: "Picked for <child>" (1 featured + 1 compact, AI-curated
/// with a why-now line) on top, then a light "More in <category>" list below.
class CardListScreen extends StatefulWidget {
  final String topicLabel;
  final List<String> tags;
  final String emoji;
  final String intro;
  const CardListScreen({
    super.key,
    required this.topicLabel,
    required this.tags,
    this.emoji = '',
    this.intro = '',
  });

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  List<ContentCard> _cards = [];
  Set<String> _saved = {};
  bool _loading = true;

  String get _childName => ChildService.current?.name ?? 'your child';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await LibraryService.cardsByTags(widget.tags);
      final saved = await LibraryService.savedCardIds();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _saved = saved;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(ContentCard c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardReaderScreen(card: c, initiallySaved: _saved.contains(c.id)),
      ),
    );
    final saved = await LibraryService.savedCardIds();
    if (mounted) setState(() => _saved = saved);
  }

  @override
  Widget build(BuildContext context) {
    final featured = _cards.isNotEmpty ? _cards[0] : null;
    final compact = _cards.length > 1 ? _cards[1] : null;
    final rest = _cards.length > 2 ? _cards.sublist(2) : <ContentCard>[];

    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: MomzoColors.coral))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _header(),
                  const SizedBox(height: 20),
                  if (featured != null) ...[
                    Row(children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: MomzoColors.coral,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text('PICKED FOR ${_childName.toUpperCase()}',
                          style: MomzoText.eyebrow(color: MomzoColors.coralDeep)
                              .copyWith(letterSpacing: .5)),
                    ]),
                    const SizedBox(height: 11),
                    _featuredPick(featured),
                    if (compact != null) ...[
                      const SizedBox(height: 11),
                      _compactPick(compact),
                    ],
                    const SizedBox(height: 22),
                  ],
                  if (rest.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('MORE IN ${widget.topicLabel.toUpperCase()}',
                            style: MomzoText.eyebrow()),
                        Text('A–Z',
                            style: MomzoText.sans(12,
                                color: MomzoColors.faint, weight: FontWeight.w700)),
                      ],
                    ),
                    for (var i = 0; i < rest.length; i++)
                      _topicRow(rest[i], last: i == rest.length - 1),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
            ),
            child: const Icon(Icons.chevron_left_rounded, size: 24, color: MomzoColors.body),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(widget.topicLabel,
                      style: MomzoText.sans(22,
                          color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.4)),
                ),
                if (widget.emoji.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(widget.emoji, style: const TextStyle(fontSize: 17)),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                  '${_cards.length} reads${widget.intro.isEmpty ? '' : ' · ${widget.intro}'}',
                  style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featuredPick(ContentCard c) {
    final why = (c.whyItMatters?.isNotEmpty ?? false) ? c.whyItMatters! : c.hook;
    return GestureDetector(
      onTap: () => _open(c),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MomzoColors.hairline, width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x17342F30), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.title,
                style: MomzoText.sans(18,
                    color: MomzoColors.ink, weight: FontWeight.w900, height: 1.25, spacing: -.3)),
            if (why?.isNotEmpty ?? false) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: MomzoColors.coralTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: 'WHY NOW · ',
                      style: MomzoText.sans(11, color: MomzoColors.coralDeep, weight: FontWeight.w800)),
                  TextSpan(
                      text: why,
                      style: MomzoText.sans(12.5,
                          color: MomzoColors.coralText, weight: FontWeight.w600, height: 1.4)),
                ])),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${c.readMinutes} min read',
                    style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.only(left: 15, right: 11, top: 9, bottom: 9),
                  decoration: BoxDecoration(
                    color: MomzoColors.coral,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Start',
                        style: MomzoText.sans(13, color: Colors.white, weight: FontWeight.w800)),
                    const Icon(Icons.chevron_right_rounded, size: 17, color: Colors.white),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactPick(ContentCard c) {
    final saved = _saved.contains(c.id);
    return GestureDetector(
      onTap: () => _open(c),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF6EDE2), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFAD9A6), MomzoColors.honey],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.menu_book_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: MomzoText.sans(14,
                          color: MomzoColors.ink, weight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 3),
                  Text('${c.readMinutes} min read',
                      style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 19, color: saved ? MomzoColors.coral : const Color(0xFFC9BBAE)),
          ],
        ),
      ),
    );
  }

  Widget _topicRow(ContentCard c, {bool last = false}) {
    final saved = _saved.contains(c.id);
    return GestureDetector(
      onTap: () => _open(c),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF1E7DB), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: MomzoText.sans(14,
                          color: MomzoColors.ink, weight: FontWeight.w700, height: 1.25)),
                  const SizedBox(height: 2),
                  Text('${c.readMinutes} min',
                      style: MomzoText.sans(12, color: MomzoColors.faint, weight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 18, color: saved ? MomzoColors.coral : const Color(0xFFC9BBAE)),
          ],
        ),
      ),
    );
  }
}
