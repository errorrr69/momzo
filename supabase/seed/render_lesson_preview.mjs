// Renders forged lesson drafts into one reviewable page in Momzo's own design
// system (tokens from app/lib/core/theme/momzo_colors.dart; Newsreader serif for
// reading prose, Nunito Sans for chrome — approximated with system stacks because
// the Artifact CSP blocks font CDNs).
//
// Accents follow Momzo's semantics rather than decoration: honey = Learn (the age
// chip), sage = Activities (the "try tonight" block), coral = primary action (the
// 30-second version and the closing reframe).
//
// Usage: node render_lesson_preview.mjs [draftsDir] [outFile]
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const DIR = process.argv[2] || 'D:/momzo/planning/lesson-drafts';
const OUT = process.argv[3] || 'D:/momzo/planning/lesson-preview.html';

const files = readdirSync(DIR).filter((f) => f.endsWith('.json') && f !== '_all.json').sort();
const lessons = files.map((f) => JSON.parse(readFileSync(join(DIR, f), 'utf8')));

const bySource = new Map();
for (const l of lessons) {
  if (!bySource.has(l.source_path)) bySource.set(l.source_path, []);
  bySource.get(l.source_path).push(l);
}

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const items = (arr) => arr.map((x) => `<li>${esc(x)}</li>`).join('');
const srcName = (p) => p.split('/').pop().replace(/\.(md|txt)$/i, '');

function lessonHtml(l) {
  return `<article class="lesson">
  <p class="agechip">${esc(l.age_band)} years<span class="dot">·</span>${l.minutes} min</p>
  <h3 class="ltitle">${esc(l.title)}</h3>

  <div class="tldr">
    <p class="lbl">The 30-second version</p>
    <p class="tldrtext">${esc(l.tldr)}</p>
  </div>

  <p class="lbl">Sound familiar?</p>
  <div class="scene">${l.scene.map((s) => `<p>${esc(s)}</p>`).join('')}</div>

  <p class="lbl">What's actually going on</p>
  <ul class="going">${items(l.whats_going_on)}</ul>

  <div class="pair">
    <div>
      <p class="lbl warn">Skip these</p>
      <ul class="skip">${items(l.skip_these)}</ul>
    </div>
    <div>
      <p class="lbl good">Try this instead</p>
      <ul class="try">${items(l.try_this)}</ul>
    </div>
  </div>

  <div class="activity">
    <p class="lbl good">Try tonight<span class="dot">·</span>${esc(l.activity.name)}</p>
    <ol class="steps">${items(l.activity.steps)}</ol>
    <p class="why"><em>Why it works:</em> ${esc(l.activity.why_it_works)}</p>
  </div>

  <p class="remember">${esc(l.remember)}</p>

  <details>
    <summary>The full read — optional depth</summary>
    <div class="fullread">${l.full_read.split(/\n\s*\n/).map((p) => `<p>${esc(p.trim())}</p>`).join('')}</div>
  </details>

  <div class="tags">
    ${l.problem_tags.map((t) => `<span class="tag prob">${esc(t)}</span>`).join('')}
    ${l.mother_need_tags.map((t) => `<span class="tag need">${esc(t)}</span>`).join('')}
  </div>
</article>`;
}

const sections = [...bySource.entries()].map(([src, variants]) => `
<section class="srcgroup">
  <h2 class="srclabel">${esc(srcName(src))}</h2>
  <div class="variants">${variants.sort((a, b) => a.age_min - b.age_min).map(lessonHtml).join('')}</div>
</section>`).join('');

