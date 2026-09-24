---
name: delta-diagrams
description: "Show behavioral before/after changes and real decision branches in operator-facing diagrams. Excludes data charts and raw code diffs."
---

# delta-diagrams

**The operator reads diagrams to answer one question: what changed, behaviorally?** Draw the decision, not the code. A diagram that lists files or diffs has failed, GitHub already renders those. Your job is the functionality delta and, when the plan iterated, which branch won and why.

## Host compatibility

Use the same workflow in Claude Code, Codex, Grok CLI, and Copilot CLI. Inline diagrams need only Markdown output; pages need file-writing tools. Resolve `assets/` relative to this skill's installed directory, not the working directory.

For a page, load the installed `artifact-design` skill using the host's skill loader or read its `SKILL.md` directly. If it is unavailable, report the missing dependency; inline diagrams remain usable. Publishing requires an available publishing tool and a user request to publish. Use that tool's actual parameters; otherwise write a local HTML file and return its path. Do not assume that an Artifact tool exists in every host.

## Default form

An ASCII decision-tree in a fenced code block. Not mermaid, not an image, unless the operator explicitly asks for one. ASCII renders everywhere the operator works (terminal, PR, issue, artifact) and diffs cleanly.

## The two shapes

**No iterations, a straight before/after.** Use when the plan had no branching decisions:

```
plan ──> BEFORE: <behavior today> ──> AFTER: <behavior after the change>
```

**With iterations, a decision tree.** Use when the session explored options (a question, competing answers, a chosen path). Show *every* considered branch, its functional consequence, and mark the one that was selected:

```
plan ─> question 1 ─┬─> answer A ─> functionality delta A   ◀ SELECTED
                    └─> answer B ─> functionality delta B
```

Chain multiple decision points left-to-right when the plan had several:

```
plan ─> Q1 ─┬─ A ─> delta A  ◀ SELECTED ─> Q2 ─┬─ C ─> delta C  ◀ SELECTED
            └─ B ─> delta B                     └─ D ─> delta D
```

## Rules

- **Deltas describe behavior**, never diffs or filenames. Write "watchdog now compacts at 150k tokens", not "edited hermit-watchdog.ts:517".
- **One diagram per decision point.** Don't cram unrelated decisions into one tree.
- **End-of-task reports get one end-to-end before/after flow** summarizing the net behavioral change, even if the body has per-decision trees.
- Mark the selected branch with `◀ SELECTED` (or `◀ CHOSEN`). Rejected branches stay in the diagram, the operator wants to see what was weighed, not just the winner.
- Keep it scannable: if a tree needs more than ~12 lines, split it into two decision points.

## ASCII inline, or a rendered Artifact?

This is the one rule the other skills defer to, decide here, don't re-decide per skill.

**Stay ASCII inline** (the default) for a single decision tree or before/after flow read in the terminal or a PR. It diffs cleanly, needs no round-trip, and is what the operator is already looking at.

**Graduate to a rendered Artifact** only when the output is genuinely a *page*, not a block:
- a **dashboard** or status board (many rows, state that reads at a glance), e.g. `fleet-sitrep`;
- a **comparison** the operator will re-read or share, e.g. `repo-teardown`;
- a **multi-decision map** too large or too visual for clean ASCII.

Never put a raw diff in an Artifact, GitHub renders diffs better and it adds no value. Artifacts carry synthesis, status, and decisions; the diff stays a link.

**Inside a page that has already graduated** (a rendered Artifact or HTML report), the before/after flow renders as a *visual* panel, styled lanes of flow nodes with semantic color (before = costly, after = improved, keeps = muted), closed by a short KPI row, never as an ASCII block; ASCII prose inside a rendered page wastes the medium and buries the one thing a human absorbs fastest. Decision trees may stay ASCII there (aligned monospace shows parallel branches best); only the behavior delta graduates.

## Artifact guardrails (when you do graduate)

Load the `artifact-design` skill before writing the page, then honor the output runtime. A local HTML file is sufficient when publishing was not requested. The bundled [HTML template](assets/delta-diagram-template.html) is available for a standalone page. Replace its placeholders with real content, repeat flow nodes as needed, and omit KPI claims that lack evidence:

- **Self-contained.** A strict CSP blocks every external host, no CDN scripts, webfont URLs, remote images, or fetch/XHR. Inline all CSS/JS; embed assets and fonts as `data:` URIs.
- **Theme-aware.** Define the palette as CSS custom properties on `:root`; redefine the tokens under `@media (prefers-color-scheme: dark)` and again under `:root[data-theme="dark"]` / `:root[data-theme="light"]` so the viewer's toggle wins both directions. Style through the tokens, never inside the media query.
- **Responsive.** Relative units, flex/grid; `max-width:100%` on images; wide content (tables, diagrams) scrolls inside its own `overflow-x:auto` container so the page body never scrolls sideways. Use `tabular-nums` for aligned columns.
- **Favicon + title stay stable across updates.** Keep the HTML favicon and `<title>` constant; when publishing, use favicon metadata only if the tool supports it.
- **Update the same deliverable** when the view repeats (a loop tick, an updated report): reuse the local file path, or the existing deployment when the publishing tool supports updates. Preserve its URL where supported.
- **State reads at a glance:** encode severity in form (a pill, a chip, a colored stripe), not just text; put the summary above the detail. Semantic good/warning/critical color is separate from any accent hue.
