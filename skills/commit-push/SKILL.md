---
name: commit-push
description: "Commit the intended changes and push the current branch. Does not open a pull request."
---

# Commit and push

1. Invoke the available `commit` skill. Pass through `--no-simplify` only when the user requested it. That skill owns staging, cleanup, and the commit message; do not duplicate its gates or ask for message approval.
2. Resolve a failed commit or a material staging ambiguity before pushing. When the requested commit is already present, do not create an empty replacement.
3. Honor the repository's documented pre-push gates. Push the current branch to its existing upstream, or use `git push -u <intended-remote> <current-branch>` when it has none. Resolve the remote from current Git configuration and the user's request.
4. Direct default-branch pushes remain allowed when within the user's requested workflow. Never force-push or push other branches. On rejection, inspect and reconcile remote changes within scope, rerun affected checks, and retry; ask only if resolution requires a material decision.
5. Report the commit subject and destination branch/remote. Do not open a PR.
