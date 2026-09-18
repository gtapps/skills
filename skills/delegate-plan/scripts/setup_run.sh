#!/usr/bin/env bash
# delegate-plan step 4: create the run dir, freeze the plan, render the executor prompt.
# Runs from inside the worktree (after EnterWorktree). Prints the run dir path as its only
# stdout line. It creates nothing else: no worktree, no cleanliness check, no launch.
#
# Usage: setup_run.sh <codex|grok|copilot|claude> <plan-path> [--model <m>] [--effort <e>]
#   model/effort: the flag, else config.json in the skill dir, else null (harness default).
#   Both land in freeze.json; the drivers read them from there, so a resume reuses them.
set -euo pipefail
EXEC="${1:-}"; PLAN="${2:-}"; shift 2 || true
MODEL=""; EFFORT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model)  MODEL="${2:-}";  shift 2 ;;
    --effort) EFFORT="${2:-}"; shift 2 ;;
    *) echo "setup_run: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# The executor's own cleanup skill, the one it owns and can read.
case "$EXEC" in
  codex)   SIMPLIFY='$simplify, or read the installed simplify skill and follow it' ;;
  grok)    SIMPLIFY='/simplify, or read the installed simplify skill and follow it' ;;
  copilot) SIMPLIFY='/simplify, or read the installed simplify skill and follow it' ;;
  claude)  SIMPLIFY='/simplify' ;;
  *) echo "setup_run: executor must be codex, grok, copilot or claude" >&2; exit 2 ;;
esac
# How the executor waits for reviewers it dispatched. The headless CLIs run one turn: the
# moment they stop, whatever they last wrote is the final message and the run is over, so
# they must block on their reviewers or not dispatch any. A claude subagent is the opposite:
# it has no blocking tool, and ending its turn while children run is how it waits (the
# harness resumes it with each child's notification). Kept out of wrapper.md because the
# two rules contradict each other. No `&` or `|` in these strings: sed would eat them.
ONE_TURN='Ending your turn ends this run: whatever you last wrote becomes your final message and a half-finished run is reported as one, so never stop to wait for a reviewer. Collect every reviewer output with your harness blocking wait or output tool before going on; if your harness has no such tool, do not dispatch reviewers at all and run the lenses serially yourself.'
case "$EXEC" in
  grok)   WAIT="$ONE_TURN For you that tool is get_command_or_subagent_output, called for every spawn_subagent task id." ;;
  claude) WAIT='Dispatched reviewers run in the background and you have no tool that blocks on them: wait by ending your turn with a one-line status. The harness resumes you when a reviewer finishes, and a stop made while your reviewers are still running is not your final message; rule 5 applies to the reply you give when no agent you dispatched is still running.' ;;
  *)      WAIT="$ONE_TURN" ;;
esac
CFG="$(cd "$(dirname "$0")/.." && pwd)/config.json"
[ -n "$MODEL" ]  || MODEL=$(jq -r --arg e "$EXEC" '.[$e].model // empty'  "$CFG" 2>/dev/null || true)
[ -n "$EFFORT" ] || EFFORT=$(jq -r --arg e "$EXEC" '.[$e].effort // empty' "$CFG" 2>/dev/null || true)
[ -f "$PLAN" ] || { echo "setup_run: no plan file at '$PLAN'" >&2; exit 2; }
grep -q '^## Steps' "$PLAN" \
  || { echo "setup_run: $PLAN has no '## Steps' section" >&2; exit 2; }
PLAN=$(realpath "$PLAN")

WT=$(git rev-parse --show-toplevel)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
SHA=$(git rev-parse HEAD)
# Inside a worktree the toplevel's basename is the branch slug, so the repo name comes from
# the main checkout, which is the parent of the common git dir.
REPO=$(basename "$(dirname "$(realpath "$(git rev-parse --git-common-dir)")")")
SLUG=${BRANCH//\//-}
RUN="$HOME/.claude/delegate-runs/$REPO-$SLUG-$(date +%Y%m%d-%H%M%S)"
# Two setups in the same second (scripted tests do this) must not share a run dir.
[ -e "$RUN" ] && RUN="$RUN-$$"
mkdir -p "$RUN"

# From here plan.md is the contract, not the source file.
cp "$PLAN" "$RUN/plan.md"
PLAN_SHA=$(sha256sum "$RUN/plan.md" | cut -d' ' -f1)

jq -cn --arg e "$EXEC" --arg src "$PLAN" --arg ps "$PLAN_SHA" --arg sha "$SHA" \
  --arg br "$BRANCH" --arg wt "$WT" --arg run "$RUN" --arg m "$MODEL" --arg ef "$EFFORT" \
  '{executor:$e, plan_source:$src, plan_sha256:$ps, grounded_sha:$sha, branch:$br,
    worktree:$wt, run_dir:$run, resumes:0,
    model:(if $m == "" then null else $m end), effort:(if $ef == "" then null else $ef end)}' \
  > "$RUN/freeze.json"

# wrapper.md with its placeholders substituted, then the frozen plan. The plan is appended
# with cat, never passed through a shell argument.
WRAPPER="$(cd "$(dirname "$0")/.." && pwd)/wrapper.md"
{
  sed -e "s|{{WORKTREE}}|$WT|g" -e "s|{{BRANCH}}|$BRANCH|g" -e "s|{{BASE_SHA}}|$SHA|g" \
      -e "s|{{PLAN_SHA256}}|$PLAN_SHA|g" -e "s|{{RUN_DIR}}|$RUN|g" \
      -e "s|{{SIMPLIFY}}|$SIMPLIFY|g" -e "s|{{WAIT}}|$WAIT|g" "$WRAPPER"
  echo
  cat "$RUN/plan.md"
  # codex and grok get the schema as a CLI flag and copilot's driver appends it per turn;
  # the claude subagent has neither, so it rides in the prompt. Without it the model
  # invents its own field names.
  if [ "$EXEC" = claude ]; then
    printf '\n--- REQUIRED FINAL MESSAGE SHAPE (JSON Schema; reply with that object only, no code fence) ---\n'
    cat "$(dirname "$WRAPPER")/result.schema.json"
  fi
} > "$RUN/prompt.md"

echo "$RUN"
