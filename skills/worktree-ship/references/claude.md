---
name: worktree-ship
description: Take an approved plan from plan mode through implementation in a worktree (or the current checkout with --no-worktree) to a reviewed, open PR, in one move. Trigger on "/worktree-ship [--no-worktree] [--level <l>] [--model <m>]", "enter worktree and ship it", "implement and open the PR", "ship the plan", "implement this in a worktree", "ship it without a worktree". Do NOT use for issue triage (use tackle-task), for a commit without a PR (use commit-push), or when no approved plan exists yet (draft one and get approval first).
---

# worktree-ship

**The operator already approved the plan. Every joint from here to an open, review-ready PR is yours; that is the whole point of this skill.** Stop only for failures you cannot fix or for scope changes the operator must decide. Do not re-litigate the plan; execute it.

## Procedure

**1. Resolve the plan, then enter the worktree.** If this session already holds the approved
plan, use it. Otherwise resolve it from disk rather than asking: the path argument if given,
else the newest plan under `~/.claude/plans/` by mtime, and say which one you picked. It must
contain a `## Steps` section; if it doesn't, stop and identify the missing section.
An actionable approved plan need not have been produced by a particular skill. A cleared, resumed, or model-switched session is a normal way to arrive here,
not an error, because the plan file is authoritative on its own and the transcript that
produced it is not needed to execute it.

Then call `EnterWorktree`. Rename the branch to this repo's convention as the repo itself documents it (`CLAUDE.md` or `AGENTS.md`, often a §Branching section); if it documents none, match the shape of recent branches in `git branch -a`. A common form is `feat/<issue>-<slug>` / `fix/<issue>-<slug>` / `chore/<slug>`, but the repo's own answer wins.

With `--no-worktree`, skip `EnterWorktree` and the branch rename, and implement in the current checkout. `review-ship` creates the branch (by the same convention) before anything is committed. Stop and ask first if the checkout is on a branch other than the default one that isn't this task's branch, because the work would land on it. Uncommitted work already in the checkout stays out of the change: `commit` stages only the files this session edited, and asks when a file it needs also holds someone else's edits.

**2. Implement the approved plan.** Follow the plan; do not grow it. Context hygiene (these rules exist because past sessions burned tokens re-reading whole files):
- Read large files with `offset`/`limit` around the region you are editing; don't slurp a 1000-line file to change 10 lines.
- Delegate review of any diff over ~300 lines to a subagent instead of reading it into this context.

**3. Verify before any commit.** Run this repo's own test and typecheck commands, exactly as the repo states them (`CLAUDE.md` / `AGENTS.md`, else its package manifest scripts or CI workflow). Repos with several suites often need more than one command, so run what the repo lists rather than a remembered shorthand. Never proceed red: fix and re-run until green, quoting the passing output.

**4. Review and publish.** Invoke the `review-ship` skill, passing through `--level` and `--model` exactly as given. Quote the step 3 run so it doesn't repeat it. It commits, has `/code-review --fix` run in a fresh-context subagent, re-verifies, runs the repo's pre-push gate, and opens the PR. This session wrote the code, so the review runs in that subagent, not here. When review-ship halts for the operator (red verification, unfixed findings, a plan-contract question), this skill halts with it.

**5. Report.** PR URL; test evidence (exact command + exit) before and after the review; the reviewer model and level with the findings' fixed or skipped state, from review-ship; and one before/after diagram rendered per the `delta-diagrams` skill.

## Suggested goal

Offer to pin this so the whole flow survives multi-turn without per-turn prompting:

    /goal Issue #<N> is shipped: the implementation passes this repo's test and typecheck commands (exit 0 shown); review-ship has run /code-review --fix in a subagent, re-verified green, and the PR URL is shown. With a worktree, no files outside it were touched. Or this session has halted for the operator: its last message is a red verification table, the numbered unfixed-findings list, or a plan-contract question, with no operator reply yet. Or stop after 30 turns.

## Don't

- Don't reimplement `review-ship`, `commit` or `open-pr`; invoke the skills.
- Don't review the diff in this session's own context; review-ship's subagent does it.
- Don't skip step 3 to "save time"; the verification spine is the whole reason terse prompts still ship tested code.
