# Claude Code review handoff

After opening or finding the PR, print these follow-up commands for the operator. Do not start the loop or activate the goal unless asked.

```text
/loop 15m /babysit-prs
/goal gh pr list shows zero open non-draft PRs with unaddressed review findings: each reviewed, confirmed findings applied and pushed with tests green, false findings refuted in a PR comment. Final gh pr list output shown as proof. Or stop after 20 turns.
```
