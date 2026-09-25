---
name: delegate-ship
description: Claude Code only. Take an approved contract-level plan through delegate-plan (executor codex, grok, copilot or a claude subagent), independent re-verification, code-review --fix, commit, a PR with a blast-radius section, and hand-off to a babysit loop, in one move. Trigger on "/delegate-ship <executor> [--model <m>] [--effort <e>] <plan>", "delegate and ship", "grok implements then PR it", "have codex build the plan and open the PR", "have a claude subagent build it and PR it". Do NOT use for planning (plan-pipeline), for this session implementing the plan itself (worktree-ship), or for a PR from work already committed (open-pr).
compatibility: Requires Claude Code as the host; Codex, Grok, and Copilot may be delegated executors.
---

# delegate-ship

Resolve `<name-skill-dir>` to the absolute installed directory of the named skill before executing the commands below.

**The plan is approved. Every joint from here to a Copilot-clean PR is yours. Stop only for a finding the operator must decide.** One command: the operator pastes the goal line and comes back for the PR URL.

## Procedure

**1. Print the goal, resolve the inputs.** Print this line first so the operator can paste it:

    /goal <PLAN> is shipped by delegate-ship: DELEGATE_DONE shown; the plan's Closing verification re-run by me in the worktree after the last commit (verify.sh table shown, every row exit 0); review-ship ran /code-review high --fix in an Opus subagent and re-verified; any finding that reverses a plan contract halted for a Yes and the plan file was edited; the PR URL is shown with a blast-radius section. Or this session has halted where delegate-ship requires the operator: its last message is the numbered unfixed-findings list, a contract-change question, or a red verification table, with no operator reply yet. Never reset --hard; on push rejection fetch, rebase, retest, retry. Or stop after 30 turns.

The goal evaluator is binary: a halt satisfies the goal and clears it, which keeps it from pushing past a decision that belongs to the operator. So every time you halt for the operator, end the message with this goal line again, so they can re-pin it with their answer.

Then resolve `<executor>` (codex, grok, copilot or claude), the optional `--model <m>` and `--effort <e>`, and `<plan>` (a path, else the newest file under `~/.claude/plans/` by mtime; say which one you picked). Pass the two flags through to delegate-plan exactly as given and never fill them in yourself: its `config.json` owns the defaults, so an absent flag is passed as absent. The plan must contain a `## Closing verification` block. If it does not, stop and say so: there is nothing to re-verify against, and this skill never supplies its own test commands.

**2. Delegate and wait.** Invoke the `delegate-plan` skill with the executor, the flags and the plan. It freezes the grounded SHA, creates the worktree, launches the executor (under a Monitor, or as a background subagent when the executor is claude), and ends with a `DELEGATE_DONE executor=<x> exit=<rc> result=<path>` line (for claude, printed by its `finish_claude.sh`). Wait on that Monitor, or on the agent's completion for claude. Never poll `status.sh` by hand, never `/loop` to watch it; a stall arrives as a Monitor event and delegate-plan's own rules handle it.

delegate-plan's report closes with an operator menu and "do not review, stage, commit, push, or open a PR in this session". That stop is overridden here on purpose: this skill owns the rest of the pipeline, and the menu's first line is exactly step 4 below. Say so in one line when you continue past it.

**3. Re-verify from the plan, not from memory.** In the worktree, run

    bash <delegate-plan-skill-dir>/scripts/verify.sh <run-dir>

and print its `<exit>  <command>` table verbatim. Every row comes from the plan's Closing verification block. A red row stops the pipeline here with the table shown; the executor's `result.json` claims are not evidence.

**4. Review and publish.** Invoke `review-ship --level high --model opus`. The executor may be a lower-effort or non-Claude harness, so the review runs on Opus whatever the session model is. Hand it:
- the goal line from step 1 (review-ship prints none of its own);
- `bash <delegate-plan-skill-dir>/scripts/verify.sh <run-dir>` as its verification command (plus the smoke below, when the plan names a protocol), with the step 3 table as its pre-review run;
- the section below as an extra PR body section.

review-ship commits the executor's tree without simplify (the executor already ran its own), runs the review in a fresh-context Opus subagent, re-verifies, and opens the PR. It halts on a red table, unfixed findings, or a finding that reverses a plan contract. On a contract halt, edit the plan file to record the new contract after the operator's Yes. The PR body section:

    ## Blast radius
    - Released surfaces touched: ...
    - Unreleased surfaces touched: ...
    - Downstream operators: ...
    - Downstream hermits: ...
    - Per-actor ledger: executor <executor>[:<model>] <what it wrote> / code-review:opus <what it changed> / operator <what was decided>

The executor's name and model come from the run's `freeze.json` (`executor`, `model`; omit the model when null), so a PR reviewer sees which harness and model wrote the code.

If the plan names an external protocol (a wire format, an MCP or HTTP contract, a channel bridge), add one real-client smoke against the worktree build to the verification commands you hand review-ship, and have review-ship paste its command and output into the PR body. No protocol named: skip the smoke, do not invent one.

**5. Report and stop.** Print the PR URL. open-pr already prints `/loop 15m /babysit-prs` and the drain-review-queue goal; pass them through as printed, do not restate them. Copilot and CI comments are the babysit loop's job, not this session's.

## Rules

- Absolute paths everywhere. The worktree is the repo root (`git rev-parse --show-toplevel`), never the main checkout.
- No test or typecheck command is named in this file. They come from the plan, through verify.sh.
- Never reset --hard. On a rejected push: fetch, rebase, re-run verify.sh, push again.
- Don't reimplement `delegate-plan` or `review-ship`; invoke them.
- Don't wait on the executor with sleep or status polls; the Monitor, or the agent completion for claude, wakes you.
- GUEST_REPORT is not a step here. Sessions in a hermit-managed repo already receive that mandate from the project's startup context.
