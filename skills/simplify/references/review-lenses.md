# Simplify Review Lenses

Use the same cross-cutting rules for every lens:

1. Preserve return values, exceptions, side effects, ordering, and edge-case behavior.
2. Prefer code that is understood faster, not merely code with fewer lines.
3. Follow AGENTS.md and repository conventions over generic preferences. Use CLAUDE.md only as compatibility guidance when AGENTS.md is absent.
4. Report behavior changes separately and do not propose them as cleanup.
5. Do not edit files during review.
6. Review for quality, not correctness. Put a suspected bug you notice in `notes` for the code review; never fix it as cleanup.
7. Keep edits inside or next to the scoped diff. A fix that needs wider changes goes in `notes`.

Each lens must return a JSON object with this shape:

    {
      "findings": [
        {
          "file": "absolute/path",
          "old_string": "unique exact text",
          "new_string": "replacement text",
          "rationale": "one sentence naming the concrete cost: what is duplicated, wasted, or harder to maintain",
          "confidence": "high | medium | low",
          "lens": "reuse | simplification | efficiency | altitude"
        }
      ],
      "notes": [
        {
          "file": "absolute/path",
          "rationale": "a behavior change, a wider change, or a suspected bug, and why it is not cleanup",
          "lens": "reuse | simplification | efficiency | altitude"
        }
      ]
    }

Return empty arrays rather than padding. `notes` feed the report: proposals not applied, and suspected bugs for the code review.

## Reuse lens

Flag new code that re-implements something the codebase already has. Search the wider codebase, especially shared and utility modules and the files next to the change, and name the existing helper to call instead. Look for:

- New functions duplicating an existing helper.
- Hand-written path, environment, parsing, validation, or collection logic already represented by a suitable utility.
- Repeated non-trivial blocks that share a real concept.

Reject reuse that hides a trivial expression, crosses an existing module boundary, or changes edge-case behavior.

## Simplification lens

Flag complexity the diff adds that a simpler form would do the same job, and name that form. Look for:

- Redundant or derivable state.
- Copy-paste with slight variation or meaningful shared structure.
- Deep conditional nesting that can become clear guard clauses.
- Dead code the change left behind.
- Parameter sprawl and leaky abstractions.
- Raw strings where the codebase already defines constants or types.
- Redundant booleans, else branches after return, or unnecessary intermediates.
- Comments that narrate obvious code instead of explaining a non-obvious reason.
- Wrapper elements or helper functions that add no semantic value.

Do not trade clear control flow for dense one-liners or speculative abstractions.

## Efficiency lens

Flag wasted work the diff introduces, and name the cheaper alternative. Look for:

- Repeated computation, file reads, API calls, or N+1 behavior.
- Independent slow operations run one after another that can safely run concurrently.
- Blocking work added to startup or request hot paths.
- Long-lived objects built from closures or captured environments, which keep the whole enclosing scope alive; prefer a class or struct that copies only the fields it needs.
- No-op state updates that still notify downstream consumers.
- Pre-check-then-act filesystem patterns vulnerable to races.
- Unbounded caches, missing cleanup, or listener leaks.
- Whole-file or whole-dataset work when the changed code needs only a bounded portion.

Reject premature optimization and any faster rewrite that changes semantics.

## Altitude lens

Check that each change fixes the root cause at the right depth, not a symptom patched with a fragile workaround. Special cases layered onto shared infrastructure suggest the fix isn't deep enough: prefer one simpler, more general change to the underlying mechanism over another special case, and name that change.

Propose an edit only when the deeper fix is behavior-preserving and stays close to the diff. A deeper fix that changes behavior or reaches wider goes in `notes`.
