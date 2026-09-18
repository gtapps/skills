#!/usr/bin/env bash
# delegate-plan driver: copilot (allowlist posture).
#
# Usage: run_copilot.sh <run-dir> [--resume "<text>"]
#   <run-dir> holds prompt.md and freeze.json (worktree, grounded_sha, resumes).
#
# Writes into <run-dir>: executor.log (JSONL event stream), result.json (the final
# assistant message, if it parses as JSON), session.txt (session id), git.json (derived
# from git, never from the model). Prints exactly one stdout line, DELEGATE_DONE, whatever
# happens, so the Monitor never mistakes silence for success.
#
# Posture: the executor implements only. It never commits, pushes or opens a PR, so git
# writes and gh are denied outright and only read-only git is allowed. A denial comes back
# as "Permission denied and could not request permission from user", which the host maps to
# status blocked. Copilot's assisted-approval judge does not engage in -p mode (verified on
# 1.0.81), so this allowlist is the gate. Add a runner below if a plan's Verify needs one.
set -uo pipefail

RUN="$1"; shift
MODE=first; TEXT=""
if [ "${1:-}" = "--resume" ]; then MODE=resume; TEXT="${2:-continue}"; fi

WT=$(jq -r .worktree "$RUN/freeze.json")
BASE=$(jq -r .grounded_sha "$RUN/freeze.json")

# codex and grok take the schema as a flag; copilot has no equivalent, so it rides in the
# prompt on every turn. Without it the model invents its own status values.
SCHEMA="$(cd "$(dirname "$0")/.." && pwd)/result.schema.json"
SCHEMA_NOTE=$'\n\n--- REQUIRED FINAL MESSAGE SHAPE (JSON Schema; reply with that object only) ---\n'"$(cat "$SCHEMA")"

# Both forms per command on purpose: the bare form matches the command with no arguments,
# the `:*` form matches it with any (`git status --porcelain`, `git commit -m ...`). Allow
# needs the wildcard or the read-only git the wrapper invites is refused; deny needs it or
# the fence only blocks argument-less commits.
# Posture: deny-list, not allowlist. The executor implements only, so the fence is that it
# must never commit, push or touch gh; everything else it needs (any test runner, any build
# tool, any shell composition) is allowed. Verified: --deny-tool overrides --allow-all-tools,
# so these refusals hold. An allowlist was tried first and is the wrong shape here: patterns
# match the command as written, a compound command is refused if ANY element is unlisted, and
# an executor freely writes things like `runner; status=$?; exit "$status"`. That made
# delegations fail intermittently on phrasing, and it forced a per-ecosystem runner list into
# a skill that has to work in every repo.
DENY=(
  'shell(git commit)' 'shell(git commit:*)'
  'shell(git push)' 'shell(git push:*)'
  'shell(git add)' 'shell(git add:*)'
  'shell(git tag)' 'shell(git tag:*)'
  'shell(git reset)' 'shell(git reset:*)'
  'shell(git checkout)' 'shell(git checkout:*)'
  'shell(git merge)' 'shell(git merge:*)'
  'shell(git rebase)' 'shell(git rebase:*)'
  'shell(gh:*)'
)

CARGS=( -C "$WT" --no-ask-user --no-auto-update --disable-builtin-mcps
        --output-format json --allow-all-tools --allow-all-urls )
for d in "${DENY[@]}"; do CARGS+=(--deny-tool "$d"); done
# Frozen at setup (flag, else config.json); empty means the harness default.
MODEL=$(jq -r '.model // empty' "$RUN/freeze.json")
EFFORT=$(jq -r '.effort // empty' "$RUN/freeze.json")
[ -n "$MODEL" ]  && CARGS+=(--model "$MODEL")
[ -n "$EFFORT" ] && CARGS+=(--effort "$EFFORT")

# write_git_json is identical in all three drivers, so it lives in one sibling file.
# A missing helper must fail loudly: continuing would leave a stale git.json from an
# earlier run readable by the host as if it were fresh.
source "$(cd "$(dirname "$0")" && pwd)/_write_git_json.sh" \
  || { echo "DELEGATE_DONE executor=copilot exit=3 result=$RUN/result.json"; exit 3; }
source "$(cd "$(dirname "$0")" && pwd)/_wait_child.sh" \
  || { echo "DELEGATE_DONE executor=copilot exit=3 result=$RUN/result.json"; exit 3; }

# Stale artifacts from an earlier run of this run dir must never be read as this run's
# result. executor.log is appended across resumes, so the final message is searched only
# from LOG_OFFSET on; without it a resume that emits no parsable message would re-report
# the previous run's status.
rm -f "$RUN/result.json"
LOG_OFFSET=$(( $(stat -c %s "$RUN/executor.log" 2>/dev/null || echo 0) + 1 ))

CHILD=""
INTERRUPTED=0
trap '[ -n "$CHILD" ] && kill -TERM -- -"$CHILD" 2>/dev/null; INTERRUPTED=1' TERM INT

if [ "$MODE" = resume ]; then
  SID=$(cat "$RUN/session.txt" 2>/dev/null)
  # No id means no resumable session; burning a resume slot on an empty one just wastes a run.
  if [ -z "$SID" ]; then
    echo "DELEGATE_DONE executor=copilot exit=2 result=$RUN/result.json"
    exit 2
  fi
  jq '.resumes = ((.resumes // 0) + 1)' "$RUN/freeze.json" > "$RUN/freeze.json.tmp" && mv "$RUN/freeze.json.tmp" "$RUN/freeze.json"
  CARGS+=(--resume="$SID" -p "$TEXT$SCHEMA_NOTE")
else
  # The session id is chosen here, not scraped from the log, so a hard kill still leaves a
  # resumable run.
  SID=$(cat /proc/sys/kernel/random/uuid)
  echo "$SID" > "$RUN/session.txt"
  CARGS+=(--session-id "$SID" -p "$(cat "$RUN/prompt.md")$SCHEMA_NOTE")
fi

setsid bash -c 'cd "$1" || exit 1; shift; exec copilot "$@"' _ "$WT" "${CARGS[@]}" \
  >> "$RUN/executor.log" 2>&1 &
CHILD=$!
wait_child copilot

# Final assistant message carries the result object. Copilot has no output-schema flag, so
# it is validated here; if it does not parse, result.json stays absent and the host reports
# on git.json alone.
# Slurped, not `| tail -1`: the content is one JSON object the model almost always pretty-
# prints, so tailing the last *line* of jq's output yields "}" rather than the last message.
# fromjson? per line tolerates any non-JSON the CLI prints into the stream.
LAST=$(tail -c "+$LOG_OFFSET" "$RUN/executor.log" 2>/dev/null | jq -sRr \
  'split("\n") | map(fromjson? // empty)
   | map(select(.type=="assistant.message") | .data.content // empty) | last // empty' 2>/dev/null)
LAST=$(printf '%s' "$LAST" | sed -e 's/^```[a-z]*//' -e 's/```$//')
if [ -n "$LAST" ] && jq -e . >/dev/null 2>&1 <<<"$LAST"; then
  jq . <<<"$LAST" > "$RUN/result.json"
fi
write_git_json
echo "DELEGATE_DONE executor=copilot exit=$rc result=$RUN/result.json"
exit "$rc"
