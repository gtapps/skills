---
name: delegate-plan
description: Claude Code only. Hand an approved implementation plan to an executor (codex, grok or copilot headless in auto mode, or a claude subagent) that implements it inside a worktree at the exact grounded commit, then bring back git-derived evidence and stop at the operator's decision. The executor implements only; it never stages, commits, pushes or opens a PR. Trigger on "/delegate-plan <executor> [--model <m>] [--effort <e>] [plan]", "/delegate-plan <executor> --resume", "/delegate-plan status", and any request to have codex, grok, copilot or a claude subagent implement or continue a plan, or to check on a running delegation. Do NOT use to have this session implement (worktree-ship), to review a plan (delegate-plan-review, final-plan-check), to prepare settled decisions for an executor missing context (plan-implementation), or to commit and open the PR (the operator's /commit-open-pr, after this skill stops).
compatibility: Requires Claude Code as the host; Codex, Grok, and Copilot may be delegated executors. Requires jq, the Monitor tool, and the chosen executor CLI (codex, grok or copilot) authenticated; the claude executor needs only the Agent tool.
---

# delegate-plan

Resolve `<name-skill-dir>` to the absolute installed directory of the named skill before executing the commands below.

The plan is approved and contract-level (per-step Verify, fence, stop-and-ask). This skill
makes another agent implement it without the planning transcript, in a worktree Claude
controls, and brings back evidence Claude derives itself rather than the executor's word.
The executor is a foreign CLI (codex, grok, copilot) or a claude subagent; the evidence
contract is the same for all four.

**The executor implements only.** It does not stage, commit, push, or open a pull request,
and it needs no `gh`. That is deliberate: it collapses the executor's permission surface to
file writes plus the plan's own test commands, it keeps anything outward-facing behind a
human, and it means the diff Claude reports is the diff the executor produced.

**This skill stops at the verified working tree.** What happens next is the operator's call,
made with the evidence in hand: review it, ship it, resume it, or throw it away. Claude does
not commit on their behalf; `/commit` says the cleanup pass may only be skipped when the
operator asks for it ("Don't decide to skip on your own"), and the operator is the one who
knows the executor already ran its own simplify.

Invocation: `/delegate-plan codex|grok|copilot|claude [--model <m>] [--effort <e>] [plan-path]`,
`/delegate-plan codex|grok|copilot|claude --resume ["<instruction>"]` (instruction defaults to
"continue"), or `/delegate-plan status [run-dir]`.

