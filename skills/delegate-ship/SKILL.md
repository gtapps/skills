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

    /goal <PLAN> is shipped by delegate-ship: DELEGATE_DONE shown; the plan's Closing verification re-run by me in the worktree after the last commit (verify.sh table shown, every row exit 0); /code-review high --fix applied and re-verified, any unfixed finding listed and decided by the operator; the PR URL is shown with a blast-radius section; every Copilot or CI comment is either applied (pushed SHA shown) or refuted with a cited reason; any finding that reverses a plan contract halted for a Yes and the plan file was edited. Never reset --hard; on push rejection fetch, rebase, retest, retry. Or stop after 30 turns.

Then resolve `<executor>` (codex, grok, copilot or claude), the optional `--model <m>` and `--effort <e>`, and `<plan>` (a path, else the newest file under `~/.claude/plans/` by mtime; say which one you picked). Pass the two flags through to delegate-plan exactly as given and never fill them in yourself: its `config.json` owns the defaults, so an absent flag is passed as absent. The plan must contain a `## Closing verification` block. If it does not, stop and say so: there is nothing to re-verify against, and this skill never supplies its own test commands.

**2. Delegate and wait.** Invoke the `delegate-plan` skill with the executor, the flags and the plan. It freezes the grounded SHA, creates the worktree, launches the executor (under a Monitor, or as a background subagent when the executor is claude), and ends with a `DELEGATE_DONE executor=<x> exit=<rc> result=<path>` line (for claude, printed by its `finish_claude.sh`). Wait on that Monitor, or on the agent's completion for claude. Never poll `status.sh` by hand, never `/loop` to watch it; a stall arrives as a Monitor event and delegate-plan's own rules handle it.

delegate-plan's report closes with an operator menu and "do not review, stage, commit, push, or open a PR in this session". That stop is overridden here on purpose: this skill owns the rest of the pipeline, and the menu's first two lines are exactly steps 4 to 6 below. Say so in one line when you continue past it.

**3. Re-verify from the plan, not from memory.** In the worktree, run

    bash <delegate-plan-skill-dir>/scripts/verify.sh <run-dir>

and print its `<exit>  <command>` table verbatim. Every row comes from the plan's Closing verification block. A red row stops the pipeline here with the table shown; the executor's `result.json` claims are not evidence.

**4. Review and fix.** Invoke `code-review high --fix` on the worktree diff, with Opus as the review model (operator rule, 2026-09-14: the executor may be a lower-effort or non-Claude harness, so the review runs on Opus regardless of the session model; if the session model is not Opus, switch with `/model opus` for this step or pin `model: opus` on the review subagent). This is not a self-review: the executor wrote the code, this session did not, so worktree-ship's "review in a fresh session" rule does not apply. Then re-run verify.sh and print the table again.

If findings remain unfixed after `--fix`, print them as a numbered list and STOP. The operator answers in the form "1. agree 2. skip, because ...". Apply the agreed ones, re-verify, continue.

A finding that reverses a contract in the plan (a step's behavior, its verify command, the scope fence) is not yours to decide: halt for an explicit Yes, edit the plan file to record the new contract, then continue.

**5. Commit.** Invoke `commit --no-simplify`. Say in one line that simplify is skipped because code-review --fix just ran on this diff. No marker files.

**6. Open the PR.** Invoke `open-pr`. The body must carry, in addition to whatever the repo's template or open-pr's default body asks for, a section:

    ## Blast radius
    - Released surfaces touched: ...
    - Unreleased surfaces touched: ...
    - Downstream operators: ...
    - Downstream hermits: ...
    - Per-actor ledger: executor <executor>[:<model>] <what it wrote> / code-review <what it changed> / operator <what was decided>

The executor's name and model come from the run's `freeze.json` (`executor`, `model`; omit the model when null), so a PR reviewer sees which harness and model wrote the code. When the executor is claude, add that the step 4 review ran in this session with a fresh context: a subagent wrote the diff, this session did not.

If the plan names an external protocol (a wire format, an MCP or HTTP contract, a channel bridge), run one real-client smoke against the worktree build before `open-pr` and paste the command and its output into the body. No protocol named: skip the smoke, do not invent one.

**7. Report and stop.** Print the PR URL. open-pr already prints `/loop 15m /babysit-prs` and the drain-review-queue goal; pass them through as printed, do not restate them. Copilot and CI comments are the babysit loop's job, not this session's.

## Rules

- Absolute paths everywhere. The worktree is the repo root (`git rev-parse --show-toplevel`), never the main checkout.
- No test or typecheck command is named in this file. They come from the plan, through verify.sh.
- Never reset --hard. On a rejected push: fetch, rebase, re-run verify.sh, push again.
- Don't reimplement `delegate-plan`, `code-review`, `commit` or `open-pr`; invoke them.
- Don't wait on the executor with sleep or status polls; the Monitor, or the agent completion for claude, wakes you.
- GUEST_REPORT is not a step here. Sessions in a hermit-managed repo already receive that mandate from the project's startup context.
