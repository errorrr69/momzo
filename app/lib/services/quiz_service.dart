import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';
import 'child_service.dart';

class QuizQuestion {
  final String id;
  final String prompt;
  const QuizQuestion({required this.id, required this.prompt});
}

/// Per-question reveal: the parent's guess + the child's answer, and whether they matched.
class QuizResult {
  final QuizQuestion question;
  final String? parent;
  final String? child;
  const QuizResult({required this.question, this.parent, this.child});

  bool get answered => (parent?.isNotEmpty ?? false) && (child?.isNotEmpty ?? false);
  bool get matched => answered && QuizService.isMatch(parent!, child!);
}

/// "How well do you know each other?" quiz (Task 25). The parent guesses what the
/// child would say; the child answers for real; the reveal compares them. Stored
/// in question_responses (type='know_each_other'); the reveal updates live via
/// Realtime on that table (RLS scopes delivery to the one family — Hard Rule #4).
class QuizService {
  const QuizService._();

  /// A stable set of quiz questions (same set across both players).
  static Future<List<QuizQuestion>> questions({int count = 5}) async {
    final rows = await supabase
        .from('questions')
        .select('id,prompt')
        .eq('type', 'know_each_other')
        .order('id')
        .limit(count) as List;
    return [
      for (final r in rows)
        QuizQuestion(id: r['id'] as String, prompt: r['prompt'] as String)
    ];
  }

  static Future<void> saveAnswer({
    required String questionId,
    required String respondent, // 'parent' | 'child'
    required String text,
  }) async {
    final user = AuthService.currentUser;
    final child = ChildService.current;
    if (user == null || child == null) throw StateError('Sign in and select a child first.');
    await supabase.from('question_responses').insert({
      'owner_id': user.id,
      'question_id': questionId,
      'child_id': child.id,
      'respondent': respondent,
      'answer': {'text': text.trim()},
    });
  }

  /// Latest parent + child answer per quiz question, for the current child.
  static Future<List<QuizResult>> reveal(List<QuizQuestion> qs) async {
    final child = ChildService.current;
    if (child == null) return [for (final q in qs) QuizResult(question: q)];
    final ids = [for (final q in qs) q.id];
    final rows = await supabase
        .from('question_responses')
        .select('question_id,respondent,answer,answered_at')
        .eq('child_id', child.id)
        .inFilter('question_id', ids)
        .order('answered_at') as List; // oldest -> newest, so later overwrites
    final parent = <String, String>{};
    final kid = <String, String>{};
    for (final r in rows) {
      final qid = r['question_id'] as String;
      final a = r['answer'];
      final text = a is Map ? (a['text']?.toString() ?? '') : (a?.toString() ?? '');
      if (r['respondent'] == 'parent') {
        parent[qid] = text;
      } else {
        kid[qid] = text;
      }
    }
    return [
      for (final q in qs)
        QuizResult(question: q, parent: parent[q.id], child: kid[q.id])
    ];
  }

  /// Live updates while the reveal is open: fires onChange on any answer for this
  /// child. RLS restricts delivery to the subscriber's own family.
  static RealtimeChannel subscribeForChild(void Function() onChange) {
    final child = ChildService.current;
    final channel = supabase.channel('quiz_${child?.id ?? 'none'}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'question_responses',
          filter: child == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'child_id',
                  value: child.id,
                ),
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  /// Loose match for a kids' free-text quiz: case/space/punctuation-insensitive,
  /// with a contains fallback.
  static bool isMatch(String a, String b) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final x = norm(a), y = norm(b);
    if (x.isEmpty || y.isEmpty) return false;
    return x == y || x.contains(y) || y.contains(x);
  }
}
