#!/usr/bin/env python3
"""Assemble a task-report HTML page from git data + narrative sections written by Claude.

The raw diff never passes through the model: this script runs git itself, renders
diff HTML mechanically, and splices in narrative sections from a file Claude writes.
Claude spends tokens only on the narrative (~1-2k tokens), so a 40-file report costs
about the same as a 3-file one and the diff can't be hallucinated or truncated.

Usage:
    python3 build_report.py --narrative narrative.html --out report.html \
        [--base HEAD] [--title "Auth refactor"] [--repo /path/to/repo]

    --base <ref>   diff baseline: working tree is compared against this ref.
                   HEAD (default) = uncommitted work; a commit/branch = everything
                   since it, committed or not.
    --base none    no git at all (research tasks, non-repo dirs); only narrative
                   sections and file-notes render.

Narrative file: HTML fragments separated by `<!-- section: name -->` markers.
Required sections: banner, summary, verification, caveats.
Optional: file-notes (plain lines `path | red|yellow|gray | note`), review-guide,
decisions, diagram, before-after, followups.

Output is Artifact-ready page content (starts with <title>, no <html>/<head>/<body>
wrapper — the Artifact tool adds the document shell).
"""

import argparse
import datetime
import fnmatch
import html
import re
import subprocess
import sys
from pathlib import Path

REQUIRED_SECTIONS = ["banner", "summary", "verification", "caveats"]
OPTIONAL_SECTIONS = ["file-notes", "review-guide", "decisions", "diagram",
                     "before-after", "followups"]

# Files whose diff bodies are noise: render stat-line only.
GENERATED_PATTERNS = [
    "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "Cargo.lock",
    "poetry.lock", "uv.lock", "Gemfile.lock", "composer.lock", "go.sum",
    "*.min.js", "*.min.css", "*.map", "*.snap",
    "dist/*", "build/*", "node_modules/*", "vendor/*", "__pycache__/*",
]

OPEN_THRESHOLD = 80        # files with <= this many changed lines start expanded
MAX_BODY_LINES = 1200      # beyond this, a file's diff body is omitted entirely
MAX_UNTRACKED_LINES = 400  # untracked files longer than this get stat-line only
PRIO_ORDER = {"red": 0, "yellow": 1, None: 2, "gray": 3}


def die(msg):
    sys.exit(f"build_report.py: error: {msg}")


def git(repo, *args, check=True):
    r = subprocess.run(["git", "-C", repo, *args],
                       capture_output=True, text=True, errors="replace")
    if check and r.returncode != 0:
        die(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout


# ---------------------------------------------------------------- narrative

def parse_narrative(path):
    text = Path(path).read_text(encoding="utf-8")
    parts = re.split(r"<!--\s*section:\s*([a-z-]+)\s*-->", text)
    sections = {}
    for i in range(1, len(parts) - 1, 2):
        sections[parts[i]] = parts[i + 1].strip()
    missing = [s for s in REQUIRED_SECTIONS if not sections.get(s)]
    if missing:
        die(f"narrative is missing required section(s): {', '.join(missing)}. "
            f"Found: {', '.join(sections) or 'none'}")
    unknown = set(sections) - set(REQUIRED_SECTIONS) - set(OPTIONAL_SECTIONS)
    if unknown:
        print(f"warning: unknown section(s) ignored: {', '.join(sorted(unknown))}",
              file=sys.stderr)
    return sections


def parse_file_notes(text):
    notes = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        bits = [b.strip() for b in line.split("|", 2)]
        if len(bits) != 3 or bits[1] not in ("red", "yellow", "gray"):
            print(f"warning: skipping malformed file-notes line: {line!r}",
                  file=sys.stderr)
            continue
        notes[bits[0]] = (bits[1], bits[2])
    return notes


# ---------------------------------------------------------------- diff parsing

class FileDiff:
    def __init__(self, path):
        self.path = path
        self.old_path = None
        self.kind = "modified"
        self.binary = False
        self.adds = 0
        self.dels = 0
        self.rows = []          # (cls, old_ln, new_ln, text) or ("hunk", header)
        self.omitted = None     # reason string when body is dropped
        self.prio = None
        self.note = ""

    @property
    def generated(self):
        return any(fnmatch.fnmatch(self.path, p) or
                   fnmatch.fnmatch(Path(self.path).name, p)
                   for p in GENERATED_PATTERNS)


def _strip_prefix(p):
    p = p.strip().strip('"')
    return p[2:] if p[:2] in ("a/", "b/") else p


HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)")


