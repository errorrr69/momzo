#!/usr/bin/env python3
"""Extract raw text from reference books (PDF via pdftotext, EPUB via stdlib) to a
gitignored working dir. This text is a TRANSIENT INPUT for writing original Momzo
notes — it is never committed or embedded. Reports which files extracted cleanly
vs. look scanned (need OCR)."""
import os, re, sys, subprocess, zipfile, html.parser, pathlib

SRC = r"D:\momzo\docs\momzo knowledge base - books"
OUT = r"D:\momzo\.book-extract\txt"
os.makedirs(OUT, exist_ok=True)

class Strip(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(); self.buf = []; self.skip = 0
    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"): self.skip += 1
        if tag in ("p", "br", "div", "h1", "h2", "h3", "h4", "li"): self.buf.append("\n")
    def handle_endtag(self, tag):
        if tag in ("script", "style") and self.skip: self.skip -= 1
    def handle_data(self, data):
        if not self.skip: self.buf.append(data)
    def text(self): return re.sub(r"\n{3,}", "\n\n", "".join(self.buf))

def slug(name):
    s = re.sub(r"\(z-library.*?\)", "", name, flags=re.I)
    s = re.sub(r"\.[^.]+$", "", s)
    s = re.sub(r"[^A-Za-z0-9]+", "-", s).strip("-").lower()
    return s[:80]

def extract_pdf(path):
    try:
        r = subprocess.run(["pdftotext", "-layout", path, "-"],
                           capture_output=True, timeout=300)
        return r.stdout.decode("utf-8", "replace")
    except Exception as e:
        return f""  # empty -> flagged

def extract_epub(path):
    out = []
    try:
        with zipfile.ZipFile(path) as z:
            names = [n for n in z.namelist() if n.lower().endswith((".xhtml", ".html", ".htm"))]
            names.sort()
            for n in names:
                p = Strip(); p.feed(z.read(n).decode("utf-8", "replace")); out.append(p.text())
    except Exception as e:
        return ""
    return "\n\n".join(out)

rows = []
for fn in sorted(os.listdir(SRC)):
    ext = fn.lower().rsplit(".", 1)[-1]
    if ext not in ("pdf", "epub"): continue
    path = os.path.join(SRC, fn)
    size = os.path.getsize(path)
    text = extract_pdf(path) if ext == "pdf" else extract_epub(path)
    text = text.strip()
    chars = len(text)
    # Heuristic: a text PDF yields many chars per MB; a scanned one yields almost none.
    per_mb = chars / (size / 1048576) if size else 0
    status = "OK" if chars > 3000 and per_mb > 400 else ("SCANNED?" if ext == "pdf" else "THIN?")
    sl = slug(fn)
    with open(os.path.join(OUT, sl + ".txt"), "w", encoding="utf-8") as f:
        f.write(text)
    rows.append((status, ext, f"{size/1048576:.1f}MB", f"{chars:,}", f"{per_mb:,.0f}/MB", fn[:52]))

w = [max(len(str(r[i])) for r in rows) for i in range(6)]
print(f"\n{'STATUS':<9} {'TYPE':<5} {'SIZE':>7} {'CHARS':>10} {'DENSITY':>9}  TITLE")
print("-" * 100)
for r in sorted(rows):
    print(f"{r[0]:<9} {r[1]:<5} {r[2]:>7} {r[3]:>10} {r[4]:>9}  {r[5]}")
ok = sum(1 for r in rows if r[0] == "OK")
print(f"\n{ok}/{len(rows)} extracted cleanly. Text -> {OUT} (gitignored, transient).")