Model and effort: the flag if given, else the executor's entry in `config.json`, else
whatever the harness does on its own (`null`). Never pick one here. Both are frozen into
`freeze.json` at step 4, so a resume runs with the same values. The claude executor takes
`--model` (it becomes the Agent call's `model`) but has no effort control: when an effort
resolves for claude, say in one line that it is ignored, and go on.

Names used below: `<repo>` is the basename of `git rev-parse --show-toplevel`;
`<branch-slug>` is the branch with `/` replaced by `-`; the worktree directory `<name>` is
the branch slug.

## Files

- `wrapper.md`: the executor prompt, placed above the frozen plan. Placeholders
  `{{WORKTREE}}`, `{{BRANCH}}`, `{{BASE_SHA}}`, `{{PLAN_SHA256}}`, `{{RUN_DIR}}`,
  `{{SIMPLIFY}}`, `{{WAIT}}` (how the executor waits for reviewers it dispatched: the
  one-turn CLIs must block on them, a claude subagent waits by ending its turn; rendered per
  executor by `setup_run.sh`).
- `result.schema.json`: the executor's final message shape (advisory; git is the evidence).
- `config.json`: per-executor default `model` and `effort`, `null` meaning the harness
  default. A flag on the invocation overrides it.
- `scripts/finish_claude.sh <run-dir> <reply-file>`: the claude executor's stand-in for a
  driver's ending. Turns the subagent's final reply into `result.json` (when it parses),
  writes `git.json`, and prints the `DELEGATE_DONE executor=claude` line.
- `scripts/run_codex.sh`, `scripts/run_grok.sh`, `scripts/run_copilot.sh`:
  `<run-dir> [--resume "<text>"]`. Each writes `executor.log`, `result.json`, `session.txt`,
  `git.json` into the run dir and prints exactly one stdout line:
  `DELEGATE_DONE executor=<x> exit=<rc> result=<path>`, plus one kind of mid-run line:
  `DELEGATE_STALL executor=<x> idle=<n>s log=<path>`, at most once per stall, when
  `executor.log` has not changed for 10 minutes (a recovery is silent: it needs no action,
  so it earns no wake). They share `scripts/_write_git_json.sh`, which derives `git.json`,
  and `scripts/_wait_child.sh`, which waits for the executor and emits the stall line; both
  are the same for every executor.
- `scripts/status.sh [run-dir]`: read-only snapshot of one delegation (phase, elapsed,
  idle, last thing the executor said or ran, worktree diff), built from the run dir files
  and `git status`. Without an argument it picks the newest run dir whose
  `freeze.json.worktree` is the worktree the caller stands in.
- `scripts/setup_run.sh <executor> <plan-path>`: step 4 in one call, run from inside the
  worktree. Creates the run dir, freezes the plan, writes `freeze.json`, renders `prompt.md`
  and prints the run dir path.
- `scripts/verify.sh <run-dir>`: step 6, check 2. Re-runs every line of the frozen plan's
  `## Closing verification` block inside the worktree and prints `<exit>  <command>` per
  line; exits 0 only when all rows are 0. Command output lands in `<run-dir>/verify.log`.
- Run dir: `~/.claude/delegate-runs/<repo>-<branch-slug>-<YYYYmmdd-HHMMSS>/` (slug: `/`
  becomes `-`).

## Procedure

**1. Resolve the plan.** Print the Suggested goal line (section below) before resolving
the plan. The path argument if given, otherwise this session's plan file; if
several exist under `~/.claude/plans/`, the one this session wrote, else the newest by
mtime, and say which. It must contain a `## Steps` section; if it doesn't, stop and
identify the missing section. An actionable approved plan need not have been produced
by a particular skill.

**2. Ground.** In the launch checkout: `grounded_sha=$(git rev-parse HEAD)`. The checkout
must be clean, or uncommitted work would not reach the worktree and the plan may have been
grounded against it: stop and ask. The check runs from the top level, because a pathspec
resolves against the cwd and a launch from a subdirectory would miss dirty files elsewhere
in the repo (earlier worktrees live under `.claude/worktrees` untracked, hence the exclude):

    git -C "$(git rev-parse --show-toplevel)" status --porcelain -- ':!.claude/worktrees'

must be empty. Pick the branch name by the repo convention
(worktree-ship step 1). Not a git repo, or no commits: stop.

**3. Worktree at the exact grounded commit.**

    root=$(git rev-parse --show-toplevel)
    git worktree add "$root/.claude/worktrees/<name>" -b <branch> "$grounded_sha"

Then `EnterWorktree(path: "$root/.claude/worktrees/<name>")`. `EnterWorktree`'s own `name`
mode would base the worktree on `origin/<default>` instead of the commit the plan was
grounded against, which is why the worktree is created by hand first. In the worktree,
`git rev-parse HEAD` must equal `grounded_sha`; otherwise stop. If `git worktree add` fails
(typically: the branch already exists), stop and show the error.

**4. Freeze.** From inside the worktree, literal absolute path (the worktree checker rejects
an inline heredoc or `sed` here; a script by absolute path passes):

    bash <delegate-plan-skill-dir>/scripts/setup_run.sh <executor> <plan-path> [--model <m>] [--effort <e>]

It creates the run dir, copies the plan to `plan.md`, writes `freeze.json` (including the
resolved `model` and `effort`), renders
`prompt.md` (`wrapper.md` with its placeholders substituted, `{{SIMPLIFY}}` being the
executor's own cleanup skill, then `plan.md`) and prints the run dir path: note it. From
here `plan.md` is the contract, not the source file. Exit 2 means the plan has no `## Steps`
section: stop and say so.

**5. Run under Monitor** (codex, grok, copilot), **or as a subagent** (claude).

*claude:* one Agent call, in the background, and its completion notification is the end
signal:

    Agent(subagent_type: "general-purpose",
          description: "delegate-plan claude on <branch>",
          model: <freeze.json.model, only when non-null>,
          prompt: "Your cwd is <worktree>. Read <run-dir>/prompt.md and follow it exactly.
                   Your final reply must be only the JSON object it asks for, nothing else.")

Tell the operator it is running and that they can keep working. What claude lacks, say
once: no `DELEGATE_STALL`, no 30m cap, no `session.txt`, and the subagent runs in this
session's permission mode, so a headless delegation needs the host in auto mode. During
its cleanup pass the executor dispatches reviewer subagents and waits for them by ending
its turn; those stops do not notify this session (a completion notification fires only
when the agent stops with no live children), so the single notification that arrives is
the end. The fence
is the wrapper's prose plus check 4 in step 6; nothing mechanical refuses a commit. When the
notification arrives, write the agent's final reply verbatim to `<run-dir>/reply.txt` with
the Write tool, then run

    bash <delegate-plan-skill-dir>/scripts/finish_claude.sh <run-dir> <run-dir>/reply.txt

which prints the same `DELEGATE_DONE executor=claude exit=0 result=<path>` line the drivers
print. Continue at step 6 as for any executor.

*codex, grok, copilot:* literal absolute paths (shell variables do not survive into the
Monitor call):

    Monitor(
      command: 'bash <delegate-plan-skill-dir>/scripts/run_<executor>.sh <run-dir>',
      description: 'delegate-plan <executor> on <branch>',
      timeout_ms: 1800000)

Tell the operator it is running and that they can keep working. The 30m cap is the tool's
maximum and doubles as the spend cap: on timeout the driver kills the executor and the run
is reported as *timed out*, with the resume command below, not as an executor failure.

While it runs the Monitor is silent unless something is wrong; do not poll it. A
`DELEGATE_STALL` line means the executor has written nothing for 10 minutes. Read the last
assistant text in `executor.log` (grok: the last `message.content[]` of type `text`; codex:
the last `item.completed`), send a `PushNotification` of the form
`<executor> <branch> idle <n>m: <last text>`, and keep waiting. Do not kill or resume it:
a long test run and a hang look identical from outside, and only the outcome tells them
apart; the 30m cap is the backstop. A recovery is silent by design; the next line is
`DELEGATE_DONE`.

**6. When the Monitor ends** (or `finish_claude.sh` has run). Normally with one
`DELEGATE_DONE executor=<x> exit=<rc> result=<path>` line. If the Monitor ends with no such
line (hard kill, driver crash), treat it as `exit=143` below. Read `result.json` (the
executor's claims, may be absent) and `git.json` (authoritative: `base_sha`, `head_sha`,
`committed`, `files_touched`, `uncommitted`; missing or empty means the driver could not
read the worktree: outcome "failed", say so, and check `git.json.err` in the run dir). Re-hash the source plan file the same way (bare hash, no filename): if it differs
from `freeze.json.plan_sha256`, add a "source plan changed since freeze" note to the report;
never abort on it, the frozen copy was what ran. Decide the outcome, then write the single
report in step 7.

- `status: done`: verify it yourself, in this order, before believing it.
  1. `git.json.uncommitted` must be non-empty *unless* `git.json.committed` is true (a
     fence-breaking commit leaves a clean tree, so jump to check 4 rather than concluding
     nothing happened). An empty tree with `committed: false` means nothing was implemented,
     whatever `result.json` says: outcome "nothing implemented", and stop here. Checks 2 to 4
     only characterise what changed, so re-running the closing verification against an
     unmodified tree cannot change the outcome.
  2. **Re-run the plan's Closing verification in the worktree** with
     `bash <delegate-plan-skill-dir>/scripts/verify.sh <run-dir>` and quote its
     table verbatim. `result.json.steps` and `result.json.closing_verification` are model claims; this is the
     one place the report gets real test evidence, and it costs one command. A non-zero row,
     including a line that will not run, means the outcome is "implementation red" and the ship line
     is withheld.
  3. Judge each `git.json.files_touched` path semantically against the plan's "Out of scope" bullets
     (they are prose, not globs) and record a warning naming the path and the bullet it
     matches. This happens while a violation is still free to revert.
  4. `git.json.committed` must be false. If the executor committed anyway it broke the
     scope fence in `wrapper.md`: report it with the SHA and let the operator decide, and
     say plainly that the working tree is no longer the whole diff.

- `status: blocked`: judge `blocked_command` against the plan's Steps, their Verify
  commands, and its Closing verification commands. In-plan means both: the command is one of
  those, and its effects stay inside the worktree (a write to `$HOME` or elsewhere is not,
  even when the plan's Verify literally names it). Anything git-writing or `gh` is out of
  scope by construction, so a block on one of those is a wrapper violation, not a
  missing permission: report it, never widen the gate. If in-plan and
  `freeze.json.resumes < 2`, resume: run the driver with `--resume "<go-ahead naming the
  command>"` under Monitor exactly as in step 5, then return here. Otherwise the outcome is
  "blocked, operator decides".

- `status: stopped`: the operator's decision, but never on the executor's word alone. When
  `stop_reason` carries a failing command, re-run that exact command in the worktree yourself
  before reporting, whatever prefix it has. It is the same cheap evidence step `done` gets,
  and the executor cannot run the discriminators you can. Three outcomes: it passes, so the
  red did not reproduce; it fails but the command itself is at fault (a flag the project's
  real spine carries, a missing dep, a path outside the worktree), which is a plan defect, so
  quote it verbatim and the plan can be repaired in one edit; or it fails on its own terms,
  outcome "stopped: <stop_reason>".

  Reach for the cheap discriminators first, in the tree you already have: run the command the
  way the project actually runs it (the CI workflow is the reference), run it serially, or run
  only the suites the diff touches. A red that clears under any of them was never the diff's.
  Only when those settle nothing, add a throwaway worktree at `grounded_sha`, run the
  executor's exact command there, remove the worktree. Red at base is a pre-existing flake,
  likeliest when `stop_reason` begins with `flaky?` (a red that did not reproduce on the
  executor's own retry): say so and resume once, under the same `resumes < 2` cap. Green at
  base implicates the diff: say the failure is unrelated by the plan but not by the evidence.
  If the command cannot run at base at all, which is common because a fresh worktree has no
  installed dependencies and the install step differs per stack, that is not evidence either
  way: say so and leave the call to the operator rather than building the environment. Beyond
  a `flaky?` red the base check exonerated, never resume a stop on your own. A stop naming an
  unresolved anchor is a plan defect too: quote it verbatim.

- `status: failed`, or `result.json` absent with `exit` not 143: outcome "failed", with the
  exit code and the last 30 lines of `executor.log`.

- `exit=143` or no `DELEGATE_DONE` line: outcome "cancelled / timed out (30m cap)". If
  `session.txt` is missing the run cannot be resumed; say so and offer a fresh
  `/delegate-plan`.

**7. Report, once, then stop.** Outcome line first. Then, as applicable: the `verify.sh`
table, the step table from
`result.json.steps` (labelled as the executor's claims), `git.json.files_touched` verbatim with fence
warnings, the `simplify: ran|skipped` line from `result.json.notes`, the source-plan note,
the worktree path, the run dir, and one before/after diagram per the `delta-diagrams` skill.

Close with the operator's menu. Print the first two lines only when your own re-run of the
closing verification is green, whatever `result.json.status` said:

      Review first (fresh session):  /code-review high --fix
      Ship it:                       /commit-open-pr   (say the executor already ran simplify, skip the cleanup)
      Not finished:                  /delegate-plan <executor> --resume "<instruction>"
      Discard:                       git worktree remove --force <worktree>

Send one `PushNotification` carrying the outcome line (the tool drops it by itself when
the operator is at the terminal). Stop there. Do not review, stage, commit, push, or open a
PR in this session.

## Resume mode

`/delegate-plan <executor> --resume ["<instruction>"]` locates the run dir: if `$PWD` is a
worktree, the newest run dir whose `freeze.json.worktree` equals `$PWD`; otherwise (fresh
session in the main checkout) the newest run dir whose `freeze.json.worktree` is under this
repo's `.claude/worktrees/`, then `EnterWorktree(path)` into it first. Say which run dir was
picked. Then run the same driver with `--resume "<instruction>"` under Monitor (step 5) and
continue at step 6. The driver increments `freeze.json.resumes` and reuses the id in
`session.txt` (`codex exec resume <id>`, `grok --resume <id>`, `copilot --resume=<id>`); it
never uses `--last`.

*claude:* the run is resumable only in the session that launched it, and only while that
agent still exists: `SendMessage` the instruction to the same agent, bump
`freeze.json.resumes` with the drivers' `jq` line, and on its next completion go through
`finish_claude.sh` and step 6 again. From a fresh session there is no agent to resume; say
so and offer a fresh `/delegate-plan claude`, exactly as the missing `session.txt` case does.

## Status mode

`/delegate-plan status [run-dir]`, or any mid-run "how is it going": run

    bash <delegate-plan-skill-dir>/scripts/status.sh [run-dir]

and print its output verbatim. That is the whole answer; do not read `executor.log`
yourself (it is hundreds of KB of JSONL), do not touch the Monitor, and do not add
interpretation beyond what the lines say. `phase: running` with a growing `tree` is
progress; `idle` is the same clock the stall detector uses, so it never disagrees with a
`DELEGATE_STALL`. A `finished` phase means step 6 is due (or already happened): the outcome
comes from that report, never from this snapshot.

Several delegations may run at once, one per worktree. The script resolves the run by the
worktree it is called from, exactly as resume mode does, and refuses rather than guessing
when the cwd is not a delegated worktree; pass the run dir explicitly in that case. The
operator can also run `/delegate-plan status` directly, or `! bash <the same command>` from
the prompt.

## Executor posture (auto mode)

Each executor runs in its CLI's auto mode, narrowed to what implementing needs:

- **codex**: `--approve-for-me` (Guardian auto-review over a workspace-write sandbox).
- **grok**: `--permission-mode auto`.
- **copilot**: `--allow-all-tools` narrowed by a deny-list. Every git write verb and all `gh`
  are refused; everything the plan needs to build and test is allowed, whatever the stack.
  The deny-list is the real gate: `--deny-tool` overrides `--allow-all-tools`, and copilot's
  assisted-approval judge does not engage in `-p` mode (1.0.81, with and without
  `COPILOT_ASSISTED_APPROVAL`). An allowlist is the wrong shape: its
  patterns match the command as written, a compound command is refused when any element is
  unlisted, and an executor legitimately writes things like `runner; status=$?; exit $status`.
- **claude**: a general-purpose subagent in this session's permission mode (it inherits
  it). No mechanical git fence: the wrapper's prose is the gate, and `git.json.committed`
  is the check. Model from `--model` or `config.json`; effort not settable on a subagent.

The exact flags live in the driver scripts; edit them there. Model and effort defaults
live in `config.json`, never in this file or the drivers.

## Suggested goal

    /goal <PLAN-FILE> is delegated: freeze.json written, worktree HEAD shown equal to the grounded SHA, DELEGATE_DONE line shown, git.json shows a non-empty working tree and committed=false, the plan's closing verification re-run by me in the worktree and shown green with exit 0, files_touched printed and checked against the plan's Out of scope list, and the operator menu printed. Nothing staged, committed, pushed or PR'd by me; any DELEGATE_STALL line was surfaced with a PushNotification and waited out, never killed or resumed; any blocked status was judged against the plan and either resumed (resumes < 2) or surfaced; any stopped status carrying a failing command was re-run by me before reporting, then surfaced, and resumed only when it was a flaky? red the base-commit check exonerated. Or stop after 20 turns.

## Don't

- Don't stage, commit, push, or open a PR here, and don't run `/code-review`. The menu in
  step 7 is where this skill ends.
- Don't use `EnterWorktree(name)`; it ignores the grounded commit.
- Don't trust `result.json` for what happened; `git.json` and your own re-run of the closing
  verification are the evidence. That holds on a `stopped` too: never report an executor's
  red without running it yourself.
- Don't resume a `stopped` run on your own, except a `flaky?` one the base-commit check
  exonerated. Don't resume `blocked` past `resumes = 2` or for a command outside the plan.
- Don't widen an executor's gate to let it commit, push, or use `gh`. If it asks, the
  wrapper's scope fence was breached.
- Don't call `ExitWorktree`; the operator's next move happens in that worktree.
- Don't kill, resume, or poll a run on a `DELEGATE_STALL` line; notify and wait for
  `DELEGATE_DONE`. Don't run `/loop` to watch a delegation; the Monitor already wakes
  the session on stall and completion. An on-demand status question is answered by
  `scripts/status.sh`, never by reading `executor.log` or the Monitor.
- Don't edit `~/.codex/config.toml`, `~/.grok/config.toml` or `~/.copilot/config.json`;
  every override is on the CLI.
- Don't hardcode a model or effort anywhere in this skill; the flag wins, then
  `config.json`, then the harness default. Don't pass `model` to the claude Agent call
  when it resolved to null; the subagent then inherits the session's model, which is what
  the operator expects.