def parse_diff(text):
    files, cur = [], None
    old_ln = new_ln = 0
    for line in text.splitlines():
        if line.startswith("diff --git "):
            cur = FileDiff(_strip_prefix(line.split(" b/")[-1]))
            files.append(cur)
            continue
        if cur is None:
            continue
        if line.startswith("new file mode"):
            cur.kind = "added"
        elif line.startswith("deleted file mode"):
            cur.kind = "deleted"
        elif line.startswith("rename from "):
            cur.old_path = line[len("rename from "):]
            cur.kind = "renamed"
        elif line.startswith("rename to "):
            cur.path = line[len("rename to "):]
        elif line.startswith("Binary files") or line.startswith("GIT binary patch"):
            cur.binary = True
        elif line.startswith("--- "):
            p = _strip_prefix(line[4:])
            if p != "/dev/null":
                cur.old_path = cur.old_path or p
        elif line.startswith("+++ "):
            p = _strip_prefix(line[4:])
            if p != "/dev/null":
                cur.path = p
        else:
            m = HUNK_RE.match(line)
            if m:
                old_ln, new_ln = int(m.group(1)), int(m.group(3))
                cur.rows.append(("hunk", line))
            elif line.startswith("+"):
                cur.adds += 1
                cur.rows.append(("add", "", new_ln, line[1:]))
                new_ln += 1
            elif line.startswith("-"):
                cur.dels += 1
                cur.rows.append(("del", old_ln, "", line[1:]))
                old_ln += 1
            elif line.startswith(" "):
                cur.rows.append(("ctx", old_ln, new_ln, line[1:]))
                old_ln += 1
                new_ln += 1
            # "\ No newline at end of file" and other lines: skip
    return files


def untracked_filediffs(repo, paths):
    out = []
    for p in paths:
        fd = FileDiff(p)
        fd.kind = "untracked"
        try:
            content = (Path(repo) / p).read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            fd.binary = True
            out.append(fd)
            continue
        lines = content.splitlines()
        fd.adds = len(lines)
        if len(lines) > MAX_UNTRACKED_LINES:
            fd.omitted = f"new file, {len(lines)} lines — body omitted"
        else:
            for i, ln in enumerate(lines, 1):
                fd.rows.append(("add", "", i, ln))
        out.append(fd)
    return out


def session_filediffs(repo, paths):
    """Non-git mode: current-content snapshots of files Claude says it edited."""
    out = []
    for p in paths:
        fd = FileDiff(p)
        fd.kind = "edited (session)"
        try:
            content = (Path(repo) / p).read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            fd.binary = True
            out.append(fd)
            continue
        lines = content.splitlines()
        if len(lines) > MAX_UNTRACKED_LINES:
            fd.omitted = f"current content, {len(lines)} lines — too long to embed"
        else:
            for i, ln in enumerate(lines, 1):
                fd.rows.append(("ctx", "", i, ln))
        out.append(fd)
    return out


# ---------------------------------------------------------------- rendering

def esc(s):
    return html.escape(str(s), quote=True)


def fstat(fd):
    if fd.kind == "edited (session)":
        n = len([r for r in fd.rows if r[0] != "hunk"])
        return f'<span class="kind">{n} lines</span>' if n else ""
    return (f'<span class="fstat"><span class="add">+{fd.adds}</span> '
            f'<span class="del">−{fd.dels}</span></span>')


def prio_dot(prio):
    return f'<span class="prio prio-{prio}" title="review priority: {prio}"></span>' \
        if prio else '<span class="prio"></span>'


def render_file_diff(fd, open_default):
    label = (f'{prio_dot(fd.prio)}<code>{esc(fd.path)}</code>'
             + (f' <span class="kind">{fd.kind}'
                + (f' ← {esc(fd.old_path)}' if fd.kind == "renamed" else "")
                + '</span>' if fd.kind != "modified" else "")
             + " " + fstat(fd)
             + (f' <span class="fnote">{esc(fd.note)}</span>' if fd.note else ""))
    if fd.binary:
        return f'<div class="file flat">{label} <span class="kind">binary</span></div>'
    if fd.generated:
        return f'<div class="file flat">{label} <span class="kind">generated/lockfile — diff omitted</span></div>'
    if fd.omitted or fd.adds + fd.dels > MAX_BODY_LINES:
        reason = fd.omitted or f"{fd.adds + fd.dels} changed lines — body omitted, run git diff locally"
        return f'<div class="file flat">{label} <span class="kind">{esc(reason)}</span></div>'
    if not fd.rows:
        return f'<div class="file flat">{label}</div>'
    rows = []
    for r in fd.rows:
        if r[0] == "hunk":
            rows.append(f'<tr class="hunk"><td colspan="3">{esc(r[1])}</td></tr>')
        else:
            cls, o, n, txt = r
            sign = {"add": "+", "del": "−", "ctx": " "}[cls]
            rows.append(f'<tr class="{cls}"><td class="ln">{o}</td>'
                        f'<td class="ln">{n}</td>'
                        f'<td class="c">{sign} {esc(txt)}</td></tr>')
    return (f'<details class="file"{" open" if open_default else ""}>'
            f'<summary>{label}</summary>'
            f'<div class="diff-wrap"><table class="diff">{"".join(rows)}</table></div>'
            f'</details>')


