"""Builds docs/offline/LinuxIAMLab-Reference.html: the reference library, all module lessons and
every exercise walkthrough in ONE self-contained, searchable HTML file (no network needed).
Run from the project root:  python tools/build_offline_reference.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAB = os.path.join(ROOT, "guest", "opt", "linux-iam-lab")
os.environ["LAB_ROOT"] = LAB
sys.path.insert(0, os.path.join(LAB, "lib"))
import labcourse  # noqa: E402

docs = [{"id": d["id"], "title": d["title"], "md": d["md"], "group": "Reference"} for d in labcourse.load_reference()]
for m in labcourse.load_course(full=True):
    body = [f"*{m['summary']}*", m["lesson"]]
    docs.append({"id": m["id"], "title": f"Module {m['number']}: {m['title']}", "md": "\n\n".join(body), "group": "Lessons"})
    for e in m["exercises"]:
        parts = [f"### {s['title']}\n{s['md']}" for s in e["sections"]]
        parts += [f"### Hint {i + 1}\n{h}" for i, h in enumerate(e["hints"])]
        parts.append("### Walkthrough\n" + e["walkthrough"])
        docs.append({"id": e["id"], "title": f"{e['id']}: {e['title']}", "md": "\n\n".join(parts), "group": f"Module {m['number']} exercises"})

md_js = open(os.path.join(LAB, "portal", "static", "md.js"), encoding="utf-8").read()
css = open(os.path.join(LAB, "portal", "static", "style.css"), encoding="utf-8").read()
data = json.dumps(docs).replace("</", "<\\/")

html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Linux IAM Lab Reference</title>
<style>{css}
body{{display:grid;grid-template-columns:300px 1fr;height:100vh;margin:0}}
nav{{overflow:auto;border-right:1px solid var(--line);background:var(--panel);padding:12px}}
nav input{{width:100%;padding:8px;border:1px solid var(--line);border-radius:8px;background:var(--bg);color:var(--text);font:inherit;margin-bottom:8px}}
nav a{{display:block;padding:4px 8px;border-radius:6px;color:var(--text);text-decoration:none;font-size:14px}}
nav a:hover,nav a.active{{background:var(--accent-soft)}}
nav h4{{margin:12px 0 4px;font-size:11px;text-transform:uppercase;letter-spacing:.08em;color:var(--muted)}}
#doc{{overflow:auto;padding:28px 40px}} #doc>div{{max-width:860px;margin:0 auto}}
.mini{{display:none}}
@media (max-width:800px){{body{{grid-template-columns:1fr;height:auto}} nav{{max-height:40vh}} #doc{{padding:16px}}}}
</style></head>
<body><nav><strong>Linux IAM Lab - offline reference</strong><p style="font-size:12px;color:var(--muted)">Works without the lab or the internet. Same content as the course portal.</p>
<input id="q" type="search" placeholder="Search everything (e.g. chmod, faillock, AllowGroups)"><div id="list"></div></nav>
<main id="doc"><div id="body"></div></main>
<script>{md_js}</script>
<script>
const DOCS = {data};
const list = document.getElementById('list'), body = document.getElementById('body'), q = document.getElementById('q');
function show(id, term) {{
  const d = DOCS.find(x => x.id === id) || DOCS[0];
  let md = d.md;
  if (term) {{
    const parts = md.split(/\\n(?=### )/);
    const hit = parts.filter(p => p.toLowerCase().includes(term));
    if (hit.length) md = hit.join('\\n');
  }}
  body.innerHTML = '<h1>' + LabMarkdown.esc(d.title) + '</h1>' + LabMarkdown.render(md);
  document.querySelectorAll('#list a').forEach(a => a.classList.toggle('active', a.dataset.id === d.id));
  location.hash = d.id;
}}
function draw() {{
  const term = q.value.trim().toLowerCase();
  let html = '', group = '';
  for (const d of DOCS) {{
    if (term && !(d.title + ' ' + d.md).toLowerCase().includes(term)) continue;
    if (d.group !== group) {{ group = d.group; html += '<h4>' + group + '</h4>'; }}
    html += '<a href="#' + d.id + '" data-id="' + d.id + '">' + LabMarkdown.esc(d.title) + '</a>';
  }}
  list.innerHTML = html || '<p>No matches</p>';
  list.querySelectorAll('a').forEach(a => a.onclick = (e) => {{ e.preventDefault(); show(a.dataset.id, term); }});
}}
q.oninput = draw; draw(); show((location.hash || '').slice(1));
</script></body></html>"""

out_dir = os.path.join(ROOT, "docs", "offline")
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "LinuxIAMLab-Reference.html"), "w", encoding="utf-8") as fh:
    fh.write(html)
print(f"wrote {len(docs)} documents to docs/offline/LinuxIAMLab-Reference.html ({len(html)//1024} KB)")
