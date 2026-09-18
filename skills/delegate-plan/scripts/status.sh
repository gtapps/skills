#!/usr/bin/env bash
# delegate-plan status: a read-only snapshot of one delegation, built from the files the
# driver already writes. It never touches the Monitor, the executor, or the worktree beyond
# `git status` / `git diff`, so it is safe to run while the executor is mid-write.
#
# Usage: status.sh [run-dir]
#
# Without an argument the run is the newest run dir whose freeze.json.worktree is the
# worktree the caller stands in. Delegations run one per worktree, so the cwd is the
# disambiguator; "newest run overall" is never used, because with several delegations in
# flight it would report someone else's run.
set -uo pipefail
RUNS="$HOME/.claude/delegate-runs"

if [ $# -ge 1 ]; then
  RUN="${1%/}"
  [ -f "$RUN/freeze.json" ] || { echo "status: $RUN has no freeze.json" >&2; exit 2; }
else
  top=$(git rev-parse --show-toplevel 2>/dev/null) \
    || { echo "status: not inside a git worktree; pass the run dir" >&2; exit 2; }
  # Run dirs for one worktree share the <repo>-<branch-slug>- prefix, so a name sort is a
  # timestamp sort.
  RUN=$(for f in "$RUNS"/*/freeze.json; do
          [ "$(jq -r .worktree "$f" 2>/dev/null)" = "$top" ] && dirname "$f"
        done | sort | tail -1)
  [ -n "$RUN" ] || { echo "status: no run dir has worktree=$top" >&2; exit 2; }
fi

EXEC=$(jq -r .executor "$RUN/freeze.json")
BRANCH=$(jq -r .branch "$RUN/freeze.json")
WT=$(jq -r .worktree "$RUN/freeze.json")
RESUMES=$(jq -r '.resumes // 0' "$RUN/freeze.json")
LOG="$RUN/executor.log"
now=$(date +%s)
fmt() { printf '%dm%02ds' $(( $1 / 60 )) $(( $1 % 60 )); }

# Phase from the files, in the driver's own order: git.json is written last, so its
# presence means the driver has ended; a live driver process means running; neither means
# the driver died before writing evidence.
if [ -f "$RUN/git.json" ]; then
  PHASE="finished"
  if [ -f "$RUN/result.json" ]; then
    PHASE="finished   result.json status=$(jq -r '.status // "?"' "$RUN/result.json")"
  else
    PHASE="finished   (no result.json)"
  fi
elif pgrep -f "run_${EXEC}\.sh ${RUN}" >/dev/null 2>&1; then
  PHASE="running"
elif [ "$EXEC" = claude ]; then
  # A subagent leaves no driver process and no executor.log; the host's completion
  # notification is the only end signal, and finish_claude.sh writes git.json then.
  PHASE="running (subagent, no executor log)"
else
  PHASE="driver gone, no git.json (killed or crashed)"
fi

started=$(stat -c %Y "$RUN/prompt.md" 2>/dev/null || echo "$now")
logm=$(stat -c %Y "$LOG" 2>/dev/null || echo "$now")
ELAPSED=$(fmt $(( now - started )))
IDLE=$(fmt $(( now - logm )))

# Last thing the executor said or ran, from the tail of the log. fromjson? drops the
# non-JSON lines codex mixes into its stream (tracing output).
last_event() {
  tail -c 524288 "$LOG" 2>/dev/null | jq -Rr --arg x "$EXEC" '
    fromjson? // empty
    | if $x == "codex" then
        if .type == "item.started" and .item.type == "command_execution" then "ran:  " + .item.command
        elif .type == "item.completed" and .item.type == "agent_message" then "said: " + .item.text
        else empty end
      elif $x == "grok" then
        select(.type == "assistant") | .message.content[]?
        | if .type == "text" then "said: " + .text
          elif .type == "tool_use" then "ran:  " + (.input.command // .name)
          else empty end
      elif $x == "copilot" then
        if .type == "tool.execution_start" then "ran:  " + (.data.arguments.command // .data.toolName)
        elif .type == "assistant.message" then "said: " + (.data.content // "")
        else empty end
      else empty end' 2>/dev/null | tail -1 | tr '\n' ' ' | cut -c1-200
}
if [ "$EXEC" = claude ]; then LAST="<n/a for claude: no executor log>"; else LAST=$(last_event); fi

echo "run      $(basename "$RUN")"
printf "%-8s %s   resumes=%s\n" "$EXEC" "$BRANCH" "$RESUMES"
echo "phase    $PHASE   elapsed $ELAPSED   idle $IDLE (stall at 10m00s)"
echo "last     ${LAST:-<nothing yet>}"
if [ -d "$WT" ]; then
  n=$(git -C "$WT" status --porcelain 2>/dev/null | wc -l)
  stat=$(git -C "$WT" diff --shortstat 2>/dev/null | sed 's/^ *//')
  echo "tree     $WT"
  echo "         $n path(s) changed${stat:+; $stat}"
  git -C "$WT" status --short 2>/dev/null | head -8 | sed 's/^/         /'
  if [ "$n" -gt 8 ]; then echo "         ... $(( n - 8 )) more"; fi
else
  echo "tree     $WT (missing)"
fi
