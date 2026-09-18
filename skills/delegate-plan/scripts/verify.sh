#!/usr/bin/env bash
# delegate-plan step 6, check 2: re-run the plan's closing verification inside the worktree,
# from a script the worktree checker can see through. Prints one row per line of the plan's
# "## Closing verification" block, "<exit>  <command>", and exits 0 only when every row is 0.
# Each command's output goes to <run-dir>/verify.log. Exit codes only: a "# 1 each" comment
# is a note for the reader, not an assertion. A prose line runs literally and shows its real
# exit (usually 127), which is the plan's defect made visible.
#
# Usage: verify.sh <run-dir>
set -uo pipefail
RUN="${1%/}"
[ -f "$RUN/freeze.json" ] || { echo "verify: $RUN has no freeze.json" >&2; exit 2; }
WT=$(jq -r .worktree "$RUN/freeze.json")
[ -d "$WT" ] || { echo "verify: worktree $WT is missing" >&2; exit 2; }

# The first fenced block under the heading. A trailing comment introduced by two or more
# spaces and '#' is dropped; a '#' inside a command (a grep pattern) is not touched.
LINES=$(awk '/^## Closing verification/{h=1;next} h&&/^```/{f++; if(f==2)exit; next} h&&f==1' "$RUN/plan.md" \
        | sed -E 's/[[:space:]]{2,}#.*$//' | sed '/^[[:space:]]*$/d')
[ -n "$LINES" ] || { echo "verify: no '## Closing verification' block in $RUN/plan.md" >&2; exit 2; }

: > "$RUN/verify.log"
FAIL=0
while IFS= read -r cmd; do
  printf '$ %s\n' "$cmd" >> "$RUN/verify.log"
  (cd "$WT" && bash -c "$cmd") </dev/null >> "$RUN/verify.log" 2>&1
  rc=$?
  echo "[exit $rc]" >> "$RUN/verify.log"
  printf '%s  %s\n' "$rc" "$cmd"
  [ "$rc" -eq 0 ] || FAIL=1
done <<< "$LINES"
exit $FAIL
