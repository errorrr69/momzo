// FCM HTTP v1 sender (Task 7). Mints a Google OAuth token from the Firebase
// service account (RS256-signed JWT), then sends messages. The service account
// JSON is the FCM_SERVICE_ACCOUNT function secret — never in the app (Hard Rule #5).

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

const enc = new TextEncoder();

function b64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === 'string' ? enc.encode(data) : new Uint8Array(data);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const bin = atob(b64);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

export function loadServiceAccount(): ServiceAccount {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!raw) throw new Error('FCM_SERVICE_ACCOUNT not set');
  return JSON.parse(raw) as ServiceAccount;
}

export async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const signingInput = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    'pkcs8', pemToPkcs8(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(signingInput));
  const jwt = `${signingInput}.${b64url(sig)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`token exchange failed: ${res.status}`);
  return (await res.json()).access_token as string;
}

export interface SendResult { token: string; ok: boolean; status: number; error?: string }

// Sends one notification message. Returns the per-token outcome (so callers can
// prune dead tokens). The body is a system notification — displayed by the OS.
export async function sendToToken(
  accessToken: string,
  projectId: string,
  token: string,
  msg: { title: string; body: string; data?: Record<string, string> },
): Promise<SendResult> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: msg.title, body: msg.body },
        data: msg.data ?? {},
        android: { priority: 'high' },
      },
    }),
  });
  if (res.ok) return { token, ok: true, status: res.status };
  let error = `${res.status}`;
  try {
    const j = await res.json();
    error = j?.error?.status ?? error; // e.g. 'UNREGISTERED', 'INVALID_ARGUMENT'
  } catch { /* ignore */ }
  return { token, ok: false, status: res.status, error };
}
