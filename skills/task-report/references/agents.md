---
name: task-report
description: Publish a completed task's debrief as a Codex.ai Artifact — outcome verdict, decisions made, verification evidence, review-priority file map, mechanically-rendered diffs, and copy-as-prompt follow-ups. Trigger on /task-report or when the user asks to summarize what you did, show what changed in this task/session, make a report/debrief/recap/handoff of the work, or review completed work — even phrased casually ("show me what you changed", "wrap this up as a report"). Do NOT use for a quick factual question about one file or change (answer in prose), for reviewing code for bugs (that's code review), or for plans awaiting approval (that's plan-to-artifact).
---

# task-report

The terminal shows the *process* — tool calls, drafts, dead ends in the order they happened. The operator reviewing finished work needs the *state*, ordered by their real question hierarchy: **did it work → what changed → should I trust it → what do I do next?** This skill renders that. It is a review instrument, not a diary: it exists so the operator can verify delegated work without replaying the session or reading a raw diff cold.

The content only you can produce is the conversation-derived layer: why decisions went one way, what was skipped, where you were uncertain, what to review first. Everything git can show is commodity — which is why the bundled script, not you, renders it. **The raw diff never passes through your context**: `scripts/build_report.py` runs git itself, converts the diff to HTML mechanically, and splices in the narrative sections you write. You spend tokens only on the ~1–2k-token narrative, so a 40-file report costs about what a 3-file one does, and the diff cannot be hallucinated, truncated, or flattered.

**Render, don't grade yourself kindly.** Every claim on the page must trace to something that mechanically happened: a command whose output you have, a diff the script rendered, a decision that occurred in this session. A polished page *increases* misplaced trust, so the honesty machinery outranks every presentation feature.

## Workflow

### 1. Pick the diff baseline — an explicit decision, not an assumption

"What changed during this task" has no single git answer. Decide first:

- Uncommitted work only → `--base HEAD` (the default).
- You made commits during the task → baseline is the parent of your first session commit (you know it from context); everything since, committed or not, is the task: `--base <that-sha>`. The diff covers committed and uncommitted work uniformly, and the page lists the commits since the baseline so the operator sees the commit boundaries too.
- Reporting on work committed before this session (or your memory of the commits was compacted) → reconstruct from `git log --oneline -15`: the task's commits are usually identifiable by message and timestamp. When it's ambiguous where the task starts, ask the operator which commits the report covers rather than guessing — an off-by-one baseline silently includes someone else's work in "what I did".
- On a feature branch and unsure → `git merge-base HEAD main` (or the trunk branch) is a reasonable fallback. Note it returns HEAD itself when you're *on* the trunk — an empty report there means the baseline is wrong, not that nothing changed.
- Research task that changed nothing → `--base none`; the report then has no diff/files sections and that's correct (a research report rendering "Files changed: 0" reads as broken).
- Not a git repo but code changed → `--base none --changed <the files you edited>`. There is no VCS baseline, so the script embeds *current-content snapshots* of the files you name — your own session memory is the file list, and the page labels it "not verified against version control". Never author a fake unified diff to compensate; instead put the key before→after hunks in the `before-after` section, quoting only text you actually saw in your Edit calls, and consider suggesting `git init` in followups so the next task has a real baseline.

In git mode, sanity-check before building: run `git diff --stat <base>` and eyeball it. A wrong baseline produces a confidently wrong report — empty, or blaming this task for someone else's changes.

### 2. Mine the conversation

This layer justifies the skill's existence; without a deliberate pass you will default to pretty-printing the diff and skip exactly this. Walk the session for:

- decisions made where a reasonable person could have chosen differently — with the alternative and why it lost (skip "I used a for loop"-grade choices)
- assumptions taken without the operator confirming them
- items explicitly skipped, deferred, or silently given up on
- dead ends attempted (one line each, only if instructive)
- the 1–3 spots you were least certain about — this becomes review priority
- follow-ups worth doing next

If earlier context was compacted, say so on the page ("earlier steps summarized — details unavailable") rather than reconstructing a tidy history from memory.

### 3. Assemble verification evidence

Prefer quoting output already captured in the transcript, labeled with when it ran ("pytest, captured 14:32 — 47 passed"). Re-run a command only if it is known-fast (under ~30s) and the code changed since it last ran. Never re-run an expensive suite to decorate a report.

The evidence-or-badge rule: a claim backed by real output links to it (see conventions below); a claim with nothing behind it gets `<span class="badge unverified">NOT VERIFIED</span>` — visibly, next to the claim. "Believed correct" and "verified by execution" must be impossible to confuse. If nothing was run at all, the banner says so.

### 4. Write the narrative file

Write `narrative.html` in the scratchpad: HTML fragments separated by `<!-- section: name -->` markers. Required sections — the script fails loudly if one is missing:

- `banner` — `<div class="banner done|caveats|partial|blocked"><span class="verdict">Done</span> one sentence: what was asked, what was delivered.</div>` The 3-second answer.
- `summary` — 1–3 bullets of what you understood the ask to be, including interpretation calls ("you said 'validation' — I took that as server-side only"). If you misread the task, the operator catches it here, not in the diff.
- `verification` — the evidence ledger: commands, output tails in `<pre>`, badges.
- `caveats` — skipped / deferred / unsure / behavior changes beyond the ask. May not be omitted; if genuinely empty, write "No known caveats" so absence is a statement, not an oversight.

Optional sections, included only when they have real content (empty ceremonial sections train the operator to skim):

- `file-notes` — plain lines, `path | red|yellow|gray | note`. Red = novel logic or you were uncertain; yellow = worth a glance; gray = mechanical. The script merges these into the files table and diff headers. Spend your self-knowledge here — it allocates the operator's scarcest resource, review attention.
- `review-guide` — an ordered reading path ("start with `auth.ts:42`, then the test; the rest is plumbing"). Include whenever more than ~3 files changed.
- `decisions` — decision / alternative / why, from step 2.
- `diagram` — see diagram rules below.
- `before-after` — old vs new behavior (CLI output, API response, error message) when the change is behavior-visible.
- `followups` — each with a copy-as-prompt button (below), ranked recommended vs nice-to-have. Never pad with "consider adding more tests".

Conventions the template supports:

- **Copy-as-prompt**: `<button class="copy" data-prompt="...">copy as prompt</button>`. The prompt must be self-executing for a fresh session — name the repo, file, and finding; don't reference "the report". Attach one to every follow-up and every caveat that implies action.
- **Claim-to-evidence links**: wrap claims as `<a href="#ev-tests">47 tests pass</a>` pointing at an `id`'d block in `verification`. No anchor to point at → the claim takes the unverified badge instead.
- **Checklists**: `<ul class="checklist"><li><label><input type="checkbox" id="ck-1"> …</label></li></ul>` — state persists in the viewer's browser across revisits. Use for genuinely operator-actionable items on larger tasks (verify on staging, set the env var), not ceremony.

### 5. Build and publish

```bash
python3 <skill-path>/scripts/build_report.py \
  --narrative <scratchpad>/narrative.html --out <scratchpad>/report-<slug>.html \
  --base <ref> --title "<short task title>" --repo <repo-root>
```

Read the script's stdout summary and sanity-check it (file count plausible? sections all there?). Then load the `artifact-design` skill per the Artifact tool contract — this skill owns the content and its ordering; the template already implements the aesthetics (theme-aware, self-contained), so don't redesign the page — and publish with the Artifact tool. Print the URL and stop: no prose recap after it (the page is the recap).

- **Identity**: file `report-<task-slug>.html`, favicon `🧾` always, title stable across republishes. One artifact per *task*, not per session. Before minting a new slug, check the scratchpad for an existing `report-*.html` for this task and reuse the path — same path = same URL. Pass a `label` per publish (`v1`, `v2-after-fixes`).
- **Cross-session updates**: scratchpad paths don't survive sessions; to update an earlier session's report, ask for its artifact URL and pass it as the Artifact tool's `url` parameter — otherwise you'll silently mint a duplicate.
- **Staleness**: more work on the same task after publishing → rebuild and republish with a bumped label before ending the turn. A report that says otherwise than the tree is worse than none.
- **Fallback ladder**: Artifact tool unavailable or publish fails → send the HTML via SendUserFile with `display: 'render'` → bare CLI, print the path. Local-HTML is also a *choosable* mode: publishing ships diff content to Codex.ai, so if the operator asks for a local/private report, skip the Artifact tool deliberately.

## Scaling and task-type shape

Report length scales logarithmically with change size, never linearly. The operator should be able to close the tab after the first screen and be *safe* (every risk was on it) — just not thorough.

- **Tiny fix (≤3 files)**: banner, two-line summary, verification, the diff (auto-expands), caveats. No review-guide, no diagram, no checklist — a half-screen report. A heavy page on a small fix taxes exactly the sessions where speed matters.
- **Bug fix**: lead the summary with the root cause — symptom → cause → fix in three sentences. Show the regression test verbatim in `verification` (it's short and it's the proof). Note blast radius in caveats: what else calls the changed path, could the same bug exist elsewhere.
- **Refactor**: the headline claim is behavior preservation — "tests pass before and after, zero test changes". Any *changed* test during a refactor is a red flag the operator must see, explained in caveats, never buried.
- **Migration / many files**: pattern, not instances — "applied X→Y in 38 files; one representative diff shown" (red-mark the representative, gray the rest via `file-notes`; the script keeps big files collapsed). The exceptions list — files that didn't fit the pattern and got hand-treatment — is 90% of what needs human review; it leads the review-guide. Include the completeness check ("grep for the old pattern: 0 remaining") in verification.
- **Research / nothing changed**: `--base none`. Answer first in the banner, evidence chain with `file:line` citations in summary/verification, what was searched vs. not searched in caveats, recommended action as a copy-as-prompt follow-up.

## Diagrams

Prefer no diagram over a bad diagram — a one-file fix diagrammed is decoration. Earn one when the change spans ≥3 modules or alters a call path, and diagram the **changed code's structure**, not a timeline of what you did (process is diary, not review material).

**The default diagram form is Before → After.** A change report is inherently comparative, so a single system snapshot makes the operator do the comparison in their head; draw the same structure twice instead and let the delta carry the story. The template provides the component:

```html
<div class="ba">
  <div class="ba-panel"><div class="ba-label">Before</div>
    <div class="flow"><div class="flow-node">handler</div><div class="flow-arrow"></div>
      <div class="flow-node gone">log_msg(level, text)</div></div>
  </div>
  <div class="ba-arrow"></div>
  <div class="ba-panel after"><div class="ba-label">After</div>
    <div class="flow"><div class="flow-node">handler</div><div class="flow-arrow"></div>
      <div class="flow-node hot">log(text, level=…)</div></div>
  </div>
</div>
<div class="muted">Every call site now passes text first; level is a keyword.</div>
```

Marking rules: `hot` = added or changed, `gone` = removed (dashed + struck through), unmarked = unchanged context — keep most nodes unmarked so the marked ones pop. Draw the *same* nodes in both panels wherever possible; the operator's eye diffs the panels, and that only works when the layouts correspond. Always close with one `muted` caption line saying what to notice — a diagram that needs no caption usually needed no diagram.

Panel contents by change type: call-path changes → flow strips (as above); structural refactors → module shapes; config changes → the old and new values as flow nodes. For genuinely branching graphs use inline SVG inside the panels (capped at ~15 nodes total; read `references/svg-patterns.md` first). No mermaid, no CDN anything.

A standalone (non-comparative) flow strip is still right when nothing existed before — a brand-new pipeline has no "before" worth drawing; don't fabricate an empty panel for it.

## What not to do

- No play-by-play of the session ("first I read X, then I grepped Y") — a *decision* log earns its place; an *action* timeline never does.
- No hand-transcribed diff content, ever — if the script can't render it, link to `git diff` locally rather than typing hunks yourself.
- No self-congratulation or prose that restates the diff ("then I added a function that…"). Every sentence must carry information the diff doesn't.
- No fabricated verification: no green banner for tests that ran before your last edit, no "passes" without output behind it.
- No bug-hunting or risk-scoring on the page — that's `/code-review`'s job; link the operator there if the change warrants it.
- No architecture tours of code you didn't touch. The operator knows their codebase.
