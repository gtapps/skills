---
name: probe
description: "Consult shared Claude Code probe results or empirically answer a harness-behavior question through a real interactive session in tmux. Supports consult-only lookup. Excludes application testing and headless substitutes for interactive probes. Scratch probes run without asking; results are saved to ~/.agents/probe-results/."
---

# probe

**One send, one wait, one read.** The transcript streams to a file the instant the session starts; you never poll the pane. A correct probe is ≤ ~8 tool calls per arm end to end; a send-keys/sleep/capture-pane loop is the failure this protocol exists to prevent.

## Why tmux, not headless

`claude -p` (headless / print mode) is **banned** for probes in this setup — it does not exercise the real interactive harness the operator is asking about, and it's on a deprecation path here. Always drive a genuine interactive session in tmux.

## Autonomy

A scratch fixture is yours to run: its own directory from `mktemp -d`, its own tmux session, torn down at the end. Once the question is clear, run it and report the verdict; never ask "want me to run the probe?" Ask first only when the target is a live resident session, a real project file, or anything outside the scratch dir. The `~/.claude.json` trust seed in the hook gotchas stays as written there: back up, edit, delete the entry at teardown.

## Shared results

Before any probe setup, search `~/.agents/probe-results/` for the question. This is the shared result store for all callers; the tested harness remains Claude Code. For "consult only" requests, report matching findings, their version/date/settings, and any gaps, then stop without launching a probe. Missing or inconclusive records are valid lookup outcomes.

For a normal probe request, reuse a conclusive finding only when the installed Claude Code version and relevant configuration match (model, thinking/effort, permission mode, trust, hooks/settings, and interactive versus headless context as applicable). Missing details, a mismatch, or an INCONCLUSIVE result do not settle the question. An explicit request to re-probe overrides reuse.

Save each new result, including INCONCLUSIVE, as one Markdown file per question in `~/.agents/probe-results/`. Include the question, Claude Code version, date, relevant settings, launch/declaration, verdict per arm, observed evidence, and evidence locations. Preserve any evidence needed from scratch files before teardown. Update an existing question's file with the new result on top and the previous result under `Superseded:`. Report the saved path. No separate index or copy in harness-specific memory is needed.

## Before launching

**0. Recall.** Follow Shared results above before declaring or setting up a probe.

**Declare.** Print this block in chat before any setup, then follow it exactly:

    Question:   <the harness claim, one line>
    Arms:       <one arm, or two arms that differ in exactly one named thing: model, permission mode, or settings>
    Reasoning:  <model, thinking setting, effort where supported, and any exception rationale>
    Ops:        <the exact tool calls the session must perform>
    Instrument: sentinel line | arm jsonl | --debug log | hook payload file
    Timeout:    <seconds>
    Nonce:      <output of `openssl rand -hex 2`>

## Reasoning policy

Default to Haiku with thinking disabled for mechanical probes, such as reading a fixture, invoking a specified tool, or triggering a hook. The launch examples below use `env MAX_THINKING_TOKENS=0` for this default.

Before launch, the outer agent chooses sufficient reasoning for the requested behavior and briefly justifies any exception. Enable thinking when the inner task requires interpretation or several dependent decisions. For models that support effort, choose low for straightforward execution, medium for meaningful reasoning, and higher only with a concrete justification. Do not assume `--effort low` controls Haiku or disables thinking.

