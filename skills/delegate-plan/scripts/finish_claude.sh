#!/usr/bin/env bash
# delegate-plan, claude executor: the subagent has finished and the host wrote its final
# reply to a file. Turn that into the same artifacts the CLI drivers leave behind, so step 6
# of the skill is identical for every executor: result.json (the model's claims, only when
# the reply parses as JSON), git.json (derived from git, never from the model), and one
# DELEGATE_DONE line.
#
# Usage: finish_claude.sh <run-dir> <reply-file>
set -uo pipefail
RUN="${1%/}"; REPLY="$2"
[ -f "$RUN/freeze.json" ] || { echo "DELEGATE_DONE executor=claude exit=2 result=$RUN/result.json"; exit 2; }
WT=$(jq -r .worktree "$RUN/freeze.json")
BASE=$(jq -r .grounded_sha "$RUN/freeze.json")

source "$(cd "$(dirname "$0")" && pwd)/_write_git_json.sh" \
  || { echo "DELEGATE_DONE executor=claude exit=3 result=$RUN/result.json"; exit 3; }

rm -f "$RUN/result.json"
# The reply is meant to be the bare JSON object; a code fence around it is tolerated.
LAST=$(sed -e 's/^```[a-z]*$//' -e 's/^```$//' "$REPLY" 2>/dev/null)
if [ -n "$LAST" ] && jq -e . >/dev/null 2>&1 <<<"$LAST"; then
  jq . <<<"$LAST" > "$RUN/result.json"
fi
write_git_json
echo "DELEGATE_DONE executor=claude exit=0 result=$RUN/result.json"
