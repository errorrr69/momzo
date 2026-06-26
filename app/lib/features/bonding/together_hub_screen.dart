import 'package:flutter/material.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../services/child_service.dart';
import '../../services/question_service.dart';
import 'daily_question_screen.dart';
import 'quiz_flow_screen.dart';
import '../wishes/wish_wall_screen.dart';

/// 17 · Together · hub — small ways to feel close, the child's voice included.
class TogetherHubScreen extends StatefulWidget {
  const TogetherHubScreen({super.key});

  @override
  State<TogetherHubScreen> createState() => _TogetherHubScreenState();
}

class _TogetherHubScreenState extends State<TogetherHubScreen> {
  String _prompt = 'If our family was an animal, which one would we be?';
  String _status = 'Tap to answer together';

  String get _childName => ChildService.current?.name ?? 'Aarav';

  @override
  void initState() {
    super.initState();
    if (AppEnv.hasSupabase && ChildService.current != null) _load();
  }

  Future<void> _load() async {
    try {
      final q = await QuestionService.todaysQuestion();
      if (q == null) return;
      final answers = await QuestionService.todaysResponses(q.id);
      if (!mounted) return;
      setState(() {
        _prompt = q.prompt;
        _status = answers.containsKey('parent') && answers.containsKey('child')
            ? 'Answered today 💜'
            : 'Tap to answer together';
      });
    } catch (_) {/* keep defaults */}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.lavenderTint, MomzoColors.cream],
            stops: [0, .42],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
            children: [
              Text('Together',
                  style: MomzoText.sans(26,
                      color: MomzoColors.ink, weight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Small ways to feel close to $_childName.',
                  style: MomzoText.serif(16, color: MomzoColors.muted)),
              const SizedBox(height: 18),
              // Daily question card
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyQuestionScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MomzoColors.lavender,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: MomzoColors.lavender.withOpacity(.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUESTION OF THE DAY',
                          style: MomzoText.eyebrow(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(_prompt,
                          style: MomzoText.serif(20, color: Colors.white, height: 1.3)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_status,
                              style: MomzoText.sans(12,
                                  color: Colors.white70, weight: FontWeight.w700)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Open',
                                style: MomzoText.sans(13,
                                    color: MomzoColors.lavenderText,
                                    weight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _row(
                context,
                emoji: '🧩',
                colors: const [Color(0xFFF3B0A0), MomzoColors.coral],
                title: 'How well do you know each other?',
                sub: 'The flagship match-up quiz',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuizFlowScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _row(
                context,
                emoji: '⭐',
                colors: const [Color(0xFFFAD9A6), MomzoColors.honey],
                title: "Aarav's Wish Wall",
                sub: '2 new wishes to plan',
                badge: '2',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WishWallScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _row(
                context,
                emoji: '🎲',
                colors: const [Color(0xFF9CCAD6), MomzoColors.sky],
                title: 'Mini-games',
                sub: 'Would-you-rather & more',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String emoji,
    required List<Color> colors,
    required String title,
    required String sub,
    String? badge,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x0F342F30), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: MomzoText.sans(15,
                          color: MomzoColors.ink, weight: FontWeight.w800, height: 1.2)),
                  Text(sub,
                      style: MomzoText.sans(12,
                          color: MomzoColors.muted, weight: FontWeight.w700)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: MomzoColors.coral,
                  shape: BoxShape.circle,
                ),
                child: Text(badge,
                    style: MomzoText.sans(12,
                        color: Colors.white, weight: FontWeight.w800)),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: MomzoColors.faint, size: 22),
          ],
        ),
      ),
    );
  }
}
