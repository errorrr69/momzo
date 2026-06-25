import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../services/child_service.dart';
import '../../services/question_service.dart';

/// 18 · Question · reveal — both answers shown side by side, a shared moment
/// (Task 19). Answer first (you + your child), then reveal. Falls back to the
/// designed sample in UI-only preview.
class DailyQuestionScreen extends StatefulWidget {
  const DailyQuestionScreen({super.key});

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  final _child = TextEditingController();
  final _parent = TextEditingController();
  DailyQuestion? _q;
  Map<String, String> _answers = {};
  bool _loading = true;
  bool _saving = false;

  bool get _live => AppEnv.hasSupabase && ChildService.current != null;
  bool get _revealed => _answers.containsKey('parent') && _answers.containsKey('child');

  @override
  void initState() {
    super.initState();
    if (_live) {
      _load();
    } else {
      _loading = false; // preview/mock
    }
  }

  @override
  void dispose() {
    _child.dispose();
    _parent.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final q = await QuestionService.todaysQuestion();
      final answers = q == null ? <String, String>{} : await QuestionService.todaysResponses(q.id);
      if (!mounted) return;
      setState(() {
        _q = q;
        _answers = answers;
        _child.text = answers['child'] ?? '';
        _parent.text = answers['parent'] ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reveal() async {
    if (_saving || _q == null) return;
    if (_child.text.trim().isEmpty || _parent.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add both answers to reveal them together.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_answers['child'] != _child.text.trim()) {
        await QuestionService.saveResponse(questionId: _q!.id, respondent: 'child', text: _child.text);
      }
      if (_answers['parent'] != _parent.text.trim()) {
        await QuestionService.saveResponse(questionId: _q!.id, respondent: 'parent', text: _parent.text);
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _childName => ChildService.current?.name ?? 'Aarav';
  String get _prompt => _q?.prompt ?? 'If our family was an animal, which one would we be?';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.lavender, MomzoColors.lavenderTint, MomzoColors.cream],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 0, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 8, 26, 0),
                child: Column(
                  children: [
                    Text(_revealed || !_live ? 'QUESTION OF THE DAY · REVEALED' : 'QUESTION OF THE DAY',
                        style: MomzoText.eyebrow(color: Colors.white).copyWith(letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Text(_prompt,
                        textAlign: TextAlign.center,
                        style: MomzoText.serif(23, color: Colors.white, height: 1.3)),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : (_live && !_revealed ? _answerView() : _revealView()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- answer mode ---
  Widget _answerView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
      children: [
        Text('Ask $_childName, then add your own — reveal them together. 💜',
            textAlign: TextAlign.center,
            style: MomzoText.sans(13.5, color: MomzoColors.lavenderText, weight: FontWeight.w600, height: 1.4)),
        const SizedBox(height: 18),
        _field("$_childName's answer", _child, MomzoColors.honey, MomzoColors.honeyTint),
        const SizedBox(height: 14),
        _field('Your answer', _parent, MomzoColors.coral, MomzoColors.coralTint),
        const SizedBox(height: 22),
        MomzoButton(_saving ? 'Saving…' : 'Reveal together',
            color: MomzoColors.lavender, onTap: _saving ? null : _reveal),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, Color accent, Color tint) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: MomzoText.sans(13, color: MomzoColors.ink, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            minLines: 1,
            maxLines: 3,
            style: MomzoText.serif(17, color: const Color(0xFF5A4F49), height: 1.3),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Type here…',
            ),
          ),
        ],
      ),
    );
  }

  // --- reveal mode ---
  Widget _revealView() {
    final childAns = _answers['child'] ?? '"A pack of wolves, because we stick together and we\'re loud!" 🐺';
    final parentAns = _answers['parent'] ?? '"Honestly? Otters. Playful, a little chaotic, always together." 🦦';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            children: [
              _answerCard(
                who: '$_childName said',
                avatarBg: MomzoColors.honeyTint, avatarColor: MomzoColors.honey, answer: childAns,
              ),
              const SizedBox(height: 14),
              _answerCard(
                who: 'You said',
                avatarBg: MomzoColors.coralTint, avatarColor: MomzoColors.coral, answer: parentAns,
              ),
              const SizedBox(height: 14),
              Text('A little moment, just the two of you. 💜',
                  textAlign: TextAlign.center,
                  style: MomzoText.serif(15, color: MomzoColors.lavenderText, italic: true)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
          child: MomzoButton('Done', color: MomzoColors.lavender, onTap: () => Navigator.pop(context)),
        ),
      ],
    );
  }

  Widget _answerCard({required String who, required Color avatarBg, required Color avatarColor, required String answer}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: MomzoColors.lavenderText.withOpacity(.18), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
              child: Icon(Icons.face_rounded, color: avatarColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(who, style: MomzoText.sans(15, color: MomzoColors.ink, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Text(answer, style: MomzoText.serif(19, color: const Color(0xFF5A4F49), height: 1.4)),
        ],
      ),
    );
  }
}
