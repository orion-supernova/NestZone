#!/usr/bin/env python3
"""Builds Docs/index.html: the one place every NestZone doc is listed.

HTML docs are linked (they open as they are). Markdown docs are embedded and
rendered in the page, so nothing needs a server. Run it after adding or moving
a doc:  python3 Docs/build-hub.py
Add a new doc to CATALOG below; anything under Docs/ that is not listed shows
up under "Not filed yet" so nothing goes missing.
"""
import html, json, os, subprocess, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "Docs")

# (path from repo root, title, one line, status)  status: current | reference | history
CATALOG = [
    ("Start here", [
        ("Docs/Design/readability.html", "Readability and themes", "Measured contrast per theme, the text roles, surfaces and component rules, and what is left to swap.", "current"),
        ("Docs/Navigation/plan.html", "Navigation plan", "Where everything lives: tabs, segments, the top bar rule, names, and opening things from elsewhere.", "current"),
        ("Docs/Calendar/sharing.html", "Calendar sharing plan", "Your iCloud/Gmail calendars both ways through EventKit, and filtering the calendar by person.", "current"),
        ("Docs/Launch/plus-badge.html", "Plus badge", "The mark every Plus feature wears: the lock without Plus, the accent sparkles with it.", "current"),
        ("Docs/Launch/index.html", "Launch plan", "App Store release: NestZone Plus, Nestie on, review blockers, store setup, status.", "current"),
        ("CLAUDE.md", "How the app is built", "Architecture, navigation, conventions, shipping, backend notes. The rulebook.", "current"),
        ("Docs/Companion/HANDOFF.md", "Nestie handoff", "Where Nestie stands, what was decided and what is next.", "current"),
    ]),
    ("Nestie: plan and decisions", [
        ("Docs/Companion/plan/index.html", "Nestie plan", "The full plan: growth, catalog, currencies, roadmap.", "current"),
        ("Docs/Companion/README.md", "Nestie overview", "What Nestie is, in short.", "reference"),
        ("Docs/Companion/plan/shop.html", "Shop prototype", "The shop prototype and how each decision was answered.", "reference"),
        ("Docs/Companion/plan/plant.html", "Household plant", "Early plant prototype.", "history"),
        ("Docs/Companion/plan/duck.html", "Duckling demo", "Early duckling prototype.", "history"),
        ("Docs/Companion/HOLIDAYS.md", "Holiday dates", "How holiday dates are worked out and where they were checked.", "reference"),
        ("Docs/Companion/lab/index.html", "Nestie Lab guide", "Testing Nestie through the Debug Lab's pretend house.", "reference"),
        ("Docs/Companion/finale/index.html", "Finale", "The finale and colourways, on the bench.", "reference"),
        ("Docs/Companion/a11y/index.html", "Accessibility pass", "Nestie at large text sizes, VoiceOver, Reduce Motion.", "reference"),
    ]),
    ("Nestie: art", [
        ("Docs/Companion/art/RULES.md", "Illustration rules", "The rules every plant and tree follows, from the pomegranate.", "current"),
        ("Docs/Companion/art/RULES-pets.md", "Illustration rules for pets", "The rules every pet follows, from the kitten.", "current"),
        ("Docs/Companion/art/stages/index.html", "Pet life stages", "Baby, little one and young for the mammal pets.", "reference"),
        ("Docs/Companion/art/pets/index.html", "Pets before and after", "The kitten, batch A and batch B.", "reference"),
        ("Docs/Companion/art/plants/index.html", "Potted plants", "Round A: before and v1.", "reference"),
        ("Docs/Companion/art/trees/index.html", "Trees before and after", "The trees after the art pass.", "reference"),
        ("Docs/Companion/art/colours/index.html", "Colourways", "The finale's colourways for every species.", "reference"),
        ("Docs/Companion/art/decor/index.html", "Decorations", "Scenes, decorations and things to wear: before and after.", "reference"),
        ("Docs/Companion/art/shop/index.html", "Shop drawings", "Shop drawings and the card at accessibility sizes.", "reference"),
        ("Docs/Companion/art/hero/index.html", "Pomegranate hero", "The hero tree: before, v1, v2.", "history"),
        ("Docs/Companion/art/pass1/index.html", "Art pass, batch 1", "The first art pass.", "history"),
        ("Docs/Companion/art/compare.html", "Trees: two directions", "Gouache against soft canopy.", "history"),
        ("Docs/Companion/art/gouache/tree.html", "Gouache tree", "Direction B prototype.", "history"),
        ("Docs/Companion/art/gouache/SPEC.md", "Gouache tree spec", "How the layered gouache tree is built.", "history"),
        ("Docs/Companion/art/soft-canopy/tree.html", "Soft canopy tree", "Direction A prototype.", "history"),
        ("Docs/Companion/art/soft-canopy/SPEC.md", "Soft canopy spec", "Direction A, written down.", "history"),
        ("Docs/Companion/art/SHADERS.md", "Shaders", "How the shaders were wired (shader effects were later dropped from the scene).", "history"),
    ]),
    ("Backend and shipping", [
        ("backend/DEPRECATIONS.md", "Deprecations", "What may be removed from the backend, and when. Includes PRO_ENFORCE.", "current"),
        ("Docs/Backend/data-integrity-audit.html", "Data integrity audit", "References, cascades, growth, backups and a phased plan to make the backend last.", "current"),
        ("XCODE_CLOUD.md", "Xcode Cloud", "What builds the app once stage is pushed, and its setup.", "current"),
        ("Docs/Convex-Migration/Backend-Deploy-Runbook.md", "Backend deploy runbook", "Convex deploy, data import, the tunnel.", "reference"),
        ("backend/README.md", "Backend README", "The PocketBase to Convex migration, backend side.", "history"),
    ]),
    ("History", [
        ("Docs/premium-audit.md", "Premium audit (Sept)", "The first look at a paid tier. Superseded by the launch plan.", "history"),
        ("Docs/Convex-Migration/iOS-Migration-Guide.md", "iOS migration guide", "PocketBase to Convex, app side.", "history"),
        ("Docs/PocketBase/README.md", "PocketBase", "The old backend.", "history"),
        ("AGENTS.md", "AGENTS.md", "Short pointer for other coding agents.", "reference"),
        ("README.md", "README", "Repository readme.", "reference"),
    ]),
]

