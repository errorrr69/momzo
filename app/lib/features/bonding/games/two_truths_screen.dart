import 'package:flutter/material.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../core/widgets/momzo_buttons.dart';
import '../../../services/game_service.dart';
import '../../../services/stt_service.dart';
import 'game_close_screen.dart';
import 'game_scaffold.dart';

/// Two Truths & a Lie — voice-to-text + manual confirm (edits #5, approach a).
/// The speaker dictates (or types) three statements; the other picks the two they
/// think are true; the speaker then marks the real truths; reveal celebrates gently
/// (Hard Rule #18). Statements are personal — kept in memory for the round only,
/// never stored. Band A plays as "Two Real, One Silly" (games spec §2.4).
class TwoTruthsScreen extends StatefulWidget {
  final Game game;
  const TwoTruthsScreen({super.key, required this.game});

  @override
  State<TwoTruthsScreen> createState() => _TwoTruthsScreenState();
}

enum _Phase { write, guess, speakerPick, reveal }

class _TwoTruthsScreenState extends State<TwoTruthsScreen> {
  List<GameItem> _items = [];
  int _round = 0;
  bool _loading = true;
  bool _sttReady = false;

  _Phase _phase = _Phase.write;
  final List<TextEditingController> _stmt = [TextEditingController(), TextEditingController(), TextEditingController()];
  final Set<int> _guessSel = {}; // the OTHER player's "these two are true"
  final Set<int> _truthSel = {}; // the SPEAKER's actual two truths
  int _listeningBox = -1;

  String get _band => GameService.currentBand;
  bool get _silly => _band == 'A';

  @override
  void initState() {
    super.initState();
    _load();
    SttService.ensureReady().then((ok) {
      if (mounted) setState(() => _sttReady = ok);
    });
  }

