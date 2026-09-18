---
name: open-pr
description: "Publish current work as a GitHub pull request, preparing the branch and committing intended changes when needed. Excludes merging and review."
---

# Open PR

Use three reusable phases. Another skill may call Prepare, then perform its own commit step, then resume at Publish.

## Phase A: Prepare

Run and inspect:

    git rev-parse --is-inside-work-tree
    gh auth status
    git status --short --branch
    git remote -v

Stop if this is not a Git repository, gh is missing or unauthenticated, or no GitHub remote exists. Ask before publishing to an unexpected fork or upstream.

Determine:

- Remote default branch from gh repo view --json defaultBranchRef. Fall back to the symbolic origin/HEAD ref when GitHub cannot answer.
- Base branch from the user's request or the remote default.
- Comparison base as origin/<base> when that ref exists; do not rely on a locally advanced base branch.
- Existing repository branch conventions from the loaded project instructions and `git branch` output.

If currently on the base branch, create a feature branch before any commit. Preserve the working tree while switching. Use a short conventional branch such as fix/login-redirect or feat/csv-export. If already on a feature branch, stay there.

Return the prepared base, comparison ref, branch, remote, and repository identity to the caller.

## Phase B: Ensure a commit

If the worktree is dirty, invoke the available `commit` skill. If it is clean, continue only when the branch contains commits beyond the comparison base.

Verify:

    git log --oneline <comparison-base>..HEAD

An empty range means there is nothing to publish. Stop rather than inventing a commit.

## Phase C: Publish

1. Push without rewriting history:

       git push -u origin HEAD

   Inspect a rejection. Reconcile remote changes within the authorized scope, rerun affected checks, and retry. Never force-push unless the user separately authorizes it.

2. Inspect the complete PR change:

       git log --oneline <comparison-base>..HEAD
       git diff --stat <comparison-base>...HEAD
       git diff <comparison-base>...HEAD

3. Compose a Conventional-Commits title: type(scope): imperative summary. Reuse a compliant single-commit subject when appropriate.
4. Fill the first repository PR template found in .github, docs, or the repository root. Remove boilerplate prompts and irrelevant empty sections. Without a template, explain the problem, resulting behavior, and validation, with detail proportional to the change.
5. State tests honestly. Add Closes #N only for a known issue.
6. When the change has a real behavioral before/after, or the plan weighed and picked between options, read the available `delta-diagrams` skill and include its ASCII before/after or decision-tree in the body. Skip this for trivial/mechanical changes.
7. Write the body to a temporary Markdown file using the file-editing tool; use gh pr create --body-file so Markdown survives intact.
8. Check for an existing PR before creating another:

       gh pr list --head <branch> --json number,url,title

   If one exists, return its URL without recreating it.
9. Create against the selected base. Create a draft only when the user asks for one; otherwise create a ready-for-review PR.
10. Report URL, title, head branch, base branch, and actual validation. In Claude Code, also read [the review handoff](references/claude-code.md) and print its follow-up commands.

## Guardrails

- Do not stage unrelated work; delegate dirty-tree commits to the commit skill.
- Do not amend, rewrite history, fabricate tests, or invent issue numbers.
- Do not open an empty PR.
- Do not open or push to an unexpected repository without confirmation.
