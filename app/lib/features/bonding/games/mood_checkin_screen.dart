import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';
import '../../../services/tts_service.dart';
import 'game_close_screen.dart';
import 'game_scaffold.dart';

/// Mood Check-in — pick a feeling face together, then a gentle (optional) follow-up.
/// The calmest, most careful game: never probes, "just picking a face is enough"
/// (games spec §2.16). If something distressing surfaces, the parent leads — the
/// app only offers the gentle prompt.
class MoodCheckinScreen extends StatefulWidget {
  final Game game;
  const MoodCheckinScreen({super.key, required this.game});

  @override
  State<MoodCheckinScreen> createState() => _MoodCheckinScreenState();
}

class _MoodCheckinScreenState extends State<MoodCheckinScreen> {
  List<GameItem> _items = [];
  int _i = 0;
  bool _loading = true;
  ({String emoji, String label})? _picked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final n = widget.game.roundsFor(GameService.currentBand);
    try {
      final items = await GameService.deal(widget.game.slug, n);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _next() {
    TtsService.stop();
    if (_i < _items.length - 1) {
      setState(() {
        _i++;
        _picked = null;
      });
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameCloseScreen()));
    }
  }

  List<({String emoji, String label})> _feelings(Map<String, dynamic> p) {
    final raw = p['feelings'] ?? p['feelingSet'] ?? const [];
    final out = <({String emoji, String label})>[];
    if (raw is List) {
      for (final f in raw) {
        if (f is Map) {
          out.add((emoji: (f['emoji'] ?? '🙂').toString(), label: (f['label'] ?? '').toString()));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GameLoading();
    if (_items.isEmpty) return const GameEmpty();
    final p = _items[_i].payload;
    final feelings = _feelings(p);
    final followUp = (p['gentleFollowUp'] ?? p['followUp'] ?? 'Want to tell me about it?').toString();

    return GameScaffold(
      title: 'Mood Check-in',
      subtitle: 'A gentle moment 💜',
      onClose: () => Navigator.maybePop(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('How are you feeling right now?',
              textAlign: TextAlign.center,
              style: MomzoText.sans(18, color: MomzoColors.ink, weight: FontWeight.w900)),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [for (final f in feelings) _faceChip(f)],
          ),
          if (_picked != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MomzoColors.lavenderTint, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Text('${_picked!.emoji}  ${_picked!.label}',
                    style: MomzoText.sans(18, color: MomzoColors.lavenderText, weight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(followUp,
                    textAlign: TextAlign.center,
                    style: MomzoText.serif(17, color: MomzoColors.ink, height: 1.4)),
                const SizedBox(height: 6),
                Text('(or just picking a face is enough 💜)',
                    textAlign: TextAlign.center,
                    style: MomzoText.sans(12, color: MomzoColors.muted, weight: FontWeight.w600)),
              ]),
            ),
          ],
        ],
      ),
      footer: _picked == null
          ? null
          : SizedBox(
              width: double.infinity,
              child: MomzoButton(_i < _items.length - 1 ? 'Next →' : 'Finish 💜',
                  color: MomzoColors.lavender, onTap: _next),
            ),
    );
  }

  Widget _faceChip(({String emoji, String label}) f) {
    final sel = _picked?.label == f.label;
    return GestureDetector(
      onTap: () {
        setState(() => _picked = f);
        TtsService.speak(f.label);
      },
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? MomzoColors.lavender : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: sel ? MomzoColors.lavender : MomzoColors.cardBorder, width: 1.5),
        ),
        child: Column(children: [
          Text(f.emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 6),
          Text(f.label,
              style: MomzoText.sans(12,
                  color: sel ? Colors.white : MomzoColors.body, weight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
