// Post a plain-words update to the Momzo Discord channel as "Mort".
//   node scripts/mort.mjs "your message here"
//   echo "your message" | node scripts/mort.mjs
// Reads the webhook URL from .ops/mort-webhook.txt (git-ignored — never committed).
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
let webhook;
try {
  webhook = readFileSync(join(root, '.ops', 'mort-webhook.txt'), 'utf8').trim();
} catch {
  console.error('No webhook found at .ops/mort-webhook.txt — set it up first.');
  process.exit(1);
}

const msg = (process.argv.slice(2).join(' ') || readFileSync(0, 'utf8')).trim();
if (!msg) { console.error('Nothing to send (pass a message arg or pipe via stdin).'); process.exit(1); }

const res = await fetch(webhook, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username: 'Mort', content: msg.slice(0, 1900) }),
});
console.log('Discord:', res.status, res.status === 204 ? '(sent ✓)' : await res.text());
