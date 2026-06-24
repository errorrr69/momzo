// Shared CORS headers so the Flutter app (and web preview) can call functions.
// Tighten Allow-Origin to the real app origins before launch if needed.
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};
