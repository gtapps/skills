---
name: review-ship
description: "Codex, Grok CLI and Copilot CLI workflow for review-ship. Verifies finished work, commits it locally, has a separate reviewer CLI review it read-only, applies the confirmed findings through review-findings, re-verifies, and opens or updates the PR."
---

# Review Ship

The code is written and the user wants it reviewed and published in one move. The review runs in a separate reviewer CLI process, which starts with none of this session's context: the session that wrote the code reads it with the author's assumptions. The reviewer only reports. This session checks each finding against the code and applies the confirmed ones, so a reviewer can't push a change this session can't justify.

Arguments:
- `--reviewer claude|codex|grok|copilot`: the reviewer CLI. Default: this host's own CLI (codex on Codex, grok on Grok CLI, copilot on Copilot CLI), which is always installed. Name another one to get a review from a different model.
- `--model <m>`: passed to the reviewer CLI as given. Default: that CLI's own default.
- `--level <l>`: the `/code-review` level when the reviewer is claude (default `high`); other reviewers ignore it.

A calling skill (worktree-ship) may hand over its verification commands and the green run it just made. Use them as given.

## Prepare and verify

1. A dirty tree, or commits beyond the remote default branch, means there is something to ship. With neither, stop: there is nothing to ship.
2. Verification commands: the approved plan's `## Closing verification` block when one is in context, else the repository's own test and typecheck commands (AGENTS.md, else CLAUDE.md, manifest scripts or CI). If the repository documents none, say so and continue. Don't invent any.
3. Run them and keep each command with its exit code. A red command stops here, with its output shown. If the caller already ran them green on this exact tree, quote that run instead.

## Branch and commit locally

1. Read `<open-pr-skill-dir>/SKILL.md` and run only its Phase A: Prepare. It moves the work off the default branch before anything is committed and returns the base, comparison ref, branch and remote. Keep them for the review and publish steps. It runs after verification, so a red halt leaves no branch behind.
2. Read and follow `<commit-skill-dir>/SKILL.md` for the implementation, with its cleanup pass: the reviewer looks for correctness bugs only. Skip this when the tree is clean and the branch already holds the commits.
3. Record the commit the review starts from: `git rev-parse HEAD`.

## Review in a separate process

Run from the repository root, with `<dir>` a new temporary directory outside the repository:

    bash <review-ship-skill-dir>/scripts/review.sh <reviewer> <comparison-ref> <dir>/findings.md <dir>/review.log [--model <m>] [--level <l>]

- **Codex host:** request escalated permissions for this one command, with the justification that the reviewer CLI needs network access and writes its own state outside the workspace. Inside the sandbox every reviewer CLI fails. The automatic approver may refuse to send a private repository's diff to an external reviewer unless the user approved that in the request. If it refuses, stop and ask the user to approve sending the diff to the named reviewer.
- **Copilot host:** in `-p` mode Copilot reads only files under the working directory. If this skill's references or `scripts/review.sh` can't be read, stop and tell the user to launch Copilot with `--add-dir` for the installed skills directory (and the directory its links point to). Don't improvise the workflow without them.
- **Grok host:** the shell moves the command to the background after 15 seconds. Wait for that task's result with the tool the shell names. Never wait by sleeping or polling.
- **All hosts:** the review takes minutes. Wait for the single `REVIEW_DONE` line. A non-zero `exit=` means stop and show the last 30 lines of the log. `No findings.` means go straight to publishing.

## Apply the findings

Read and follow `<review-findings-skill-dir>/SKILL.md` on `<dir>/findings.md` in execution mode with "verify then fix". Apply Confirmed actions and the corrected part of Partial ones.

Then show `git diff --stat <review-start>` and re-run the verification commands.
- Red after the fixes: stop with the output and the diff. The user decides whether to keep or revert.
- Findings marked Needs investigation: list them numbered and stop. The user answers "1. agree 2. skip, because ...". Apply the agreed ones, re-verify, continue.
- A finding that reverses a contract in an approved plan (a step's behavior, a verify command, the scope fence): stop for an explicit yes, record the new contract in the plan file, then continue.

## Publish

1. If the fixes changed files, commit them through the commit skill, skipping its cleanup pass: the implementation commit already had one.
2. Immediately before any push, run the repository's documented pre-push gate if it has one (a release lock, a migration, schema or changelog check). A hold means report what the gate said and don't push. Never bypass or remove a gate.
3. Resume the open-pr skill at Phase C with the context from Phase A. It pushes, and it creates the PR or returns the one that already exists. The PR body names the reviewer CLI and model, and lists the findings with their verdicts.

## Report

Lead with the PR URL. Then the verification results before and after the review, the reviewer and model, the review's diff stat, and each finding with its verdict. Pass through any follow-up lines the open-pr skill prints, unchanged.

## Guardrails

- Never review the diff in this session in place of the reviewer CLI.
- Never force-push, amend, rewrite history, or merge the PR.
- Never claim a check passed without running it.
