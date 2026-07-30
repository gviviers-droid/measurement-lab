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
FONT_PATH = ROOT / "frontend" / "assets" / "public-sans-400.woff2.b64"
LOGO_PATH = ROOT / "frontend" / "assets" / "ripe-ncc-logo.svg"
OUT = ROOT / "frontend" / "index.html"

MD = markdown.Markdown(extensions=["tables", "fenced_code"])

# Sections whose body must stay hidden until the learner opens them
SPOILER_HEADINGS = ("Check your answers", "Model incident summary")

# Nav icons: small, original, monochrome (currentColor) -- not copied from any
# external icon set. Activities use a plain numbered badge instead (see CSS).
ICON_GUIDE = (
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">'
    '<path d="M4 5.5C4 4.7 4.7 4 5.5 4H12v16H5.5A1.5 1.5 0 0 1 4 18.5v-13Z"/>'
    '<path d="M20 5.5c0-.8-.7-1.5-1.5-1.5H12v16h6.5a1.5 1.5 0 0 0 1.5-1.5v-13Z"/>'
    "</svg>"
)
ICON_PORTAL = (
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">'
    '<rect x="3.5" y="4.5" width="17" height="15" rx="1.8"/>'
    '<path d="M7 9.5 10.2 12 7 14.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M12.5 14.5h4.5" stroke-linecap="round"/>'
    "</svg>"
)
ICON_CHEATSHEET = (
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6">'
    '<path d="M6 3.5h9l4 4v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-16a1 1 0 0 1 1-1Z"/>'
    '<path d="M9 12h7M9 15.5h7M9 8.5h3"/>'
    "</svg>"
)

