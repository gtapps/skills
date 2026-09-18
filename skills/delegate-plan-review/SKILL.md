---
name: delegate-plan-review
description: >-
  Claude Code only. Send a plan to another harness for an adversarial second opinion: codex, grok or copilot
  read-only in a background Monitor process, or a claude Plan subagent. Reviews the current
  session's plan by default, or plan text the user pastes or points at. With --verify, every
  claim in the review is checked against the live code by /review-findings before anything
  reaches the plan, without asking. Trigger on "/delegate-plan-review <harness> [--model <m>]
  [--effort <e>] [--verify] [plan]", "have codex review this plan", "send the plan to grok",
  "get copilot to critique the plan", "second opinion on the plan from <harness>", "review the
  plan with <harness> and only apply what holds up", and proactively right after a plan-mode
  session when the user wants external review before executing. Do NOT use to implement a plan
  (delegate-plan), for Claude's own final critique (final-plan-check), or to verify findings
  you already have (review-findings).
compatibility: >-
  Requires Claude Code as the host; Codex, Grok, and Copilot may be delegated executors.
  Requires jq, the Monitor tool, and the chosen CLI (codex, grok or copilot) authenticated; the
  claude harness needs only the Agent tool. --verify delegates to the review-findings skill.
---

# delegate-plan-review

Resolve `<name-skill-dir>` to the absolute installed directory of the named skill before executing the commands below.

Hand a plan to a harness that did not write it and get an adversarial review back, while the
user keeps working. The mental model: *"imagine I'm copying a plan into codex / grok /
copilot / a fresh claude."* This skill grabs the plan that is already in play (or whatever the
user pastes on top), sends it, and surfaces the review attributed to that harness.

The ask is not a polite review. The reviewer is told to treat the plan as one candidate
rather than the presumed solution: verify the diagnosis, hunt for the deepest appropriate
fix, challenge model-driven or duplicated orchestration, prefer deterministic ownership at
the layer that owns the data, and answer in a fixed six-part structure (premise, problems,
best design, trade-offs, files and regression tests, verdict), grounded in the live repo
with `path:line` citations. That prompt is `prompt.md` in this skill dir, one copy for every
harness, so two reviews differ only in who wrote them.

Invocation: `/delegate-plan-review codex|grok|copilot|claude [--model <m>] [--effort <e>] [--verify] [plan]`.

Model and effort: the flag if given, else the harness entry in `config.json`, else the
harness default (`null`). Never pick one here. The claude harness takes `--model` (it becomes
the Agent call's `model`) but has no effort control; when an effort resolves for claude, say
in one line that it is ignored and go on.

## Files

- `prompt.md`: the adversarial ask, ending in the `--- PLAN UNDER REVIEW ---` delimiter. Edit
  it here, nowhere else.
- `config.json`: per-harness default `model` and `effort`, `null` meaning the harness default.
- `scripts/review.sh <harness> <plan-file> <review-out> <log> [--model <m>] [--effort <e>]`:
  the CLI drivers (codex, grok, copilot) in one script. Runs the harness read-only, writes
  its final answer to `<review-out>` and everything else to `<log>`, and prints exactly one
  stdout line: `REVIEW_DONE harness=<x> exit=<rc> review=<path> log=<path>`.

## Step 1: get the plan

Resolve the text to review, in this order:

1. **Text the user pasted or typed with the request wins**: a pasted block, "review this:
   ...", or a referenced plan file. Use exactly that.
2. **Otherwise the current session's plan**: the plan-mode draft (the file the plan-mode
   reminder names, under `~/.claude/plans/`), or the most recent concrete plan produced and
   discussed this session. Verbatim; never re-summarize or trim it.
3. **If neither exists, ask**: "What plan should <harness> review? Paste it or point me at
   it."

Pick a working directory (this session's scratchpad dir if it has one, else
`mkdir -p /tmp/delegate-plan-review`) and write the plan there as `<workdir>/plan.txt` with
the Write tool (not a heredoc: Write preserves formatting and special characters exactly).
Also note where the plan actually lives (plan-mode draft, or a `~/.claude/plans/*.md` path):
`--verify` needs it to know whether there is a real plan to patch, and `plan.txt` is only the
copy the reviewer reads.

> Use literal absolute paths from here on. Shell variables set in one Bash call do not
> survive into a Monitor call.

## Step 2: launch

**codex, grok, copilot:** one Monitor, with the real paths written out:

    Monitor(
      command: 'bash <delegate-plan-review-skill-dir>/scripts/review.sh <harness> <workdir>/plan.txt <workdir>/review.md <workdir>/<harness>.log [--model <m>] [--effort <e>]',
      description: '<harness> reviewing the plan',
      timeout_ms: 1800000)

Pass `--model`/`--effort` only when the operator gave them; the script consults
`config.json` itself. The 30-minute cap is generous for a bounded review. The one
`REVIEW_DONE` line is the event the Monitor delivers, and it carries the exit code, so a
crash can never look like success.

