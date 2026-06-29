import '../core/supabase/supabase_init.dart';
import 'child_service.dart';
import 'media_service.dart';

/// One entry in the Memory Timeline — either a logged activity (with optional
/// photo/note) or a milestone (Task 30).
class Memory {
  final String kind; // 'activity' | 'milestone'
  final String title;
  final String? note;
  final String? photoUrl; // resolved short-lived signed URL (private storage)
  final DateTime date;
  const Memory({
    required this.kind,
    required this.title,
    required this.date,
    this.note,
    this.photoUrl,
  });
}

/// Builds the private Memory Timeline from activity_logs + milestones, newest
/// first, resolving stored photo PATHS into short-lived signed URLs (Hard Rule #16).
class MemoryService {
  const MemoryService._();

  static Future<List<Memory>> load() async {
    final child = ChildService.current;
    if (child == null) return [];

    final logs = await supabase
        .from('activity_logs')
        .select('note,photo_url,completed_at,created_at,activities(title)')
        .eq('child_id', child.id)
        .order('completed_at', ascending: false)
        .limit(60) as List;

    final miles = await supabase
        .from('milestones')
        .select('title,note,photo_url,date,created_at')
        .eq('child_id', child.id)
        .order('date', ascending: false)
        .limit(60) as List;

    final raw = <({String kind, String title, String? note, String? path, DateTime date})>[];

    for (final r in logs) {
      final m = r as Map<String, dynamic>;
      final note = m['note'] as String?;
      final path = m['photo_url'] as String?;
      if ((note == null || note.isEmpty) && (path == null || path.isEmpty)) continue; // nothing to keep
      final act = m['activities'];
      final title = (act is Map ? act['title'] as String? : null) ?? 'Together time';
      raw.add((
        kind: 'activity',
        title: title,
        note: note,
        path: path,
        date: DateTime.parse((m['completed_at'] ?? m['created_at']) as String).toLocal(),
      ));
    }
    for (final r in miles) {
      final m = r as Map<String, dynamic>;
      raw.add((
        kind: 'milestone',
        title: (m['title'] ?? 'Milestone') as String,
        note: m['note'] as String?,
        path: m['photo_url'] as String?,
        date: DateTime.parse((m['date'] ?? m['created_at']) as String).toLocal(),
      ));
    }

    raw.sort((a, b) => b.date.compareTo(a.date));

    // Resolve all photo paths to signed URLs in parallel.
    final urls = await Future.wait(raw.map((e) =>
        (e.path == null || e.path!.isEmpty) ? Future.value(null) : MediaService.signedUrl(e.path!)));

    return [
      for (var i = 0; i < raw.length; i++)
        Memory(kind: raw[i].kind, title: raw[i].title, note: raw[i].note, date: raw[i].date, photoUrl: urls[i]),
    ];
  }
}
