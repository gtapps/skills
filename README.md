# Personal agent skills

Reusable agent workflows for investigating tasks, planning, shipping code, and making reports or visuals. Each folder under `skills/` is one installable skill; install only what you need.

## Install

```bash
npx skills add gtapps/skills --agent claude-code --global
```

Pick skills when prompted, then start a fresh session. Leave `simplify` unselected to keep Claude Code's bundled `/simplify`. For another host, change `--agent`. Use `.` instead of `gtapps/skills` to install from this checkout; add `--skill <name>` to pick directly or `--list` to browse. See the [skills CLI](https://github.com/vercel-labs/skills#readme).

Update with `npx skills update <names> --global`. Edit skills in this repo, not in installed copies: updates overwrite them.

## Issue to PR in Claude Code

Every route starts with `/tackle-task`, which is read-only and ends in a verdict. Stop there on SKIP or DEFER.

| Task | Plan | Ship |
|---|---|---|
| Trivial: a clear fix of a few lines | None; fix it in the session | `/review-ship` |
| Simple: settled approach, few files | Plan mode, then `/plan-implementation` | `/clear`, then `/delegate-ship <executor> @<plan>` |
| Hard: open design choices or a wide blast radius | `/plan-pipeline`, or the steps below by hand | Same as simple |

Hard tasks by hand, in plan mode:

1. Draft the plan ("propose a plan"). Run `/grilling` first if requirements are still open.
2. Optional: `/delegate-plan-review <harness> [--model <m>] [--effort <e>] --verify`. Without `--verify`, run `/review-findings` on the review before changing the plan.
3. `/final-plan-check`.
4. `/plan-implementation`, last, so it encodes the reviewed decisions.

For example:

```text
/tackle-task https://github.com/OWNER/REPO/issues/123    # or @proposal.md
# discuss the verdict, then "propose a plan" in plan mode
/delegate-plan-review codex --effort high --verify
/plan-implementation
# approve the plan, then delegate from a clean context
/clear
/delegate-ship grok @~/.claude/plans/123-fix-timeout.md
```

