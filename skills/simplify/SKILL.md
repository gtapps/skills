---
name: simplify
description: "Review and apply behavior-preserving cleanup to the recent or staged diff. Excludes feature redesign."
---

# Simplify

Preserve behavior, prefer clarity over brevity, and follow repository conventions. Treat behavior-changing ideas as rejected proposals, not cleanup.

## Select the scope

- Staged-only mode, when called by commit: capture git diff --staged and exclude all unstaged and untracked work.
- Standalone mode: capture git status --short and git diff HEAD, including the contents of relevant untracked files as additions.
- Optional focus: weight all review lenses toward the user's named concern.

If the diff is empty, fall back only to files explicitly mentioned or modified in the session. If no scope remains, report that there is nothing to simplify. For a single-concern diff under roughly twenty lines, use only the most relevant lens.

## Review

Read references/review-lenses.md completely before reviewing.

When subagents and capacity are available, launch the required independent read-only lenses in parallel. This skill explicitly requests those agents. Use the running harness's exposed delegation tool: Codex's collaboration/spawn API, Grok's `spawn_subagent`, or Copilot's `task`. Follow its actual parameters and configured model defaults; do not require Claude's `Agent` tool or a Claude model. Give reviewers the raw scoped diff and minimal repository context, not expected findings. Reviewers must report proposals and must not edit files.

Collect every reviewer's result using the harness's supported wait/output mechanism before applying changes. In a headless run, do not end the run while reviewers are pending. When agents or a usable completion mechanism are unavailable, review serially and disclose that the review was not independent. Scale the lenses to the actual diff; preserve behavior and staging boundaries.

## Resolve and apply

1. Parse and validate proposals.
2. Group them by file and target region.
3. Deduplicate equivalent edits.
4. Resolve conflicts using behavior preservation, clarity, and house conventions. When those principles do not select a winner, apply neither.
5. Detect overlapping edits. Prefer a safe local edit over a broad rewrite unless the broad edit clearly subsumes it without changing behavior.
6. Re-read each target region immediately before editing.
7. Apply accepted edits sequentially with the running harness's available editing tool. If an anchor is stale because an earlier edit subsumed it, skip it. In staged-only mode, preserve all pre-existing unstaged edits, including edits in the same file; do not replace the working file wholesale with the index version.
8. In staged-only mode, leave re-staging to the calling commit skill.

Never stop to ask about an ambiguous style preference. Record the proposal as not applied.

## Report

Report the changes, material proposals not applied and why, and relevant verification. Omit empty bookkeeping categories.