const html = `<title>Momzo — pilot lesson drafts</title>
<style>
  /* Momzo tokens — app/lib/core/theme/momzo_colors.dart */
  :root{
    --cream:#FFF7F0; --creamWarm:#FBF1E7; --card:#FFFFFF;
    --ink:#3D3330; --body:#6B5D55; --muted:#9C8E85; --faint:#B6A89D;
    --hairline:#F0E6DC; --cardBorder:#EFE4D8;
    --coral:#EC8366; --coralDeep:#C26A4D; --coralText:#8A5742; --coralTint:#FBE3D8;
    --honey:#F2B441; --honeyTint:#FCEFD0; --honeyText:#9A7424;
    --sage:#84B89A; --sageTint:#E2F0E4; --sageText:#4E7A60;
    --serif:"Newsreader",Charter,"Iowan Old Style","Source Serif Pro",Georgia,serif;
    --sans:"Nunito Sans",ui-sans-serif,system-ui,"Segoe UI",Avenir,sans-serif;
  }
  /* Dark stays WARM — Momzo's rule is soft and warm, never neutral grey or pure black. */
  @media (prefers-color-scheme:dark){
    :root{
      --cream:#221B18; --creamWarm:#2A211D; --card:#2C2320;
      --ink:#F6EDE6; --body:#DAC9BE; --muted:#A89689; --faint:#8A7970;
      --hairline:#3B2F2A; --cardBorder:#3B2F2A;
      --coralText:#F0AB90; --coralTint:#3E2720;
      --honeyTint:#3A2B12; --honeyText:#EFC069;
      --sageTint:#1F2E25; --sageText:#A3D4B6;
    }
  }
  :root[data-theme="dark"]{
      --cream:#221B18; --creamWarm:#2A211D; --card:#2C2320;
      --ink:#F6EDE6; --body:#DAC9BE; --muted:#A89689; --faint:#8A7970;
      --hairline:#3B2F2A; --cardBorder:#3B2F2A;
      --coralText:#F0AB90; --coralTint:#3E2720;
      --honeyTint:#3A2B12; --honeyText:#EFC069;
      --sageTint:#1F2E25; --sageText:#A3D4B6;
  }
  :root[data-theme="light"]{
      --cream:#FFF7F0; --creamWarm:#FBF1E7; --card:#FFFFFF;
      --ink:#3D3330; --body:#6B5D55; --muted:#9C8E85; --faint:#B6A89D;
      --hairline:#F0E6DC; --cardBorder:#EFE4D8;
      --coralText:#8A5742; --coralTint:#FBE3D8;
      --honeyTint:#FCEFD0; --honeyText:#9A7424;
      --sageTint:#E2F0E4; --sageText:#4E7A60;
  }

  *{box-sizing:border-box;}
  body{margin:0;background:var(--cream);color:var(--body);font-family:var(--sans);
    font-size:16px;line-height:1.6;-webkit-font-smoothing:antialiased;}
  .wrap{max-width:1180px;margin:0 auto;padding:40px 20px 96px;}

  /* masthead */
  .mast{border-bottom:1px solid var(--hairline);padding-bottom:26px;margin-bottom:38px;}
  .kicker{font-size:11.5px;font-weight:800;letter-spacing:.14em;text-transform:uppercase;
    color:var(--coralDeep);margin:0 0 12px;}
  h1{font-family:var(--serif);font-weight:600;font-size:clamp(28px,4vw,40px);line-height:1.15;
    color:var(--ink);margin:0 0 14px;text-wrap:balance;letter-spacing:-.01em;}
  .standfirst{font-family:var(--serif);font-size:18px;color:var(--body);margin:0;max-width:62ch;}
  .meta{display:flex;flex-wrap:wrap;gap:8px;margin-top:20px;}
  .stat{background:var(--card);border:1px solid var(--cardBorder);border-radius:99px;
    padding:6px 13px;font-size:12.5px;font-weight:700;color:var(--muted);}
  .stat b{color:var(--ink);font-variant-numeric:tabular-nums;}

  .note{background:var(--honeyTint);border-radius:14px;padding:16px 18px;margin:26px 0 0;}
  .note p{margin:0;font-size:14.5px;color:var(--honeyText);}
  .note p + p{margin-top:8px;}
  .note strong{color:var(--honeyText);}

  /* per-source group */
  .srcgroup{margin:0 0 46px;}
  .srclabel{font-size:11.5px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;
    color:var(--faint);margin:0 0 14px;padding-bottom:9px;border-bottom:1px solid var(--hairline);}
  .variants{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:18px;align-items:start;}

  .lesson{background:var(--card);border:1px solid var(--cardBorder);border-radius:20px;
    padding:24px 26px 26px;max-width:56ch;}
  .agechip{display:inline-block;background:var(--honeyTint);color:var(--honeyText);
    font-size:11px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;
    padding:5px 11px;border-radius:99px;margin:0;}
  .dot{padding:0 6px;opacity:.55;}
  .ltitle{font-family:var(--serif);font-weight:600;font-size:22px;line-height:1.25;
    color:var(--ink);margin:13px 0 16px;text-wrap:balance;}

  .lbl{font-size:10.5px;font-weight:800;letter-spacing:.11em;text-transform:uppercase;
    color:var(--muted);margin:20px 0 8px;}
  .lbl.good{color:var(--sageText);} .lbl.warn{color:var(--coralDeep);}

  .tldr{background:var(--coralTint);border-radius:14px;padding:15px 17px;}
  .tldr .lbl{margin:0 0 7px;color:var(--coralText);}
  .tldrtext{font-family:var(--serif);font-size:16.5px;font-weight:500;color:var(--coralText);margin:0;}

  .scene p{font-family:var(--serif);font-style:italic;font-size:16px;margin:0 0 9px;color:var(--body);}
  .scene p:last-child{margin-bottom:0;}

  ul,ol{margin:0;padding-left:19px;}
  .going li,.skip li,.try li,.steps li{font-family:var(--serif);font-size:15.5px;margin:0 0 7px;}
  .skip li{color:var(--coralText);} .try li{color:var(--sageText);}

  .pair{display:grid;grid-template-columns:1fr 1fr;gap:16px;}
  @media (max-width:560px){ .pair{grid-template-columns:1fr;} }

  .activity{background:var(--sageTint);border-radius:14px;padding:15px 17px;margin-top:22px;}
  .activity .lbl{margin:0 0 9px;}
  .why{font-family:var(--serif);font-size:14.5px;color:var(--sageText);margin:11px 0 0;}

  .remember{font-family:var(--serif);font-size:17px;font-weight:600;color:var(--ink);
    margin:22px 0 0;padding:2px 0 2px 15px;border-left:3px solid var(--coral);text-wrap:balance;}

  details{margin-top:20px;border-top:1px solid var(--hairline);padding-top:14px;}
  summary{cursor:pointer;font-size:12px;font-weight:800;letter-spacing:.06em;
    text-transform:uppercase;color:var(--faint);}
  summary:focus-visible{outline:2px solid var(--coral);outline-offset:3px;border-radius:4px;}
  .fullread{margin-top:12px;}
  .fullread p{font-family:var(--serif);font-size:15.5px;margin:0 0 12px;}

  .tags{display:flex;flex-wrap:wrap;gap:6px;margin-top:18px;}
  .tag{font-size:10.5px;font-weight:700;padding:4px 9px;border-radius:99px;}
  .tag.prob{background:var(--coralTint);color:var(--coralText);}
  .tag.need{background:var(--sageTint);color:var(--sageText);}
</style>

<div class="wrap">
  <header class="mast">
    <p class="kicker">Pilot draft · for review</p>
    <h1>Sixteen lessons, rewritten for a mother with three minutes</h1>
    <p class="standfirst">Forged from ${bySource.size} of your source articles, two age variants each.
      Every word is original — the source only decided which ideas a lesson covers.
      The test to apply: could she stop after the 30-second version and still have gotten something real?</p>
    <div class="meta">
      <span class="stat"><b>${lessons.length}</b> lessons</span>
      <span class="stat"><b>${bySource.size}</b> source articles</span>
      <span class="stat">ages <b>6–7</b> and <b>8–10</b></span>
    </div>
    <div class="note">
      <p><strong>Two known issues, so you can look past them:</strong> the closing reframes almost all
        landed on the same “They’re not X, they’re Y” shape — too formulaic read back-to-back, and stiffer
        than they should be. That’s fixed in the generator for the full run, not re-run here.</p>
      <p>The screen-time 8–10 lesson is still on an earlier, untuned draft — its API quota ran out.</p>
    </div>
  </header>
  ${sections}
</div>`;

writeFileSync(OUT, html);
console.log(`Wrote ${OUT} — ${lessons.length} lessons across ${bySource.size} sources`);
