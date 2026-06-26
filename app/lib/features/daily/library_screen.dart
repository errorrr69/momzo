import 'package:flutter/material.dart';

import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/content_card.dart';
import '../../services/library_service.dart';
import 'card_list_screen.dart';
import 'card_reader_screen.dart';

/// 09 · Learn · library — saved cards + browse vetted content by topic (Task 24).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // Gradient per topic tile (indexed by position in LibraryService.topicGroups).
  static const _tileColors = [
    [Color(0xFFFAD9A6), MomzoColors.honey],
    [Color(0xFFF3B0A0), MomzoColors.coral],
    [Color(0xFFA6D6C2), MomzoColors.sage],
    [Color(0xFF9CCAD6), MomzoColors.sky],
    [Color(0xFFC9B6EC), MomzoColors.lavender],
    [Color(0xFFF6C9A0), MomzoColors.honey],
  ];

  List<ContentCard> _saved = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (AppEnv.hasSupabase) _load();
    LibraryService.savedRevision.addListener(_onSavedChanged);
  }

  @override
  void dispose() {
    LibraryService.savedRevision.removeListener(_onSavedChanged);
    super.dispose();
  }

  void _onSavedChanged() {
    if (mounted && AppEnv.hasSupabase) _load();
  }

  Future<void> _load() async {
    try {
      final saved = await LibraryService.loadSaved();
      final counts = await LibraryService.topicCounts();
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _counts = counts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openReader(ContentCard c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardReaderScreen(card: c, initiallySaved: true),
      ),
    );
    _load(); // a card may have been un-saved
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          children: [
            Text('Learn',
                style: MomzoText.sans(26,
                    color: MomzoColors.ink, weight: FontWeight.w900)),
            const SizedBox(height: 18),
            Text('SAVED BY YOU', style: MomzoText.eyebrow()),
            const SizedBox(height: 11),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: MomzoColors.coral)),
              )
            else if (_saved.isEmpty)
              _emptySaved()
            else
              for (final c in _saved) ...[
                _savedRow(c),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 16),
            Text('BROWSE ALL', style: MomzoText.eyebrow()),
            const SizedBox(height: 11),
            _topicGrid(),
          ],
        ),
      ),
    );
  }

  Widget _emptySaved() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MomzoColors.sageTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🔖', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap the bookmark on any read to keep it here for later.',
              style: MomzoText.sans(13,
                  color: const Color(0xFF5C6B5F), weight: FontWeight.w700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedRow(ContentCard c) {
    return GestureDetector(
      onTap: () => _openReader(c),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC9B6EC), MomzoColors.lavender],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white70, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MomzoText.sans(15,
                          color: MomzoColors.ink, weight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 5),
                  Text('${c.readMinutes} min · ${c.topicLabel}',
                      style: MomzoText.sans(12,
                          color: MomzoColors.muted, weight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.bookmark_rounded, color: MomzoColors.coral, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _topicGrid() {
    final groups = LibraryService.topicGroups;
    final rows = <Widget>[];
    for (var i = 0; i < groups.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: _topic(i)),
          const SizedBox(width: 12),
          if (i + 1 < groups.length)
            Expanded(child: _topic(i + 1))
          else
            const Expanded(child: SizedBox()),
        ],
      ));
      if (i + 2 < groups.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _topic(int i) {
    final g = LibraryService.topicGroups[i];
    final count = _counts[g.label] ?? 0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardListScreen(topicLabel: g.label, tags: g.tags),
        ),
      ),
      child: Container(
        height: 96,
        padding: const EdgeInsets.all(13),
        alignment: Alignment.bottomLeft,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _tileColors[i % _tileColors.length],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(g.label,
                style: MomzoText.sans(14, color: Colors.white, weight: FontWeight.w800)),
            Text('$count reads',
                style: MomzoText.sans(11,
                    color: Colors.white.withValues(alpha: .85), weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
