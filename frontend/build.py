#!/usr/bin/env python3
"""Generate frontend/index.html from the markdown task sheets.

Single source of truth: activities/*.md and frontend/pages/*.md.
Edit those, then run:  python3 frontend/build.py
Requires: pip install markdown
"""

import re
import html as htmlmod
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
PAGES_DIR = ROOT / "frontend" / "pages"
ACTIVITIES_DIR = ROOT / "activities"
SVG_PATH = ROOT / "topology-diagram.svg"
OUT = ROOT / "frontend" / "index.html"

MD = markdown.Markdown(extensions=["tables", "fenced_code"])

# Sections whose body must stay hidden until the learner opens them
SPOILER_HEADINGS = ("Check your answers", "Model incident summary")

PORTAL_HTML = r"""
<p>Start and stop the lab and its activities from here, and use real terminals
into your own network instead of typing <code>docker exec</code> commands by
hand. Run <code>./portal.sh</code> on your own machine first (not inside the
lab), then reload this page from <code>http://localhost:8080</code>.</p>

<h2>Lab lifecycle</h2>
<div class="btn-row">
  <button class="portal-btn" data-action="lab_up">Start lab (up)</button>
  <button class="portal-btn" data-action="lab_check">Health check</button>
  <button class="portal-btn" data-action="lab_reset">Reset to base state</button>
  <button class="portal-btn danger" data-action="lab_down">Stop lab (down)</button>
</div>

<h2>Activity 2 &middot; congestion</h2>
<div class="btn-row">
  <button class="portal-btn" data-action="congestion_start">Start congestion</button>
  <button class="portal-btn" data-action="congestion_stop">Stop congestion</button>
  <button class="portal-btn" data-action="congestion_status">Status</button>
</div>

<h2>Activity 3 &middot; peering</h2>
<div class="btn-row">
  <button class="portal-btn" data-action="peering_up">Enable peering</button>
  <button class="portal-btn" data-action="peering_down">Disable peering</button>
  <button class="portal-btn" data-action="peering_status">Status</button>
</div>

<h2>Activities 4 &amp; 5 &middot; scenarios</h2>
<div class="btn-row">
  <button class="portal-btn" data-action="scenario1_on">Scenario 1 on</button>
  <button class="portal-btn" data-action="scenario1_off">Scenario 1 off</button>
  <button class="portal-btn" data-action="scenario2_on">Scenario 2 on</button>
  <button class="portal-btn" data-action="scenario2_off">Scenario 2 off</button>
</div>

<h2>Looking glass</h2>
<p>Read-only <code>show</code> commands against the Internet routers &mdash;
same rule as <code>lg.sh</code>: observe only.</p>
<div class="lg-row">
  <select id="lg-router">
    <option value="upstream-a">upstream-a</option>
    <option value="upstream-b">upstream-b</option>
    <option value="transit">transit</option>
    <option value="route-server">route-server</option>
  </select>
  <input id="lg-cmd" type="text" value="show bgp summary">
  <button class="portal-btn" id="lg-run">Run</button>
</div>

<pre id="portal-output">Output will appear here.</pre>

<h2>Terminals</h2>
<p>Live shells into the nodes you're allowed to touch: r1, r2, r3, host1.
Each opens where <code>docker exec -it clab-measlab-&lt;node&gt; sh</code> would
have dropped you &mdash; run <code>vtysh</code>, <code>ping</code>,
<code>traceroute</code>, <code>mtr</code> directly, no prefix needed.</p>
<div class="term-tabs">
  <button class="term-tab active" data-term="host1" type="button">host1</button>
  <button class="term-tab" data-term="r1" type="button">r1</button>
  <button class="term-tab" data-term="r2" type="button">r2</button>
  <button class="term-tab" data-term="r3" type="button">r3</button>
</div>
<div class="term-frames">
  <iframe class="term-frame visible" data-term="host1" src="http://localhost:7681" title="host1 terminal"></iframe>
  <iframe class="term-frame" data-term="r1" src="http://localhost:7682" title="r1 terminal"></iframe>
  <iframe class="term-frame" data-term="r2" src="http://localhost:7683" title="r2 terminal"></iframe>
  <iframe class="term-frame" data-term="r3" src="http://localhost:7684" title="r3 terminal"></iframe>
</div>

<script>
(function () {
  var out = document.getElementById("portal-output");

  function show(text) { out.textContent = text; }

  function post(url, body) {
    return fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    }).then(function (r) { return r.json(); }).catch(function (e) {
      return { ok: false, output: "Request failed: " + e + "\n\nIs ./portal.sh running?" };
    });
  }

  document.querySelectorAll(".portal-btn[data-action]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var action = btn.dataset.action;
      btn.disabled = true;
      show("Running " + action + " ...");
      post("/api/run", { action: action }).then(function (res) {
        btn.disabled = false;
        show((res.ok ? "" : "[failed]\n") + res.output);
      });
    });
  });

  document.getElementById("lg-run").addEventListener("click", function () {
    var router = document.getElementById("lg-router").value;
    var cmd = document.getElementById("lg-cmd").value;
    show("Running looking glass ...");
    post("/api/lg", { router: router, cmd: cmd }).then(function (res) {
      show((res.ok ? "" : "[failed]\n") + res.output);
    });
  });

  var tabs = Array.prototype.slice.call(document.querySelectorAll(".term-tab"));
  var frames = Array.prototype.slice.call(document.querySelectorAll(".term-frame"));
  tabs.forEach(function (tab) {
    tab.addEventListener("click", function () {
      tabs.forEach(function (t) { t.classList.toggle("active", t === tab); });
      frames.forEach(function (f) {
        f.classList.toggle("visible", f.dataset.term === tab.dataset.term);
      });
    });
  });
})();
</script>
"""


