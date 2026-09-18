---
name: wrap
description: Close an operator session on disk. Classify learnings verified vs idea and route them (personal memory, or the destination the project's instructions name), run the project's mandated close (proposal-act, GUEST_REPORT) and show its output, refresh the final-plan-check gauntlet with any question that bounced a plan this session, write the loose-ends line, give the plan file its issue name, print a five-line close. Trigger on "/wrap", "save learnings", "save this as a learning", "wrap this up", "wrap up", "close the session", and proactively before ending any session that produced a verdict, a plan, or a measurement. Do NOT use to commit or push (commit, commit-push), to open a PR (open-pr), or to write a handoff document for another agent (handoff).
---

# wrap

**Nothing that matters may live only in chat.** Learnings that exist only in the transcript, guest reports that expire unsent, verdicts reached but never written, and docs edits orphaned in an uncommitted worktree are all lost when the session ends. This skill closes all of them on disk in one pass.

## Procedure

**1. Classify.** List every candidate learning from this session and tag each one:
- **verified**: the transcript shows the command and its output, or a `path:line` that was read.
- **idea**: everything else. Ideas are written down as ideas, never as facts.

Every number in what you write is measured (the command and output appear in the transcript) or carries the label "estimate". Every verdict written down was reached in this session; never invent or upgrade one.

**2. Route.**
- How-I-work facts and harness facts go to the memory directory the system prompt names: one file per fact with the frontmatter that directory uses, plus one index line in its `MEMORY.md`. Check for an existing file that already covers it and update that one instead.
- Everything else goes to whatever destination the project's loaded instructions name. Read the project's `AGENTS.md`, `Codex.local.md`, and any startup-context text the session received; they name things like a `compiled/` directory with a schema, a proposal queue, a progress log. Use those, with their required frontmatter.
- No destination named by the project: memory only, and say so.

**3. Project-mandated close.** Run whatever those same instructions mandate at the end of a session, and show the output of each:
- A proposal verdict reached this session: run the project's proposal-act equivalent (in hermit repos, `/Codex-hermit:proposal-act` accept, defer or dismiss). No verdict reached: no call, and do not invent one.
- A guest report mandated by the startup context (in hermit repos, a `GUEST_REPORT:` line to the resident via SendMessage): send it. If the send is held for approval, also write it to the inbox file the instructions name, after checking that the path exists, and say which happened.
- Anything else the instructions list for session close (a progress-log entry, a session-close skill): run it.

Nothing mandated (a plain repo, a scratch directory): say "no project close mandated" and move on.

**4. Refresh the gauntlet.** If the operator bounced a plan this session with a question that is not already in step 7 of `<final-plan-check-skill-dir>/SKILL.md`, append it to that step's "Current gate" list in generic wording (no project names), and show the diff. No bounce, or the question is already there: skip, say nothing.

**5. Loose ends.** One line, always present:

    Loose ends: <uncommitted worktrees with paths> | <unsent messages> | <unrun probes> | none

**6. Plan file.** If plan-pipeline left a `~/.Codex/plans/<ISSUE>-<slug>.md` symlink, plan mode is over now, so make it real: remove the link, rename the harness plan file to that name. If the session used a plan file without a link, add an `Issue: <ISSUE or URL>` line at the top of its header. No plan file this session: skip.

**7. Five-line close.** Print exactly:

    Outcome: <one line>
    Artifacts: <paths or URLs, comma separated>
    Learnings: <n verified, m ideas, where they went>
    Loose ends: <same line as step 5>
    Next: <the one command to type next, or "nothing">

Then stop.

## Rules

- Never commits, never pushes. If step 2 or 3 left files in a git working tree, that shows up in the loose-ends line.
- Never edits a `AGENTS.md` or `Codex.local.md`; the gauntlet append in step 4 is the only skill file this skill touches.
- Never writes an idea as a fact, a guess as a measurement, or a verdict that was not reached.
- Everything written is shown: file paths for memory and knowledge files, command output for the mandated close, the diff for the gauntlet append.