def last_change(rel):
    try:
        out = subprocess.run(["git", "log", "-1", "--format=%cs", "--", rel], cwd=ROOT,
                             capture_output=True, text=True).stdout.strip()
        return out or datetime.date.fromtimestamp(os.path.getmtime(os.path.join(ROOT, rel))).isoformat()
    except Exception:
        return ""

def main():
    seen, sections, md_blobs = set(), [], {}
    for name, items in CATALOG:
        rows = []
        for rel, title, line, status in items:
            path = os.path.join(ROOT, rel)
            if not os.path.exists(path):
                continue
            seen.add(os.path.normpath(rel))
            rows.append((rel, title, line, status, last_change(rel)))
            if rel.endswith(".md"):
                md_blobs[rel] = open(path, encoding="utf-8").read()
        if rows:
            sections.append((name, rows))
    stray = []
    for dirpath, _, files in os.walk(DOCS):
        for f in files:
            if not f.endswith((".md", ".html")) or f == "index.html" and dirpath == DOCS:
                continue
            rel = os.path.normpath(os.path.relpath(os.path.join(dirpath, f), ROOT))
            if rel not in seen:
                stray.append((rel, rel, "Not described yet.", "reference", last_change(rel)))
                if f.endswith(".md"):
                    md_blobs[rel] = open(os.path.join(dirpath, f), encoding="utf-8").read()
    if stray:
        sections.append(("Not filed yet", sorted(stray)))

    def href(rel):
        return os.path.relpath(os.path.join(ROOT, rel), DOCS)

    cards = []
    for name, rows in sections:
        items = []
        for rel, title, line, status, date in rows:
            kind = "md" if rel.endswith(".md") else "html"
            attrs = (f'data-md="{html.escape(rel)}" href="#doc-{html.escape(rel)}"' if kind == "md"
                     else f'href="{html.escape(href(rel))}" target="_blank" rel="noopener"')
            items.append(
                f'<li data-search="{html.escape((title + " " + line + " " + rel).lower())}">'
                f'<a class="doc" {attrs}><span class="t">{html.escape(title)}</span>'
                f'<span class="l">{html.escape(line)}</span>'
                f'<span class="m"><span class="pill {status}">{status}</span>'
                f'<span class="k">{kind.upper()}</span><span>{html.escape(rel)}</span><span>{date}</span></span></a></li>')
        cards.append(f'<section><h2>{html.escape(name)}</h2><ul>{"".join(items)}</ul></section>')

    out = TEMPLATE.replace("%%SECTIONS%%", "\n".join(cards)) \
                  .replace("%%MD%%", json.dumps(md_blobs).replace("</", "<\\/")) \
                  .replace("%%BUILT%%", datetime.date.today().isoformat())
    open(os.path.join(DOCS, "index.html"), "w", encoding="utf-8").write(out)
    print(f"Docs/index.html: {sum(len(r) for _, r in sections)} docs, {len(stray)} not filed")

