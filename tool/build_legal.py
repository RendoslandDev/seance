#!/usr/bin/env python3
"""Publish the legal documents as web pages.

    python3 tool/build_legal.py   # assets/legal/*.md -> web/privacy.html, web/terms.html

The app shows the same Markdown in-app (lib/screens/legal_screen.dart); the web
pages give the App Store, Play Store and visitors a public URL:
https://<your-site>/privacy.html and /terms.html. Re-run after editing either
document. Only the small Markdown subset the documents use is supported.
"""

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = {"privacy": "Privacy Policy", "terms": "Terms of Service"}

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · séance</title>
<meta name="description" content="{title} for séance, a daily practice app.">
<meta name="theme-color" content="#131211">
<link rel="icon" type="image/png" href="favicon.png">
<style>
  :root {{ --bg:#131211; --text:#edeae3; --mid:rgba(237,234,227,.72); --rule:rgba(237,234,227,.14); }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--mid);
         font:16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Inter, Roboto, sans-serif; }}
  main {{ max-width:720px; margin:0 auto; padding:40px 20px 80px; }}
  nav {{ display:flex; gap:18px; align-items:baseline; margin-bottom:36px; }}
  nav .brand {{ font:italic 28px Georgia, "Playfair Display", serif; color:var(--text); text-decoration:none; margin-right:auto; }}
  nav a {{ color:var(--mid); }}
  h1 {{ font:500 38px/1.15 Georgia, "Playfair Display", serif; color:var(--text); margin:0 0 18px; }}
  h2 {{ font:500 23px/1.3 Georgia, "Playfair Display", serif; color:var(--text); margin:34px 0 10px; }}
  strong {{ color:var(--text); font-weight:600; }}
  a {{ color:var(--text); }}
  ul {{ padding-left:22px; }} li {{ margin:6px 0; }}
  footer {{ margin-top:48px; padding-top:18px; border-top:1px solid var(--rule); font-size:14px; }}
</style>
</head>
<body>
<main>
<nav><a class="brand" href="./">séance</a><a href="privacy.html">Privacy</a><a href="terms.html">Terms</a></nav>
{body}
<footer><a href="./">Open séance</a></footer>
</main>
</body>
</html>
"""


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\*(.+?)\*", r"<em>\1</em>", text)
    return re.sub(
        r"\[(.+?)\]\((.+?)\)",
        lambda m: f'<a href="{m.group(2)}"'
        + ("" if m.group(2).endswith(".html") else ' rel="noopener" target="_blank"')
        + f">{m.group(1)}</a>",
        text,
    )


def render(md: str) -> str:
    out, para, items = [], [], []

    def flush():
        if para:
            out.append(f"<p>{inline(' '.join(para))}</p>")
            para.clear()
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items.clear()

    for line in md.splitlines():
        line = line.rstrip()
        if not line:
            flush()
        elif line.startswith("# "):
            flush(); out.append(f"<h1>{inline(line[2:])}</h1>")
        elif line.startswith("## "):
            flush(); out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("- "):
            if para:
                out.append(f"<p>{inline(' '.join(para))}</p>"); para.clear()
            items.append(line[2:])
        else:
            if items:
                flush()
            para.append(line)
    flush()
    return "\n".join(out)


for name, title in DOCS.items():
    md = (ROOT / "assets" / "legal" / f"{name}.md").read_text(encoding="utf-8")
    out = ROOT / "web" / f"{name}.html"
    out.write_text(PAGE.format(title=title, body=render(md)), encoding="utf-8")
    print(f"{name}.md -> {out.relative_to(ROOT)}")
