// Structured, PII-free logging for Edge Functions (Build Guide §5).
//
// NEVER pass child names, parent contact details, message/AI bodies, or any free
// text a user typed. Log only ids, counts, durations, status codes, booleans —
// things safe to keep in an ops log.
type Fields = Record<string, string | number | boolean | null>;

function emit(level: string, event: string, fields: Fields) {
  // One JSON object per line — easy to grep/ingest. Supabase adds the timestamp.
  console.log(JSON.stringify({ level, event, ...fields }));
}

export const log = {
  info: (event: string, fields: Fields = {}) => emit('info', event, fields),
  warn: (event: string, fields: Fields = {}) => emit('warn', event, fields),
  error: (event: string, fields: Fields = {}) => emit('error', event, fields),
};
