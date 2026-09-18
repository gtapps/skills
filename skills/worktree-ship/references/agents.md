---
name: worktree-ship
description: "Implement an approved plan in a Git worktree, verify it, and publish a pull request using Codex, Grok CLI, or Copilot CLI."
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

## Repository publishing gates

Immediately before publishing, run the repository's documented pre-push gates, including any release lock, migration check, or schema check. Use the repository's actual command and configuration; do not substitute a remembered project-specific path.

Honor a failing gate, report its evidence, and do not publish or remove a lock to proceed. If no publishing gate is documented, do not invent one.

## Publish and hand off

1. Read and follow <commit-open-pr-skill-dir>/SKILL.md from inside the worktree.
2. By default, hand off at the open PR for independent review. If the user also authorized review resolution, complete that scope using an independent reviewer; do not treat self-review as independent.
3. Read and follow <delta-diagrams-skill-dir>/SKILL.md to render one end-to-end behavioral before/after.
4. Report:
   - PR URL, title, and base branch.
   - Absolute worktree path and head branch.
   - Exact verification commands and exit results.
   - The diagram.
   - A handoff to a fresh review context in the chosen harness: review PR <URL> using the existing worktree at <absolute-worktree-path>, against <base-branch>.
   - Give a native review command only after checking it is available in that CLI. Distinguish a local review result from a review actually submitted to GitHub.

## Guardrails

- Never push while a repository publishing gate says hold.
- Never force-push, rewrite history, or merge the PR.
- Never work outside the created worktree.
- Never claim a check passed without running it.
