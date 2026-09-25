---
name: review-to-pr
description: Ships work that is implemented but not yet reviewed. Verifies it, commits it locally, has a reviewer with a fresh context review the change (a /code-review subagent in Claude Code, a separate reviewer CLI in Codex, Grok CLI or Copilot CLI), applies the fixes, re-verifies, and opens or updates the PR, so no /clear or second session is needed. Trigger on "/review-to-pr [--level <l>] [--model <m>] [--reviewer claude|codex|grok|copilot]", "review and ship this", "code-review it then open the PR", "review it with opus and PR it", and when worktree-ship reaches its publish step. Do NOT use for planning, for work an executor still has to implement (delegate-ship), for a review with no commit or PR (/code-review), or for someone else's open PRs (babysit-prs).
argument-hint: "[--level low|medium|high|xhigh|max] [--model <m>] [--reviewer claude|codex|grok|copilot]"
compatibility: Claude Code, Codex, Grok CLI, or Copilot CLI as host. Needs gh and the commit and open-pr skills; code-review in Claude Code; review-findings and a reviewer CLI on the other hosts.
---

# Review to PR

Choose the workflow for the host running this skill, not the reviewer or the model under review:

- Claude Code: read [the Claude workflow](references/claude.md).
- Codex, Grok CLI, or Copilot CLI: read [the agents workflow](references/agents.md).

Read only the matching workflow. If the host is unclear or not listed, ask which workflow applies.

Resource paths such as `scripts/` and `references/` are relative to this skill's package root, the directory containing this `SKILL.md`. Resolve `<name-skill-dir>` placeholders to the absolute installed directory of the named skill before executing a command; they are not literal shell syntax.
