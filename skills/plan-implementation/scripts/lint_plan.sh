#!/usr/bin/env bash
# Static checks on an implementation plan, run before it is shown for approval.
# Prints one line per defect and exits 1; prints nothing and exits 0 when the plan is clean.
# It never runs a plan command: the closing verification is executed later by verify.sh.
#
# Usage: lint_plan.sh <plan-path>
set -uo pipefail
[ $# -eq 1 ] || { echo "usage: lint_plan.sh <plan-path>" >&2; exit 2; }
PLAN=$(cat "$1") || { echo "lint_plan: cannot read '$1'" >&2; exit 2; }
FAIL=0
bad() { echo "lint_plan: $*"; FAIL=1; }
has() { grep -q "^$1[[:space:]]*\$" <<<"$PLAN"; }

for h in '## Steps' '## Closing verification' '## Live gates'; do
  has "$h" || bad "missing heading '$h'"
done

# The same extraction verify.sh uses: the first fenced block under the heading. It must open
# before the next heading, or verify.sh would run a later section's block as the commands.
if has '## Closing verification'; then
  CV=$(awk '/^## Closing verification/{h=1;next} h&&!f&&/^## /{exit} h&&/^```/{f++; if(f==2)exit; next} h&&f==1' <<<"$PLAN" \
       | sed '/^[[:space:]]*$/d')
  [ -n "$CV" ] || bad "'## Closing verification' has no fenced block of commands"
fi

if has '## Live gates'; then
  LG=$(awk '/^## Live gates/{h=1;next} h&&/^## /{exit} h' <<<"$PLAN" | sed '/^[[:space:]]*$/d')
  [ -n "$LG" ] || bad "'## Live gates' is empty: list the gates or write 'None.'"
fi

# Every step needs a Contract, and a Verify that holds a command in backticks on its own line.
if has '## Steps'; then
  # Lines inside fenced blocks are snippets, never headings.
  DEFECTS=$(awk '/^[[:space:]]*```/{f=!f; next} f{next} /^## Steps/{s=1;next} s&&/^## /{s=0} s' <<<"$PLAN" | awk '
    function flush() {
      if (t == "") return
      if (!c) print "step \"" t "\" has no Contract"
      if (!v) print "step \"" t "\" has no Verify with a command in backticks"
    }
    /^### /                    { flush(); t = substr($0, 5); c = 0; v = 0; n++; next }
    /\*\*Contract:\*\*/         { c = 1 }
    /\*\*Verify:\*\*.*`[^`]+`/  { v = 1 }
    END { flush(); if (!n) print "\"## Steps\" holds no \"### \" step" }')
  if [ -n "$DEFECTS" ]; then
    while IFS= read -r line; do bad "$line"; done <<<"$DEFECTS"
  fi
fi
exit $FAIL