  @override
  void dispose() {
    SttService.stop();
    for (final c in _stmt) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final n = widget.game.roundsFor(_band);
    try {
      final items = await GameService.deal(widget.game.slug, n);
      if (mounted) setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _scaffold {
    final p = _items.isNotEmpty ? _items[_round % _items.length].payload : const {};
    return (p['scaffold'] as String?) ?? 'something you like, somewhere you’ve been, an animal';
  }

  bool get _allFilled => _stmt.every((c) => c.text.trim().isNotEmpty);

  // ---- dictation ----
  Future<void> _dictate(int box) async {
    if (!_sttReady) return;
    if (SttService.isListening) {
      await SttService.stop();
      if (mounted) setState(() => _listeningBox = -1);
      return;
    }
    setState(() => _listeningBox = box);
    await SttService.listen(onResult: (text, isFinal) {
      if (!mounted) return;
      setState(() {
        _stmt[box].text = text;
        _stmt[box].selection = TextSelection.collapsed(offset: text.length);
        if (isFinal) _listeningBox = -1;
      });
    });
  }

  void _resetRound() {
    for (final c in _stmt) {
      c.clear();
    }
    _guessSel.clear();
    _truthSel.clear();
    _listeningBox = -1;
  }

  void _nextRound() {
    SttService.stop();
    if (_round < _items.length - 1) {
      setState(() {
        _round++;
        _phase = _Phase.write;
        _resetRound();
      });
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameCloseScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GameLoading();
    if (_items.isEmpty) return const GameEmpty();
    return GameScaffold(
      title: 'Two Truths & a Lie',
      subtitle: 'Round ${_round + 1} of ${_items.length}',
      onClose: () => Navigator.maybePop(context),
      child: switch (_phase) {
        _Phase.write => _writeStep(),
        _Phase.guess => _pickStep(
            heading: 'Pick the TWO you think are TRUE',
            sub: 'Other player’s turn — no peeking who wrote what!',
            sel: _guessSel,
            cta: 'Truth',
            onDone: () => setState(() => _phase = _Phase.speakerPick),
          ),
        _Phase.speakerPick => _pickStep(
            heading: 'Which two were actually true?',
            sub: 'Speaker — mark your two real ones.',
            sel: _truthSel,
            cta: 'Reveal',
            onDone: () => setState(() => _phase = _Phase.reveal),
          ),
        _Phase.reveal => _revealStep(),
      },
    );
  }

  // Phase 1 — speaker writes/dictates three statements.
  Widget _writeStep() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: MomzoColors.lavenderTint, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(_silly ? 'Say two REAL things and one SILLY pretend thing! 🤭'
                          : 'Say two TRUE things and one made-up one.',
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(14, color: MomzoColors.lavenderText, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Ideas: $_scaffold',
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(12, color: MomzoColors.body, weight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 3; i++) ...[
          _statementField(i),
          const SizedBox(height: 10),
        ],
        const Spacer(),
        if (!_sttReady)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Tip: type your statements (voice isn’t available on this phone).',
                textAlign: TextAlign.center,
                style: MomzoText.sans(11, color: MomzoColors.faint, weight: FontWeight.w600)),
          ),
        SizedBox(
          width: double.infinity,
          child: MomzoButton('Done — pass to guess', color: MomzoColors.lavender,
              onTap: _allFilled ? () => setState(() => _phase = _Phase.guess) : null),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _statementField(int i) {
    final listening = _listeningBox == i;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: listening ? MomzoColors.coral : MomzoColors.cardBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Text('${i + 1}', style: MomzoText.sans(15, color: MomzoColors.faint, weight: FontWeight.w900)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _stmt[i],
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none, isDense: true, hintText: 'Statement…',
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_sttReady)
            GestureDetector(
              onTap: () => _dictate(i),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: listening ? MomzoColors.coral : MomzoColors.coralTint, shape: BoxShape.circle),
                child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: listening ? Colors.white : MomzoColors.coral, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // Phases 2 & 3 — tap to select exactly two of the three statements.
  Widget _pickStep({
    required String heading,
    required String sub,
    required Set<int> sel,
    required String cta,
    required VoidCallback onDone,
  }) {
    return Column(
      children: [
        Text(heading,
            textAlign: TextAlign.center,
            style: MomzoText.sans(19, color: MomzoColors.ink, weight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center,
            style: MomzoText.sans(13, color: MomzoColors.muted, weight: FontWeight.w600)),
        const SizedBox(height: 18),
        for (var i = 0; i < 3; i++) ...[
          _selectableBox(i, sel.contains(i), () {
            setState(() {
              if (sel.contains(i)) {
                sel.remove(i);
              } else if (sel.length < 2) {
                sel.add(i);
              }
            });
          }),
          const SizedBox(height: 12),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: MomzoButton(cta, color: MomzoColors.lavender, onTap: sel.length == 2 ? onDone : null),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _selectableBox(int i, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? MomzoColors.lavender : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? MomzoColors.lavender : MomzoColors.cardBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? Colors.white : MomzoColors.faint, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_stmt[i].text.trim(),
                  style: MomzoText.sans(15,
                      color: selected ? Colors.white : MomzoColors.ink, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // Phase 4 — reveal truths vs the lie + whether the guesser matched.
  Widget _revealStep() {
    final got = _guessSel.length == 2 && _guessSel.containsAll(_truthSel);
    return Column(
      children: [
        Text(got ? 'You got it! 🎉' : 'So close — now you know! 💜',
            textAlign: TextAlign.center,
            style: MomzoText.sans(22, color: MomzoColors.ink, weight: FontWeight.w900)),
        const SizedBox(height: 18),
        for (var i = 0; i < 3; i++) ...[
          _revealBox(i),
          const SizedBox(height: 12),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: MomzoButton(_round < _items.length - 1 ? 'Next round →' : 'Finish 💜',
              color: MomzoColors.lavender, onTap: _nextRound),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _revealBox(int i) {
    final isTruth = _truthSel.contains(i);
    final bg = isTruth ? MomzoColors.sageTint : MomzoColors.coralTint;
    final label = isTruth ? (_silly ? 'REAL' : 'TRUE') : (_silly ? 'SILLY' : 'LIE');
    final labelColor = isTruth ? MomzoColors.sageText : MomzoColors.coralText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Text(_stmt[i].text.trim(),
                style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text(label, style: MomzoText.sans(11, color: labelColor, weight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