# Nav subtitles, keyed by page id (kept as plain data so build.py stays the
# single place nav copy lives -- edit here, not in the generated HTML)
NAV_SUBTITLES = {
    "lab-guide": "Topology, addressing, requirements",
    "portal": "Start/stop the lab, live terminals",
    "activity1": "Traceroute, ping, mtr, BGP tables",
    "activity2": "Congestion, jitter, loss under load",
    "activity3": "Enable peering, measure the difference",
    "activity4": "Diagnose a degraded path",
    "activity5": "Diagnose an intermittent fault",
    "cheatsheet": "Command reference",
}
NAV_ICONS = {"lab-guide": ICON_GUIDE, "portal": ICON_PORTAL, "cheatsheet": ICON_CHEATSHEET}

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
<p>Live shells into the nodes you're allowed to touch, side by side. Each opens
where <code>docker exec -it clab-measlab-&lt;node&gt; sh</code> would have
dropped you &mdash; run <code>vtysh</code>, <code>ping</code>,
<code>traceroute</code>, <code>mtr</code> directly, no prefix needed. Drag a
console's bottom-right corner to resize it.</p>
<div class="console-grid">
  <div class="console" data-port="7681">
    <div class="console-head">
      <span class="console-name">host1</span>
      <a href="#" class="console-action" data-act="reconnect">reconnect</a>
      <a href="http://localhost:7681" target="_blank" class="console-action">pop out</a>
    </div>
    <div class="console-resizer"><iframe src="http://localhost:7681" title="host1 terminal"></iframe></div>
  </div>
  <div class="console" data-port="7682">
    <div class="console-head">
      <span class="console-name">r1</span>
      <a href="#" class="console-action" data-act="reconnect">reconnect</a>
      <a href="http://localhost:7682" target="_blank" class="console-action">pop out</a>
    </div>
    <div class="console-resizer"><iframe src="http://localhost:7682" title="r1 terminal"></iframe></div>
  </div>
  <div class="console" data-port="7683">
    <div class="console-head">
      <span class="console-name">r2</span>
      <a href="#" class="console-action" data-act="reconnect">reconnect</a>
      <a href="http://localhost:7683" target="_blank" class="console-action">pop out</a>
    </div>
    <div class="console-resizer"><iframe src="http://localhost:7683" title="r2 terminal"></iframe></div>
  </div>
  <div class="console" data-port="7684">
    <div class="console-head">
      <span class="console-name">r3</span>
      <a href="#" class="console-action" data-act="reconnect">reconnect</a>
      <a href="http://localhost:7684" target="_blank" class="console-action">pop out</a>
    </div>
    <div class="console-resizer"><iframe src="http://localhost:7684" title="r3 terminal"></iframe></div>
  </div>
  <div class="console-aside">
    <div class="hints-box">
      <h3>Hints</h3>
      <ul>
        <li>Drag a console's bottom-right corner to resize it (not supported in Firefox).</li>
        <li>If the first character typed into a freshly opened console looks garbled, press Ctrl-C and retype &mdash; a one-time artifact per console, it will not recur.</li>
        <li>"pop out" opens the same console full-page, useful on small screens.</li>
      </ul>
    </div>
    <div class="scratch-pad">
      <h3>Scratch-pad</h3>
      <textarea id="scratchpad" placeholder="Notes or commands to copy back in. Saved in this browser only."></textarea>
    </div>
  </div>
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

  document.querySelectorAll('.console-action[data-act="reconnect"]').forEach(function (link) {
    link.addEventListener("click", function (e) {
      e.preventDefault();
      var iframe = link.closest(".console").querySelector("iframe");
      iframe.src = iframe.src;
    });
  });

  var pad = document.getElementById("scratchpad");
  if (pad) {
    var padKey = "measlab.scratchpad";
    try { pad.value = localStorage.getItem(padKey) || ""; } catch (e) {}
    pad.addEventListener("input", function () {
      try { localStorage.setItem(padKey, pad.value); } catch (e) {}
    });
  }
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

    font_b64 = FONT_PATH.read_text(encoding="utf-8").strip()
    logo_svg = LOGO_PATH.read_text(encoding="utf-8").strip()

    def nav_icon(pid: str) -> str:
        if pid in NAV_ICONS:
            return f'<span class="nav-icon">{NAV_ICONS[pid]}</span>'
        m = re.match(r"activity(\d)", pid)
        num = m.group(1) if m else "?"
        return f'<span class="nav-icon nav-badge">{num}</span>'

    nav_items = "\n".join(
        f'<a class="nav-item" href="#{pid}" data-page="{pid}">'
        + nav_icon(pid)
        + '<span class="nav-text">'
        + f'<span class="nav-label">{htmlmod.escape(label)}</span>'
        + (
            f'<span class="nav-subtitle">{htmlmod.escape(NAV_SUBTITLES[pid])}</span>'
            if pid in NAV_SUBTITLES
            else ""
        )
        + "</span>"
        + f'<span class="nav-progress" data-progress="{pid}"></span></a>'
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

    out = (
        TEMPLATE.replace("{{NAV}}", nav_items)
        .replace("{{ARTICLES}}", articles)
        .replace("{{FONT_B64}}", font_b64)
        .replace("{{RIPE_LOGO}}", logo_svg)
    )
    OUT.write_text(out, encoding="utf-8")
    print(f"wrote {OUT} ({len(out)//1024} KB, {len(pages)} pages)")


TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Internet Measurements Lab</title>
<style>
@font-face {
  font-family: "Public Sans";
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url(data:font/woff2;base64,{{FONT_B64}}) format("woff2");
}
:root {
  --bg: #0d1226;
  --panel: #151d3b;
  --panel-2: #1b2547;
  --line: #2a3763;
  --text: #dfe6f5;
  --muted: #8fa0c9;
  --blue: #8fb7e1;
  --orange: #f26b21;
  --grey: #c9c9c9;
  --mono: ui-monospace, "SF Mono", "Cascadia Code", Consolas, "Liberation Mono", monospace;
  --sans: "Public Sans", system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
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
.brand-logo { color: var(--text); margin: 0 0 16px; width: 148px; }
.brand-logo svg { width: 100%; height: auto; display: block; }
.brand-title { font-family: var(--mono); font-size: 17px; font-weight: 700; color: var(--text); margin: 0 0 2px; letter-spacing: .3px; }
.brand-sub { font-size: 12.5px; color: var(--muted); margin: 0 0 22px; }
.nav-item {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 9px 10px; margin: 2px 0; border-radius: 6px;
  color: var(--blue); text-decoration: none;
  border-left: 3px solid transparent;
}
.nav-item:hover { background: var(--panel-2); }
.nav-item.active { background: var(--panel-2); color: var(--text); border-left-color: var(--orange); }
.nav-icon {
  flex: none; width: 20px; height: 20px; margin-top: 1px; color: var(--muted);
}
.nav-item.active .nav-icon { color: var(--orange); }
.nav-icon svg { width: 100%; height: 100%; }
.nav-badge {
  display: flex; align-items: center; justify-content: center;
  width: 20px; height: 20px; border-radius: 50%; border: 1.5px solid currentColor;
  font-family: var(--mono); font-size: 11px; font-weight: 700;
}
.nav-text { display: flex; flex-direction: column; gap: 1px; flex: 1; min-width: 0; }
.nav-label { font-size: 14.5px; }
.nav-subtitle { font-size: 12px; color: var(--muted); font-weight: 400; }
.nav-item.active .nav-subtitle { color: var(--blue); }
.nav-progress { flex: none; font-family: var(--mono); font-size: 11.5px; color: var(--muted); white-space: nowrap; }
.nav-progress.done { color: var(--orange); }
nav .foot { margin-top: 26px; padding-top: 14px; border-top: 1px solid var(--line);
  font-size: 12.5px; color: var(--muted); }
nav .foot a { color: var(--blue); }

/* ---- content ---- */
main { padding: 42px clamp(24px, 5vw, 72px); max-width: 900px; }
main:has(#portal.visible) { max-width: none; }
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
.console-grid { display: flex; flex-wrap: wrap; gap: 16px; margin: 16px 0 0; align-items: flex-start; }
.console {
  background: var(--panel); border: 1px solid var(--line); border-radius: 8px;
  overflow: hidden; flex: none;
}
.console-head {
  display: flex; align-items: center; gap: 12px; padding: 8px 12px;
  background: var(--panel-2); border-bottom: 1px solid var(--line);
}
.console-name { font-family: var(--mono); font-size: 13.5px; color: var(--text); font-weight: 700; }
.console-action { font-family: var(--mono); font-size: 12px; color: var(--blue); text-decoration: none; }
.console-action:hover { color: var(--orange); }
.console-resizer {
  resize: both; overflow: auto; width: 420px; height: 300px; min-width: 280px; min-height: 160px;
  display: flex;
}
.console-resizer iframe { flex: 1; width: 100%; height: 100%; border: 0; background: #000; }
.console-aside { flex: 1; min-width: 240px; display: flex; flex-direction: column; gap: 16px; }
.hints-box, .scratch-pad {
  background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 12px 16px;
}
.hints-box h3, .scratch-pad h3 { margin: 0 0 8px; font-size: 14px; color: var(--muted);
  font-family: var(--mono); text-transform: uppercase; letter-spacing: .04em; }
.hints-box ul { margin: 0; padding-left: 18px; font-size: 13.5px; }
.hints-box li { margin: 6px 0; color: var(--muted); }
.scratch-pad textarea {
  width: 100%; min-height: 140px; resize: vertical; background: #0a0f1f; color: var(--text);
  border: 1px solid var(--line); border-radius: 6px; padding: 10px 12px;
  font-family: var(--mono); font-size: 13px;
}

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
  <div class="brand-logo">{{RIPE_LOGO}}</div>
  <p class="brand-title">Internet Measurements Lab</p>
  <p class="brand-sub">RIPE NCC Academy</p>
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
