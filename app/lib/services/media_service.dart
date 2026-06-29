import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../core/supabase/supabase_init.dart';
import 'auth_service.dart';

/// Private family media (Hard Rule #16). Photos live in the `family-media` bucket,
/// path-scoped by the owner's uid so RLS keeps each family's media private. We
/// store the PATH in the DB (photo_url) and mint short-lived signed URLs on read —
/// never a public URL.
class MediaService {
  const MediaService._();

  static const _bucket = 'family-media';

  /// Upload bytes under the caller's own folder; returns the stored object PATH.
  /// [folder] groups media (e.g. 'activities', 'milestones').
  static Future<String> upload(
    Uint8List bytes, {
    required String folder,
    String ext = 'jpg',
    String contentType = 'image/jpeg',
  }) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) throw StateError('Sign in first.');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$uid/$folder/$stamp.$ext';
    await supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  /// A short-lived signed URL for displaying a stored path (default 1 hour).
  /// Returns null on failure so a broken/missing image never crashes a list.
  static Future<String?> signedUrl(String path, {int expiresIn = 3600}) async {
    if (path.isEmpty) return null;
    try {
      return await supabase.storage.from(_bucket).createSignedUrl(path, expiresIn);
    } catch (_) {
      return null;
    }
  }
}
