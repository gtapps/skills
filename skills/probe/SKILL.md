---
name: probe
description: "Consult shared Claude Code probe results or test Claude Code harness behavior through a real interactive session. Excludes application testing and tests of the outer CLI."
---

# Probe

Choose the workflow for the host running this skill, not the model provider, delegated executor, or harness being tested:

- Claude Code: read [the Claude workflow](references/claude.md).
- Codex, Grok CLI, or Copilot CLI: read [the agents workflow](references/agents.md).

Read only the matching workflow and preserve its model-specific instructions. If the host is unclear or not listed, ask which workflow applies.

Resource paths such as `scripts/` and `references/` in the workflow are relative to this skill's package root, the directory containing this `SKILL.md`. Resolve `<name-skill-dir>` placeholders to the absolute installed directory of the named skill before executing a command; they are not literal shell syntax. Keep model and executor choices as specified by the selected workflow.
