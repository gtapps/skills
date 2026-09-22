---
name: plan-pipeline
description: Claude Code only. Run the whole planning chain for a triaged issue or proposal (grilling, anchor grounding, optional plan-implementation, optional delegate-plan-review --verify, final-plan-check) and end in exactly one ExitPlanMode. Trigger on "/plan-pipeline", "plan this properly", "take it through the plan chain", "full plan pass". Runs inside plan mode. Do NOT use to critique an existing plan (final-plan-check), to verify reviewer findings (review-findings), or to execute a plan (delegate-ship, worktree-ship).
compatibility: Requires Claude Code as the host; Codex, Grok, and Copilot may be delegated executors.
---

# plan-pipeline

**One ExitPlanMode per feature. The operator's gate questions are pre-answered inside the plan, not asked after it.** This skill sequences the planning skills itself and asks for approval once.

## Procedure

**1. Print the goal, name the plan.** Print this line first so the operator can paste it:

    /goal The plan for <ISSUE> is ready for a single ExitPlanMode: the plan file is named <ISSUE>-<slug>.md; it contains a BEFORE/AFTER delta diagram, a worth-it ledger (tokens per wake, wakes per day, added files/hooks, overlap with CC native / OpenClaw / Hermes), a blast-radius section (released vs unreleased surfaces, downstream operators, downstream hermits), and an explicit core-vs-plugin decision; every harness-behavior premise cites a PROBE_VERDICT or is listed as unprobed; delegate-plan-review --verify and final-plan-check verdicts are quoted; no ExitPlanMode was called before those verdicts. Or this session has halted for the operator: its last message is a grilling question or a rejected-plan follow-up, with no operator reply yet. Or stop after 20 turns.

The goal evaluator is binary: a halt satisfies the goal and clears it, which keeps it from pushing past a question that belongs to the operator. So print this goal line again when grilling ends, before step 4, and at the end of every step 8 wait, so the operator can re-pin it.

If this session is not in plan mode, stop and say to enter it (`/plan` or the plan-mode toggle); this skill does not run outside it.

The harness owns the plan file path (the plan-mode reminder names it, under `~/.claude/plans/`) and resolves it from an in-session slug, so that file is never renamed while plan mode is active. Give it the issue name with a link instead:

    ln -s <harness plan path> ~/.claude/plans/<ISSUE>-<slug>.md

`<ISSUE>` is the issue number or proposal id as the operator gave it; `<slug>` is three to five words from the title. The `wrap` skill turns the link into the real name once plan mode is over.

**2. Grill.** Invoke the `grilling` skill as-is. It asks one question at a time; that is its contract, leave it.

**3. Your own questions.** Anything still open after grilling that the codebase cannot answer: batch 2 to 4 independent forks per AskUserQuestion, at most 5 calls in the whole pipeline. Explore the code before asking; most "questions" are lookups. A rejected question that carries text is an answer: process it, do not re-ask.

**4. Ground the anchors.** Launch a Plan agent to ground every anchor the plan needs (file plus symbol, with `path:line` citations). Its findings come back in its reply and go straight into the plan file's anchors. Grounding happens before the implementation plan is written, never after.

**5. Implementation handoff, when needed.** Invoke `plan-implementation` when the executor needs a self-contained handoff of settled decisions. It rewrites the plan file in place with per-step contracts, verify commands, the scope fence, and the before/after delta diagrams. Skip conversion when the existing plan and available context already suffice, regardless of executor model or tier. Preserve any plan sections required by the chosen execution workflow.

**6. Reviews.** Ask one AskUserQuestion: "External plan review before the final check?" with the harness as the options (codex, grok, copilot, claude) plus "no".
- A harness: invoke `delegate-plan-review <harness> --verify` (its findings are verified before they touch the plan), then `final-plan-check`.
- No: invoke `final-plan-check` only.

`final-plan-check` always runs. Quote both verdicts in the plan file under a `## Review trail` heading.

**7. Mandatory blocks.** Before exiting, check the plan file has all of:
- Worth-it ledger (what we gain, what we lose, the honest net; tokens per wake and wakes per day for anything unattended).
- Blast radius (released vs unreleased surfaces, downstream operators, downstream hermits).
- Where it lives (core vs plugin, or the project's equivalent boundary, as the project's CLAUDE.md defines it).
- Harness premises: every claim about Claude Code behavior the plan rests on, each citing a PROBE_VERDICT line or marked "unprobed".

A missing block is added now, from what the session already established; do not exit without it, and do not pad a block with guesses. An unprobed premise stays labeled unprobed.

**8. Exactly one ExitPlanMode.** Call it once. Then:
- Approved: go to step 9.
- Rejected with text: the text is an answer. Process it, edit the plan file, print what changed, and wait for the operator. Never call ExitPlanMode a second time without an operator reply in between. While a question is open, do not rewrite the plan beyond that answer.
- Never type a slash command into a rejection. This skill invokes the next skill itself; the rejection channel is for the operator's words only.

**9. On approval, print the next move** and stop:

    /delegate-ship <executor> ~/.claude/plans/<ISSUE>-<slug>.md

or, when Claude implements it itself:

    /worktree-ship

## Living gauntlet

Step 7 of `final-plan-check` owns the operator's gate questions and the `wrap` skill keeps it current. Do not duplicate or hardcode those questions here.

## Don't

- Don't call `grill-me`; it is operator-only. `grilling` is what it runs.
- Don't rename or move the harness plan file while plan mode is active.
- Don't skip `final-plan-check` because codex reviewed the plan; they check different things.
- Don't call ExitPlanMode before the review verdicts are in the plan file.
