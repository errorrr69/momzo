import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/content_card.dart';
import '../../services/library_service.dart';
import 'card_reader_screen.dart';

/// Browse the vetted cards in one topic (Task 24).
class CardListScreen extends StatefulWidget {
  final String topicLabel;
  final List<String> tags;
  const CardListScreen({super.key, required this.topicLabel, required this.tags});

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  List<ContentCard> _cards = [];
  Set<String> _saved = {};
  bool _loading = true;

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
    // refresh bookmark state on return
    final saved = await LibraryService.savedCardIds();
    if (mounted) setState(() => _saved = saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: MomzoColors.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(widget.topicLabel,
                      style: MomzoText.sans(22,
                          color: MomzoColors.ink, weight: FontWeight.w900)),
                ],
              ),
            ),
            if (_loading)
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(color: MomzoColors.coral)))
            else if (_cards.isEmpty)
              Expanded(
                child: Center(
                  child: Text('No reads here yet.',
                      style: MomzoText.serif(16, color: MomzoColors.muted)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: _cards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _row(_cards[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(ContentCard c) {
    final saved = _saved.contains(c.id);
    return GestureDetector(
      onTap: () => _open(c),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: MomzoText.sans(15,
                          color: MomzoColors.ink, weight: FontWeight.w800, height: 1.25)),
                  const SizedBox(height: 5),
                  Text('${c.readMinutes} min  ·  ${c.topicLabel}',
                      style: MomzoText.sans(12,
                          color: MomzoColors.muted, weight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: saved ? MomzoColors.coral : MomzoColors.faint, size: 20),
          ],
        ),
      ),
    );
  }
}
