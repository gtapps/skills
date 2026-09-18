---
name: probe
description: "Consult shared Claude Code probe results or test its harness behavior through a real interactive Claude session in tmux, driven by Codex, Grok CLI, or Copilot CLI. Excludes tests of those outer CLIs and application tests."
---

# Probe

Use one send, one bounded readiness wait, one bounded completion wait, and one harvest. Keep the inner subject a genuine interactive Claude Code session.

The outer CLI runs shell commands and collects their completion through its available command/wait tools. Do not require Claude's `Monitor`, `Agent`, or memory tools. Returning an outer tool's running-process handle is not completion; retain it and use that harness's wait/output mechanism for the same process.

## Shared results

Before any probe setup, search `~/.agents/probe-results/` for the question. This is the shared result store for all callers; the tested harness remains Claude Code. For "consult only" requests, report matching findings, their version/date/settings, and any gaps, then stop without launching a probe. Missing or inconclusive records are valid lookup outcomes.

For a normal probe request, reuse a conclusive finding only when the installed Claude Code version and relevant configuration match (model, thinking/effort, permission mode, trust, hooks/settings, and interactive versus headless context as applicable). Missing details, a mismatch, or an INCONCLUSIVE result do not settle the question. An explicit request to re-probe overrides reuse.

Save each new result, including INCONCLUSIVE, as one Markdown file per question in `~/.agents/probe-results/`. Include the question, Claude Code version, date, relevant settings, launch/declaration, verdict per arm, observed evidence, and evidence locations. Preserve any evidence needed from scratch files before teardown. Update an existing question's file with the new result on top and the previous result under `Superseded:`. Report the saved path. No separate index or copy in harness-specific memory is needed.

## Preflight

1. Confirm `claude` is installed and inspect `claude --version` and `claude --help`.
2. Confirm `tmux` is installed and `tmux -V` succeeds.
3. If tmux fails, report the exact prerequisite error and stop. Do not replace the inner tmux session with the outer CLI's PTY, headless mode, or another terminal driver.
4. Choose the permission mode required by the question: `plan`, `acceptEdits`, or `bypassPermissions`.
5. Choose model, thinking, and effort using the reasoning policy below. Use Sonnet for auto-mode safety-classifier probes because Haiku may silently change the measured mode.
6. Declare the question, one or two arms (differing in one named variable), model, thinking, effort where supported, any exception rationale, actual evidence source, and timeout before setup. For hook, permission, or latency questions, read [Claude evidence](claude-evidence.md) and choose the measurement before launching.
7. If renderer onboarding is needed, normalize it in a throwaway gated tmux session before the formal probe. Attach `pipe-pane`, release Claude, and take one startup `capture-pane` after output begins. If and only if the visible pane is the exact `Try the new fullscreen renderer?` dialog documented on Claude 2.1.220, send Escape to select the non-enabling path, then tear down that throwaway session and start the real probe fresh. If the pane is anything else, send no input. This dated setup exception is outside the formal probe evidence; do not assume a current release shows that dialog.

## Reasoning policy

Default to Haiku with thinking disabled for mechanical probes, such as reading a fixture, invoking a specified tool, or triggering a hook. The launch examples below use `env MAX_THINKING_TOKENS=0` for this default.

Before launch, the outer agent chooses sufficient reasoning for the requested behavior and briefly justifies any exception. Enable thinking when the inner task requires interpretation or several dependent decisions. For models that support effort, choose low for straightforward execution, medium for meaningful reasoning, and higher only with a concrete justification. Do not assume `--effort low` controls Haiku or disables thinking.

