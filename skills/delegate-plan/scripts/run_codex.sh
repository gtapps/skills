#!/usr/bin/env bash
# delegate-plan driver: codex (auto mode = --approve-for-me).
#
# Usage: run_codex.sh <run-dir> [--resume "<text>"]
#   <run-dir> holds prompt.md and freeze.json (worktree, grounded_sha, resumes).
#
# Writes into <run-dir>: executor.log (JSONL transcript), result.json (schema-
# constrained final message), session.txt (thread id), git.json (derived from
# git, never from the model). Prints exactly one stdout line, DELEGATE_DONE,
# whatever happens, so the Monitor never mistakes silence for success.
set -uo pipefail

RUN="$1"; shift
MODE=first; TEXT=""
if [ "${1:-}" = "--resume" ]; then MODE=resume; TEXT="${2:-continue}"; fi

SCHEMA="$(cd "$(dirname "$0")/.." && pwd)/result.schema.json"
WT=$(jq -r .worktree "$RUN/freeze.json")
BASE=$(jq -r .grounded_sha "$RUN/freeze.json")
# Frozen at setup (flag, else config.json); exported so the setsid child sees them. Empty
# means the harness default, and the ${VAR:+...} expansions below add nothing.
export MODEL=$(jq -r '.model // empty' "$RUN/freeze.json")
export EFFORT=$(jq -r '.effort // empty' "$RUN/freeze.json")

# write_git_json is identical in all three drivers, so it lives in one sibling file.
# A missing helper must fail loudly: continuing would leave a stale git.json from an
# earlier run readable by the host as if it were fresh.
source "$(cd "$(dirname "$0")" && pwd)/_write_git_json.sh" \
  || { echo "DELEGATE_DONE executor=codex exit=3 result=$RUN/result.json"; exit 3; }
source "$(cd "$(dirname "$0")" && pwd)/_wait_child.sh" \
  || { echo "DELEGATE_DONE executor=codex exit=3 result=$RUN/result.json"; exit 3; }

# Stale artifacts from an earlier run of this run dir must never be read as this run's
# result: codex only writes -o on success, so a failed resume would otherwise leave the
# previous run's status in place.
rm -f "$RUN/result.json"

CHILD=""
INTERRUPTED=0
trap '[ -n "$CHILD" ] && kill -TERM -- -"$CHILD" 2>/dev/null; INTERRUPTED=1' TERM INT

if [ "$MODE" = resume ]; then
  SID=$(cat "$RUN/session.txt" 2>/dev/null)
  # No id means no resumable thread; burning a resume slot on an empty one just wastes a run.
  if [ -z "$SID" ]; then
    echo "DELEGATE_DONE executor=codex exit=2 result=$RUN/result.json"
    exit 2
  fi
  jq '.resumes = ((.resumes // 0) + 1)' "$RUN/freeze.json" > "$RUN/freeze.json.tmp" && mv "$RUN/freeze.json.tmp" "$RUN/freeze.json"
  # `codex exec resume` has no --approve-for-me/--sandbox flags: set the same
  # three keys the first run's --approve-for-me expands to.
  setsid bash -c 'cd "$1" && codex exec resume "$2" \
      ${MODEL:+-m} ${MODEL:+"$MODEL"} ${EFFORT:+-c} ${EFFORT:+"model_reasoning_effort=$EFFORT"} \
      -c approvals_reviewer=auto_review -c approval_policy=on-request \
      -c sandbox_mode=workspace-write -c sandbox_workspace_write.network_access=true \
      --skip-git-repo-check --json --output-schema "$3" -o "$4/result.json" - <<<"$5"' \
    _ "$WT" "$SID" "$SCHEMA" "$RUN" "$TEXT" >> "$RUN/executor.log" 2>&1 &
else
  setsid bash -c 'cd "$1" && codex exec --approve-for-me \
      ${MODEL:+-m} ${MODEL:+"$MODEL"} ${EFFORT:+-c} ${EFFORT:+"model_reasoning_effort=$EFFORT"} \
      -c sandbox_workspace_write.network_access=true \
      --skip-git-repo-check --json --output-schema "$2" -o "$3/result.json" - < "$3/prompt.md"' \
    _ "$WT" "$SCHEMA" "$RUN" > "$RUN/executor.log" 2>&1 &
fi
CHILD=$!
# Capture the thread id as soon as it appears so a hard kill still leaves a resumable run.
if [ "$MODE" = first ]; then
  for _ in $(seq 1 120); do
    # jq guards a partially-written last line: an unparsable frame yields empty, not a
    # truncated or "null" session.txt that would silently break resume.
    sid=$(grep -m1 '"thread.started"' "$RUN/executor.log" 2>/dev/null | jq -r '.thread_id // empty' 2>/dev/null)
    if [ -n "$sid" ]; then printf '%s\n' "$sid" > "$RUN/session.txt"; break; fi
    kill -0 "$CHILD" 2>/dev/null || break
    sleep 1
  done
fi
wait_child codex

write_git_json
echo "DELEGATE_DONE executor=codex exit=$rc result=$RUN/result.json"
exit "$rc"