def render_files_table(files, note_only):
    rows = []
    for fd in files:
        rows.append(
            f'<tr><td>{prio_dot(fd.prio)}</td>'
            f'<td><code>{esc(fd.path)}</code></td>'
            f'<td>{fd.kind}</td>'
            f'<td class="num">{fstat(fd)}</td>'
            f'<td>{esc(fd.note)}</td></tr>')
    for path, (prio, note) in note_only:
        rows.append(f'<tr><td>{prio_dot(prio)}</td><td><code>{esc(path)}</code></td>'
                    f'<td></td><td class="num"></td><td>{esc(note)}</td></tr>')
    return ('<table class="files"><thead><tr><th></th><th>File</th><th>Change</th>'
            '<th>±</th><th>Note</th></tr></thead><tbody>'
            + "".join(rows) + "</tbody></table>")


def render_stats(files, commits, branch):
    adds = sum(f.adds for f in files)
    dels = sum(f.dels for f in files)
    tiles = [(str(len(files)), "files changed")]
    if adds or dels:
        tiles.append((f'+{adds} / −{dels}', "lines"))
    if branch:
        tiles.append((str(commits), "commits" if commits != 1 else "commit"))
        tiles.append((esc(branch), "branch"))
    return ('<div class="stats">'
            + "".join(f'<div class="stat"><div class="v">{v}</div>'
                      f'<div class="k">{k}</div></div>' for v, k in tiles)
            + "</div>")


def section(sid, heading, inner, extra=""):
    return (f'<section id="{sid}"><h2>{esc(heading)}{extra}</h2>{inner}</section>')


# ---------------------------------------------------------------- page shell

