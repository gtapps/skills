#!/usr/bin/env bash
# delegate-plan-review driver for the CLI harnesses (codex, grok, copilot). The claude
# harness is a subagent and never comes through here.
#
# Usage: review.sh <harness> <plan-file> <review-out> <log> [--model <m>] [--effort <e>]
#
# Builds prompt.md + plan into one temp file, runs the harness read-only, writes its final
# answer to <review-out> and everything else to <log>, and prints exactly one stdout line:
#   REVIEW_DONE harness=<x> exit=<rc> review=<path> log=<path>
# That line is the one event the Monitor delivers, and it carries the exit code, so a crash
# can never look like success.
#
# Postures (verified 2026-09-04, see memory reference-harness-readonly-postures):
#   codex   --sandbox read-only
#   grok    --permission-mode dontAsk --deny 'Write(*)' --deny 'Edit(*)'  (dontAsk alone
#           does not block writes; the deny rules also catch shell redirects)
#   copilot --no-ask-user with only read-only git allowed (an unlisted tool is denied)
# Model and effort: CLI flag, else config.json next to this script's parent, else the
# harness default.
set -uo pipefail

H="${1:-}"; PLAN="${2:-}"; OUT="${3:-}"; LOG="${4:-}"
[ -n "$H" ] && [ -f "$PLAN" ] && [ -n "$OUT" ] && [ -n "$LOG" ] \
  || { echo "usage: review.sh <harness> <plan-file> <review-out> <log> [--model m] [--effort e]" >&2; exit 2; }
shift 4
MODEL=""; EFFORT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model)  MODEL="${2:-}";  shift 2 ;;
    --effort) EFFORT="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

DIR="$(cd "$(dirname "$0")/.." && pwd)"
CFG="$DIR/config.json"
[ -n "$MODEL" ]  || MODEL=$(jq -r --arg h "$H" '.[$h].model // empty'  "$CFG" 2>/dev/null)
[ -n "$EFFORT" ] || EFFORT=$(jq -r --arg h "$H" '.[$h].effort // empty' "$CFG" 2>/dev/null)

PROMPT="$(mktemp)"
{ cat "$DIR/prompt.md"; cat "$PLAN"; } > "$PROMPT"
rm -f "$OUT"
: > "$LOG"

case "$H" in
  codex)
    args=()
    [ -n "$MODEL" ]  && args+=(-m "$MODEL")
    [ -n "$EFFORT" ] && args+=(-c "model_reasoning_effort=$EFFORT")
    codex exec --sandbox read-only --skip-git-repo-check ${args[@]+"${args[@]}"} \
      --output-last-message "$OUT" - < "$PROMPT" > "$LOG" 2>&1
    rc=$?
    ;;
  grok)
    args=()
    [ -n "$MODEL" ]  && args+=(-m "$MODEL")
    [ -n "$EFFORT" ] && args+=(--effort "$EFFORT")
    grok --prompt-file "$PROMPT" --cwd "$PWD" --permission-mode dontAsk \
      --deny 'Write(*)' --deny 'Edit(*)' --output-format json ${args[@]+"${args[@]}"} \
      > "$LOG" 2>&1
    rc=$?
    # The whole stdout is one JSON object; its .text is the answer.
    text=$(jq -r '.text // empty' "$LOG" 2>/dev/null)
    [ -n "$text" ] && printf '%s\n' "$text" > "$OUT"
    ;;
  copilot)
    args=()
    [ -n "$MODEL" ]  && args+=(--model "$MODEL")
    [ -n "$EFFORT" ] && args+=(--effort "$EFFORT")
    copilot -p "$(cat "$PROMPT")" --no-ask-user --no-auto-update --disable-builtin-mcps \
      --allow-tool 'shell(git log:*)' --allow-tool 'shell(git diff:*)' --allow-tool 'shell(git show:*)' \
      --output-format json ${args[@]+"${args[@]}"} > "$LOG" 2>&1
    rc=$?
    # JSONL event stream; the last assistant.message is the answer.
    text=$(jq -sRr 'split("\n") | map(fromjson? // empty)
      | map(select(.type=="assistant.message") | .data.content // empty) | last // empty' "$LOG" 2>/dev/null)
    [ -n "$text" ] && printf '%s\n' "$text" > "$OUT"
    ;;
  *)
    rm -f "$PROMPT"
    echo "REVIEW_DONE harness=$H exit=2 review=$OUT log=$LOG"
    exit 2
    ;;
esac

rm -f "$PROMPT"
# A zero exit with no answer is still a failure for the caller.
[ "$rc" -eq 0 ] && [ ! -s "$OUT" ] && rc=1
echo "REVIEW_DONE harness=$H exit=$rc review=$OUT log=$LOG"
exit "$rc"
