# Simplify Review Lenses

Use the same cross-cutting rules for every lens:

1. Preserve return values, exceptions, side effects, ordering, and edge-case behavior.
2. Prefer code that is understood faster, not merely code with fewer lines.
3. Follow AGENTS.md and repository conventions over generic preferences. Use CLAUDE.md only as compatibility guidance when AGENTS.md is absent.
4. Report behavior changes separately and do not propose them as cleanup.
5. Do not edit files during review.

Each lens must return a JSON object with this shape:

    {
      "findings": [
        {
          "file": "absolute/path",
          "old_string": "unique exact text",
          "new_string": "replacement text",
          "rationale": "one sentence",
          "confidence": "high | medium | low",
          "lens": "reuse | quality | efficiency"
        }
      ]
    }

Return an empty findings array rather than padding.

## Reuse lens

Search the wider codebase for:

- New functions duplicating an existing helper.
- Hand-written path, environment, parsing, validation, or collection logic already represented by a suitable utility.
- Repeated non-trivial blocks that share a real concept.

Reject reuse that hides a trivial expression, crosses an existing module boundary, or changes edge-case behavior.

## Quality lens

Look for:

- Redundant or derivable state.
- Parameter sprawl and leaky abstractions.
- Copy-paste with meaningful shared structure.
- Raw strings where the codebase already defines constants or types.
- Redundant booleans, else branches after return, or unnecessary intermediates.
- Deep conditional nesting that can become clear guard clauses.
- Comments that narrate obvious code instead of explaining a non-obvious reason.
- Wrapper elements or helper functions that add no semantic value.

Do not trade clear control flow for dense one-liners or speculative abstractions.

## Efficiency lens

Look for:

- Repeated computation, file reads, API calls, or N+1 behavior.
- Independent slow operations that can safely run concurrently.
- Blocking work added to startup or request hot paths.
- No-op state updates that still notify downstream consumers.
- Pre-check-then-act filesystem patterns vulnerable to races.
- Unbounded caches, missing cleanup, or listener leaks.
- Whole-file or whole-dataset work when the changed code needs only a bounded portion.

Reject premature optimization and any faster rewrite that changes semantics.