**claude:** a Plan subagent, in the background. Its tool set has no Edit or Write, so the
read-only fence is mechanical for file tools; a shell redirect is forbidden by the instruction
only. Concatenate `prompt.md` and `plan.txt` into `<workdir>/prompt-full.md` first, then:

    Agent(subagent_type: "Plan",
          description: "claude reviewing the plan",
          model: <resolved model, only when non-null>,
          prompt: "Read <workdir>/prompt-full.md (the review ask followed by the plan) and
                   answer it, grounded in the repository at <cwd>: read its files and git
                   history as needed. Read only; write nothing. Reply with the review in the
                   six-part structure the file asks for.")

Its completion notification is the end signal; on it, write the reply verbatim to
`<workdir>/review.md` with the Write tool. Prefer a model different from the one that wrote
the plan when the operator leaves the choice open, but never choose one silently: with no
flag and a null config, omit `model` and say the reviewer inherits the session's model.

Either way, tell the user it is running and that they can keep working. With `--verify`,
say now that the findings will be checked against the code before anything actionable is
shown; that stops the completion from turning into a "want me to verify?" exchange later.

## Step 3: surface the review

`exit` non-zero (or no `review.md` for claude): the harness errored. Read the tail of the
log and say what went wrong. The usual cause is authentication: if the log mentions
login/auth, tell the user to run the harness's login (suggest `! codex login`, `! grok
login`, `! copilot login` so it runs in this session) and offer to retry. Stop; there is
nothing to verify.

`exit=0`: read `review.md` and present it in full, attributed to the harness by name (it is
an outside opinion, not yours).

**Without `--verify`:** ask "Would you like me to run `/review-findings` with these?" and,
on yes, invoke the `review-findings` skill with the review as the findings to verify.

**With `--verify`:** do not ask. The reviewer worked in a separate process with no memory of
the conversation that produced the plan, so its output reliably mixes real problems with
misread context, stale line numbers and fixes for constraints the plan already handles.

1. Split the review into two buckets. **Checkable claims**: reading the repo or running
   something could show them wrong ("`validateUser()` already does this, see
   `auth/user.ts:40`", "this breaks when the queue is empty", "no test covers the retry
   path", "the premise is wrong because X does not behave that way"); mostly parts 1, 2 and
   5, plus the factual assertions load-bearing under part 3. **Judgments**: no amount of
   reading settles them ("over-engineered", "I'd prefer a different layering", the part 6
   verdict). Write the checkable claims, numbered, each with the reviewer's reasoning and
   any `path:line` it cited, to `<workdir>/findings.md`. Keep judgments out of that file.
   No checkable claims at all (a clean "the premise holds"): say so, show the review, skip
   to 3.
2. Invoke `review-findings` on `<workdir>/findings.md`, with: the reviewed plan is
   `<workdir>/plan.txt`, the live plan is at <location from step 1>, the reviewer ran in a
   separate process with no session context, so expect stale line numbers and locate by
   symbol, not line. Let that skill own the method (locate, read the file on disk rather
   than the quoted snippet, claim against actual behavior, evaluate the fix separately from
   the problem, classify Confirmed / Refuted / Partial / Needs investigation).
3. Present, in this order: verified findings (Confirmed and Partial, with their actions,
   highest severity first); refuted findings (one line each on what the reviewer misread,
   shown rather than dropped); the reviewer's judgment calls, labeled unverified and
   attributed. Then, on the plan itself: a live plan (plan mode active, or a
   `~/.claude/plans/*.md` was the input) gets the Confirmed and Partial actions applied,
   Partial only via the corrected fix established during verification, never Refuted, and
   nothing no finding names. No live plan (pasted text, a referenced doc): report only.
   Say which findings were applied and which were not. In plan mode, do not call
   `ExitPlanMode`; whether the revised plan is ready is the user's call.

## Why it is built this way

- **One prompt, four harnesses.** A review here and a review from another harness differ
  only in who wrote it, which is the point of a second opinion.
- **Read-only by mechanism, not by request** (verified 2026-09-04): codex `--sandbox
  read-only`; grok `--permission-mode dontAsk` plus `--deny 'Write(*)' --deny 'Edit(*)'`
  (dontAsk alone lets writes through; the deny rules also catch a shell redirect); copilot
  `--no-ask-user` with only read-only git allowed; claude a Plan subagent with no Edit or
  Write tool. Plan mode is never used for a review: it injects plan-writing framing, and its
  read-only guarantee was never verified where the deny rules were.
- **Prompt via file, plan last.** Plans are long and full of special characters; the
  instructions come first and the plan last behind a delimiter, so a long plan never blurs
  where the ask ends.
- **Adversarial framing, fixed structure.** An open-ended "review this" invites agreement.
  Forcing a verdict on the premise first is what makes the wait worth it, and the six-part
  shape is what `--verify` can split into claims.
- **One stdout marker per CLI run.** The Monitor stream stays quiet and the exit code rides
  on the line.
- **Claims and judgments are separated before verifying.** Verification settles factual
  disputes with evidence; feeding it taste produces confident-looking noise. Routing taste
  to the human keeps both halves honest.