CSS = """
:root{
  --bg:#f7f7f5; --fg:#23231f; --muted:#71716a; --card:#ffffff; --border:#e4e4de;
  --accent:#3d6ea5; --code-bg:#f0f0ed;
  --add-bg:#e7f4ec; --add-fg:#186a33; --del-bg:#fbebe9; --del-fg:#b0392e;
  --hunk-bg:#eeeeeb; --hunk-fg:#71716a;
  --ok-bg:#e7f4ec; --ok-bd:#2c8a4b; --warn-bg:#fdf3dd; --warn-bd:#c08a1e;
  --part-bg:#fdeadd; --part-bd:#c2661e; --bad-bg:#fbebe9; --bad-bd:#b0392e;
}
@media (prefers-color-scheme: dark){:root{
  --bg:#1a1b1d; --fg:#e8e6e0; --muted:#99978e; --card:#222325; --border:#35362f;
  --accent:#82abd9; --code-bg:#2a2b2e;
  --add-bg:#18321f; --add-fg:#82c793; --del-bg:#3a201d; --del-fg:#e08a80;
  --hunk-bg:#27282b; --hunk-fg:#99978e;
  --ok-bg:#18321f; --ok-bd:#3f9e63; --warn-bg:#332a14; --warn-bd:#c9a04a;
  --part-bg:#37260f; --part-bd:#cf8146; --bad-bg:#3a201d; --bad-fg:#e08a80; --bad-bd:#c25a4e;
}}
:root[data-theme="light"]{
  --bg:#f7f7f5; --fg:#23231f; --muted:#71716a; --card:#ffffff; --border:#e4e4de;
  --accent:#3d6ea5; --code-bg:#f0f0ed;
  --add-bg:#e7f4ec; --add-fg:#186a33; --del-bg:#fbebe9; --del-fg:#b0392e;
  --hunk-bg:#eeeeeb; --hunk-fg:#71716a;
  --ok-bg:#e7f4ec; --ok-bd:#2c8a4b; --warn-bg:#fdf3dd; --warn-bd:#c08a1e;
  --part-bg:#fdeadd; --part-bd:#c2661e; --bad-bg:#fbebe9; --bad-bd:#b0392e;
}
:root[data-theme="dark"]{
  --bg:#1a1b1d; --fg:#e8e6e0; --muted:#99978e; --card:#222325; --border:#35362f;
  --accent:#82abd9; --code-bg:#2a2b2e;
  --add-bg:#18321f; --add-fg:#82c793; --del-bg:#3a201d; --del-fg:#e08a80;
  --hunk-bg:#27282b; --hunk-fg:#99978e;
  --ok-bg:#18321f; --ok-bd:#3f9e63; --warn-bg:#332a14; --warn-bd:#c9a04a;
  --part-bg:#37260f; --part-bd:#cf8146; --bad-bg:#3a201d; --bad-bd:#c25a4e;
}
body{background:var(--bg);color:var(--fg);
  font:15px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif;margin:0}
main{max-width:960px;margin:0 auto;padding:32px 20px 64px}
h1{font-size:1.5rem;margin:0 0 4px}
h2{font-size:1.05rem;margin:0 0 12px;letter-spacing:.01em}
section{margin:28px 0}
code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
  font-size:.86em;background:var(--code-bg);padding:1px 5px;border-radius:4px}
a{color:var(--accent)}
.muted{color:var(--muted)}
.banner{border:1px solid var(--border);border-left:4px solid var(--muted);
  background:var(--card);border-radius:8px;padding:14px 18px;margin:20px 0}
.banner.done{border-left-color:var(--ok-bd);background:var(--ok-bg)}
.banner.caveats{border-left-color:var(--warn-bd);background:var(--warn-bg)}
.banner.partial{border-left-color:var(--part-bd);background:var(--part-bg)}
.banner.blocked{border-left-color:var(--bad-bd);background:var(--bad-bg)}
.banner .verdict{font-weight:650;text-transform:uppercase;font-size:.78rem;
  letter-spacing:.06em;display:block;margin-bottom:2px}
.stats{display:flex;gap:12px;flex-wrap:wrap;margin:20px 0}
.stat{background:var(--card);border:1px solid var(--border);border-radius:8px;
  padding:10px 16px;min-width:96px}
.stat .v{font-weight:650;font-size:1.05rem}
.stat .k{color:var(--muted);font-size:.78rem}
.badge{display:inline-block;font-size:.72rem;font-weight:650;letter-spacing:.05em;
  padding:1px 8px;border-radius:10px;vertical-align:middle}
.badge.verified{background:var(--add-bg);color:var(--add-fg)}
.badge.unverified{background:var(--del-bg);color:var(--del-fg)}
.prio{display:inline-block;width:9px;height:9px;border-radius:50%;
  margin-right:7px;vertical-align:baseline}
.prio-red{background:#d64545}.prio-yellow{background:#d9a125}.prio-gray{background:#9a9a94}
table.files{width:100%;border-collapse:collapse;background:var(--card);
  border:1px solid var(--border);border-radius:8px;overflow:hidden;font-size:.9rem}
table.files th,table.files td{padding:6px 10px;text-align:left;
  border-bottom:1px solid var(--border)}
table.files th{color:var(--muted);font-size:.75rem;text-transform:uppercase;
  letter-spacing:.05em;font-weight:600}
table.files tr:last-child td{border-bottom:none}
td.num{white-space:nowrap}
.add{color:var(--add-fg)}.del{color:var(--del-fg)}
.file{margin:10px 0;border:1px solid var(--border);border-radius:8px;
  background:var(--card)}
.file.flat{padding:8px 14px;font-size:.9rem}
.file summary{padding:8px 14px;cursor:pointer;font-size:.9rem}
.file summary::-webkit-details-marker{margin-right:6px}
.fstat{margin-left:8px;font-size:.82rem}
.fnote{color:var(--muted);font-size:.85rem;margin-left:8px}
.kind{color:var(--muted);font-size:.8rem;margin-left:6px}
.diff-wrap{overflow-x:auto;border-top:1px solid var(--border)}
table.diff{border-collapse:collapse;width:100%;
  font:12.5px/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
table.diff td{padding:0 8px;white-space:pre}
table.diff td.ln{color:var(--muted);text-align:right;user-select:none;
  min-width:34px;font-size:11px}
table.diff tr.add td.c{background:var(--add-bg);color:var(--add-fg)}
table.diff tr.del td.c{background:var(--del-bg);color:var(--del-fg)}
table.diff tr.hunk td{background:var(--hunk-bg);color:var(--hunk-fg);
  padding:2px 8px;font-size:11px}
.flow{display:flex;align-items:stretch;gap:6px;flex-wrap:wrap;margin:12px 0}
.flow-node{border:1px solid var(--border);background:var(--card);padding:8px 14px;
  border-radius:8px;font-size:.88rem;display:flex;align-items:center}
.flow-node.hot{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent)}
.flow-arrow{display:flex;align-items:center;color:var(--muted)}
.flow-arrow::after{content:"\\2192"}
.flow-node.gone{border-style:dashed;color:var(--muted);text-decoration:line-through}
.ba{display:grid;grid-template-columns:1fr auto 1fr;gap:12px;align-items:stretch;
  margin:14px 0}
.ba-panel{border:1px solid var(--border);border-radius:10px;background:var(--card);
  padding:12px 14px;min-width:0}
.ba-label{font-size:.7rem;font-weight:700;letter-spacing:.08em;
  text-transform:uppercase;color:var(--muted);margin-bottom:8px}
.ba-panel.after .ba-label{color:var(--accent)}
.ba-panel.after{border-color:var(--accent)}
.ba-arrow{display:flex;align-items:center;color:var(--muted);font-size:1.3rem}
.ba-arrow::after{content:"\\2192"}
@media (max-width:640px){.ba{grid-template-columns:1fr}
  .ba-arrow{justify-content:center}.ba-arrow::after{content:"\\2193"}}
button.copy{font:inherit;font-size:.8rem;color:var(--accent);
  background:transparent;border:1px solid var(--accent);border-radius:6px;
  padding:2px 10px;cursor:pointer;margin-left:6px}
button.copy:hover{background:var(--code-bg)}
.checklist{list-style:none;padding:0}
.checklist li{margin:6px 0}
details.commits{margin:12px 0;font-size:.9rem}
details.commits summary{cursor:pointer;color:var(--muted)}
details.commits ul{margin:8px 0 0;padding-left:18px;list-style:none}
details.commits li{margin:3px 0}
footer{margin-top:48px;padding-top:14px;border-top:1px solid var(--border);
  color:var(--muted);font-size:.8rem}
svg text{fill:var(--fg)}
svg .box{fill:var(--card);stroke:var(--border)}
svg .box.hot{stroke:var(--accent);stroke-width:2}
svg .edge{stroke:var(--muted);fill:none}
"""

