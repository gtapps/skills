#!/usr/bin/env bash
# delegate-plan driver: grok (auto mode = --permission-mode auto).
#
# Usage: run_grok.sh <run-dir> [--resume "<text>"]
#   <run-dir> holds prompt.md and freeze.json (worktree, grounded_sha, resumes).
#
# Writes into <run-dir>: executor.log (streaming JSONL transcript), result.json
# (structured_output of the result frame), session.txt (session id), git.json
# (derived from git, never from the model). Prints exactly one stdout line,
# DELEGATE_DONE, whatever happens.
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
  || { echo "DELEGATE_DONE executor=grok exit=3 result=$RUN/result.json"; exit 3; }
source "$(cd "$(dirname "$0")" && pwd)/_wait_child.sh" \
  || { echo "DELEGATE_DONE executor=grok exit=3 result=$RUN/result.json"; exit 3; }

# Stale artifacts from an earlier run of this run dir must never be read as this run's
# result. executor.log is appended across resumes, so the result frame is searched only
# from LOG_OFFSET on; without it a resume that emits no frame would re-report the previous
# run's structured_output.
rm -f "$RUN/result.json"
LOG_OFFSET=$(( $(stat -c %s "$RUN/executor.log" 2>/dev/null || echo 0) + 1 ))

CHILD=""
INTERRUPTED=0
trap '[ -n "$CHILD" ] && kill -TERM -- -"$CHILD" 2>/dev/null; INTERRUPTED=1' TERM INT

if [ "$MODE" = resume ]; then
  SID=$(cat "$RUN/session.txt" 2>/dev/null)
  # No id means no resumable thread; burning a resume slot on an empty one just wastes a run.
  if [ -z "$SID" ]; then
    echo "DELEGATE_DONE executor=grok exit=2 result=$RUN/result.json"
    exit 2
  fi
  jq '.resumes = ((.resumes // 0) + 1)' "$RUN/freeze.json" > "$RUN/freeze.json.tmp" && mv "$RUN/freeze.json.tmp" "$RUN/freeze.json"
  setsid bash -c 'grok -p "$5" --resume "$2" --cwd "$1" --permission-mode auto \
      ${MODEL:+-m} ${MODEL:+"$MODEL"} ${EFFORT:+--effort} ${EFFORT:+"$EFFORT"} \
      --output-format streaming-messages-json --json-schema "$(cat "$3")"' \
    _ "$WT" "$SID" "$SCHEMA" "$RUN" "$TEXT" >> "$RUN/executor.log" 2>&1 &
else
  setsid bash -c 'grok --prompt-file "$3/prompt.md" --cwd "$1" --permission-mode auto \
      ${MODEL:+-m} ${MODEL:+"$MODEL"} ${EFFORT:+--effort} ${EFFORT:+"$EFFORT"} \
      --output-format streaming-messages-json --json-schema "$(cat "$2")"' \
    _ "$WT" "$SCHEMA" "$RUN" > "$RUN/executor.log" 2>&1 &
fi
CHILD=$!
# Capture the session id from the init frame as soon as it appears so a hard kill still leaves a resumable run.
if [ "$MODE" = first ]; then
  for _ in $(seq 1 120); do
    # jq guards a partially-written last line: an unparsable frame yields empty, not a
    # truncated or "null" session.txt that would silently break resume.
    sid=$(grep -m1 '"type":"system"' "$RUN/executor.log" 2>/dev/null | jq -r '.session_id // empty' 2>/dev/null)
    if [ -n "$sid" ]; then printf '%s\n' "$sid" > "$RUN/session.txt"; break; fi
    kill -0 "$CHILD" 2>/dev/null || break
    sleep 1
  done
fi
wait_child grok

# Last result frame of this run carries structured_output.
RESULT_FRAME=$(tail -c "+$LOG_OFFSET" "$RUN/executor.log" 2>/dev/null | grep '"type":"result"' | tail -1)
if [ -n "$RESULT_FRAME" ] && jq -e '.structured_output' <<<"$RESULT_FRAME" >/dev/null 2>&1; then
  jq '.structured_output' <<<"$RESULT_FRAME" > "$RUN/result.json"
fi
write_git_json
echo "DELEGATE_DONE executor=grok exit=$rc result=$RUN/result.json"
exit "$rc"
