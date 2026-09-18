---
name: plan-implementation
description: "Prepare a self-contained implementation handoff from settled decisions when the executor needs missing context. Skip when the existing plan and available context already suffice."
---

# plan-implementation

A plan written while thinking is **argumentative**, it carries the reasoning, the options weighed, the "we should probably". An executor session doesn't have the conversation that produced it and can't act on argument. It needs the **residue**: where to change, what must be true after, how to prove it, and where to stop.

That is the whole transform. Same decisions, re-encoded for someone who wasn't there.

## When to use

Use when execution needs a self-contained handoff, such as a fresh session or delegated executor missing the discussion. Skip when the existing plan and available context already provide actionable decisions, scope, and verification. The same agent continuing in the same conversation usually does not need a separate conversion.

Choose based on context and plan readiness, not model identity or tier. Preserve the grounded anchors, observable contracts, runnable verification, and scope boundaries for every executor, including lower tier models. Resolve material open design decisions before preparing the handoff.

The executor is a capable model. It does not fail from lack of dictated code, it fails from **missing anchors and missing stopping conditions**. So spend your effort grounding anchors in the real repo and writing falsifiable contracts, not on writing the diff for it.

## Source and editing boundary

Use the user-named source or current plan. Preserve settled decisions; identify material open decisions before converting them into contracts.

- In Claude Code Plan Mode, update the harness-designated plan file and never rename it or call `ExitPlanMode`. Outside Plan Mode, use the requested path or `~/.claude/plans/`.
- In Codex Plan Mode, obey the current interface's edit permissions and return the complete replacement plan when it requires that. Outside Plan Mode, update the user-named plan file when requested.
- Do not change modes or start implementation. User instructions and later corrections take precedence over the saved plan; reconcile the plan with those corrections before execution.

## 1. Strip to decisions

Delete from the source everything an executor cannot act on: the restated ask, the reasoning trail, options as prose, hedges ("we might want to"), and anything another skill already owns, worktree hygiene, commit/PR mechanics and the test-before-commit spine live in `worktree-ship`, not in your plan. Repeating them wastes the executor's context and desynchronizes the moment those skills change.

Rejected alternatives don't vanish; they move into the decision tree (step 4) where their *consequence* is visible. That is the only place a discarded option earns space.

## 2. Ground every anchor

**A contract-level plan is only as good as its anchors.** If a named symbol has moved or never existed, the executor improvises and your plan silently degrades into a suggestion. Before writing a single step, verify the cheapest way, grep the symbol, read the function it lives in, count the call sites.

**Structural anchors resolve as a path, not a string.** A heading under a section, a key under
a config table, a method under a class, a case under an enum: match the child under the parent
the anchor names, never anywhere in the file. A bare grep for the leaf matches every other
occurrence in the file and proves nothing. Parent present and child absent means the child is
the step's work, not its anchor.

**A pinned literal is grounded by grepping the literal.** Symbols get imported, but counts,
inline id lists, enum tables, route tables, translation keys and fixtures get copied. Grep a
distinctive element rather than the count, and anchor every file holding a copy. A fence that
names which tests may go red is a claim about that grep's result.

**The closing verification is an anchor too.** Read the spine out of the file that defines it
(the CI workflow, the `scripts` block, the Makefile, CONTRIBUTING) and cite that `path:line` in
References. Reconstructing it from memory drops the flags that make it pass, and an executor
halting on a defective spine looks exactly like an executor halting on a broken diff.

While you're in there, hunt for **reuse**: the existing helper, the established pattern, the test file with prior art. An executor that can't see one writes a new one, and you get the speculative structure `final-plan-check` exists to strip out. Naming the helper is one line and saves that whole round trip.

Anchor format, carry both, they do different jobs:

    `src/watchdog/watchdog.ts:517` → `compactIfNeeded()`

The **symbol** is authoritative for locating the work (survives drift between planning and execution). The **`path:line`** is the citation that makes the claim traceable now, as required by the project instructions. When they disagree at execution time, the symbol wins.

## 3. Write steps as contracts

Each step is a unit of work that ends in something provable. Three fields are mandatory, a step without them isn't a step, it's a wish. The rest render only when they carry real content; ceremonial empty fields train the executor to skim.

    ### 3, Gate compaction on the token threshold
    - **Anchor:** `src/watchdog/watchdog.ts:517` → `compactIfNeeded()`
    - **Contract:** a session at 150k tokens compacts once; a session below it never compacts. (mandatory)
    - **Verify:** `bun test test/watchdog.test.ts` → green, including the new threshold case. (mandatory)
    - **Reuse:** `tokenCountFor()` in `src/util/tokens.ts:44`, don't re-derive the count.
    - **Fence:** don't touch the watchdog's restart path; that's step 5.
    - **Depends on:** step 2 (the threshold constant must exist first).

**Contracts state observable behavior**, never the edit. "A session at 150k tokens compacts once" is checkable by someone who never read your plan; "update the compaction logic" is not. If you cannot write a contract for a step, you have not finished deciding, go back to the source, or surface it as an open question.

