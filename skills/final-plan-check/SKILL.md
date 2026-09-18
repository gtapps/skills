---
name: final-plan-check
description: "Critique an existing implementation plan against current evidence, scope, complexity, and operator constraints. Does not execute it."
---

# final-plan-check

The plan is a draft; the user is asking whether it's the *right* plan before it becomes code. Two failure modes, both fatal:

- **Sycophancy**, "looks great!" wastes the checkpoint and trains the user to stop asking.
- **Forced criticism**, invented concerns to look thorough. "No material concerns, here's what I checked" is a legitimate verdict, but it must be earned by the procedure below, not asserted.

The bar for every concern: name the step/file/section it lives in, and give a concrete alternative (cut X, defer Y, replace A with B, probe C first). "Consider simplifying" is banned.

## Hard constraint

Do not call `ExitPlanMode`, and do not nudge toward exiting. Deliver the critique and stop. If the user then says "apply those cuts," edit the plan, still without exiting.

## Procedure

**0. Re-anchor.** Restate the user's original request in one line. In a long session the ask is buried; every scope judgment below measures against this line, not against what the plan grew into.

**1. Spot-check the plan's factual claims.** A critique built on the same unread assumptions as the plan is fake confidence. For each load-bearing claim about the codebase ("`parse_range` handles X", "the config lives in Y", "there's only one caller"), verify the cheapest way, grep the symbol, read the function, count the call sites. You don't need to re-read everything; you do need to have opened the files the riskiest steps touch before writing "Looks right."

**2. Scope vs. the original ask.** For each plan item: did the user ask for this, or did the plan grow it? Classic drift: a bug fix that becomes a refactor of the surroundings; a one-shot script that grows config/flags/a helper module; "while we're in here" cleanup; new files where an edit would do. Cite `Simplicity First` / `Surgical Changes` from the loaded project instructions only where they directly bear, don't quote at length.

**3. Speculative structure.** Config objects with one caller, base classes with one subclass, registries with one entry, interfaces with one implementation, helpers extracted to avoid ~3 duplicated lines, and anything justified as "flexible / extensible / pluggable / for future X", push back unless the user explicitly asked for that flexibility. (Five identical blocks is a real case for extraction; three similar lines usually isn't; the gray zone in between is the user's call, name it and let them decide.)

**4. Defensive code for impossible scenarios.** Validating inputs from internal trusted code, catching exceptions the callee can't throw, fallbacks for states the install guarantees away, compat shims with one caller. Rule: validate at system boundaries (user input, external APIs, network); trust internal code and framework guarantees everywhere else.

**5. Under-engineering, the symmetric failure.**
- Cases the plan should handle and doesn't (concurrency, partial failure, empty input).
- Wrong layer, a fix in the wrong layer usually means the real bug is elsewhere.
- **No verification step**: does the plan say how we'll know it worked (a failing test that passes, a probe, an observable behavior)? A plan without success criteria fails `Goal-Driven Execution`.
- **Ordering**: is there a step that must come first (the failing test, the probe, the backup) that's scheduled last or missing?
- **Irreversible steps** (migrations, deletions, external side effects) with no safety net.

**6. Unverified assumptions about external behavior.** A plan can pass everything above and still rest on a guess about how something outside the code behaves: a tool's return shape, a hook's input contract, an API/library response, what a command actually outputs. For each step ask: *does its correctness depend on behavior assumed but never confirmed?* Name each load-bearing guess and recommend confirming it **now**, a one-off call, a tmux session driving the real thing, because plan mode is the cheapest place to catch a false premise and mid-implementation is the most expensive. Don't flag well-established behavior (stdlib semantics, documented guarantees you've used before); flag the "I think it returns X" steps.

**7. Operator gauntlet.** This operator reliably asks the same questions *after* seeing a plan. Pre-answer them now so the plan doesn't bounce. Each answer must cite the plan step or file that settles it; if the plan doesn't settle it, that item goes under `Possibly missing`, not into a hand-wave.

