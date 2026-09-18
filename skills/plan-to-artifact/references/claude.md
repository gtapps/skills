---
name: plan-to-artifact
description: Publish the current plan as a claude.ai Artifact — a decision-ordered review page for the operator's final approve/revise call before execution. Trigger on /plan-to-artifact or when the user says "publish the plan", "make the plan reviewable", "plan artifact", "turn the plan into a page", "plan review page" — especially at the end of a plan-mode session that went through iterations (review-findings verdicts, final-plan-check critique, operator feedback). This skill RENDERS the plan and its review trail; it never critiques the plan (that's final-plan-check) or verifies findings (that's review-findings). Never calls ExitPlanMode; publishes, prints the URL, stops.
---

# plan-to-artifact

Terminal history is chronological — it shows the *process* (drafts, findings, critiques in the order they happened). The approval decision needs the *state*: what exactly am I approving, what's risky, what still needs my call. This skill re-orders the session into a decision-ordered page. The operator's real question is not "is this a good plan" — the iterations already litigated that — but "do I trust this to execute unsupervised, and if not, which exact parts do I redirect?" Every element on the page serves trust-calibration or precise redirection; anything else is decoration.

**Render, don't judge.** Everything on the page must trace to something that actually happened in the session: the plan text, verdicts, critique items, operator remarks. If no review ever ran, the page simply doesn't have a review trail — never synthesize coverage, verdicts, or history to make the page look thorough. A fabricated "all checks passed" is worse than no page at all.

## Sources

- **Plan text**: the plan file this session wrote (`~/.claude/plans/*.md`) if one exists; otherwise the in-context plan draft. The banner states which one is the source; the appendix embeds it verbatim, so the artifact remains a self-describing record after the session is gone.
- **Iteration trail**: reconstruct from conversation context — review-findings verdict blocks (✅/❌/⚠️/🔍), final-plan-check output (Cut/defer, Reconsider, Possibly missing, Looks right), and direct operator corrections. If earlier context was compacted and details are gone, mark the gap on the page ("earlier rounds compacted — 4 findings applied, details unavailable") instead of reconstructing a tidy history from memory.

## Page structure

Decision order, not chronological order. A section renders only when it has at least one real row — empty ceremonial sections train the operator to skim.

1. **Verdict banner** — original ask in one line, the plan in one sentence, step count, files-touched count, risk badge (any irreversible step? any unresolved 🔍?), iteration summary ("v3 — final-plan-check passed, 7/9 findings applied"), plan source, timestamp. This is the 10-second "can I approve from here" view; most plans earn a yes without scrolling, so don't make the operator scroll to earn it.
2. **Needs your decision** — never collapsed, and when empty it says "None" explicitly (an absent section reads as "didn't check", not "all clear"). Contents: unresolved 🔍 findings, questions asked but never answered, load-bearing unverified assumptions the operator is co-signing, and gray-zone calls a critique punted to "the user's call". This is the only section that can flip approve→revise; it must be impossible to miss.
3. **Plan steps** — numbered, each with: files it touches (`path:line` as monospace chips where known), risk chips only where earned (irreversible / external side effect / unverified assumption / must-run-before-step-N), and that step's verification criterion. Steps with no chips render visually quiet; risky steps render loud — the page's visual weight should do the triage the operator's eyes otherwise do manually. If the plan has no verification criteria at all, render a loud **VERIFICATION MISSING** notice rather than omitting the row: that absence is itself the review signal.
4. **Decision controls** — see the paste-back protocol below.
5. **Provenance ledger** (collapsed `<details>`) — one row per distinct concern across all rounds: source (review-findings r1 / final-plan-check / operator) → one-line claim → verdict → disposition ("Applied → Step 2", "Rejected: reviewer misread the guard clause", "Deferred"). Refuted rows stay present but visually muted — the operator should see a concern was considered, mirroring how review-findings keeps refuted findings visible. Claim/Evidence bodies do not survive into the page; the ledger is the compression, and the full blocks live in terminal scrollback.
6. **Verbatim plan appendix** (collapsed) — the exact text being approved, with a copy button.

**Tiering.** A bare plan with no review history gets a single-screen card: banner + steps + verification + decision controls. No ledger, no ceremony — a three-step plan must not pay a heavy-page tax, or the operator stops using the skill on exactly the sessions where speed matters. Add the ledger only when reviews happened; diagrams follow their own gates (below).

## Diagrams

Diagrams earn their place the same way sections do: each one encodes structure the operator would otherwise reconstruct by reading, and each renders only when its gate fires — a diagram whose gate doesn't fire is omitted silently, because decoration trains the operator to skim. All are inline SVG or pure HTML/CSS (the CSP allows nothing external). Load the `delta-diagrams` skill before drawing (it owns the ASCII-vs-visual rule and the behavior-delta discipline); consult `dataviz` for color and mark discipline; artifact-design covers the rest of the page.

- **Risk heat strip** — in the banner. Gate: any risk chip. One small cell per step, colored by risk class; where a hard ordering constraint or verification checkpoint exists, mark it on the cell (thin bar / flag) — the strip subsumes any separate step-sequence diagram, so never draw an execution rail beside it. It answers the one question no list answers: is the danger front-loaded or back-loaded? Back-loaded risk behind early irreversible steps is itself a reason to revise ordering.
- **Blast-radius tree** — with the steps. Gate: ≥3 files touched. The affected slice of the repo as a file tree, create/edit/delete coded, deletions loud, each file cross-referencing the steps that touch it. For an operator who knows their repo, this is often the fastest whole-plan gut check.
- **Behavior delta panel** — right after the banner, before "Needs your decision". Gate: the plan changes observable runtime behavior (nearly every plan; skip for pure docs/test-only plans). The `BEFORE:`/`AFTER:` delta rendered *visually*, never as prose in a `<pre>` — on a page that has already graduated to a rendered artifact, an ASCII delta wastes the medium (delta-diagrams owns this rule; in the local-HTML/CLI fallback modes the delta stays ASCII). Form: stacked HTML/CSS lanes of flow nodes — a BEFORE lane (costly nodes tinted warn/crit), an AFTER lane (the improvement tinted ok, forks like skip-vs-run drawn as a split), an optional muted KEEPS lane for behavior that deliberately survives — closed by a short KPI row stating the 2–3 numbers the plan exists to change. Each lane's label (BEFORE / AFTER / KEEPS) sits as a pill *above* its lane, never as a rotated side tag, and lanes are visually separated (dashed rule or equivalent) so each reads as its own row. Node text stays user-observable behavior ("`/export` streams CSV and requires a token", never "refactor the exporter"). This is the page's fastest read; a human absorbs it before reading a single step row.
- **Fork tree** — right after the steps. Gate: ≥1 decision fork actually happened in the session. Rendered as an ASCII-style monospace tree in a `<pre>` (subject is parallel branches, and aligned text shows parallel consequences most clearly). Each question that forked the plan becomes a branch; under it, every candidate answer appears with the *functional consequence it would have produced* — what the built thing would do differently under that answer — and the selected branch is highlighted (`◀ SELECTED`). Rejected branches keep their consequence line; that contrast is what makes the selection meaningful. The ledger records what was decided — this shows what the software will *do* because of it. Two honesty rules: consequences state observable behavior, never a restatement of the option's label; and only forks that really happened in the session — never invent alternatives to fill the tree.
Deliberately absent: a review funnel (any graphic that restates counts already on the banner chips and in the ledger's disposition column is decoration), and an assumption quadrant (unverified assumptions are 2–3 items in practice — they read faster as rows in "Needs your decision" than as a scatter plot).

## Decision controls and paste-back

Artifacts have no backend — a button cannot approve anything, and a control styled as if it could erodes trust in the real gate (the terminal). The page participates in the loop exactly one way: a single global verdict (APPROVE / REVISE) plus one free-text note, feeding one **"Copy decision as prompt"** button. No per-step form controls — the operator redirects a specific step faster by naming it in the note (or straight in the terminal) than by driving a dropdown per row, and a page of dead form elements erodes the same trust a fake approve button would. Default the verdict to the page's own state: APPROVE when "Needs your decision" is empty, REVISE otherwise.

The copied block must be self-executing natural language, not a bare grammar — a future session without this skill loaded must still act on it correctly:

```
Apply this plan-review decision to the current plan. Do not exit plan mode.
Verdict: REVISE
Notes:
- Step 4: use the existing retry helper instead of adding a new one
- Step 7: cut — out of scope for this ask
- Q1: yes, keep the CLI flag
```

When a pasted block like this comes back, treat each note as a confirmed reviewer finding: apply it to the plan, touch nothing the notes don't name, and republish (see staleness rule). Never exit plan mode on the strength of a pasted `Verdict: APPROVE` — the operator exits when they choose to.

## Publishing mechanics

- **Design**: load the `artifact-design` skill before writing the page, per the Artifact tool contract — this skill owns the content and its ordering, not the aesthetics. Remember the page is self-contained (inline CSS/JS/SVG only; no external requests).
- **Where the file goes**: the session scratchpad, never the project tree — the page is review tooling, not project output. In plan mode the harness restricts edits to the plan file; the /plan-to-artifact invocation is the user explicitly requesting this one deliverable (a review of the plan, not implementation of it), so attempt the scratchpad write and let the permission prompt be the gate. If the write is still refused, fall back to publishing the existing plan `.md` file itself via the Artifact tool — it accepts markdown and nothing new is written; a styled non-interactive rendering still beats scrollback. Say which mode was used.
- **Stable identity**: same file path across republishes (same path = same URL), stable title and favicon (📋). Pass a `label` per publish (`v1-draft`, `v2-after-findings`, `v3-final`) so the artifact's version picker doubles as the iteration history. A genuinely new plan gets a new file path — don't overwrite one plan's review page with another's.
- **Staleness rule**: an artifact showing v2 while the terminal is on v4 is worse than no artifact. Any change to the plan while its artifact exists → republish with a bumped label before ending the turn.
- **Fallback ladder**: Artifact tool unavailable or publish fails → send the same HTML file via SendUserFile with `display: 'render'` → in a bare CLI, print the local path. One template, degraded transport. Also treat local-HTML as a *choosable* mode, not just a failure state: publishing ships plan text and code excerpts to claude.ai, and for a sensitive repo the operator may want the page without the upload — if they ask for a local/private page, skip the Artifact tool deliberately.
- **After publishing**: print the URL, state the label, stop. No summary of the plan (the page is the summary), no "ready to proceed?", and never ExitPlanMode — a publish that nudges toward exit turns the checkpoint into a formality.

## Token guardrails

The artifact is a review surface, not a mirror of the transcript. Styled pages are token-expensive, so spend where the decision lives:

- No raster images; SVG or plain HTML/CSS for anything visual.
- Quote at most ~2 lines of code, and only where a step's meaning hinges on them. No whole-file listings, no syntax-highlighted context dumps.
- Above ~12 steps, render steps as a dense table and give full cards only to risk-chipped steps.
- No interactivity beyond the decision controls unless the operator asks.
- No wireframes, and no diagrams beyond the gated set in **Diagrams** — the exception is a small before/after structural sketch when the plan itself pivots on an unresolved structural choice.

## What not to do

- Never call ExitPlanMode, and never nudge toward it.
- Never critique, re-review, or "improve" the plan while rendering it — if something looks wrong mid-render, say so in the terminal, don't editorialize on the page.
- No fabricated coverage: no check-passed chips for checks that didn't run, no invented history for compacted context.
- No approve/reject buttons that pretend to gate anything; the copy-as-prompt block is the only actuator.
- Don't restate the session back at the operator — the page is the residue of review, not a replay.