Use launch-scoped overrides only. To enable thinking, remove the zero-budget override and explicitly enable thinking for that launch, accounting for inherited settings and environment. Check the installed CLI and provider support and verify the effective configuration; a prompt cannot override disabled thinking. See [Claude Code thinking and effort controls](https://code.claude.com/docs/en/model-config#extended-thinking).

When a model, thinking setting, or production configuration is part of the question, reproduce it instead of applying the cheap default. Keep model, thinking, and effort fixed within each measured arm; between arms, change only the declared variable. Include these choices and any exception rationale in the declaration and report.

Seek decisive evidence, not a confirming verdict. Never increase effort merely to confirm a claim. After an inconclusive result, increase reasoning only when the evidence points to insufficient reasoning rather than a harness failure.

## Protocol

1. Choose a unique `probe-<slug>-<run-id>` session name and create one exact scratch directory with `mktemp -d /tmp/probe-<slug>-<run-id>.XXXXXX`. Record its resolved absolute path, require it to match `/tmp/probe-<slug>-<run-id>.*`, and put only minimal fixtures there.
2. Create a one-shot FIFO with `mkfifo "$D/launch.fifo"` inside the scratch directory. Start the tmux pane with a shell that blocks on one read from that FIFO and then `exec`s the real interactive Claude command:

       tmux new-session -d -s "$S" -x 220 -y 50 -c "$D" \
         "bash -lc 'read -r < \"$D/launch.fifo\"; exec env MAX_THINKING_TOKENS=0 claude --model haiku --permission-mode <mode>'"

   Adjust the model and thinking override for the declared exception under the reasoning policy; use Sonnet for classifier probes. Keep the Claude command; never replace it with the outer CLI. If the installed Claude version rejects an interactive option, report the probe INCONCLUSIVE rather than switching to `claude -p`.

3. Attach pane logging while the launch gate is still closed:

       tmux pipe-pane -o -t "$S" "cat >> $D/probe.log"

   Release the FIFO once with `printf '\n' > "$D/launch.fifo"`, causing the pane shell to become the real Claude process. This closes the startup-output race: every dialog is logged before the readiness phase begins.
4. Perform one readiness phase, bounded to 60 seconds, through one long-running `timeout` plus `tail -F` command session. It must:

   - wait for the workspace-trust dialog or the normal input prompt;
   - send Enter once only when the trust dialog is actually present;
   - after accepting trust, continue in the same bounded readiness command until the normal prompt appears;
   - exit immediately when the normal prompt is ready.

   Do not assume the trust dialog appears. Do not send blind input or answer any other modal. Do not sleep-loop, poll, or repeatedly capture the pane.
5. Send the complete probe prompt literally, then send Enter separately.
6. Generate a unique completion nonce and split it into two fragments. The complete nonce must never appear contiguously in the injected prompt. End the prompt by giving the fragments separately and instructing Claude to concatenate them in the final line, for example:

       Finish with exactly one final line and nothing after it. Concatenate fragment A `PROBE_DONE_7f3a` with fragment B `_91bc`, then append `: <CONFIRMED|REFUTED|INCONCLUSIVE> - <one-line evidence>`.

   Here the completion matcher waits for `PROBE_DONE_7f3a_91bc`, which is output-only.
7. Perform one completion wait, bounded to ten minutes, for the complete nonce in `probe.log`. Use one `timeout` plus `tail -F` piped to `grep -m1` through the command-session waiting mechanism. Do not loop.
8. Strip ANSI sequences and harvest the nonce line plus up to ten surrounding lines. Verify the matching occurrence is after the requested action evidence and belongs to assistant output (the response block marked by Claude's `●`), not echoed user input. If that cannot be proved, report INCONCLUSIVE rather than accepting the match.
   A completion marker only proves the response ended. Judge the claim against the declared instrument, including actual tool results or hook payloads where relevant. If terminal redraws obscure the output, use the exact scratch arm's Claude record as described in the evidence reference; never search unrelated runs.

## Timeout

If no completion nonce appears within ten minutes:

1. Capture the tmux pane exactly once for post-mortem.
2. Classify the result as `INCONCLUSIVE - timeout`.
3. Include the final pane evidence.

Never capture the pane before a timeout.

## Teardown and report

Kill only the named tmux session. Before cleanup, resolve and revalidate that the scratch path is the exact recorded `/tmp/probe-<slug>-<run-id>.*` directory. Remove only that directory using `rm -r`, never `rm -rf`, unless the user asked to retain evidence.

Report:

    ## Probe verdict
    **Claim:** <question tested>
    **Claude command:** <full launch command, including model, permission mode, and thinking/effort overrides>
    **Reasoning:** <effective thinking setting, effort where supported, and any exception rationale>
    **Prompt:** <literal probe prompt>
    **Evidence:** <output-only nonce line and actual observations supporting the verdict>
    **Verdict:** CONFIRMED | REFUTED | INCONCLUSIVE

Include the tested Claude version and any missing measurement. Save the result using Shared results above.

## Banned

- `claude -p`, print mode, or any headless replacement.
- The outer CLI as the inner test subject.
- A non-tmux terminal fallback.
- `--no-session-persistence` in the interactive Claude command.
- Launching Claude before `pipe-pane` is attached.
- Blind trust-dialog input or input to an unrecognized modal.
- A completion token that appears contiguously in the injected prompt.
- Sleep loops, repeated polling, or repeated `capture-pane`.
- More than one readiness wait or one completion wait.
