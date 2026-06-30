// Remove retired games cleanly: deleting the games row cascades to game_items and
// game_play_history (FKs on delete cascade). Idempotent. Run:
//   node supabase/seed/remove_games.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
const here = dirname(fileURLToPath(import.meta.url));
const env=(()=>{const o={};for(const r of readFileSync(join(here,'..','.env'),'utf8').split(/\r?\n/)){const l=r.trim();if(!l||l.startsWith('#'))continue;const e=l.indexOf('=');if(e<0)continue;let v=l.slice(e+1).trim();v=v.startsWith('"')?v.slice(1,v.indexOf('"',1)):v.split(/\s+#/)[0].trim();o[l.slice(0,e).trim()]=v;}return o;})();
const a = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, { auth:{persistSession:false} });
const RETIRED = ['dance-freeze', 'mood-checkin'];
for (const slug of RETIRED) {
  const { count: items } = await a.from('game_items').select('id',{count:'exact',head:true}).eq('game_slug', slug);
  const { error } = await a.from('games').delete().eq('slug', slug);
  console.log(`${slug}: removed (had ${items ?? 0} items)${error?' ERROR '+error.message:''}`);
}
const { data: left } = await a.from('games').select('slug').order('sort');
console.log('remaining games:', left.length, '->', left.map(g=>g.slug).join(', '));
