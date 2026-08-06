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

/// The region every Edge Function call is pinned to — the region the DATABASE
/// lives in, not the one nearest the parent.
///
/// By default Supabase runs a function at the edge closest to the caller. That
/// is right for a function that mostly computes, and badly wrong for ours, which
/// is chatty with Postgres: ai-chat makes roughly ten sequential round trips
/// (ownership, conversation, rate limit, breaker, memory, cache, retrieval,
/// persistence, telemetry). Measured from India, each hop to the us-west-1
/// database cost ~244ms and opening the connection ~1.5s, so the round trips —
/// not the model — were the wait.
///
/// Pinning execution beside the database turned those hops into ~3ms each and
/// cut a measured probe from 5126ms to 1418ms. The parent still pays one long
/// hop to reach the function, instead of paying it ten times over.
const String kFunctionRegion = 'us-west-1';