Current gate:
- **Worth-it ledger**: what do we gain and what do we lose? Name the concrete gain, the concrete cost (files, hooks, maintenance surface), and the honest net.
- **Operational cost**: if the plan adds anything that runs unattended (a hook, a routine, a loop, a watcher), state tokens per wake and wakes per day, each measured or labeled "estimate".
- **Overlap**: what does the platform already do natively, and what do the named alternatives for this project do (the project's instructions name them)? If it overlaps, say why it is built here anyway.
- **Where it lives**: core vs plugin, or the project's equivalent boundary. A plan that does not say is missing a decision.
- **Show me the flow**: every option ships with the full option list and one example flow per audience. An option without a flow is not an option yet.
- **Compatibility shims**: when the project ships as a research preview with no legacy-compatibility promise, name every dual-shape reader, one-release bridge or retirement window and either cut it or justify it as migration, not compatibility.
- **Execution ceremony**: the number of delegations or waves and the executor choice follow the dependency order the plan actually has, not a parallelism the chosen executor will not use; state the count and why.

Standing four:
- **Degenerate environments**, what happens in a non-git repo, an empty repo, or with a required tool missing? (The "what about a non git repo?" question.)
- **Already-done work**, what if the change is already committed, merged, or released? Does the plan detect and no-op, or does it double-apply?
- **State deciders**, for every gate or state machine the plan introduces, name the *exact input* that decides each transition (the "what decides EMPTY vs RUN?" question). A transition with no named decider is a hole.
- **Runtime / dependency choice**, if the plan adds a script or dependency, why this runtime, and what is the zero-dependency alternative? (The "why a python script and not node?" question.)

## Output

Lead with a one-line verdict, then items grouped by section, highest impact first, if there are ten concerns, the top three matter most; don't bury them. Stop after the items: no summary, no next steps, nothing that nudges toward exit.

```
Original ask: <one line>
Verdict: <one line>

Cut / defer:
- [Step N / file X]: <what to remove>, because <reason>. Alternative: <what to do instead>.

Reconsider:
- [Step N / file X]: <concern>, because <reason>. Alternative: <instead, for unverified assumptions, the specific probe to run>.

Possibly missing:
- <case / layer / verification gap, incl. any unanswered operator-gauntlet item from step 7>, because <reason>.

Looks right:
- <what you actively checked, say what you opened or grepped, and judged sound>
```

Omit empty sections. "Looks right" is mandatory when there are no cuts, and its entries must reference what you actually inspected in step 1, not what you remember. For a trivial plan (a few steps, one file), compress to the verdict plus whichever single section applies, don't run the full ceremony on a three-line plan.

## Calibration

**Bad (sycophantic):** "The plan looks comprehensive; the abstractions provide good flexibility. Ready when you are.", cites nothing, checked nothing, pushes toward exit.

**Bad (forced):** "Consider simplifying the validation logic. Naming could be clearer. Add tests.", applies to any plan; nothing actionable.

**Good:** "Verdict: scope creep around the migration step, otherwise sound. Cut / defer: Step 4's `MigrationRunner` class, the ask was a one-shot script; `run()/rollback()/dry_run()` is three methods for code that runs once; inline it in the script. Looks right: Steps 1–3 match the request directly (opened `migrate.py`, the transform lives where the plan says)."

The "no concerns" verdict is allowed and sometimes correct. It is not the default, it has to be earned by steps 1–7.

## What not to do

- No `ExitPlanMode`, ever.
- Don't rewrite the plan unasked, surface concerns; the user decides what to revise.
- No nitpicks on naming, formatting, or style, that's not what this checkpoint is for.
- No concern without a named location and a concrete alternative.
- Don't restate the plan back at the user; they wrote it.

Scale the review to the plan. Apply the operator gates where they affect a real decision; do not invent runtime costs or hypothetical failure cases for unrelated work. Respect the active harness's plan-editing permissions.
