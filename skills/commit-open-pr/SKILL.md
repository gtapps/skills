---
name: commit-open-pr
description: "Commit the intended changes and open a GitHub pull request. Use commit for commit-only requests and open-pr for existing commits."
---

# Commit and Open PR

Orchestrate the sibling commit and open-pr skills without duplicating their logic.

## Sequence

1. Read the available `open-pr` skill.
2. Execute only its Phase A: Prepare. This must move work off the default branch before committing. Preserve the returned base, comparison ref, branch, remote, and repository identity.
3. Inspect the prepared worktree and comparison range. If the tree is clean and the branch already contains commits beyond the comparison base, treat the commit step as already done and continue without creating an empty commit.
4. Otherwise, invoke the available `commit` skill.
   - If the user passed `--no-simplify`, carry that through so commit skips its simplify pass.
   - If it needs a staging decision or a hook fails, resolve that step before continuing.
   - Do not publish without a successful commit.
5. Resume open-pr at Phase C: Publish using the preserved context.
6. Return the commit subject and PR URL, title, head branch, and base branch. Preserve any follow-up commands printed by the active harness's `open-pr` handoff.

## Why branch first

Committing on a local default branch before creating the feature branch advances that default branch and can make a local base comparison appear empty. Preparing the branch first keeps the default branch untouched and makes the remote comparison unambiguous.

## Guardrails

- Do not call open-pr Phase B after the explicit commit; that would duplicate work.
- Do not implement git commit or gh pr create independently of the sibling skills.
- Do not continue past a failed commit, failed push, unexpected remote, or empty PR range.
