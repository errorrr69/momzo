import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/try_this_tonight.dart';
import '../../core/widgets/why_it_matters.dart';
import '../../models/daily_card.dart';
import '../../services/child_service.dart';
import '../../services/daily_service.dart';
import '../../services/library_service.dart';
import 'daily_slides_screen.dart';

/// 07 · Daily card · read — micro-read with the signature "why it matters".
///
/// Loads today's assigned card for the current child (age + struggles targeted),
/// records read_at on "Mark as read". Falls back to the designed sample when run
/// in UI-only preview mode (no backend / no child).
class DailyCardScreen extends StatefulWidget {
  const DailyCardScreen({super.key});

  @override
  State<DailyCardScreen> createState() => _DailyCardScreenState();
}

class _DailyCardScreenState extends State<DailyCardScreen> {
  DailyCard? _card;
  bool _loading = true;
  bool _marking = false;
  bool _saved = false;
  bool _savingBookmark = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final child = ChildService.current;
    if (!AppEnv.hasSupabase || child == null) {
      setState(() => _loading = false); // preview/mock mode
      return;
    }
    try {
      final card = await DailyService.todaysCard(child);
      final saved = card == null
          ? <String>{}
          : await LibraryService.savedCardIds();
      if (!mounted) return;
      setState(() {
        _card = card;
        _saved = card != null && saved.contains(card.cardId);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSaved() async {
    final card = _card;
    if (card == null || _savingBookmark) return;
    setState(() {
      _savingBookmark = true;
      _saved = !_saved; // optimistic
    });
    try {
      final now = await LibraryService.toggleSaved(card.cardId);
      if (mounted) setState(() => _saved = now);
    } catch (_) {
      if (mounted) setState(() => _saved = !_saved); // revert
    } finally {
      if (mounted) setState(() => _savingBookmark = false);
    }
  }

  Future<void> _markRead() async {
    final card = _card;
    if (card == null || card.isRead || _marking) {
      if (mounted) Navigator.maybePop(context);
      return;
    }
    setState(() => _marking = true);
    try {
      await DailyService.markRead(card.assignmentId);
      if (!mounted) return;
      setState(() => _card = card.copyWith(readAt: DateTime.now()));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark as read. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  // ---- display values (real card, else the designed sample) ----
  //
  // Every field maps straight to a column now. The old screen had to derive its
  // lede by hunting for the first readable paragraph of a scraped article; the
  // cards are written to the structure, so `summary` IS the lede.
  String get _childName => ChildService.current?.name ?? 'Aarav';
  String get _title => _card?.title ?? 'When "no" turns into a meltdown';
  String get _summary => _card != null
      ? _card!.summary
      : "A meltdown isn't your child being \"difficult\" — it's a brain that's flooded "
          "and can't access calm yet. At 5, that part is still very much under construction.";
  String? get _why => _card != null
      ? _card!.whyItMatters // may be null (renders only when present)
      : "When you said no to more screen time and he crumbled — that was a flood, not "
          "defiance. Naming it out loud helps him learn to ride it.";
  String get _mainRead => _card != null
      ? _card!.mainRead
      : "Feelings arrive faster than words at this age. When something goes wrong, the "
          "feeling fills the whole room and there's no way to describe it.\n\nWhen you "
          "say the feeling out loud, something shifts. Naming it gives the thinking part "
          "of the brain something to hold onto.";
  String? get _activity => _card != null
      ? _card!.activity
      : 'Next time the storm comes, say one sentence and then stop talking: "You really '
          'wanted that." Count to five in your head before adding anything.';
  String get _chip => _card != null ? _chipLabel(_card!) : '😣 BIG FEELINGS · 2 MIN';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: MomzoColors.cream,
        body: Center(child: CircularProgressIndicator(color: MomzoColors.coral)),
      );
    }
    final read = _card?.isRead ?? false;
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleBtn(Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.pop(context)),
                  _circleBtn(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      onTap: _card == null ? null : _toggleSaved),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                children: [
                  GestureDetector(
                    onTap: _openSlides,
                    child: Container(
                      height: 150,
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.bottomLeft,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFAD9A6), MomzoColors.honey],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_chip,
                            style: MomzoText.sans(12,
                                color: MomzoColors.honeyText, weight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // The fixed structure (00_CARD_SPEC §7). Same shape on every
                  // card, every day, so her eye learns where things are:
                  //   title → summary → why this matters → the read → try tonight
                  Text(_title,
                      style: MomzoText.sans(25,
                          color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5, height: 1.2)),
                  const SizedBox(height: 14),

                  // summary — the at-a-glance, largest body text on the screen
                  Text(_summary,
                      style: MomzoText.serif(16.5, color: const Color(0xFF5A4F49), height: 1.6)),
                  const SizedBox(height: 16),

                  // why this matters — coral callout, addressed to her child by name
                  if (_why != null && _why!.isNotEmpty) ...[
                    WhyItMatters(childName: _childName, body: _why!),
                    const SizedBox(height: 18),
                  ],

                  // main_read — the teaching, one idea
                  for (final p in _paragraphs(_mainRead)) ...[
                    Text(p,
                        style: MomzoText.serif(15.5, color: MomzoColors.body, height: 1.6)),
                    const SizedBox(height: 12),
                  ],

                  // activity — sage card, one thing to try inside tonight's routine
                  if (_activity != null && _activity!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    TryThisTonight(_activity!),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF3E9DD))),
              ),
              child: Row(
                children: [
                  _squareBtn(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MomzoButton.confirm(
                      read ? 'Read ✓' : (_marking ? 'Saving…' : 'Mark as read'),
                      onTap: read ? null : _markRead,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSlides() {
    // Preview mode shows the sample deck; a real card opens slides only if it has them.
    if (_card == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DailySlidesScreen()));
    } else if (_card!.hasSlides) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DailySlidesScreen(slides: _card!.slides)));
    }
  }

  // Paragraph split, nothing more.
  //
  // This used to strip markdown headings, bylines and SharePoint placeholders,
  // because the text came from scraped articles and arrived full of CMS debris.
  // The cards are written for this screen, so the only structure in main_read is
  // the blank line between paragraphs.
  static List<String> _paragraphs(String text) => text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  static String _chipLabel(DailyCard c) {
    final tag = (c.tags.isNotEmpty ? c.tags.first : 'read').toUpperCase().replaceAll('-', ' ');
    return '📖 $tag · ${c.readMinutes} MIN';
  }

  Widget _circleBtn(IconData icon, {VoidCallback? onTap}) {
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
        child: Icon(icon, size: 17, color: MomzoColors.body),
      ),
    );
  }

  Widget _squareBtn() {
    return GestureDetector(
      onTap: _card == null ? null : _toggleSaved,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _saved ? MomzoColors.coralTint : MomzoColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
        ),
        child: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            size: 20, color: MomzoColors.coral),
      ),
    );
  }
}
