import postgres from 'npm:postgres@3';

// Shared pooled DB client for ALL Edge Functions.
//
// Connects through the Supabase **transaction pooler** (port 6543) with prepared
// statements OFF — both required in transaction-pooling mode (Hard Rule #2).
// The connection string (which contains the DB password) is a server-side
// Function secret, DB_POOL_URL — never shipped to the app (Build Guide §5).
//
// Reused across invocations of a warm instance; created lazily on first use.
let sql: ReturnType<typeof postgres> | null = null;

export function db() {
  if (sql) return sql;

  const url = Deno.env.get('DB_POOL_URL');
  if (!url) throw new Error('DB_POOL_URL is not set (transaction pooler connection string).');

  sql = postgres(url, {
    prepare: false,     // transaction pooler cannot use prepared statements
    max: 5,             // keep the pool small — Auth & others share the cluster (Free tier)
    idle_timeout: 20,
  });
  return sql;
}
