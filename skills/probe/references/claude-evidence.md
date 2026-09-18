# Claude evidence for hook and permission probes

Choose an instrument that can prove the question. Claude's final verdict is not itself evidence that a tool ran, a permission was granted, or a hook fired.

- Capture hook stdin into a file inside the exact scratch arm. For payload or firing-order questions, use that file as the completion condition; a later dialog can stall the assistant after the hook already ran.
- For tool execution and permission questions, inspect the actual tool call and tool result. When terminal redraws obscure them, locate only the record for the exact scratch cwd under Claude's `~/.claude/projects/` directory. Parse entries by role and tool-use identity, not a whole-file text match that could include prompt echoes. Never substitute an outer CLI's storage path.
- For latency, use timestamps that actually bracket the operation or Claude debug timing for that operation. If the installed release does not expose suitable timestamps or fields, report the measurement unavailable rather than inferring duration from a verdict or aggregate elapsed time.
- Record the Claude version, tested mode, and observed trust state. A permission-mode flag is not evidence that workspace trust was accepted.

## Dated findings to recheck when relevant

These findings come from the existing Claude-native probe workflow. They are investigation leads, not guarantees about the installed release:

- On Claude 2.1.232, an untrusted scratch workspace could execute tools while skipping hooks; debug output reported `workspace trust not accepted`.
- On Claude 2.1.258, `acceptEdits` could still prompt for a write in an untrusted scratch workspace. A pending call was not proof of execution.
- Claude 2.1.232 exposed `permissionDecisionMs` in debug logs for some permission decisions. Confirm its meaning and presence before using it as a timing instrument.

Establish trust through the documented flow only when the actual dialog is present and authorization permits it. Do not silently edit the user's global trust database or blindly answer an unrecognized permission prompt to complete a probe. A probe that cannot establish its prerequisites is INCONCLUSIVE.