JS = """
document.addEventListener('click', function(e){
  var b = e.target.closest('[data-prompt]');
  if (b && navigator.clipboard){
    navigator.clipboard.writeText(b.getAttribute('data-prompt')).then(function(){
      var t = b.textContent; b.textContent = 'copied \\u2713';
      setTimeout(function(){ b.textContent = t; }, 1400);
    });
  }
  if (e.target.id === 'toggle-diffs'){
    var ds = document.querySelectorAll('#diff details');
    var anyClosed = Array.prototype.some.call(ds, function(d){ return !d.open; });
    ds.forEach(function(d){ d.open = anyClosed; });
  }
});
document.querySelectorAll('.checklist input[type=checkbox][id]').forEach(function(cb){
  var k = 'task-report:' + document.title + ':' + cb.id;
  cb.checked = localStorage.getItem(k) === '1';
  cb.addEventListener('change', function(){
    localStorage.setItem(k, cb.checked ? '1' : '0');
  });
});
"""


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--narrative", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--base", default="HEAD",
                    help="git baseline ref, or 'none' for no git data")
    ap.add_argument("--changed", nargs="*", default=[],
                    help="with --base none: files edited this session, embedded "
                         "as current-content snapshots (labeled unverified)")
    ap.add_argument("--title", default="Task report")
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()

    sections = parse_narrative(args.narrative)
    notes = parse_file_notes(sections.get("file-notes", ""))

    files, commits, branch, commit_lines = [], 0, "", []
    provenance = ""
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    if args.base != "none":
        head = git(args.repo, "rev-parse", "--short", "HEAD").strip()
        branch = git(args.repo, "rev-parse", "--abbrev-ref", "HEAD").strip()
        base_sha = git(args.repo, "rev-parse", "--short", args.base).strip()
        diff_text = git(args.repo, "diff", "-M", "--no-color", args.base)
        files = parse_diff(diff_text)
        untracked = git(args.repo, "ls-files", "--others",
                        "--exclude-standard").splitlines()
        files += untracked_filediffs(args.repo, untracked)
        commit_lines = []
        if base_sha != head:
            commit_lines = git(args.repo, "log", "--oneline",
                               f"{args.base}..HEAD").splitlines()
            commits = len(commit_lines)
        dirty = bool(git(args.repo, "status", "--porcelain").strip())
        provenance = (f'baseline <code>{esc(args.base)}</code> ({base_sha}) '
                      f'→ working tree at <code>{head}</code> on '
                      f'<code>{esc(branch)}</code> '
                      f'({"dirty" if dirty else "clean"} tree)')
    else:
        files = session_filediffs(args.repo, args.changed)
        provenance = ("no VCS baseline — file list from session memory (unverified)"
                      if files else
                      "no git baseline (research task or non-repo directory)")

    for fd in files:
        if fd.path in notes:
            fd.prio, fd.note = notes[fd.path]
    note_only = [(p, v) for p, v in notes.items()
                 if not any(f.path == p for f in files)]
    files.sort(key=lambda f: (PRIO_ORDER.get(f.prio, 2), -(f.adds + f.dels)))

    small = len(files) <= 8
    body = ['<main>', f'<h1>{esc(args.title)}</h1>',
            f'<div class="muted">{provenance} · generated {now}</div>',
            sections["banner"]]
    if files:
        body.append(render_stats(files, commits, branch))
    if commit_lines:
        shown = "".join(f"<li><code>{esc(l)}</code></li>" for l in commit_lines[:50])
        more = (f'<li class="muted">… {len(commit_lines) - 50} more</li>'
                if len(commit_lines) > 50 else "")
        body.append(f'<details class="commits"><summary>{len(commit_lines)} '
                    f'commit(s) since baseline</summary><ul>{shown}{more}</ul>'
                    f'</details>')
    body.append(section("summary", "What was asked & done", sections["summary"]))
    body.append(section("verification", "Verification", sections["verification"]))
    body.append(section("caveats", "Caveats, skipped & unsure", sections["caveats"]))
    if files or note_only:
        unverified_note = (
            '<div class="muted" style="margin-bottom:8px">File list from session '
            'memory — not verified against version control.</div>'
            if args.base == "none" and files else "")
        body.append(section("files", "Files changed",
                            unverified_note + render_files_table(files, note_only)))
    if "review-guide" in sections:
        body.append(section("review-guide", "How to review this",
                            sections["review-guide"]))
    if files:
        diff_html = "".join(
            render_file_diff(
                fd, small and (fd.adds + fd.dels or len(fd.rows)) <= OPEN_THRESHOLD)
            for fd in files)
        body.append(section(
            "diff", "Diff" if args.base != "none" else "Current file contents",
            diff_html,
            extra=' <button class="copy" id="toggle-diffs">expand / collapse all</button>'))
    for sid, heading in [("decisions", "Decisions & rationale"),
                         ("diagram", "How it fits together"),
                         ("before-after", "Before / after"),
                         ("followups", "Follow-ups")]:
        if sid in sections:
            body.append(section(sid, heading, sections[sid]))
    body.append('<footer>Generated by the task-report skill · '
                'content is hosted on claude.ai when published as an Artifact'
                '</footer></main>')

    page = (f"<title>{esc(args.title)}</title>\n<style>{CSS}</style>\n"
            + "\n".join(body)
            + f"\n<script>{JS}</script>\n")
    out = Path(args.out)
    out.write_text(page, encoding="utf-8")

    rendered = [s for s in REQUIRED_SECTIONS + OPTIONAL_SECTIONS if s in sections]
    print(f"wrote {out} ({len(page.encode())/1024:.0f} KiB)")
    print(f"sections: {', '.join(rendered)}")
    if files:
        omitted = sum(1 for f in files
                      if f.generated or f.binary or f.omitted
                      or f.adds + f.dels > MAX_BODY_LINES)
        if branch:
            print(f"files: {len(files)} rendered "
                  f"(+{sum(f.adds for f in files)}/−{sum(f.dels for f in files)}), "
                  f"{omitted} with diff body omitted, "
                  f"{commits} commit(s) since baseline")
        else:
            print(f"files: {len(files)} session-memory snapshot(s) rendered, "
                  f"{omitted} with body omitted")
    else:
        print("files: none (no-git mode or empty diff) — "
              "check --base if you expected changes")


if __name__ == "__main__":
    main()
