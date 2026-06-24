import { createClient } from 'npm:@supabase/supabase-js@2';

// Verify the caller's identity from their JWT and return the authenticated user
// (or null). Uses the ANON key + the caller's access token — never service_role,
// which would bypass the user's identity. Functions that need elevated, RLS-free
// writes opt into the service_role key explicitly and deliberately.
export async function getUser(req: Request) {
  const header = req.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length);

  const client = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
  );
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user;
}
