---
name: tackle-task
description: "Investigate a GitHub issue or pasted proposal, test its premise, and recommend whether to proceed. Read-only; does not implement."
---

# Tackle Task

Treat every issue or proposal as a hypothesis, not a specification. Attempt to disprove it before planning a fix. Keep the entire workflow read-only.

## Resolve the input

For a GitHub issue, fetch:

    gh issue view <number> --json title,body,labels,comments,author,state,url

Fetch referenced GitHub issues or PRs when they carry load-bearing context. Treat proposal identifiers such as PROP-123 as opaque unless the user provides the proposal. Check for an existing open PR:

    gh pr list --state open --search "<issue-number>"

If the issue is closed, surface that fact before continuing. For pasted content, use it directly. If no issue or task is identifiable, ask for it.

## Falsify the premise

Scale the investigation to the blast radius:

1. Reproduce the claimed bug when safe, or inspect the real implementation path.
2. Search for the feature under related symbols and names.
3. Verify cited paths, symbols, callers, tests, and documentation.
4. Inspect relevant history when the task may be stale.
5. Probe live behavior when a load-bearing claim cannot be settled from code.

Use rg for repository search and read the actual files on disk. Label recalled facts as unverified. Absence in a searched tree is not proof of absence in deployments or live systems.

## Choose the premise verdict

- Confirmed as-is: the framing and proposed approach match reality.
- Refined approach: the premise holds but a simpler fix exists.
- Corrected scope: work is needed but the task is shaped incorrectly.
- Nothing to do: the premise is false or already resolved.

Use Nothing to do only after a strong falsification attempt. Never base it solely on grep silence. For this verdict, output only the verdict, evidence, and suggested issue action; do not manufacture a plan.

## Choose the recommendation

- SHIP: net positive and ready.
- SHIP WITH CAVEAT: proceed with a concrete named risk or follow-up.
- DEFER: worthwhile after a named blocker or dependency.
- SKIP: technically valid but not worth its complexity or maintenance cost.

## Output

Use this structure:

    ## Verdict: <verdict>
    ## Evidence
    - <path:symbol or command> -> <what it established> [read code | probed live | unverified]
    ## Trade-offs
    **Pros:** <specific value>
    **Cons:** <specific cost or risk>
    **Cost of doing nothing:** <specific consequence>
    ## Recommendation: <recommendation>

For SHIP or SHIP WITH CAVEAT, append a minimal proposed approach, files to touch, and verification plan. When the verdict is Refined approach or Corrected scope, state every deviation from the source task as a table:

    | Source proposed | This plan does instead | Why |
    |---|---|---|

## Boundaries

- Do not edit files, create branches, comment, label, close, assign, push, or open a PR.
- Do not change collaboration mode. In Plan Mode, remain read-only and let the user decide what happens next.
- Keep every proposed line traceable to the verified task; move unrelated observations outside the plan.

