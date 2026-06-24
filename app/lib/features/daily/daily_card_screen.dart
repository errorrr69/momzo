import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../core/widgets/why_it_matters.dart';
import '../../models/daily_card.dart';
import '../../services/child_service.dart';
import '../../services/daily_service.dart';
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
      if (!mounted) return;
      setState(() {
        _card = card;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
  String get _childName => ChildService.current?.name ?? 'Aarav';
  String get _title => _card?.title ?? 'When "no" turns into a meltdown';
  String get _lede => _card != null
      ? _ledeFrom(_card!.body)
      : "A meltdown isn't your child being \"difficult\" — it's a brain that's flooded "
          "and can't access calm yet. At 8, that part is still very much under construction.";
  String? get _why => _card != null
      ? _card!.whyItMatters // may be null (renders only when present)
      : "When you said no to more screen time and he crumbled — that was a flood, not "
          "defiance. Naming it out loud helps him learn to ride it.";
  String get _source => _card?.source ?? "Based on Momzo's guide on big emotions";
  String get _chip => _card != null ? _chipLabel(_card!) : '😣 BIG EMOTIONS · 3 MIN';

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
                  _circleBtn(Icons.bookmark_border_rounded),
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
                  Text(_title,
                      style: MomzoText.sans(25,
                          color: MomzoColors.ink, weight: FontWeight.w900, spacing: -.5, height: 1.2)),
                  const SizedBox(height: 14),
                  Text(_lede,
                      style: MomzoText.serif(16.5, color: const Color(0xFF5A4F49), height: 1.6)),
                  const SizedBox(height: 14),
                  if (_why != null && _why!.isNotEmpty)
                    WhyItMatters(childName: _childName, body: _why!),
                  const SizedBox(height: 16),
                  Text(_source,
                      style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w700)),
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
                  _squareBtn(Icons.bookmark_border_rounded),
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

  // First readable paragraph, stripped of markdown — keeps this a micro-read.
  static String _ledeFrom(String body) {
    final paras = body.split(RegExp(r'\n\s*\n'));
    for (var p in paras) {
      p = p.trim();
      if (p.isEmpty) continue;
      if (p.startsWith('#')) continue; // skip headings (incl. the title)
      final clean = p
          .replaceAll(RegExp(r'^[#>\-\*\s]+', multiLine: true), '')
          .replaceAll(RegExp(r'[*_`]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.length > 24) return clean.length > 320 ? '${clean.substring(0, 317)}…' : clean;
    }
    return body.replaceAll(RegExp(r'[#>*_`]'), '').trim();
  }

  static String _chipLabel(DailyCard c) {
    final tag = (c.tags.isNotEmpty ? c.tags.first : 'read').toUpperCase().replaceAll('-', ' ');
    final mins = (c.body.split(RegExp(r'\s+')).length / 200).ceil().clamp(1, 9);
    return '📖 $tag · $mins MIN';
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

  Widget _squareBtn(IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: MomzoColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
      ),
      child: const Icon(Icons.bookmark_border_rounded, size: 20, color: MomzoColors.coral),
    );
  }
}