TEMPLATE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>NestZone Docs</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400&display=swap">
<style>
:root{--bg:#f5f7f6;--surface:#fff;--ink:#15211d;--muted:#5b6b65;--line:#dbe3df;--accent:#1f7a5c;--soft:#e1f1ea;--hist:#8a8f8c;--histsoft:#eceeed;--ref:#3a6fb0;--refsoft:#e4edf8;
--display:"Bricolage Grotesque",system-ui,sans-serif;--body:"Inter",system-ui,-apple-system,sans-serif;--mono:"JetBrains Mono",ui-monospace,Menlo,monospace}
@media (prefers-color-scheme:dark){:root{--bg:#0f1513;--surface:#161e1b;--ink:#e4ece8;--muted:#94a59e;--line:#26322d;--accent:#4cc79b;--soft:#183128;--hist:#8d9590;--histsoft:#1f2523;--ref:#7fb0ef;--refsoft:#18243a;color-scheme:dark}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 var(--body)}
.wrap{max-width:1000px;margin:0 auto;padding:40px max(16px,env(safe-area-inset-left)) 80px}
h1{font:700 40px/1.1 var(--display);margin:0 0 6px}h2{font:600 20px/1.2 var(--display);margin:36px 0 10px}
.sub{color:var(--muted);margin:0 0 20px}input#q{width:100%;padding:12px 14px;border:1px solid var(--line);border-radius:10px;background:var(--surface);color:var(--ink);font:15px var(--body)}
input#q:focus{outline:2px solid var(--accent);outline-offset:1px}
ul{list-style:none;margin:0;padding:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:10px}
a.doc{display:grid;gap:4px;padding:14px 16px;background:var(--surface);border:1px solid var(--line);border-radius:12px;text-decoration:none;color:inherit;height:100%}
a.doc:hover,a.doc:focus-visible{border-color:var(--accent);outline:none}
.t{font-weight:600}.l{color:var(--muted);font-size:14px}.m{display:flex;flex-wrap:wrap;gap:6px 10px;font:12px var(--mono);color:var(--muted);margin-top:4px;align-items:center}
.pill{font:600 10px/1 var(--mono);text-transform:uppercase;letter-spacing:.05em;padding:4px 7px;border-radius:99px}
.pill.current{background:var(--soft);color:var(--accent)}.pill.reference{background:var(--refsoft);color:var(--ref)}.pill.history{background:var(--histsoft);color:var(--hist)}
.k{font-weight:600}
dialog{width:min(920px,96vw);max-height:90vh;border:1px solid var(--line);border-radius:14px;padding:0;background:var(--surface);color:var(--ink)}
dialog::backdrop{background:rgba(0,0,0,.4)}.bar{position:sticky;top:0;display:flex;justify-content:space-between;align-items:center;gap:12px;padding:12px 18px;border-bottom:1px solid var(--line);background:var(--surface);font:13px var(--mono)}
.bar button{font:600 13px var(--body);border:1px solid var(--line);background:var(--bg);color:var(--ink);border-radius:8px;padding:6px 12px;cursor:pointer}
.md{padding:8px 28px 32px;overflow-wrap:anywhere}.md pre{background:var(--bg);padding:12px;border-radius:8px;overflow-x:auto}.md code{font:13px var(--mono)}
.md table{border-collapse:collapse;display:block;overflow-x:auto}.md td,.md th{border:1px solid var(--line);padding:6px 10px}.md a{color:var(--accent)}
.legend{display:flex;gap:14px;flex-wrap:wrap;font-size:13px;color:var(--muted);margin:10px 0 0}
</style></head><body><div class="wrap">
<h1>NestZone docs</h1>
<p class="sub">Every plan, handoff, rulebook and art page in one place. HTML opens in a new tab; Markdown opens here. Built %%BUILT%% by <code>Docs/build-hub.py</code>.</p>
<input id="q" type="search" placeholder="Filter: nestie, art, launch, deploy…" aria-label="Filter docs">
<p class="legend"><span><span class="pill current">current</span> what is true now</span><span><span class="pill reference">reference</span> still useful</span><span><span class="pill history">history</span> how we got here</span></p>
%%SECTIONS%%
</div>
<dialog id="dlg"><div class="bar"><span id="dlgt"></span><button id="close" type="button">Close</button></div><div class="md" id="mdbody"></div></dialog>
<script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.2/marked.min.js"></script>
<script>
const MD = %%MD%%;
const q=document.getElementById('q');
q.addEventListener('input',()=>{const v=q.value.trim().toLowerCase();document.querySelectorAll('li').forEach(li=>{li.hidden=v&&!li.dataset.search.includes(v)});document.querySelectorAll('section').forEach(s=>{s.hidden=![...s.querySelectorAll('li')].some(li=>!li.hidden)})});
const dlg=document.getElementById('dlg'),body=document.getElementById('mdbody');
function show(rel){const src=MD[rel]||'';document.getElementById('dlgt').textContent=rel;
 if(window.marked){body.innerHTML=marked.parse(src)}else{const p=document.createElement('pre');p.textContent=src;body.replaceChildren(p)}
 dlg.showModal();dlg.scrollTop=0}
document.querySelectorAll('a[data-md]').forEach(a=>a.addEventListener('click',e=>{e.preventDefault();show(a.dataset.md)}));
document.getElementById('close').onclick=()=>dlg.close();
</script></body></html>
"""

if __name__ == "__main__":
    main()