def md_to_html(text: str) -> str:
    MD.reset()
    return MD.convert(text)


def wrap_spoilers(html: str) -> str:
    """Wrap spoiler sections (h2 until next h2 or end) in <details>."""
    for heading in SPOILER_HEADINGS:
        pattern = re.compile(
            r"<h2>" + re.escape(heading) + r"</h2>(.*?)(?=<h2>|\Z)", re.S
        )
        html = pattern.sub(
            lambda m: (
                '<details class="answers"><summary>'
                + heading
                + " (reveal after writing your own)</summary>"
                + m.group(1)
                + "</details>"
            ),
            html,
        )
    return html


def load_page(path: Path):
    text = path.read_text(encoding="utf-8")
    title_match = re.search(r"^# (.+)$", text, re.M)
    title = title_match.group(1) if title_match else path.stem
    body = re.sub(r"^# .+$", "", text, count=1, flags=re.M)
    html = wrap_spoilers(md_to_html(body))
    return title, html


def nav_label(title: str) -> str:
    title = re.sub(r"^Activity (\d+)[,:]? ?(Scenario \d+: )?", r"\1 · ", title)
    return title


def main():
    pages = []  # (id, nav label, full title, html)

    guide_files = sorted(PAGES_DIR.glob("*.md"))
    activity_files = sorted(ACTIVITIES_DIR.glob("activity*.md"))

    for path in guide_files:
        title, body = load_page(path)
        pid = re.sub(r"^\d+-", "", path.stem)
        pages.insert(0 if "lab-guide" in pid else len(pages), (pid, title, title, body))

    pages.insert(1, ("portal", "Control Portal", "Control Portal", PORTAL_HTML))

    for path in activity_files:
        title, body = load_page(path)
        pid = path.stem.split("-")[0]
        pages.insert(len(pages) - 1, (pid, nav_label(title), title, body))

    svg = SVG_PATH.read_text(encoding="utf-8")
    svg = re.sub(r"<\?xml.*?\?>", "", svg, flags=re.S).strip()

    nav_items = "\n".join(
        f'<a class="nav-item" href="#{pid}" data-page="{pid}">'
        f'<span class="nav-label">{htmlmod.escape(label)}</span>'
        f'<span class="nav-progress" data-progress="{pid}"></span></a>'
        for pid, label, _, _ in pages
    )

    articles = "\n".join(
        f'<article id="{pid}" class="page" data-title="{htmlmod.escape(full)}">'
        f"<h1>{htmlmod.escape(full)}</h1>\n{body}\n</article>"
        for pid, _, full, body in pages
    )

    # The diagram image reference in the lab guide becomes the inline SVG
    articles = articles.replace(
        '<p><img alt="Lab topology" src="topology-diagram.svg" /></p>',
        '<div class="diagram">' + svg + "</div>",
    )

    out = TEMPLATE.replace("{{NAV}}", nav_items).replace("{{ARTICLES}}", articles)
    OUT.write_text(out, encoding="utf-8")
    print(f"wrote {OUT} ({len(out)//1024} KB, {len(pages)} pages)")


TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Internet Measurements Lab</title>
<style>
:root {
  --bg: #0d1226;
  --panel: #151d3b;
  --panel-2: #1b2547;
  --line: #2a3763;
  --text: #dfe6f5;
  --muted: #8fa0c9;
  --blue: #8fb7e1;
  --orange: #f36b21;
  --grey: #c9c9c9;
  --mono: ui-monospace, "SF Mono", "Cascadia Code", Consolas, "Liberation Mono", monospace;
  --sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
@media (prefers-reduced-motion: reduce) { html { scroll-behavior: auto; } }
body {
  margin: 0; background: var(--bg); color: var(--text);
  font-family: var(--sans); font-size: 16px; line-height: 1.65;
}
.shell { display: grid; grid-template-columns: 290px 1fr; min-height: 100vh; }

/* ---- sidebar ---- */
nav {
  background: var(--panel); border-right: 1px solid var(--line);
  padding: 22px 18px; position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
.brand { font-family: var(--mono); font-size: 14px; color: var(--muted); margin: 0 0 2px; }
.brand::before { content: "learner@as65001:~$ "; color: var(--orange); }
.brand-title { font-family: var(--mono); font-size: 18px; font-weight: 700; color: var(--text); margin: 0 0 22px; letter-spacing: .3px; }
.nav-item {
  display: flex; justify-content: space-between; align-items: baseline; gap: 8px;
  padding: 9px 10px; margin: 2px 0; border-radius: 6px;
  color: var(--blue); text-decoration: none; font-size: 14.5px;
  border-left: 3px solid transparent;
}
.nav-item:hover { background: var(--panel-2); }
.nav-item.active { background: var(--panel-2); color: var(--text); border-left-color: var(--orange); }
.nav-progress { font-family: var(--mono); font-size: 11.5px; color: var(--muted); white-space: nowrap; }
.nav-progress.done { color: var(--orange); }
nav .foot { margin-top: 26px; padding-top: 14px; border-top: 1px solid var(--line);
  font-size: 12.5px; color: var(--muted); }
nav .foot a { color: var(--blue); }

/* ---- content ---- */
main { padding: 42px clamp(24px, 5vw, 72px); max-width: 900px; }
.page { display: none; }
.page.visible { display: block; }
h1 { font-family: var(--mono); font-size: 26px; line-height: 1.3; margin: 0 0 6px; }
h1::before { content: "$ "; color: var(--orange); }
h2 { font-family: var(--mono); font-size: 18px; margin: 34px 0 10px; color: var(--text);
  padding-top: 14px; border-top: 1px solid var(--line); display: flex; align-items: center; gap: 10px; }
h3 { font-size: 16px; margin: 22px 0 8px; }
p, li { color: var(--text); max-width: 74ch; }
a { color: var(--blue); }
strong { color: #fff; }
blockquote { margin: 14px 0; padding: 10px 18px; border-left: 3px solid var(--blue);
  background: var(--panel); border-radius: 0 6px 6px 0; }
blockquote p { color: var(--muted); }

/* code */
code { font-family: var(--mono); font-size: 14px; background: var(--panel-2);
  padding: 1.5px 6px; border-radius: 4px; color: var(--blue); }
.codewrap { position: relative; margin: 14px 0; }
pre { background: #0a0f1f; border: 1px solid var(--line); border-radius: 8px;
  padding: 14px 16px; overflow-x: auto; margin: 0; }
pre code { background: none; padding: 0; color: #e8eefb; font-size: 14px; }
.copy-btn { position: absolute; top: 8px; right: 8px; font-family: var(--mono); font-size: 12px;
  background: var(--panel-2); color: var(--blue); border: 1px solid var(--line);
  border-radius: 5px; padding: 3px 10px; cursor: pointer; }
.copy-btn:hover { color: var(--orange); border-color: var(--orange); }
.copy-btn:focus-visible, .nav-item:focus-visible, summary:focus-visible, .task-check:focus-visible {
  outline: 2px solid var(--orange); outline-offset: 2px; }

/* tables */
table { border-collapse: collapse; margin: 14px 0; font-size: 14.5px; width: 100%; }
th, td { border: 1px solid var(--line); padding: 7px 11px; text-align: left; vertical-align: top; }
th { background: var(--panel); font-family: var(--mono); font-size: 13px; color: var(--muted); }
td code { white-space: nowrap; }

/* task checkboxes */
.task-check { width: 17px; height: 17px; accent-color: var(--orange); cursor: pointer; flex: none; }
h2.task-done { color: var(--muted); }
h2.task-done .task-title { text-decoration: line-through; text-decoration-color: var(--orange); }

/* answers */
details.answers { margin: 26px 0; background: var(--panel); border: 1px dashed var(--line);
  border-radius: 8px; padding: 0 18px; }
details.answers summary { font-family: var(--mono); font-size: 15px; color: var(--orange);
  cursor: pointer; padding: 13px 0; }
details.answers[open] { border-style: solid; padding-bottom: 8px; }

/* diagram */
.diagram { background: #fff; border-radius: 10px; padding: 10px; margin: 16px 0; }
.diagram svg { width: 100%; height: auto; display: block; }

/* control portal */
.btn-row { display: flex; flex-wrap: wrap; gap: 10px; margin: 10px 0 20px; }
.portal-btn {
  font-family: var(--mono); font-size: 13.5px; color: var(--blue);
  background: var(--panel-2); border: 1px solid var(--line); border-radius: 6px;
  padding: 8px 14px; cursor: pointer;
}
.portal-btn:hover { color: var(--orange); border-color: var(--orange); }
.portal-btn:disabled { opacity: .5; cursor: wait; }
.portal-btn.danger { color: #f36b6b; }
.portal-btn.danger:hover { border-color: #f36b6b; }
.lg-row { display: flex; flex-wrap: wrap; gap: 10px; margin: 10px 0 20px; align-items: center; }
.lg-row select, .lg-row input {
  font-family: var(--mono); font-size: 13.5px; background: var(--panel-2); color: var(--text);
  border: 1px solid var(--line); border-radius: 6px; padding: 7px 10px;
}
.lg-row input { flex: 1; min-width: 220px; }
#portal-output {
  background: #0a0f1f; border: 1px solid var(--line); border-radius: 8px;
  padding: 14px 16px; font-family: var(--mono); font-size: 13px; color: #e8eefb;
  white-space: pre-wrap; word-break: break-word; max-height: 360px; overflow-y: auto;
}
.term-tabs { display: flex; gap: 6px; margin: 16px 0 0; }
.term-tab {
  font-family: var(--mono); font-size: 13.5px; color: var(--muted);
  background: var(--panel); border: 1px solid var(--line); border-bottom: none;
  border-radius: 6px 6px 0 0; padding: 8px 16px; cursor: pointer;
}
.term-tab.active { color: var(--text); background: var(--panel-2); }
.term-frames { border: 1px solid var(--line); border-radius: 0 8px 8px 8px; overflow: hidden; }
.term-frame { display: none; width: 100%; height: 480px; border: 0; background: #000; }
.term-frame.visible { display: block; }

/* mobile */
@media (max-width: 860px) {
  .shell { grid-template-columns: 1fr; }
  nav { position: static; height: auto; border-right: 0; border-bottom: 1px solid var(--line); }
  main { padding: 26px 18px; }
}
@media print {
  nav, .copy-btn { display: none; }
  body { background: #fff; color: #000; }
  .page { display: block !important; page-break-after: always; }
  details.answers { border: 1px solid #999; }
  details.answers[open] summary { color: #000; }
}
</style>
</head>
<body>
<div class="shell">
<nav aria-label="Lab pages">
  <p class="brand">measlab</p>
  <p class="brand-title">Internet Measurements Lab</p>
  {{NAV}}
  <p class="foot">Progress is saved in this browser only. Answers stay hidden until you open them; open them only after committing to your own answers in writing.</p>
</nav>
<main>
{{ARTICLES}}
</main>
</div>
<script>
(function () {
  var pages = Array.prototype.slice.call(document.querySelectorAll(".page"));
  var navItems = Array.prototype.slice.call(document.querySelectorAll(".nav-item"));

  function show(id) {
    var target = document.getElementById(id) ? id : pages[0].id;
    pages.forEach(function (p) { p.classList.toggle("visible", p.id === target); });
    navItems.forEach(function (n) { n.classList.toggle("active", n.dataset.page === target); });
    document.title = (document.getElementById(target).dataset.title || "Lab") + " · Internet Measurements Lab";
    try { window.scrollTo(0, 0); } catch (e) {}
  }
  window.addEventListener("hashchange", function () { show(location.hash.slice(1)); });

  // Copy buttons on every code block
  document.querySelectorAll("pre").forEach(function (pre) {
    var wrap = document.createElement("div");
    wrap.className = "codewrap";
    pre.parentNode.insertBefore(wrap, pre);
    wrap.appendChild(pre);
    var btn = document.createElement("button");
    btn.className = "copy-btn"; btn.type = "button"; btn.textContent = "Copy";
    btn.addEventListener("click", function () {
      var text = pre.innerText;
      function ok() { btn.textContent = "Copied"; setTimeout(function () { btn.textContent = "Copy"; }, 1400); }
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(ok);
      } else {
        var ta = document.createElement("textarea");
        ta.value = text; document.body.appendChild(ta); ta.select();
        try { document.execCommand("copy"); ok(); } catch (e) {}
        document.body.removeChild(ta);
      }
    });
    wrap.appendChild(btn);
  });

  // Task checkboxes with progress, persisted per browser
  function store(key, val) { try { localStorage.setItem(key, val); } catch (e) {} }
  function load(key) { try { return localStorage.getItem(key); } catch (e) { return null; } }

  pages.forEach(function (page) {
    var tasks = Array.prototype.slice.call(page.querySelectorAll("h2")).filter(function (h) {
      return /^Task /.test(h.textContent);
    });
    var pill = document.querySelector('[data-progress="' + page.id + '"]');

    function refresh() {
      if (!pill) return;
      if (!tasks.length) { pill.textContent = ""; return; }
      var done = tasks.filter(function (h) { return h.querySelector("input").checked; }).length;
      pill.textContent = done + "/" + tasks.length;
      pill.classList.toggle("done", done === tasks.length);
    }

    tasks.forEach(function (h, i) {
      var key = "measlab." + page.id + ".task" + i;
      var box = document.createElement("input");
      box.type = "checkbox"; box.className = "task-check";
      box.setAttribute("aria-label", "Mark task complete");
      box.checked = load(key) === "1";
      var span = document.createElement("span");
      span.className = "task-title"; span.textContent = h.textContent;
      h.textContent = ""; h.appendChild(box); h.appendChild(span);
      h.classList.toggle("task-done", box.checked);
      box.addEventListener("change", function () {
        store(key, box.checked ? "1" : "0");
        h.classList.toggle("task-done", box.checked);
        refresh();
      });
    });
    refresh();
  });

  show(location.hash.slice(1));
})();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
