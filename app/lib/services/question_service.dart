import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';
import 'child_service.dart';

/// A daily bonding question (PRD §8 `questions`).
class DailyQuestion {
  final String id;
  final String prompt;
  final String type;
  const DailyQuestion({required this.id, required this.prompt, required this.type});
}

/// Shared Question of the Day (Task 19): one daily question for the whole family,
/// each person answers, then the answers are revealed side by side.
class QuestionService {
  const QuestionService._();

  /// Today's daily question — deterministic by date so parent + child get the
  /// same one. Rotates through the 'daily' bank.
  static Future<DailyQuestion?> todaysQuestion() async {
    final rows = await supabase
        .from('questions')
        .select('id,prompt,type')
        .eq('type', 'daily')
        .order('created_at', ascending: true) as List;
    if (rows.isEmpty) return null;
    final epochDay = DateTime.now().toUtc().difference(DateTime.utc(2020)).inDays;
    final q = rows[epochDay % rows.length] as Map<String, dynamic>;
    return DailyQuestion(id: q['id'] as String, prompt: q['prompt'] as String, type: q['type'] as String);
  }

  static String _todayStartIso() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).toUtc().toIso8601String();
  }

  /// Today's answers for a question, keyed by respondent ('parent' | 'child').
  static Future<Map<String, String>> todaysResponses(String questionId) async {
    final child = ChildService.current;
    if (child == null) return {};
    final rows = await supabase
        .from('question_responses')
        .select('respondent,answer')
        .eq('question_id', questionId)
        .eq('child_id', child.id)
        .gte('answered_at', _todayStartIso()) as List;
    final out = <String, String>{};
    for (final r in rows) {
      final a = (r as Map)['answer'];
      out[r['respondent'] as String] = a is Map ? (a['text']?.toString() ?? '') : (a?.toString() ?? '');
    }
    return out;
  }

  static Future<void> saveResponse({
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
}
