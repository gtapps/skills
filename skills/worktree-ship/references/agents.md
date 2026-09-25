---
name: worktree-ship
description: "Implement an approved plan in a Git worktree, verify it, and publish a reviewed pull request through review-ship, using Codex, Grok CLI, or Copilot CLI."
---

# Worktree Ship

Treat the approved plan as the contract. Execute it without re-litigating scope. Stop only for an unfixable failure, a required scope change, or a user decision that materially changes the result.

## Preconditions

1. Confirm execution is permitted. If the session is still constrained to Plan Mode or the plan is not approved, do not mutate anything; report the blocker.
   Use the approved plan supplied in context or by explicit path. Do not infer approval from the newest file in a harness's plans directory.
2. Confirm the current directory is a Git repository and inspect the branch, status, remotes, and worktrees.
3. Read repository guidance in AGENTS.md and honor other instructions loaded by the running harness. If AGENTS.md is absent, use a repository CLAUDE.md as compatibility guidance.
4. If the originating checkout has changes whose relationship to the approved plan is unclear, stop and ask. A new worktree starts from a commit and will not inherit uncommitted changes.

## Create the worktree

With `--no-worktree`, skip this section and implement in the current checkout: review-ship creates the branch before anything is committed. Stop and ask first if the checkout is on a branch other than the default one that isn't this task's branch.

Honor an explicit repository worktree convention first. Otherwise:

- Derive the branch from repository conventions and the task: feat/<issue>-<slug>, fix/<issue>-<slug>, or chore/<slug>.
- Inspect git worktree list and local branches before creating anything. Resume a matching worktree only after checking its branch, base, status, and relationship to the approved plan. Do not reset a mismatched or independently modified worktree to make it fit.
- Create the sibling <repo>-worktrees parent when needed and use <branch-with-slashes-replaced-by-dashes> as the worktree directory.
- Create a new branch from the intended base with git worktree add -b. If the branch already exists without a worktree, attach it with git worktree add and do not recreate it.
- Resolve the worktree's absolute path. Perform every implementation and verification command with that worktree as the working directory, and target file tools with paths inside it. Creating a Git worktree or running `cd` in one shell does not switch the harness's session context or grant file access. Use a native session switch only if the current harness actually exposes one; do not call Claude's `EnterWorktree` from another CLI.
- Read the worktree's repository instructions before implementing. If the current session cannot access it, resolve that concrete access restriction before editing.

Never edit files in the originating checkout after entering the worktree. Do not remove the worktree at the end; it may be needed for review fixes.

## Implement and verify

1. Follow the approved plan exactly. Do not add adjacent cleanup or speculative abstractions.
2. Inspect only the relevant regions of large files. Preserve user changes and repository style.
3. Run the verification commands named in the plan. Otherwise derive them from AGENTS.md, package scripts, build files, and CI configuration.
4. Do not proceed to commit while a relevant check is red. Fix and rerun it, or report the genuine blocker.

## Publish

1. Read and follow <review-ship-skill-dir>/SKILL.md from inside the worktree, passing through `--reviewer`, `--model` and `--level` when the user gave them, and the verification run above. It commits, has a separate reviewer CLI review the change, applies the confirmed findings, re-verifies, runs the publishing gates, and opens the PR. When it stops for the user (red verification, unsettled findings, a plan-contract question), this skill stops with it.
2. Read and follow <delta-diagrams-skill-dir>/SKILL.md to render one end-to-end behavioral before/after.
3. Report:
   - PR URL, title, and base branch.
   - Absolute worktree path and head branch.
   - Exact verification commands and exit results, before and after the review.
   - The reviewer and model, and each finding with its verdict.
   - The diagram.

## Guardrails

- Never push while a repository publishing gate says hold.
- Never force-push, rewrite history, or merge the PR.
- Never work outside the created worktree.
- Never claim a check passed without running it.
