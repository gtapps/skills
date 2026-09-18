---
name: worktree-ship
description: Take an approved plan from plan mode through worktree implementation to an open PR, handed off for review in a fresh session, in one move. Trigger on "/worktree-ship", "enter worktree and ship it", "For implementation Enter Worktree and when done run /commit-open-pr", "implement and open the PR", "ship the plan", "implement this in a worktree". Do NOT use for issue triage (use tackle-issue), for a commit without a PR (use commit-push), or when no approved plan exists yet — draft and get approval first.
---

# worktree-ship

**The operator already approved the plan. Every joint from here to an open, review-ready PR is yours — that is the whole point of this skill.** Stop only for failures you cannot fix or for scope changes the operator must decide. Do not re-litigate the plan; execute it.

## Procedure

**1. Resolve the plan, then enter the worktree.** If this session already holds the approved
plan, use it. Otherwise resolve it from disk rather than asking: the path argument if given,
else the newest plan under `~/.claude/plans/` by mtime, and say which one you picked. It must
contain a `## Steps` section; if it doesn't, stop and identify the missing section.
An actionable approved plan need not have been produced by a particular skill. A cleared, resumed, or model-switched session is a normal way to arrive here,
not an error, because the plan file is authoritative on its own and the transcript that
produced it is not needed to execute it.

Then call `EnterWorktree`. Rename the branch to this repo's convention as the repo itself documents it (`CLAUDE.md` or `AGENTS.md`, often a §Branching section); if it documents none, match the shape of recent branches in `git branch -a`. A common form is `feat/<issue>-<slug>` / `fix/<issue>-<slug>` / `chore/<slug>`, but the repo's own answer wins.

**2. Implement the approved plan.** Follow the plan; do not grow it. Context hygiene — these rules exist because past sessions burned tokens re-reading whole files:
- Read large files with `offset`/`limit` around the region you are editing; don't slurp a 1000-line file to change 10 lines.
- Delegate review of any diff over ~300 lines to a subagent instead of reading it into this context.

**3. Verify before any commit.** Run this repo's own test and typecheck commands, exactly as the repo states them (`CLAUDE.md` / `AGENTS.md`, else its package manifest scripts or CI workflow). Repos with several suites often need more than one command, so run what the repo lists rather than a remembered shorthand. Never proceed red — fix and re-run until green, quoting the passing output.

**4. Repo-specific pre-push gate, before any push or merge to the default branch.** If this repo documents a gate that must pass before pushing (a release lock, a migration check, a schema or changelog guard), run it and honor its result: passing means proceed; failing means print exactly what it reported, hold the push, and tell the operator to retry once the condition clears. Never bypass, disable, or delete a gate to keep moving. If the repo documents no such gate, skip this step.

**5. Commit and open the PR.** Invoke the `commit-open-pr` skill (it chains `commit` → `simplify` → `open-pr`). Do not reimplement its steps. Quote the PR URL it returns.

**6. Stop at the open PR — do not review your own code.** `/review` and `/code-review` run in a *separate* session on purpose: fresh context and a different model give the diff an unbiased read that this session — which just wrote the code — cannot. So worktree-ship ends here. Print the PR URL and the exact handoff line:

    Review in a fresh session: /review <PR#>

The findings are verified as hypotheses and applied in *that* session per the `review-findings` skill (✅ apply confirmed + re-run tests + push; ❌ refute in a PR comment with evidence; ⚠️/🔍 to the operator) — not here.

**7. Report.** PR URL; test evidence (exact command + exit); the "Review in a fresh session: /review <PR#>" handoff line from step 6; and one before/after diagram rendered per the `delta-diagrams` skill.

## Suggested goal

Offer to pin this so the whole flow survives multi-turn without per-turn prompting:

    /goal Issue #<N> is shipped: implementation in its worktree passes this repo's test and typecheck commands (exit 0 shown); commit-open-pr has run and the PR URL is shown, with the "Review in a fresh session: /review <PR#>" handoff line printed. No files outside the worktree touched, no inline review. Or stop after 30 turns.

## Don't

- Don't reimplement `commit` or `open-pr` — invoke the skills.
- Don't run `/review` or `/code-review` inline — this session wrote the code; the review belongs in a fresh session with a different model. Hand it off (step 6) and stop.
- Don't push while a repo pre-push gate says hold.
- Don't skip step 3 to "save time"; the verification spine is the whole reason terse prompts still ship tested code.
