import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../services/child_service.dart';
import '../../services/quiz_service.dart';
import 'quiz_match_screen.dart';

/// Play flow for "How well do you know each other?" (Task 25). The parent guesses
/// what the child would say; the phone is handed over; the child answers; then the
/// reveal. Answers are saved to question_responses (parent / child).
class QuizFlowScreen extends StatefulWidget {
  const QuizFlowScreen({super.key});

  @override
  State<QuizFlowScreen> createState() => _QuizFlowScreenState();
}

class _QuizFlowScreenState extends State<QuizFlowScreen> {
  List<QuizQuestion> _qs = [];
  bool _loading = true;
  String _phase = 'parent'; // parent -> handoff -> child
  int _i = 0;
  final _ctrl = TextEditingController();
  bool _busy = false;

  String get _childName => ChildService.current?.name ?? 'your child';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final qs = await QuizService.questions(count: 5);
      if (!mounted) return;
      setState(() {
        _qs = qs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await QuizService.saveAnswer(
        questionId: _qs[_i].id,
        respondent: _phase, // 'parent' | 'child'
        text: text,
      );
      _ctrl.clear();
      if (!mounted) return;
      if (_i < _qs.length - 1) {
        setState(() => _i++);
      } else if (_phase == 'parent') {
        setState(() => _phase = 'handoff');
      } else {
        // child finished -> reveal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => QuizMatchScreen(questions: _qs)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: MomzoColors.cream,
        body: Center(child: CircularProgressIndicator(color: MomzoColors.coral)),
      );
    }
    if (_qs.isEmpty) {
      return Scaffold(
        backgroundColor: MomzoColors.cream,
        body: Center(
          child: Text('No quiz questions yet.',
              style: MomzoText.serif(16, color: MomzoColors.muted)),
        ),
      );
    }
    if (_phase == 'handoff') return _handoff();
    return _questionView();
  }

  Widget _handoff() {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📱', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 20),
              Text('Your turn is done!',
                  textAlign: TextAlign.center,
                  style: MomzoText.sans(26,
                      color: MomzoColors.ink, weight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('Now hand the phone to $_childName so they can answer too.',
                  textAlign: TextAlign.center,
                  style: MomzoText.serif(17, color: MomzoColors.muted, height: 1.45)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: MomzoButton("I'm $_childName — my turn!",
                    onTap: () => setState(() {
                          _phase = 'child';
                          _i = 0;
                        })),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionView() {
    final isParent = _phase == 'parent';
    final q = _qs[_i];
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 8, 26, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: MomzoColors.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (_i + 1) / _qs.length,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF6D9C8),
                        valueColor: const AlwaysStoppedAnimation(MomzoColors.coral),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                isParent
                    ? "What do you think $_childName would say?"
                    : "Your turn, $_childName! 💛",
                style: MomzoText.sans(14,
                    color: isParent ? MomzoColors.coral : MomzoColors.lavenderText,
                    weight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Text(q.prompt,
                  style: MomzoText.serif(26, color: MomzoColors.ink, height: 1.3)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                ),
                child: TextField(
                  // New key per question so autofocus re-fires (keyboard stays up).
                  key: ValueKey('q_${_phase}_$_i'),
                  controller: _ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: MomzoText.sans(16,
                      color: MomzoColors.ink, weight: FontWeight.w600),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type here…',
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onSubmitted: (_) => _next(),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: MomzoButton(
                  _busy
                      ? 'Saving…'
                      : (_i < _qs.length - 1
                          ? 'Next'
                          : (isParent ? 'Done — pass it on' : 'See how you did!')),
                  onTap: _busy ? null : _next,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
