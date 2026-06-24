import 'package:supabase_flutter/supabase_flutter.dart';

import '../env/app_env.dart';

/// Initializes the Supabase client for the app.
///
/// The Flutter client talks to Supabase **directly** for ordinary reads/writes,
/// fully protected by Row-Level Security (Build Guide §2). It uses only the anon
/// key (see [AppEnv]); anything needing a secret key goes through an Edge
/// Function instead.
///
/// Returns `true` if Supabase was initialized, `false` when running in UI-only
/// mode (no env provided) so the screen gallery still runs without a backend.
Future<bool> initSupabase() async {
  if (!AppEnv.hasSupabase) return false;

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );
  return true;
}

/// Convenience accessor for the initialized client.
/// Only valid after [initSupabase] returned `true`.
SupabaseClient get supabase => Supabase.instance.client;