- `plan-implementation` does not plan. It turns settled decisions into the `## Steps` and `## Closing verification` blocks that `delegate-ship` runs, so use it whenever a fresh context or another executor implements.
- `plan-pipeline` runs grilling, grounding, review, the final check, and `plan-implementation` with one approval. Go by hand to set the reviewer's `--model` or `--effort`.
- `delegate-ship` prints a `/goal` line; paste it so the session keeps going until the PR is open. If it stops to ask you, the goal ends; answer and paste the reprinted line.
- Executors are `grok`, `codex`, `copilot`, or `claude`. `/delegate-plan status` checks a running delegation. `/delegate-plan` alone stops at verified, uncommitted changes; `/worktree-ship` has the current session implement instead.
- `review-ship` runs `/code-review --fix` in a subagent with no session history, so there's no `/clear` and no second session. `--model <m>` picks the reviewer's model (default: the session's) and `--level` the review level (default `high`).
- `/worktree-ship` ends with `review-ship`; `/worktree-ship --no-worktree` implements in the current checkout instead of a worktree.
- In Codex, Grok CLI, and Copilot CLI, the review runs read-only in a separate CLI process: the host's own CLI by default, or another with `--reviewer claude|codex|grok|copilot`. The host checks each finding and applies the confirmed ones through `review-findings`.
- On a Codex host the reviewer command needs escalated permissions. With a private repository, Codex's automatic approval (`codex --approve-for-me`) refuses to send the diff to the reviewer unless your request approves it.
- `copilot -p` reads only the working directory, so launch it with `--add-dir` for the installed skills directory.
- Nothing here merges; an open PR still needs review.

Already have the changes? Use `/commit`, `/commit-push`, `/commit-open-pr`, or `/open-pr`.

## Hosts

Invoke skills as `/name` in Claude Code and Copilot CLI, or `$name` in Codex and Grok CLI.

- **Claude Code only:** `plan-pipeline`, `delegate-plan`, `delegate-plan-review`, `delegate-ship`. They can delegate to Codex, Grok, Copilot, or a Claude subagent.
- **Separate instructions per host:** `worktree-ship`, `review-ship`, `plan-to-artifact`, `task-report`, `probe`, `wrap`.
- Other skills share instructions but depend on the host's tools. The installer does not enforce these limits.

In Codex, Grok CLI, or Copilot CLI: `tackle-task`, draft a plan, `final-plan-check`, then `worktree-ship`.

## Skills

**Planning and review**

| Skill | What it does |
|---|---|
| [tackle-task](skills/tackle-task/SKILL.md) | Investigates an issue or proposal and recommends whether to proceed; read-only |
| [plan-pipeline](skills/plan-pipeline/SKILL.md) | Runs the whole planning chain in plan mode, ending in one approval |
| [plan-implementation](skills/plan-implementation/SKILL.md) | Turns settled decisions into an executor-ready plan |
| [final-plan-check](skills/final-plan-check/SKILL.md) | Critiques a plan against the code, scope, and complexity |
| [delegate-plan-review](skills/delegate-plan-review/SKILL.md) | Gets a second opinion from another harness; `--verify` checks it first |
| [review-findings](skills/review-findings/SKILL.md) | Verifies review findings against the code; fixes only on request |
| [plan-to-artifact](skills/plan-to-artifact/SKILL.md) | Renders a plan and its review trail as a page |

**Implementation and publishing**

| Skill | What it does |
|---|---|
| [delegate-plan](skills/delegate-plan/SKILL.md) | Another executor implements in a worktree; stops before committing |
| [delegate-ship](skills/delegate-ship/SKILL.md) | `delegate-plan`, then re-verification, code review, commit, and PR |
| [worktree-ship](skills/worktree-ship/SKILL.md) | This session implements in a worktree and opens a PR |
| [review-ship](skills/review-ship/SKILL.md) | Commits finished work, has a fresh-context reviewer check it, applies the fixes, and opens the PR |
| [simplify](skills/simplify/SKILL.md) | Behavior-preserving cleanup of a diff |
| [commit](skills/commit/SKILL.md) | Cleanup, precise staging, and a local commit |
| [commit-push](skills/commit-push/SKILL.md) | Commits and pushes the current branch |
| [commit-open-pr](skills/commit-open-pr/SKILL.md) | Commits and opens a PR |
| [open-pr](skills/open-pr/SKILL.md) | Publishes existing work as a PR |

**Investigation and reporting**

| Skill | What it does |
|---|---|
| [probe](skills/probe/SKILL.md) | Answers questions about Claude Code behavior with a real session, or from saved results |
| [task-report](skills/task-report/SKILL.md) | Debriefs completed work with its changes and evidence |
| [wrap](skills/wrap/SKILL.md) | Closes a session: learnings, close steps, loose ends |

**Visuals**

| Skill | What it does |
|---|---|
| [artifact-design](skills/artifact-design/SKILL.md) | Self-contained HTML reports, dashboards, and explainers |
| [artifact-diagramming](skills/artifact-diagramming/SKILL.md) | Mechanism diagrams inside an HTML page |
| [delta-diagrams](skills/delta-diagrams/SKILL.md) | Behavioral before/after flows and decision branches; shared across hosts |
| [dataviz](skills/dataviz/SKILL.md) | Accessible charts |
| [canvas-design](skills/canvas-design/SKILL.md) | Static PNG or PDF posters and artwork |
| [algorithmic-art](skills/algorithmic-art/SKILL.md) | p5.js generative art with an interactive viewer |

**Dependencies:** `worktree-ship` (every host) and `delegate-ship` call `review-ship`, which calls `commit` and `open-pr`, plus `code-review` in Claude Code, or `review-findings` and a reviewer CLI on the other hosts. `commit-open-pr` calls `commit` and `open-pr`. `delta-diagrams` uses `artifact-design` for HTML pages; inline diagrams need no companion skill. Some skills need skills from outside this repo: `grilling` for `plan-pipeline`, `code-review` for `delegate-ship` and `review-ship`, and `babysit-prs` for PR follow-up.

<details>
<summary>Saved Claude Code selection</summary>

```bash
npx skills add . --agent claude-code --global --skill \
  tackle-task delegate-plan delegate-plan-review delegate-ship \
  plan-pipeline plan-to-artifact probe task-report worktree-ship review-ship wrap \
  plan-implementation commit-open-pr commit commit-push open-pr \
  final-plan-check review-findings
```

It uses Claude Code's bundled `/simplify` and leaves out the visual skills.

</details>

<details>
<summary>Authoring</summary>

Each `skills/<name>/SKILL.md` is the entrypoint; scripts, references, and assets stay in that folder. Skills with separate host instructions keep them in `references/claude.md` and `references/agents.md`. For live editing, symlink a user-scope skill folder to `skills/<name>` in this checkout, and don't install over that link.

</details>

Bundled license files and font notices stay with their assets. The repository has no overall license.
