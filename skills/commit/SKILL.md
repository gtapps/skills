---
name: commit
description: "Create a Git commit from the intended changes, with the simplify cleanup gate and precise staging. Does not push."
---

# Commit

Create one deliberate commit without sweeping in unrelated user work.

## Establish scope

Resolve the repository root with `git rev-parse --show-toplevel` and run Git operations there. In Claude Code, use a separate Bash call to `cd` to the returned literal path; its worktree checker rejects Git command substitutions.

Inspect `git status --short` and `git diff --staged --stat`.

- If changes are staged, respect that exact staged scope.
- If nothing is staged and this session created or edited known paths, exclude secrets and scratch files, then stage only the intended paths with `git add -- <paths>`.
- If nothing is staged and session ownership is unclear, show modified and untracked paths and ask what belongs. Do not guess.
- Never use git add ., git add -A, or git add -u.

Before cleanup, record staged files that also have unstaged changes. Inspect the staged path list for secret-shaped files such as .env, credentials files, private keys, PEM files, tokens, or generated secret material. If any are staged, stop and flag paths without printing secret contents.

## Simplify the staged diff

Unless the user passed `--no-simplify` or explicitly requested skipping cleanup for a trivial typo, documentation, or comment-only commit:

1. Invoke the available `simplify` skill with mode set to staged-only.
2. Surface its concise report.
3. Re-stage each file simplify changed only when that file had no pre-existing unstaged changes.
4. If a changed file already had unstaged work, stop. A whole-file git add would mix unrelated hunks; let the user stage the cleanup interactively or authorize the whole file.

If simplify made no edits, continue.

## Commit

1. Show git diff --staged --stat.
2. Inspect git diff --staged and git log -5 --oneline to understand intent and local message style.
3. Draft a concise message focused on why the change exists. Use Conventional Commits only when the repository does.
4. Run `git commit -m` with the selected message. Existing commit authorization covers choosing the message; do not ask for another confirmation.
5. If a hook fails, fix the cause, re-stage only intended paths, and create a new commit attempt. Never bypass the hook or amend a previous commit.
6. Run git status and report the commit identifier, subject, and outstanding changes.

## Guardrails

- Never push unless the user separately asks.
- Never amend, use --no-verify, disable signing, or add AI attribution trailers unless requested.
- Never claim cleanup or checks ran when they did not.

