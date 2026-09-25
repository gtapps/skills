#!/usr/bin/env bash
# review-ship reviewer driver for the Codex, Grok CLI and Copilot CLI hosts.
#
# Usage: review.sh <reviewer> <base-ref> <findings-out> <log> [--model <m>] [--level <l>]
#   reviewer: claude | codex | grok | copilot
#   base-ref: the comparison ref, e.g. origin/main; the review covers <base-ref>...HEAD
#   --level:  the /code-review level, used by the claude reviewer only (default high)
#
# Run it from the repository root. The reviewer runs read-only in its own process, so it
# starts with a fresh context. It writes its findings to <findings-out> and everything
# else to <log>, then prints exactly one stdout line:
#   REVIEW_DONE reviewer=<x> exit=<rc> findings=<path> log=<path>
# A zero exit with an empty findings file is reported as exit 1.
#
# Commands and read-only postures verified 2026-09-25 (codex-cli 0.157.0, grok 1.0.41,
# Copilot CLI 1.0.82, Claude Code 2.1.282): each reviewed main...HEAD without touching the
# tree. See ~/.agents/probe-results/cross-host-reviewer-cli-feasibility.md.
# delegate-plan-review/scripts/review.sh drives the same CLIs read-only for plan reviews.
# Skills install independently, so each keeps its own copy: change a CLI posture in both.
set -uo pipefail

R="${1:-}"; BASE="${2:-}"; OUT="${3:-}"; LOG="${4:-}"
[ -n "$R" ] && [ -n "$BASE" ] && [ -n "$OUT" ] && [ -n "$LOG" ] \
  || { echo "usage: review.sh <reviewer> <base-ref> <findings-out> <log> [--model m] [--level l]" >&2; exit 2; }
shift 4
MODEL=""; LEVEL="high"
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --level) LEVEL="${2:-high}"; shift; [ $# -gt 0 ] && shift ;;
    *) shift ;;
  esac
done

# Report every finding and let review-findings filter them: a reviewer told to report only
# high-severity issues reports less.
PROMPT="Review the changes on the current branch against $BASE (git diff $BASE...HEAD) for correctness bugs. Do not edit any file. Report every finding, including ones you are unsure of, each as: file:line, a one-sentence summary, and a concrete failure scenario. If there are none, reply exactly: No findings."

rm -f "$OUT"
: > "$LOG"

case "$R" in
  claude)
    args=(); [ -n "$MODEL" ] && args+=(--model "$MODEL")
    claude -p ${args[@]+"${args[@]}"} "/code-review $LEVEL $BASE...HEAD" > "$OUT" 2> "$LOG" < /dev/null
    rc=$?
    ;;
  codex)
    # codex review prints its findings on stdout and its working log on stderr.
    args=(); [ -n "$MODEL" ] && args+=(-c "model=\"$MODEL\"")
    codex review --base "$BASE" -c 'sandbox_mode="read-only"' ${args[@]+"${args[@]}"} > "$OUT" 2> "$LOG" < /dev/null
    rc=$?
    ;;
  grok)
    PF="$(mktemp)"; printf '%s\n' "$PROMPT" > "$PF"
    args=(); [ -n "$MODEL" ] && args+=(-m "$MODEL")
    grok --prompt-file "$PF" --cwd "$PWD" --permission-mode dontAsk \
      --deny 'Write(*)' --deny 'Edit(*)' --output-format json ${args[@]+"${args[@]}"} \
      > "$LOG" 2>&1 < /dev/null
    rc=$?
    rm -f "$PF"
    # The whole stdout is one JSON object; its .text is the answer.
    text=$(jq -r '.text // empty' "$LOG" 2>/dev/null)
    [ -n "$text" ] && printf '%s\n' "$text" > "$OUT"
    ;;
  copilot)
    args=(); [ -n "$MODEL" ] && args+=(--model "$MODEL")
    # Without an allow-list its shell is denied, so it can't run git diff; allow read-only git only.
    copilot -p "/review $PROMPT" -s --no-ask-user --no-auto-update \
      --allow-tool 'shell(git log:*)' --allow-tool 'shell(git diff:*)' --allow-tool 'shell(git show:*)' \
      ${args[@]+"${args[@]}"} > "$OUT" 2> "$LOG" < /dev/null
    rc=$?
    ;;
  *)
    echo "REVIEW_DONE reviewer=$R exit=2 findings=$OUT log=$LOG"
    exit 2
    ;;
esac

[ "$rc" -eq 0 ] && [ ! -s "$OUT" ] && rc=1
echo "REVIEW_DONE reviewer=$R exit=$rc findings=$OUT log=$LOG"
exit "$rc"
