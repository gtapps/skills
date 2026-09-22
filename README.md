# Personal agent skills

Reusable skills for Codex, Claude Code, Grok CLI, and Copilot CLI. Each directory under `skills/` is one installable skill, with its supporting scripts, references, and assets.

## Install and use

Requires Node.js/npm and the agent you intend to use. From this checkout, list the catalog and install selected skills at user scope:

```bash
npx skills add . --list
npx skills add . --skill commit worktree-ship --agent codex --global
npx skills add . --skill commit delegate-plan --agent claude-code --global
```

Once the repository is published, replace `.` with its GitHub `OWNER/REPO` or Git URL. Private repositories use your existing Git authentication. To install into a project instead, run from that project, use the repository URL or absolute checkout path, and omit `--global`.

Start a fresh agent session and invoke `$commit` in Codex or `/commit` in Claude Code. There is no plugin namespace. Add `--copy` to an installation command if you want independent agent copies; the default uses a canonical installed copy and agent links. Neither mode links back to this source checkout.

For Git-sourced installations, update selected skills with:

```bash
npx skills update commit delegate-plan --global
```

For local-path installations, pull changes into the checkout and rerun the original install command. Keep source edits in this repository; updates can replace edits made to installed copies.

See the [Vercel skills CLI documentation](https://github.com/vercel-labs/skills#readme) for installation and update options.

## Included skills

- Planning and review: `tackle-task`, `plan-pipeline`, `plan-implementation`, `plan-to-artifact`, `final-plan-check`, `delegate-plan-review`, `review-findings`.
- Execution and delivery: `delegate-plan`, `delegate-ship`, `worktree-ship`, `commit`, `commit-push`, `commit-open-pr`, `open-pr`, `simplify`.
- Investigation and reporting: `probe`, `task-report`, `wrap`.
- Visual work: `algorithmic-art`, `artifact-design`, `artifact-diagramming`, `canvas-design`, `dataviz`.

To reproduce the existing Claude selection, install these 17 skills:

```bash
npx skills add . --agent claude-code --global --skill \
  tackle-task delegate-plan delegate-plan-review delegate-ship \
  plan-pipeline plan-to-artifact probe task-report worktree-ship wrap \
  plan-implementation commit-open-pr commit commit-push open-pr \
  final-plan-check review-findings
```

The existing Claude selection excludes `simplify`, `algorithmic-art`, `artifact-design`, `artifact-diagramming`, `canvas-design`, and `dataviz`. In particular, Claude uses its bundled `/simplify`. Choose skills explicitly instead of using `--all` to preserve that selection.

## Structure and maintenance

Most skills keep their original `SKILL.md`. Five preserve separate workflows inside one package: `plan-to-artifact`, `probe`, `task-report`, `worktree-ship`, and `wrap`.

```text
skills/task-report/
  SKILL.md                 # Select the workflow for the current host
  references/agents.md     # Original .agents workflow
  references/claude.md     # Original Claude Code workflow
  scripts/                 # One copy of identical supporting files
```

Select the workflow by the host running the skill, not by the model provider, delegated executor, or harness being tested. Claude Code delegating to Codex still uses the Claude workflow. Existing model-specific prose, executor defaults, and constraints stay in the selected reference.

`delegate-plan`, `delegate-plan-review`, `delegate-ship`, and `plan-pipeline` keep the original Claude Code workflow directly in `SKILL.md`, without a routing entrypoint or separate workflow reference. Install these four for Claude Code; they are not supported as workflows hosted by Codex, Grok CLI, or Copilot CLI. Claude can still use their bundled scripts to delegate to those executors.

Preserve existing workflow prose when maintaining these packages. Keep organization and path fixes separate from behavior changes. Resource paths in the moved workflows remain relative to the package root; Markdown links are relative to their containing document. Resolve `<name-skill-dir>` to the absolute installed location of the named skill before executing a command.

This checkout is the source of truth. For local authoring, individual user-scope skill folders can later be symlinked directly to `skills/<name>` here. Those links share edits with the checkout and are maintained through Git, independently of Vercel-managed installations. Do not install over an authoring link. Installing from this repository does not migrate existing user-scope folders automatically.

## Dependencies and compatibility

The catalog preserves existing workflows; packaging does not establish compatibility with every agent. The four Claude-only workflows require Claude-specific host capabilities. The remaining workflows retain platform-specific assumptions that need a separate compatibility review. Artifact publishing depends on tools available in the host; the existing workflows describe local HTML fallbacks.

Install dependencies needed by the selected workflow. External references include `grilling` for `plan-pipeline`, `delta-diagrams` for planning and execution workflows, `code-review` for `delegate-ship`, and `babysit-prs` for the Claude PR handoff. These are not bundled here. Follow each skill's requirements for authenticated executor CLIs, Git/GitHub access, `jq`, Python, tmux, and other tools. Missing dependencies are not supplied by the installer.

Bundled license files and font notices remain with their assets. No repository-wide license is assigned by this import.