Use launch-scoped overrides only. To enable thinking, remove the zero-budget override and explicitly enable thinking for that launch, accounting for inherited settings and environment. Check the installed CLI and provider support and verify the effective configuration; a prompt cannot override disabled thinking. See [Claude Code thinking and effort controls](https://code.claude.com/docs/en/model-config#extended-thinking).

When a model, thinking setting, or production configuration is part of the question, reproduce it instead of applying the cheap default. Keep model, thinking, and effort fixed within each measured arm; between arms, change only the declared variable. Include these choices and any exception rationale in the declaration and report.

Seek decisive evidence, not a confirming verdict. Never increase effort merely to confirm a claim. After an inconclusive result, increase reasoning only when the evidence points to insufficient reasoning rather than a harness failure.

## Protocol

**1. Setup (per arm).** `S=probe-<slug>-<arm>`; `D=$(mktemp -d /tmp/$S.XXXX)`. Write any minimal fixtures into `$D` only. With two arms, run steps 1 to 3b for both, back to back, before any wait.

**2. Launch the real session:**

    tmux new-session -d -s "$S" -x 220 -y 50 -c "$D" "env MAX_THINKING_TOKENS=0 claude --model haiku --permission-mode <mode>"

Do NOT pass `--no-session-persistence` — since at least CC 2.1.207 it errors out in interactive mode ("can only be used with --print mode") and the session dies at launch. The scratch dir keeps transcripts contained; no persistence flag is needed.

Model rule: follow the reasoning policy above; probes of the auto-mode safety classifier require `--model sonnet` (haiku silently falls back to acceptEdits and you'd measure the wrong thing). `<mode>` is the permission mode the question needs: `plan`, `acceptEdits`, or `bypassPermissions`.

Append `--debug` to the launch command when the instrument is the `--debug` log (gotcha 6).

**3. Immediately stream the transcript to a file** (before sending anything):

    tmux pipe-pane -o -t "$S" "cat >> $D/probe.log"

**3b. Trust dialog.** A fresh scratch dir always triggers the workspace-trust dialog ("Is this a project you created or one you trust?"), and pre-approved permissions in `.claude/settings.local.json` add a confirmation to it. Send one Enter ~5s after launch to accept the default ("Yes, I trust this folder"): `tmux send-keys -t "$S" Enter`. Safe if the dialog already passed — a stray Enter on an empty prompt is a no-op.

**4. Readiness wait — ONCE.** Use the `Monitor` tool (load via `ToolSearch "select:Monitor"` if deferred) to wait until the prompt marker appears in `$D/probe.log` (the `❯` prompt line, or the mode footer `shift+tab to cycle`; "? for shortcuts" is not printed on CC 2.1.258); timeout 60s. Do not sleep-loop.

**5. Inject the probe.** Send the prompt as a literal, then Enter as a separate call:

    tmux send-keys -t "$S" -l '<probe prompt>'
    tmux send-keys -t "$S" Enter

The prompt MUST end by requiring one final line of the form `PROBE_VERDICT_<nonce>: <CONFIRMED|REFUTED|INCONCLUSIVE> — <one-line evidence>` and nothing after it.

**Sentinel-echo rule:** the injected prompt is echoed into `probe.log`, so the concatenated token must never appear in the prompt. Spell it in fragments: tell the model to print `PROBE_VERDICT_` immediately followed by the nonce and a colon. Every wait and harvest greps the concatenated `PROBE_VERDICT_<nonce>:`. Verify the harvested line is model output (prefixed by the `●` response marker), not prompt echo.

**6. Completion wait — ONCE.** One `Monitor` whose condition is `grep -q 'PROBE_VERDICT_<nonce>:'` succeeding on every arm's `probe.log`; timeout from the declaration. Fallback if Monitor is unavailable: ONE backgrounded Bash per arm, `timeout <s> tail -F -n +1 $D/probe.log | grep -m1 'PROBE_VERDICT_<nonce>:'`, which exits on match so the harness re-invokes you. Never a sleep loop.

**7. Harvest (per arm).** Read the verdict from the arm's session transcript, not the pane log: `probe.log` is a TUI byte stream with redraws, so a `grep -a` on it returns one huge blob.

    grep -ho 'PROBE_VERDICT_<nonce>:[^"]*' ~/.claude/projects/<munged $D>/*.jsonl

The munged dir is `$D` with every `/` and `.` turned into `-` (it starts with a dash, so always pass the absolute path). A match there is model output by construction: the user entry holds only the prompt fragments. Quote the verbatim line, plus the arm's tool_use names from the same jsonl, in a `## Probe verdict` block: claim, full launch command, effective model/thinking/effort settings and any exception rationale, verbatim evidence, verdict.

**8. Teardown.** `tmux kill-session -t "$S"`; `rm -r "$D"` (never `rm -rf`) unless the operator asked to keep it.

**9. Save.** Follow Shared results above. Include each verbatim `PROBE_VERDICT_<nonce>` line (or INCONCLUSIVE plus the final 20 pane lines), the declaration block, and each arm's exact Claude transcript path. The Claude transcript survives scratch teardown. Every probe ends here, INCONCLUSIVE included.

**Timeout policy:** if an arm shows no sentinel by the declared timeout, take ONE `tmux capture-pane -p -t "$S"` for post-mortem, kill the session, record that arm as `INCONCLUSIVE - timeout`, and quote the last 20 pane lines in the report and in the shared result record.

## Suggested goal

When launching a probe, print this line before any setup so the operator can paste it:

    /goal The harness question "<QUESTION>" is answered by the probe skill: one or two arms, and if two they differ in exactly one declared variable; each arm's PROBE_VERDICT_<nonce> line is quoted verbatim, or recorded INCONCLUSIVE with the last 20 pane lines; per-tool-call latency is reported for ask/hook questions; the verdict was saved to ~/.agents/probe-results/ with the Claude Code version and shown; no scratch probe waited for operator approval. Or stop after 8 turns.

## Banned

- `claude -p` / headless / print mode — always a real tmux session.
- Any `sleep`-then-poll loop. Waiting is done with `Monitor` (or the single `tail -F | grep -m1` fallback), never repeated polling.
- Repeated `capture-pane` — allowed exactly once, and only as the post-mortem after a timeout.
- More than one wait per phase (one readiness wait, one completion wait).

## Hook-probe gotchas (learned live, 2026-08-14, CC v2.1.232)

Probing hook behavior (payload shape, firing order) has extra traps:

1. **`--permission-mode <mode>` suppresses the workspace-trust dialog but records trust as NOT accepted — and untrusted workspaces silently skip ALL hook execution.** Tools still run, `/hooks` still lists the hooks as configured, nothing errors. The only tell is `--debug`: `Skipping PreToolUse:Bash hook execution - workspace trust not accepted` in `~/.claude/debug/<id>.txt`. Fix BEFORE launching a hook probe: pre-seed trust for the scratch dir —
   `jq '.projects["<scratch>"].hasTrustDialogAccepted = true' ~/.claude.json > t && mv t ~/.claude.json`
   (back up `~/.claude.json` first; delete the entry at teardown). A plain launch without `--permission-mode` may not show the dialog either, so don't rely on answering it interactively.
2. **Plugin `hooks/hooks.json` needs `"command": "<exe>", "args": [...]` (argv array).** A single command string with embedded spaces registers, renders correctly in `/hooks`, and never runs. Settings-file hooks accept the single-string form; plugin hooks do not.
3. **Permission `allow` rules in a scratch project's `.claude/settings.json` do not reliably suppress the WebFetch dialog** (even `WebFetch(domain:...)`). Script an auto-answer into the completion Monitor: if the pane shows `allow Claude to fetch`, send `1` + Enter.
4. **Capture hook stdin to a file the hook writes itself** (`{ printf '%s|' "$1"; cat; echo; } >> <scratch>/payloads.log`), and key the completion wait on the payload file, not the model's sentinel — a dialog stall then can't hide a successful capture.
5. When the probe question is about payload fields, **the session transcript JSONL is a second instrument**: `~/.claude/projects/<munged-path>/<session>.jsonl` records per-entry `cwd` and the model's RAW `tool_use` input (pre-normalization), which the hook payload may not match (e.g. `file_path` is normalized to absolute for hooks).
6. **Ask/hook questions: self-report is not the instrument.** Read the arm's jsonl (`tool_use` and `tool_result` entries carry timestamps, so their delta is the per-call latency; a denial appears as a `tool_result` saying "The user doesn't want to proceed"; `permission-mode` entries record the mode), or launch the arm with `--debug` and read `permissionDecisionMs` from `~/.claude/debug/<session>.txt` (seen on CC 2.1.232 as `[Stall] tool_dispatch_start ... permissionDecisionMs=20`; confirm the field on the current version in the first such probe).
7. **`--permission-mode acceptEdits` still prompts for a Write in an untrusted scratch dir** (CC 2.1.258, learned 2026-09-02): the arm stalls on "Do you want to create hello.txt? 1. Yes / 2. Yes, and allow ... / 3. No" until timeout, and the pending Write never reaches the jsonl. Trust, not mode, is what auto-accepts (see gotcha 1). Pre-seed trust before launch, or make the completion wait auto-answer `1` + Enter when the pane shows `Do you want to`.