**Verification is per step, not just at the end.** A single "run the tests" at the bottom lets four steps of drift accumulate before anything goes red. Bind each step to the cheapest command that would actually fail if the step were done wrong; the project's own full spine closes the plan, named exactly as this repo runs it.

**A Verify that is not a runnable command is not a Verify.** "The entry sits under the right heading" asks the executor to grade itself, and it cannot. Write the command (a grep, a test, a build) or fold the check into the closing verification. Writing the command is also how you find out that the thing it greps for is not there yet.

**A Verify asserting a count must be run at plan time.** `grep -c X` returning 1 is a claim
about the whole file, not about your step. If a pre-existing occurrence makes it 2, the
executor has been handed an instruction to edit whatever else matches until the number agrees,
and it will. Run it; if the phrase is not unique, pick one that is.

**A Verify runs inside the worktree.** Both `worktree-ship` and `delegate-plan` fence the
executor there, so a check needing a scratch dir elsewhere on disk cannot run and the step
stalls. Make it in-tree or drop it from the plan. A step that pre-authorizes its own skip is
not a step, it is a suggestion.

### Calibration, how much detail

Contract-level, and resist the pull toward more. Line-by-line specs rot between planning and execution, and an executor following a stale spec produces worse code than one given intent plus a verification command.

Escalate to a **snippet of ≤5 lines** only where prose genuinely can't encode the decision precisely, a type shape, a schema, a regex, an exact API signature, a state transition. Inline it in the step and say why it's exact. Never a full function, never a diff.

Specify ordering and stopping conditions where the workflow requires them; do not add instructions solely because the executor uses a different model.

## 4. Draw the delta

Load the `delta-diagrams` skill before drawing, it owns the house style and the behavior-delta discipline. Two diagrams, both ASCII in the plan file (a markdown plan read in the terminal is exactly the case where ASCII inline is right; graduating to a rendered page is `plan-to-artifact`'s call, not yours):

- **One end-to-end BEFORE/AFTER flow**, near the top. This is the operator's fastest read and the reason they can approve without reading every step. Nodes are user-observable behavior, never filenames.
- **A decision tree per fork that actually happened** in the session, each candidate answer carrying the functional consequence it would have produced, the taken one marked `◀ SELECTED`.

Honesty rule: only forks that really occurred. Inventing alternatives to make the tree look considered is worse than no tree, it fabricates a review that never happened.

## 5. Fence the scope

Executors drift by accretion, a fix becomes a refactor of its surroundings. Two cheap guards, both at the top of the plan where they're read before any step:

- **Out of scope**, the adjacent things deliberately not being done, so "while we're in here" has an answer.
- **Stop and ask if**, the conditions under which the executor must halt instead of improvising. The reliable ones: an anchor symbol doesn't exist or has moved materially; the contract can't be met without editing outside the fence; a test outside this plan's scope goes red; a step's verification passes for a reason the contract didn't predict.

That last list is what makes an unattended run safe. Without it a blocked executor invents its way forward, and you find out at review time.

## Output shape

Rewrite the plan file to this. Sections with nothing real in them are omitted, not left empty.

```markdown
# <thing>, implementation plan

**Ask:** <the original request, one line>
**Done when:** <falsifiable end state, the same sentence you'd pin as a /goal>
**Execution contract:** use this plan for implementation. If the user changes a decision, update the affected contract before executing it. The saved plan never overrides the user.

## Behavior delta
<ASCII BEFORE/AFTER flow>

## Decisions            (only if forks actually happened)
<ASCII decision tree, ◀ SELECTED marked>

## Ground rules
- Out of scope: ...
- Stop and ask if: ...

## Steps
### 1, <imperative goal>
- **Anchor:** / **Contract:** / **Verify:** (+ Reuse / Fence / Depends on where real)

## Closing verification
<the project spine, exact commands and expected exit>

## References
<files as `path:line`, docs/URLs that informed the plan>
```

Every line of the closing verification block must run as-is with `bash -c` inside the worktree: repeat a step's grep verbatim rather than referring to it by step number. `delegate-plan`'s `verify.sh` runs the block literally, and a prose line shows up as a red row.

Report the plan location or return the replacement plan, its behavior delta, and the next applicable review step. Refer only to skills available in the active harness. Use its goal library when a goal suggestion is appropriate; do not activate a goal unless asked.

## Don't

- Don't call `ExitPlanMode`, and don't nudge toward it.
- Don't critique or re-decide the plan while converting it, if something looks wrong, say so in the terminal and let the operator route it to `/final-plan-check`. Converting is not the moment to relitigate.
- Don't invent contracts, anchors, forks, or verification for things the source plan never settled. A gap surfaced as an open question is useful; a plausible-looking fabrication is a trap the executor walks into.
- Don't anchor a step to something that same step creates. If the heading, section, file or key isn't there yet, creating it is the step's work and the anchor is its parent. An anchor that names the step's own output can never resolve, and the executor stops.
- Don't cite bare line numbers as the anchor, symbols locate, line numbers cite.
- Don't pin a Verify to a count you haven't run. An ungrounded count is not a check, it is an
  instruction to edit whatever else matches until the number agrees.
- Don't restate `worktree-ship`, `commit`, or the test spine inside the plan. Reference the skill, don't fork it.
