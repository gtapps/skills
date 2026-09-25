---
name: review-ship
description: Claude Code workflow for review-ship. Verifies finished work, commits it locally, runs /code-review --fix in a fresh-context subagent on a chosen model, re-verifies, and opens or updates the PR, so no /clear or second session is needed.
---

# review-ship

The code is written and the operator wants it reviewed and published in one move. The review runs in a subagent with none of this session's history, because the session that wrote the code reads it with the author's assumptions. The same isolation `/clear` would give, without the round trip.

Arguments: `--level` is the `/code-review` effort level, default `high`. `--model` is the reviewer's model; when it is absent the reviewer inherits the session's model. Pass both through exactly as given. `--reviewer` is for the other hosts; here the reviewer is always the `/code-review` subagent.

A calling skill (worktree-ship, delegate-ship) may hand over its verification commands, extra PR body sections, and a goal it has already printed. Use them as given: its commands replace the ones step 1 would resolve, and its goal replaces this skill's goal line.

## Procedure

**1. Print the goal, then prepare.** Print this line so the operator can pin it:

    /goal The work on <branch> is shipped by review-ship: verification shown green before the review; the implementation committed locally before the review; /code-review <level> --fix ran in a subagent on <model>, and its own diff was shown; verification re-run green after it; the PR URL is shown. Or this session has halted for the operator: its last message is a red verification table, the numbered unfixed-findings list, or a plan-contract question, with no operator reply yet. Never reset --hard, amend or force-push; on push rejection fetch, rebase, re-verify, retry. Or stop after 25 turns.

When you halt for the operator, end the message with this goal line again, so the operator can re-pin it with their answer.

A dirty tree, or commits beyond the remote default branch, means there is something to ship. With neither, stop: there is nothing to ship.

Verification commands: the approved plan's `## Closing verification` block when the session holds one, else the repo's own test and typecheck commands (`CLAUDE.md` / `AGENTS.md`, else manifest scripts or CI). If the repo documents none, say so and continue. Don't invent any.

**2. Verify.** Run the commands and keep each command with its exit code. A red row stops here, with the output shown. If the caller already ran them green on this exact tree in this turn, quote that run instead of repeating it.

**3. Branch and commit locally.** Run `open-pr` Phase A only. It moves work off the default branch before anything is committed and returns the base, comparison ref, branch and remote; keep them for steps 4 and 6. It runs after verification so a red halt leaves no branch behind. Then invoke `commit --no-simplify`, and say in one line that the review covers the cleanup pass. Skip this when the tree is clean and the branch already holds the commits. Run `git rev-parse HEAD` and keep the printed SHA as `<pre-review>`, used literally below: shell variables don't survive between Bash calls. Note any paths `git status --short` still lists: they are unrelated work, not this change's. A background `--fix` edits outside Claude Code's checkpoints, so this commit is what makes the review's own changes visible and revertible with git.

**4. Review in a fresh context.** Make one Agent call and wait for its completion notification:

    Agent(subagent_type: "general-purpose",
          description: "code-review <level> on <branch>",
          model: <--model, only when given>,
          prompt: "Your cwd is <repo root>. Invoke the code-review skill with the Skill tool,
                   args \"<level> --fix <comparison-ref>...HEAD\". Do not review or edit
                   anything yourself. When its result arrives, reply with its findings verbatim,
                   each one marked fixed or not fixed.")

The wrapper is what sets the model. A skill call takes no model argument, and `/code-review` reads extra words as its review target. The nested review inherits the wrapper's model: on CC 2.1.282 an `Agent(model: opus)` wrapper produced an Opus review from a Sonnet session. The explicit level stops `/code-review` from reusing the last level the operator typed. The range target keeps unrelated uncommitted work in the checkout out of the review.

**5. Check what the review did.** Print `git diff --stat <pre-review>`, leaving out the unrelated paths noted in step 3, and the diff itself when it is short. At `high` and above the review may apply findings it is less sure of, and this diff is where the operator sees them. Re-run verification and show the table again.
- Red after the review: stop with the table and the review diff. The operator decides whether to keep or revert.
- Findings left unfixed: print them as a numbered list and stop. The operator answers "1. agree 2. skip, because ...". Apply the agreed ones, re-verify, continue.
- A finding that reverses a contract in an approved plan (a step's behavior, a verify command, the scope fence): halt for an explicit Yes, record the new contract in the plan file, then continue.

**6. Publish.** If the review changed files, invoke `commit --no-simplify` for them, never for the unrelated paths noted in step 3. Before any push, run the repo's documented pre-push gate if it has one (a release lock, a migration, schema or changelog check). A hold means print what the gate reported, don't push, and tell the operator to retry once it clears; never bypass or remove a gate. Then resume `open-pr` at Phase C with the context from step 3. It pushes, and it creates the PR or returns the one that already exists. The PR body states the review level and the reviewer model, and carries any sections the caller handed over.

**7. Report.** Lead with the PR URL. Then the verification tables from before and after the review, the reviewer model and level, the review's diff stat, and the findings with their fixed or skipped state. Pass through the follow-up lines open-pr prints, unchanged.

## Don't

- Don't review the diff in this session or run `/code-review` directly here. The wrapper subagent's clean context is the point of this skill.
- Don't reimplement `commit`, `open-pr` or `code-review`; invoke them.
- Don't wait with sleep or status polls; the Agent completion notification wakes you.
