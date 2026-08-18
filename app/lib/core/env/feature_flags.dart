/// Features that are BUILT but not switched on.
///
/// A flag here means the code is finished, tested and shipping in the binary —
/// it is simply not shown yet. That is different from unfinished work, and the
/// distinction matters: flipping one of these is a one-line change and a
/// release, not a project.
class FeatureFlags {
  const FeatureFlags._();

  /// The Circle — the mothers' forum (Expansion Plan §2).
  ///
  /// OFF for now. Not because anything is wrong with it: 20 database tests and
  /// 10 widget tests pass and the whole loop was verified on a real phone. It is
  /// off because a forum is the one feature with a STANDING operational cost —
  /// replies, moderation, tending — and it launches best into an audience the
  /// rest of the app has already warmed up (§5).
  ///
  /// What this does NOT hide is Florie's posts. They live in the same tab, and
  /// they are the freshest content in the app; burying them again to hide the
  /// community would undo the redesign's main win. With this off, that tab shows
  /// her posts alone and is named for her.
  ///
  /// Turning it on: flip to `true`, make sure at least one moderator exists
  /// (`node supabase/seed/build_forum.mjs --moderator you@example.com`), and
  /// ship. Nothing else changes — the tables, policies, auto-hide and moderator
  /// queue are all already live.
  static const bool circle = false;
}
